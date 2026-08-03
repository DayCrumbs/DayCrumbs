import Foundation

nonisolated enum GemmaRuntimeError: LocalizedError, Equatable, Sendable {
    case concurrentRequest
    case runtimeUnavailable
    case invalidModelFile
    case cachePreparationFailed
    case initializationFailed
    case conversationFailed
    case generationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .concurrentRequest:
            "Another on-device insight request is still finishing."
        case .runtimeUnavailable:
            "The Gemma runtime is not available in this build."
        case .invalidModelFile:
            "The installed Gemma model could not be opened."
        case .cachePreparationFailed:
            "Gemma could not prepare its on-device cache."
        case .initializationFailed, .conversationFailed, .generationFailed:
            "Gemma could not generate the on-device insight."
        case .cancelled:
            "Gemma insight generation was cancelled."
        }
    }
}

nonisolated protocol GemmaTextGeneratingRuntime: Sendable {
    func generate(
        prompt: GemmaAnalyticsPrompt,
        modelURL: URL,
        configuration: LocalLLMConfiguration
    ) async throws -> String
    func cancel()
    func release() async
}

nonisolated enum GemmaRuntimePolicy {
    /// Two inference workers keep sustained CPU near two fully utilized cores.
    /// LiteRT may still briefly use auxiliary loader/callback threads.
    static let cpuThreadCount = 2
    static let maximumContextTokens = 4_096
}

#if canImport(CLiteRTLM)
import CLiteRTLM

private nonisolated final class GemmaConversationCancellationBox:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var conversation: Conversation?

    func store(_ conversation: Conversation?) {
        lock.lock()
        self.conversation = conversation
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let currentConversation = conversation
        lock.unlock()
        try? currentConversation?.cancel()
    }
}

/// One actor owns one just-in-time LiteRT-LM engine and conversation.
actor LiteRTLMGemmaRuntime: GemmaTextGeneratingRuntime {
    private let cancellationBox = GemmaConversationCancellationBox()
    private var engine: Engine?
    private var conversation: Conversation?
    private var isGenerating = false

    func generate(
        prompt: GemmaAnalyticsPrompt,
        modelURL: URL,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        guard !isGenerating else {
            throw GemmaRuntimeError.concurrentRequest
        }
        guard FileManager.default.isReadableFile(atPath: modelURL.path) else {
            throw GemmaRuntimeError.invalidModelFile
        }

        isGenerating = true
        defer {
            cancellationBox.store(nil)
            conversation = nil
            engine = nil
            isGenerating = false
        }

        try Task.checkCancellation()
        let cacheURL = try makeCacheDirectory()
        let engineConfig: EngineConfig
        do {
            engineConfig = try EngineConfig(
                modelPath: modelURL.path,
                backend: .cpu(
                    threadCount: GemmaRuntimePolicy.cpuThreadCount
                ),
                maxNumTokens: GemmaRuntimePolicy.maximumContextTokens,
                cacheDir: cacheURL.path
            )
        } catch {
            throw GemmaRuntimeError.initializationFailed
        }

        let engine = Engine(engineConfig: engineConfig)
        self.engine = engine
        do {
            try await engine.initialize()
        } catch is CancellationError {
            throw GemmaRuntimeError.cancelled
        } catch {
            throw GemmaRuntimeError.initializationFailed
        }

        try Task.checkCancellation()
        let samplerConfig = try makeSamplerConfig(configuration)
        let conversationConfig = ConversationConfig(
            systemMessage: Message(
                prompt.systemInstructions,
                role: .system
            ),
            samplerConfig: samplerConfig
        )

        let conversation: Conversation
        do {
            conversation = try await engine.createConversation(
                with: conversationConfig
            )
        } catch {
            throw GemmaRuntimeError.conversationFailed
        }
        self.conversation = conversation
        cancellationBox.store(conversation)

        do {
            let response = try await withTaskCancellationHandler {
                try await conversation.sendMessage(
                    Message(prompt.userPrompt, role: .user)
                )
            } onCancel: {
                self.cancellationBox.cancel()
            }
            try Task.checkCancellation()
            return response.toString
        } catch is CancellationError {
            throw GemmaRuntimeError.cancelled
        } catch {
            if Task.isCancelled {
                throw GemmaRuntimeError.cancelled
            }
            throw GemmaRuntimeError.generationFailed
        }
    }

    nonisolated func cancel() {
        cancellationBox.cancel()
    }

    func release() {
        cancellationBox.cancel()
        cancellationBox.store(nil)
        conversation = nil
        engine = nil
        isGenerating = false
    }

    private func makeCacheDirectory() throws -> URL {
        let cacheURL = URL.applicationSupportDirectory
            .appending(path: "LiteRTLMCache")
            .appending(path: LocalModelCatalog.gemma4E2B.id)
        do {
            try FileManager.default.createDirectory(
                at: cacheURL,
                withIntermediateDirectories: true
            )
            return cacheURL
        } catch {
            throw GemmaRuntimeError.cachePreparationFailed
        }
    }

    private func makeSamplerConfig(
        _ configuration: LocalLLMConfiguration
    ) throws -> SamplerConfig {
        let temperature = Float(configuration.temperature ?? 0)
        switch configuration.samplingPolicy {
        case .greedy:
            return try SamplerConfig(
                topK: 1,
                topP: 1,
                temperature: temperature
            )
        case .topK(let value):
            return try SamplerConfig(
                topK: value,
                topP: 1,
                temperature: temperature
            )
        case .probabilityThreshold(let value):
            return try SamplerConfig(
                topK: 40,
                topP: Float(value),
                temperature: temperature
            )
        }
    }
}
#else
nonisolated struct LiteRTLMGemmaRuntime: GemmaTextGeneratingRuntime {
    func generate(
        prompt: GemmaAnalyticsPrompt,
        modelURL: URL,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        throw GemmaRuntimeError.runtimeUnavailable
    }

    func cancel() {}
    func release() async {}
}
#endif

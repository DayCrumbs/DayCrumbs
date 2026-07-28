import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Thin adapter around one fresh SystemLanguageModel session per attempt.
@available(iOS 26.0, *)
@MainActor
final class AppleFoundationModelsTypedRuntime: AppleTypedInsightGeneratingRuntime {
    private var activeSession: LanguageModelSession?

    var availability: AppleFoundationModelAvailability {
        AppleFoundationModelsRuntime.availability
    }

    func generateTypedInsight(
        from context: AnalyticsContext,
        for range: TimeRange,
        configuration: LocalLLMConfiguration
    ) async throws -> AppleGeneratedAnalyticsInsight {
        guard activeSession == nil else {
            throw AppleFoundationModelsSessionError.concurrentRequest
        }

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: Self.instructions
        )
        activeSession = session

        defer {
            if activeSession === session {
                activeSession = nil
            }
        }

        do {
            let response = try await session.respond(
                to: Self.prompt(from: context, for: range),
                generating: AppleGeneratedAnalyticsInsight.self,
                options: Self.options(from: configuration)
            )
            return response.content
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.mapGenerationError(error)
        }
    }

    func releaseSession() {
        // iOS owns the system model; the app only releases its session reference.
        activeSession = nil
    }

    private static let instructions = """
    \(AnalyticsSystemPrompt.text)

    Write every field in English for later on-device localization. Follow the typed \
    schema without JSON, Markdown, or surrounding text.
    """

    private static func prompt(
        from context: AnalyticsContext,
        for range: TimeRange
    ) -> String {
        """
        \(AnalyticsSystemPrompt.scopeInstructions(for: range))

        Analyze only this analytics context:
        \(context.text)
        """
    }

    private static func options(
        from configuration: LocalLLMConfiguration
    ) -> GenerationOptions {
        GenerationOptions(
            sampling: samplingMode(from: configuration.samplingPolicy),
            temperature: configuration.temperature,
            maximumResponseTokens: configuration.outputTokenLimit
        )
    }

    private static func samplingMode(
        from policy: LocalLLMSamplingPolicy
    ) -> GenerationOptions.SamplingMode {
        switch policy {
        case .greedy:
            .greedy
        case .topK(let value):
            .random(top: value)
        case .probabilityThreshold(let value):
            .random(probabilityThreshold: value)
        }
    }

    private static func mapGenerationError(
        _ error: LanguageModelSession.GenerationError
    ) -> AppleFoundationModelsSessionError {
        switch error {
        case .exceededContextWindowSize:
            .exceededContextWindow
        case .assetsUnavailable:
            .assetsUnavailable
        case .guardrailViolation:
            .guardrailViolation
        case .unsupportedGuide:
            .unsupportedGuide
        case .unsupportedLanguageOrLocale:
            .unsupportedLanguageOrLocale
        case .decodingFailure:
            .decodingFailure
        case .rateLimited:
            .rateLimited
        case .concurrentRequests:
            .concurrentRequest
        case .refusal:
            .refusal
        @unknown default:
            .unavailableRuntime
        }
    }
}
#endif

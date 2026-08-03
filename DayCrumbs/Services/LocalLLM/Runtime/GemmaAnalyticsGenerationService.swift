import Foundation

nonisolated enum GemmaAnalyticsGenerationError:
    Error,
    Equatable,
    Sendable
{
    case emptyEntries
    case invalidEntries(AnalyticsContextBuilder.BuildError)
    case generationFailed
    case invalidGeneratedInsight
    case cancelled
}

@MainActor
protocol GemmaAnalyticsInsightGenerating: AnyObject {
    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        modelURL: URL
    ) async throws -> AnalyticsInsight
    func releaseRuntime()
}

@MainActor
final class GemmaAnalyticsGenerationService:
    GemmaAnalyticsInsightGenerating
{
    private let runtime: any GemmaTextGeneratingRuntime
    private let configuration: LocalLLMConfiguration
    private let recoveryConfiguration: LocalLLMConfiguration
    private let promptBuilder: GemmaAnalyticsPromptBuilder
    private let parser: GemmaAnalyticsInsightParser
    private let groundingService: AnalyticsInsightGroundingService
    private let responseLanguageResolver: GemmaResponseLanguageResolver
    private let responseLanguageValidator: GemmaInsightLanguageValidator

    init(
        runtime: any GemmaTextGeneratingRuntime = LiteRTLMGemmaRuntime(),
        configuration: LocalLLMConfiguration = .gemmaCreative,
        recoveryConfiguration: LocalLLMConfiguration = .gemmaRecovery,
        promptBuilder: GemmaAnalyticsPromptBuilder =
            GemmaAnalyticsPromptBuilder(),
        parser: GemmaAnalyticsInsightParser = GemmaAnalyticsInsightParser(),
        groundingService: AnalyticsInsightGroundingService =
            AnalyticsInsightGroundingService(),
        responseLanguageResolver: GemmaResponseLanguageResolver =
            GemmaResponseLanguageResolver(),
        responseLanguageValidator: GemmaInsightLanguageValidator =
            GemmaInsightLanguageValidator()
    ) {
        self.runtime = runtime
        self.configuration = configuration
        self.recoveryConfiguration = recoveryConfiguration
        self.promptBuilder = promptBuilder
        self.parser = parser
        self.groundingService = groundingService
        self.responseLanguageResolver = responseLanguageResolver
        self.responseLanguageValidator = responseLanguageValidator
    }

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        modelURL: URL
    ) async throws -> AnalyticsInsight {
        guard !entries.isEmpty else {
            throw GemmaAnalyticsGenerationError.emptyEntries
        }

        let responseLanguage: GemmaResponseLanguage
        do {
            let completeContext = try AnalyticsContextBuilder(
                configuration: configuration
            ).build(from: entries, eventLimit: .all)
            responseLanguage = responseLanguageResolver.resolve(
                from: completeContext
            )
        } catch let error as AnalyticsContextBuilder.BuildError {
            throw GemmaAnalyticsGenerationError.invalidEntries(error)
        }

        do {
            return try await generateAttempt(
                from: entries,
                for: range,
                modelURL: modelURL,
                eventLimit: .primary,
                configuration: configuration,
                promptMode: .creative,
                responseLanguage: responseLanguage
            )
        } catch is CancellationError {
            throw GemmaAnalyticsGenerationError.cancelled
        } catch GemmaRuntimeError.cancelled {
            throw GemmaAnalyticsGenerationError.cancelled
        } catch let error where isRecoverableOutputError(error) {
            do {
                return try await generateAttempt(
                    from: entries,
                    for: range,
                    modelURL: modelURL,
                    eventLimit: .retry,
                    configuration: recoveryConfiguration,
                    promptMode: .recovery,
                    responseLanguage: responseLanguage
                )
            } catch is CancellationError {
                throw GemmaAnalyticsGenerationError.cancelled
            } catch GemmaRuntimeError.cancelled {
                throw GemmaAnalyticsGenerationError.cancelled
            } catch let error where isRecoverableOutputError(error) {
                throw GemmaAnalyticsGenerationError.invalidGeneratedInsight
            } catch let error as GemmaAnalyticsGenerationError {
                throw error
            } catch {
                throw GemmaAnalyticsGenerationError.generationFailed
            }
        } catch let error as GemmaAnalyticsGenerationError {
            throw error
        } catch {
            throw GemmaAnalyticsGenerationError.generationFailed
        }
    }

    func releaseRuntime() {
        runtime.cancel()
        Task {
            await runtime.release()
        }
    }

    private func generateAttempt(
        from entries: [StoryEntry],
        for range: TimeRange,
        modelURL: URL,
        eventLimit: AnalyticsContextBuilder.EventLimit,
        configuration: LocalLLMConfiguration,
        promptMode: GemmaAnalyticsPromptMode,
        responseLanguage: GemmaResponseLanguage
    ) async throws -> AnalyticsInsight {
        let context: AnalyticsContext
        do {
            context = try AnalyticsContextBuilder(
                configuration: configuration
            ).build(
                from: entries,
                eventLimit: eventLimit
            )
        } catch let error as AnalyticsContextBuilder.BuildError {
            throw GemmaAnalyticsGenerationError.invalidEntries(error)
        }

        let prompt = promptBuilder.prompt(
            from: context,
            for: range,
            configuration: configuration,
            mode: promptMode,
            responseLanguage: responseLanguage
        )
        do {
            let output = try await runtime.generate(
                prompt: prompt,
                modelURL: modelURL,
                configuration: configuration
            )
            let insight = try parser.parse(output)
            try responseLanguageValidator.validate(
                insight,
                expected: responseLanguage
            )
            await runtime.release()
            return groundingService.grounded(insight, in: context)
        } catch {
            // Complete release before a smaller-context retry may start. An
            // unstructured deferred task could otherwise clear the new engine.
            await runtime.release()
            throw error
        }
    }

    private func isRecoverableOutputError(_ error: Error) -> Bool {
        error is GemmaAnalyticsInsightParsingError
            || error is GemmaInsightLanguageValidationError
    }
}

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

    Apple typed-output rules:
    - Write every generated field in English. A separate on-device layer localizes it later.
    - Follow the provided typed schema. Do not return JSON, Markdown, or surrounding chat text.
    - When the context contains only one or very few observations, explicitly state that the insight is based on limited data. Do not claim a repeated pattern or trend.
    """

    private static func prompt(
        from context: AnalyticsContext,
        for range: TimeRange
    ) -> String {
        """
        Analyze only the following analytics context and produce the typed insight.

        \(AnalyticsSystemPrompt.scopeInstructions(for: range))

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

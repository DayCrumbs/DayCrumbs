import Foundation

/// View-bound input preparation can call AppleInsightTranslationFlow in Section 3.
typealias AppleAnalyticsInputPreparationHandler = @MainActor @Sendable (
    AnalyticsContext
) async -> AppleInsightInputPreparationResult

nonisolated struct AppleAnalyticsGenerationResult: Equatable, Sendable {
    let englishInsight: AnalyticsInsight
    let responseLanguage: LanguageIdentifier
}

nonisolated enum AppleFoundationModelsSessionError: Error, Equatable, Sendable {
    case exceededContextWindow
    case assetsUnavailable
    case guardrailViolation
    case unsupportedGuide
    case unsupportedLanguageOrLocale
    case decodingFailure
    case rateLimited
    case concurrentRequest
    case refusal
    case unavailableRuntime

    var allowsSmallerContextRetry: Bool {
        switch self {
        case .exceededContextWindow, .decodingFailure:
            true
        default:
            false
        }
    }
}

nonisolated enum AppleAnalyticsGenerationError: Error, Equatable, Sendable {
    case emptyEntries
    case invalidEntries(AnalyticsContextBuilder.BuildError)
    case modelUnavailable(AppleFoundationModelAvailability)
    case inputTranslationBlocked(AppleInsightTranslationFailure)
    case invalidGeneratedInsight(AnalyticsInsight.ValidationError)
    case generationFailed(AppleFoundationModelsSessionError)
    case concurrentRequest
    case cancelled
}

@MainActor
protocol AnalyticsInsightGenerating {
    func generateInsight(
        from entries: [StoryEntry],
        preparingInputWith prepareInput: AppleAnalyticsInputPreparationHandler
    ) async throws -> AppleAnalyticsGenerationResult

    /// Releases app-owned transient runtime references. The owning Task handles cancellation.
    func releaseSession()
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@MainActor
protocol AppleTypedInsightGeneratingRuntime: AnyObject {
    var availability: AppleFoundationModelAvailability { get }

    func generateTypedInsight(
        from context: AnalyticsContext,
        configuration: LocalLLMConfiguration
    ) async throws -> AppleGeneratedAnalyticsInsight

    func releaseSession()
}
#endif

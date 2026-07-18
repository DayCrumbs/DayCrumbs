import Foundation

#if canImport(FoundationModels)
/// Apple-only pipeline joining input translation, typed generation, and localization.
@available(iOS 26.0, *)
@MainActor
protocol AppleLocalizedInsightGenerating: AnyObject {
    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> AppleLocalizedAnalyticsInsight

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight

    func releaseSession()
}

/// Keeps Gemma outside Apple's native translation path by construction.
@available(iOS 26.0, *)
@MainActor
final class AppleLocalizedInsightGenerationService: AppleLocalizedInsightGenerating {
    private let generationService: any AnalyticsInsightGenerating
    private let translationFlow: any AppleInsightTranslationFlow
    private let localizationService: any AppleAnalyticsInsightLocalizing

    init() {
        let translationFlow = AppleInsightTranslationFlowService()
        generationService = AppleAnalyticsGenerationService()
        self.translationFlow = translationFlow
        localizationService = AppleAnalyticsInsightLocalizationService(
            translationFlow: translationFlow
        )
    }

    init(
        generationService: any AnalyticsInsightGenerating,
        translationFlow: any AppleInsightTranslationFlow
    ) {
        self.generationService = generationService
        self.translationFlow = translationFlow
        localizationService = AppleAnalyticsInsightLocalizationService(
            translationFlow: translationFlow
        )
    }

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> AppleLocalizedAnalyticsInsight {
        let generationResult = try await generationService.generateInsight(
            from: entries,
            for: range
        ) { [translationFlow] context in
            await translationFlow.prepareInputContext(
                context,
                using: executeBatch
            )
        }

        return await localizationService.localize(
            generationResult.englishInsight,
            to: generationResult.responseLanguage,
            using: executeBatch
        )
    }

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight {
        // No StoryEntry or generation service is accepted on this retry path.
        await localizationService.retryOutputTranslation(
            fallback,
            using: executeBatch
        )
    }

    func releaseSession() {
        generationService.releaseSession()
    }
}
#endif

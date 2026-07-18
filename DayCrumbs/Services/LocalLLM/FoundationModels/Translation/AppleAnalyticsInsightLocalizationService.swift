import Foundation

/// Domain fallback keeps the validated English insight alongside translation metadata.
nonisolated struct AppleAnalyticsInsightEnglishFallback: Equatable, Sendable {
    let englishInsight: AnalyticsInsight
    let translationFallback: AppleInsightEnglishFallback

    var displayLabel: String {
        translationFallback.displayLabel
    }

    var failure: AppleInsightTranslationFailure {
        translationFallback.failure
    }
}

/// Presentation-ready output; English fallback remains usable after localization fails.
nonisolated struct AppleLocalizedAnalyticsInsight: Equatable, Sendable {
    let insight: AnalyticsInsight
    let responseLanguage: LanguageIdentifier
    let englishFallback: AppleAnalyticsInsightEnglishFallback?

    var isEnglishFallback: Bool {
        englishFallback != nil
    }
}

@MainActor
protocol AppleAnalyticsInsightLocalizing {
    func localize(
        _ englishInsight: AnalyticsInsight,
        to responseLanguage: LanguageIdentifier,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight

    /// Accepting only preserved output makes this retry unable to regenerate an insight.
    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight
}

@MainActor
struct AppleAnalyticsInsightLocalizationService: AppleAnalyticsInsightLocalizing {
    private let translationFlow: any AppleInsightTranslationFlow
    private let mapper: AnalyticsInsightTranslationMapper

    init() {
        translationFlow = AppleInsightTranslationFlowService()
        mapper = AnalyticsInsightTranslationMapper()
    }

    init(
        translationFlow: any AppleInsightTranslationFlow,
        mapper: AnalyticsInsightTranslationMapper = AnalyticsInsightTranslationMapper()
    ) {
        self.translationFlow = translationFlow
        self.mapper = mapper
    }

    func localize(
        _ englishInsight: AnalyticsInsight,
        to responseLanguage: LanguageIdentifier,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight {
        let englishTexts = mapper.identifiedTexts(from: englishInsight)
        let result = await translationFlow.localizeGeneratedTexts(
            englishTexts,
            to: responseLanguage,
            using: executeBatch
        )

        return localizedResult(
            from: result,
            preserving: englishInsight,
            targetLanguage: responseLanguage
        )
    }

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight {
        let result = await translationFlow.retryOutputTranslation(
            fallback.translationFallback,
            using: executeBatch
        )

        return localizedResult(
            from: result,
            preserving: fallback.englishInsight,
            targetLanguage: fallback.translationFallback.targetLanguage
        )
    }

    private func localizedResult(
        from result: AppleInsightOutputTranslationResult,
        preserving englishInsight: AnalyticsInsight,
        targetLanguage: LanguageIdentifier
    ) -> AppleLocalizedAnalyticsInsight {
        switch result {
        case .localized(let localizedTexts):
            do {
                let localizedInsight = try mapper.reconstructedInsight(
                    from: localizedTexts,
                    matching: englishInsight
                )
                return AppleLocalizedAnalyticsInsight(
                    insight: localizedInsight,
                    responseLanguage: targetLanguage,
                    englishFallback: nil
                )
            } catch {
                // Unsafe reconstruction must never replace the validated English result.
                return makeFallback(
                    preserving: englishInsight,
                    targetLanguage: targetLanguage,
                    reason: .invalidTranslationData
                )
            }

        case .englishFallback(let translationFallback):
            return AppleLocalizedAnalyticsInsight(
                insight: englishInsight,
                responseLanguage: targetLanguage,
                englishFallback: AppleAnalyticsInsightEnglishFallback(
                    englishInsight: englishInsight,
                    translationFallback: translationFallback
                )
            )
        }
    }

    private func makeFallback(
        preserving englishInsight: AnalyticsInsight,
        targetLanguage: LanguageIdentifier,
        reason: AppleInsightTranslationFailure.Reason
    ) -> AppleLocalizedAnalyticsInsight {
        let translationFallback = AppleInsightEnglishFallback(
            englishTexts: mapper.identifiedTexts(from: englishInsight),
            targetLanguage: targetLanguage,
            failure: AppleInsightTranslationFailure(
                stage: .output,
                reason: reason,
                pair: TranslationLanguagePair(
                    source: .english,
                    target: targetLanguage
                )
            )
        )

        return AppleLocalizedAnalyticsInsight(
            insight: englishInsight,
            responseLanguage: targetLanguage,
            englishFallback: AppleAnalyticsInsightEnglishFallback(
                englishInsight: englishInsight,
                translationFallback: translationFallback
            )
        )
    }
}

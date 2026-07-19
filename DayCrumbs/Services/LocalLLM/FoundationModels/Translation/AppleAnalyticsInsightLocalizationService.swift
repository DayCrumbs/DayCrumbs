import Foundation

/// Domain fallback keeps the validated English insight alongside translation metadata.
nonisolated struct AppleAnalyticsInsightEnglishFallback: Equatable, Sendable {
    let englishInsight: AnalyticsInsight
    let englishTriggerDetails: [TriggerDetail]
    let translationFallback: AppleInsightEnglishFallback

    init(
        englishInsight: AnalyticsInsight,
        englishTriggerDetails: [TriggerDetail] = [],
        translationFallback: AppleInsightEnglishFallback
    ) {
        self.englishInsight = englishInsight
        self.englishTriggerDetails = englishTriggerDetails
        self.translationFallback = translationFallback
    }

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
    let triggerDetails: [TriggerDetail]
    let responseLanguage: LanguageIdentifier
    let englishFallback: AppleAnalyticsInsightEnglishFallback?

    init(
        insight: AnalyticsInsight,
        triggerDetails: [TriggerDetail] = [],
        responseLanguage: LanguageIdentifier,
        englishFallback: AppleAnalyticsInsightEnglishFallback?
    ) {
        self.insight = insight
        self.triggerDetails = triggerDetails
        self.responseLanguage = responseLanguage
        self.englishFallback = englishFallback
    }

    var isEnglishFallback: Bool {
        englishFallback != nil
    }
}

@MainActor
protocol AppleAnalyticsInsightLocalizing {
    func localize(
        _ englishInsight: AnalyticsInsight,
        triggerDetails englishTriggerDetails: [TriggerDetail],
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
    private let triggerDetailMapper: TriggerDetailTranslationMapper

    init() {
        translationFlow = AppleInsightTranslationFlowService()
        mapper = AnalyticsInsightTranslationMapper()
        triggerDetailMapper = TriggerDetailTranslationMapper()
    }

    init(
        translationFlow: any AppleInsightTranslationFlow,
        mapper: AnalyticsInsightTranslationMapper = AnalyticsInsightTranslationMapper(),
        triggerDetailMapper: TriggerDetailTranslationMapper =
            TriggerDetailTranslationMapper()
    ) {
        self.translationFlow = translationFlow
        self.mapper = mapper
        self.triggerDetailMapper = triggerDetailMapper
    }

    func localize(
        _ englishInsight: AnalyticsInsight,
        triggerDetails englishTriggerDetails: [TriggerDetail],
        to responseLanguage: LanguageIdentifier,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight {
        let englishTexts = combinedEnglishTexts(
            insight: englishInsight,
            triggerDetails: englishTriggerDetails
        )
        let result = await translationFlow.localizeGeneratedTexts(
            englishTexts,
            to: responseLanguage,
            using: executeBatch
        )

        return localizedResult(
            from: result,
            preserving: englishInsight,
            englishTriggerDetails: englishTriggerDetails,
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
            englishTriggerDetails: fallback.englishTriggerDetails,
            targetLanguage: fallback.translationFallback.targetLanguage
        )
    }

    private func localizedResult(
        from result: AppleInsightOutputTranslationResult,
        preserving englishInsight: AnalyticsInsight,
        englishTriggerDetails: [TriggerDetail],
        targetLanguage: LanguageIdentifier
    ) -> AppleLocalizedAnalyticsInsight {
        switch result {
        case .localized(let localizedTexts):
            do {
                try validateIdentifiers(
                    in: localizedTexts,
                    expected: combinedEnglishTexts(
                        insight: englishInsight,
                        triggerDetails: englishTriggerDetails
                    )
                )
                let localizedInsightTexts = localizedTexts.filter {
                    !$0.id.hasPrefix(
                        TriggerDetailTranslationMapper.identifierPrefix
                    )
                }
                let localizedTriggerDetailTexts = localizedTexts.filter {
                    $0.id.hasPrefix(
                        TriggerDetailTranslationMapper.identifierPrefix
                    )
                }
                let localizedInsight = try mapper.reconstructedInsight(
                    from: localizedInsightTexts,
                    matching: englishInsight
                )
                let localizedTriggerDetails =
                    try triggerDetailMapper.reconstructedTriggerDetails(
                        from: localizedTriggerDetailTexts,
                        matching: englishTriggerDetails,
                        englishInsight: englishInsight,
                        localizedInsight: localizedInsight
                    )
                return AppleLocalizedAnalyticsInsight(
                    insight: localizedInsight,
                    triggerDetails: localizedTriggerDetails,
                    responseLanguage: targetLanguage,
                    englishFallback: nil
                )
            } catch {
                // Unsafe reconstruction must never replace the validated English result.
                return makeFallback(
                    preserving: englishInsight,
                    englishTriggerDetails: englishTriggerDetails,
                    targetLanguage: targetLanguage,
                    reason: .invalidTranslationData
                )
            }

        case .englishFallback(let translationFallback):
            return AppleLocalizedAnalyticsInsight(
                insight: englishInsight,
                triggerDetails: englishTriggerDetails,
                responseLanguage: targetLanguage,
                englishFallback: AppleAnalyticsInsightEnglishFallback(
                    englishInsight: englishInsight,
                    englishTriggerDetails: englishTriggerDetails,
                    translationFallback: translationFallback
                )
            )
        }
    }

    private func makeFallback(
        preserving englishInsight: AnalyticsInsight,
        englishTriggerDetails: [TriggerDetail],
        targetLanguage: LanguageIdentifier,
        reason: AppleInsightTranslationFailure.Reason
    ) -> AppleLocalizedAnalyticsInsight {
        let translationFallback = AppleInsightEnglishFallback(
            englishTexts: combinedEnglishTexts(
                insight: englishInsight,
                triggerDetails: englishTriggerDetails
            ),
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
            triggerDetails: englishTriggerDetails,
            responseLanguage: targetLanguage,
            englishFallback: AppleAnalyticsInsightEnglishFallback(
                englishInsight: englishInsight,
                englishTriggerDetails: englishTriggerDetails,
                translationFallback: translationFallback
            )
        )
    }

    private func combinedEnglishTexts(
        insight: AnalyticsInsight,
        triggerDetails: [TriggerDetail]
    ) -> [IdentifiedTranslationText] {
        mapper.identifiedTexts(from: insight)
            + triggerDetailMapper.identifiedTexts(from: triggerDetails)
    }

    private func validateIdentifiers(
        in localizedTexts: [IdentifiedTranslationText],
        expected englishTexts: [IdentifiedTranslationText]
    ) throws {
        let expectedIdentifiers = Set(englishTexts.map(\.id))
        var localizedIdentifiers: Set<String> = []

        for localizedText in localizedTexts {
            guard expectedIdentifiers.contains(localizedText.id) else {
                throw AnalyticsInsightTranslationMappingError.unexpectedIdentifier(
                    localizedText.id
                )
            }
            guard localizedIdentifiers.insert(localizedText.id).inserted else {
                throw AnalyticsInsightTranslationMappingError.duplicateIdentifier(
                    localizedText.id
                )
            }
        }

        for expectedText in englishTexts
        where !localizedIdentifiers.contains(expectedText.id) {
            throw AnalyticsInsightTranslationMappingError.missingIdentifier(
                expectedText.id
            )
        }
    }
}

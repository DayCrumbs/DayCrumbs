import Foundation

nonisolated enum AnalyticsInsightTranslationMappingError: Error, Equatable, Sendable {
    case duplicateIdentifier(String)
    case missingIdentifier(String)
    case unexpectedIdentifier(String)
    case emptyIdentifier(String)
    case shapeMismatch
    case invalidInsight(AnalyticsInsight.ValidationError)
}

/// Converts every model-authored insight field to stable translation requests.
nonisolated struct AnalyticsInsightTranslationMapper: Sendable {
    func identifiedTexts(
        from insight: AnalyticsInsight
    ) -> [IdentifiedTranslationText] {
        var texts = [
            IdentifiedTranslationText(id: FieldID.summary, text: insight.summary),
        ]

        for (index, trigger) in insight.commonTriggers.enumerated() {
            texts.append(
                IdentifiedTranslationText(
                    id: FieldID.triggerTitle(index),
                    text: trigger.title
                )
            )
            texts.append(
                IdentifiedTranslationText(
                    id: FieldID.triggerExplanation(index),
                    text: trigger.explanation
                )
            )
        }

        for (index, pattern) in insight.observedPatterns.enumerated() {
            texts.append(
                IdentifiedTranslationText(
                    id: FieldID.patternTitle(index),
                    text: pattern.title
                )
            )
            texts.append(
                IdentifiedTranslationText(
                    id: FieldID.patternEvidence(index),
                    text: pattern.evidence
                )
            )

            if let linkedTrigger = pattern.linkedTrigger {
                texts.append(
                    IdentifiedTranslationText(
                        id: FieldID.patternLinkedTrigger(index),
                        text: linkedTrigger
                    )
                )
            }

            for (tagIndex, tag) in pattern.contextTags.enumerated() {
                texts.append(
                    IdentifiedTranslationText(
                        id: FieldID.patternContextTag(index, tagIndex),
                        text: tag
                    )
                )
            }
        }

        texts.append(
            IdentifiedTranslationText(
                id: FieldID.parentReflectionPrompt,
                text: insight.parentReflectionPrompt
            )
        )
        texts.append(
            IdentifiedTranslationText(
                id: FieldID.ethicalNote,
                text: insight.ethicalNote
            )
        )
        return texts
    }

    /// Rebuilds the same insight shape while replacing only translated text.
    func reconstructedInsight(
        from translatedTexts: [IdentifiedTranslationText],
        matching englishInsight: AnalyticsInsight
    ) throws -> AnalyticsInsight {
        let expectedTexts = identifiedTexts(from: englishInsight)
        let expectedIdentifiers = Set(expectedTexts.map(\.id))
        var translatedByIdentifier: [String: String] = [:]

        for translatedText in translatedTexts {
            guard expectedIdentifiers.contains(translatedText.id) else {
                throw AnalyticsInsightTranslationMappingError.unexpectedIdentifier(
                    translatedText.id
                )
            }
            guard translatedByIdentifier[translatedText.id] == nil else {
                throw AnalyticsInsightTranslationMappingError.duplicateIdentifier(
                    translatedText.id
                )
            }
            translatedByIdentifier[translatedText.id] = translatedText.text
        }

        for expectedText in expectedTexts
        where translatedByIdentifier[expectedText.id] == nil {
            throw AnalyticsInsightTranslationMappingError.missingIdentifier(
                expectedText.id
            )
        }

        let triggers = try englishInsight.commonTriggers.enumerated().map {
            index, _ in
            AnalyticsInsight.CommonTrigger(
                title: try text(
                    for: FieldID.triggerTitle(index),
                    in: translatedByIdentifier
                ),
                explanation: try text(
                    for: FieldID.triggerExplanation(index),
                    in: translatedByIdentifier
                )
            )
        }

        let patterns = try englishInsight.observedPatterns.enumerated().map {
            index, pattern in
            let linkedTrigger = try pattern.linkedTrigger.map { _ in
                try text(
                    for: FieldID.patternLinkedTrigger(index),
                    in: translatedByIdentifier
                )
            }
            let contextTags = try pattern.contextTags.indices.map { tagIndex in
                try text(
                    for: FieldID.patternContextTag(index, tagIndex),
                    in: translatedByIdentifier
                )
            }

            return AnalyticsInsight.ObservedPattern(
                title: try text(
                    for: FieldID.patternTitle(index),
                    in: translatedByIdentifier
                ),
                evidence: try text(
                    for: FieldID.patternEvidence(index),
                    in: translatedByIdentifier
                ),
                linkedTrigger: linkedTrigger,
                contextTags: contextTags
            )
        }

        do {
            return try AnalyticsInsight(
                validatingSummary: text(
                    for: FieldID.summary,
                    in: translatedByIdentifier
                ),
                commonTriggers: triggers,
                observedPatterns: patterns,
                parentReflectionPrompt: text(
                    for: FieldID.parentReflectionPrompt,
                    in: translatedByIdentifier
                ),
                ethicalNote: text(
                    for: FieldID.ethicalNote,
                    in: translatedByIdentifier
                )
            )
        } catch let error as AnalyticsInsight.ValidationError {
            throw AnalyticsInsightTranslationMappingError.invalidInsight(error)
        }
    }

    private func text(
        for identifier: String,
        in translations: [String: String]
    ) throws -> String {
        guard let translatedText = translations[identifier] else {
            throw AnalyticsInsightTranslationMappingError.missingIdentifier(identifier)
        }
        return translatedText
    }
}

/// Translates only reviewed catalog copy and its section labels.
///
/// Generated trigger/evidence text is reconstructed from the already-localized
/// AnalyticsInsight, while source labels remain unchanged proper names.
nonisolated struct TriggerDetailTranslationMapper: Sendable {
    static let identifierPrefix = "recommendations."

    func identifiedTexts(
        from triggerDetails: [TriggerDetail]
    ) -> [IdentifiedTranslationText] {
        guard !triggerDetails.isEmpty else {
            return []
        }

        var texts = [
            IdentifiedTranslationText(
                id: FieldID.recommendedActivitiesLabel,
                text: TriggerDetail.SectionLabels.english.recommendedActivities
            ),
            IdentifiedTranslationText(
                id: FieldID.whatMayHelpLabel,
                text: TriggerDetail.SectionLabels.english.whatMayHelp
            ),
            IdentifiedTranslationText(
                id: FieldID.curatedSourcesLabel,
                text: TriggerDetail.SectionLabels.english.curatedSources
            ),
        ]

        for (detailIndex, detail) in triggerDetails.enumerated() {
            texts.append(
                IdentifiedTranslationText(
                    id: FieldID.recommendationTitle(detailIndex),
                    text: detail.recommendationTitle
                )
            )

            let indexedActivities = detail.recommendedActivities.enumerated()
            for (activityIndex, activity) in indexedActivities {
                texts.append(
                    IdentifiedTranslationText(
                        id: FieldID.recommendedActivity(
                            detailIndex,
                            activityIndex
                        ),
                        text: activity
                    )
                )
            }

            for (helpIndex, suggestion) in detail.whatMayHelp.enumerated() {
                texts.append(
                    IdentifiedTranslationText(
                        id: FieldID.whatMayHelp(detailIndex, helpIndex),
                        text: suggestion
                    )
                )
            }
        }

        return texts
    }

    /// Restores localized generated evidence and translated curated copy by index.
    func reconstructedTriggerDetails(
        from translatedTexts: [IdentifiedTranslationText],
        matching englishDetails: [TriggerDetail],
        englishInsight: AnalyticsInsight,
        localizedInsight: AnalyticsInsight
    ) throws -> [TriggerDetail] {
        guard englishDetails.count == englishInsight.commonTriggers.count,
              localizedInsight.commonTriggers.count
                == englishInsight.commonTriggers.count,
              localizedInsight.observedPatterns.count
                == englishInsight.observedPatterns.count else {
            throw AnalyticsInsightTranslationMappingError.shapeMismatch
        }
        guard !englishDetails.isEmpty else {
            guard translatedTexts.isEmpty else {
                throw AnalyticsInsightTranslationMappingError.unexpectedIdentifier(
                    translatedTexts[0].id
                )
            }
            return []
        }

        let translatedByIdentifier = try translationsByIdentifier(
            translatedTexts,
            expectedTexts: identifiedTexts(from: englishDetails)
        )
        let sectionLabels = TriggerDetail.SectionLabels(
            recommendedActivities: try text(
                for: FieldID.recommendedActivitiesLabel,
                in: translatedByIdentifier
            ),
            whatMayHelp: try text(
                for: FieldID.whatMayHelpLabel,
                in: translatedByIdentifier
            ),
            curatedSources: try text(
                for: FieldID.curatedSourcesLabel,
                in: translatedByIdentifier
            )
        )

        return try englishDetails.enumerated().map { detailIndex, detail in
            let englishTrigger = englishInsight.commonTriggers[detailIndex]
            let localizedTrigger = localizedInsight.commonTriggers[detailIndex]
            let linkedPatternIndices = englishInsight.observedPatterns.indices.filter {
                guard let linkedTrigger =
                    englishInsight.observedPatterns[$0].linkedTrigger else {
                    return false
                }
                return Self.normalized(linkedTrigger)
                    == Self.normalized(englishTrigger.title)
            }

            guard linkedPatternIndices.count == detail.evidence.count else {
                throw AnalyticsInsightTranslationMappingError.shapeMismatch
            }

            let localizedEvidence = linkedPatternIndices.map { patternIndex in
                let pattern = localizedInsight.observedPatterns[patternIndex]
                return TriggerDetail.Evidence(
                    title: pattern.title,
                    explanation: pattern.evidence,
                    contextTags: pattern.contextTags
                )
            }
            let activities = try detail.recommendedActivities.indices.map {
                activityIndex in
                try text(
                    for: FieldID.recommendedActivity(
                        detailIndex,
                        activityIndex
                    ),
                    in: translatedByIdentifier
                )
            }
            let suggestions = try detail.whatMayHelp.indices.map { helpIndex in
                try text(
                    for: FieldID.whatMayHelp(detailIndex, helpIndex),
                    in: translatedByIdentifier
                )
            }

            return TriggerDetail(
                title: localizedTrigger.title,
                explanation: localizedTrigger.explanation,
                evidence: localizedEvidence,
                recommendationTitle: try text(
                    for: FieldID.recommendationTitle(detailIndex),
                    in: translatedByIdentifier
                ),
                recommendedActivities: activities,
                whatMayHelp: suggestions,
                sourceLabels: detail.sourceLabels,
                sectionLabels: sectionLabels
            )
        }
    }

    private func translationsByIdentifier(
        _ translatedTexts: [IdentifiedTranslationText],
        expectedTexts: [IdentifiedTranslationText]
    ) throws -> [String: String] {
        let expectedIdentifiers = Set(expectedTexts.map(\.id))
        var translatedByIdentifier: [String: String] = [:]

        for translatedText in translatedTexts {
            guard expectedIdentifiers.contains(translatedText.id) else {
                throw AnalyticsInsightTranslationMappingError.unexpectedIdentifier(
                    translatedText.id
                )
            }
            guard translatedByIdentifier[translatedText.id] == nil else {
                throw AnalyticsInsightTranslationMappingError.duplicateIdentifier(
                    translatedText.id
                )
            }
            translatedByIdentifier[translatedText.id] = translatedText.text
        }

        for expectedText in expectedTexts
        where translatedByIdentifier[expectedText.id] == nil {
            throw AnalyticsInsightTranslationMappingError.missingIdentifier(
                expectedText.id
            )
        }

        return translatedByIdentifier
    }

    private func text(
        for identifier: String,
        in translations: [String: String]
    ) throws -> String {
        guard let translatedText = translations[identifier] else {
            throw AnalyticsInsightTranslationMappingError.missingIdentifier(identifier)
        }

        let normalizedText = translatedText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalizedText.isEmpty else {
            throw AnalyticsInsightTranslationMappingError.emptyIdentifier(identifier)
        }
        return normalizedText
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }
}

private extension AnalyticsInsightTranslationMapper {
    nonisolated enum FieldID {
        static let summary = "analytics.summary"
        static let parentReflectionPrompt = "analytics.parentReflectionPrompt"
        static let ethicalNote = "analytics.ethicalNote"

        static func triggerTitle(_ index: Int) -> String {
            "analytics.commonTriggers.\(index).title"
        }

        static func triggerExplanation(_ index: Int) -> String {
            "analytics.commonTriggers.\(index).explanation"
        }

        static func patternTitle(_ index: Int) -> String {
            "analytics.observedPatterns.\(index).title"
        }

        static func patternEvidence(_ index: Int) -> String {
            "analytics.observedPatterns.\(index).evidence"
        }

        static func patternLinkedTrigger(_ index: Int) -> String {
            "analytics.observedPatterns.\(index).linkedTrigger"
        }

        static func patternContextTag(_ index: Int, _ tagIndex: Int) -> String {
            "analytics.observedPatterns.\(index).contextTags.\(tagIndex)"
        }
    }
}

private extension TriggerDetailTranslationMapper {
    nonisolated enum FieldID {
        static let recommendedActivitiesLabel =
            "recommendations.labels.recommendedActivities"
        static let whatMayHelpLabel = "recommendations.labels.whatMayHelp"
        static let curatedSourcesLabel = "recommendations.labels.curatedSources"

        static func recommendationTitle(_ detailIndex: Int) -> String {
            "recommendations.\(detailIndex).title"
        }

        static func recommendedActivity(
            _ detailIndex: Int,
            _ activityIndex: Int
        ) -> String {
            "recommendations.\(detailIndex).activities.\(activityIndex)"
        }

        static func whatMayHelp(
            _ detailIndex: Int,
            _ helpIndex: Int
        ) -> String {
            "recommendations.\(detailIndex).whatMayHelp.\(helpIndex)"
        }
    }
}

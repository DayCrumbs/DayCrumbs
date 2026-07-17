import Foundation

nonisolated enum AnalyticsInsightTranslationMappingError: Error, Equatable, Sendable {
    case duplicateIdentifier(String)
    case missingIdentifier(String)
    case unexpectedIdentifier(String)
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

private extension AnalyticsInsightTranslationMapper {
    enum FieldID {
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

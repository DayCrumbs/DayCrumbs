import Foundation

/// Shared, engine-neutral insight displayed by the Dashboard.
nonisolated struct AnalyticsInsight: Equatable, Sendable {
    struct CommonTrigger: Equatable, Sendable {
        let title: String
        let explanation: String
    }

    struct ObservedPattern: Equatable, Sendable {
        let title: String
        let evidence: String
        let linkedTrigger: String?
        let contextTags: [String]
    }

    /// Optional, low-risk ideas authored by a runtime that supports creative
    /// suggestions. Apple Foundation Models can leave this empty and continue
    /// using the reviewed local recommendation catalog.
    struct ParentSuggestion: Equatable, Sendable {
        let linkedTrigger: String
        let title: String
        let recommendedActivities: [String]
        let whatMayHelp: [String]
    }

    let summary: String
    let commonTriggers: [CommonTrigger]
    let observedPatterns: [ObservedPattern]
    let parentSuggestions: [ParentSuggestion]
    let parentReflectionPrompt: String
    let ethicalNote: String

    init(
        summary: String,
        commonTriggers: [CommonTrigger],
        observedPatterns: [ObservedPattern],
        parentSuggestions: [ParentSuggestion] = [],
        parentReflectionPrompt: String,
        ethicalNote: String
    ) {
        self.summary = summary
        self.commonTriggers = commonTriggers
        self.observedPatterns = observedPatterns
        self.parentSuggestions = parentSuggestions
        self.parentReflectionPrompt = parentReflectionPrompt
        self.ethicalNote = ethicalNote
    }
}

extension AnalyticsInsight {
    nonisolated enum ValidationError: Error, Equatable, Sendable {
        case emptySummary
        case emptyTriggerTitle
        case emptyTriggerExplanation
        case emptyPatternTitle
        case emptyPatternEvidence
        case emptySuggestionLinkedTrigger
        case emptySuggestionTitle
        case emptyRecommendedActivities
        case emptyWhatMayHelp
        case emptyParentReflectionPrompt
        case emptyEthicalNote
    }

    /// Normalizes model-authored whitespace and rejects incomplete typed output.
    nonisolated init(
        validatingSummary summary: String,
        commonTriggers: [CommonTrigger],
        observedPatterns: [ObservedPattern],
        parentSuggestions: [ParentSuggestion] = [],
        parentReflectionPrompt: String,
        ethicalNote: String
    ) throws {
        let summary = Self.normalized(summary)
        guard !summary.isEmpty else {
            throw ValidationError.emptySummary
        }

        let commonTriggers = try commonTriggers.map { trigger in
            let title = Self.normalized(trigger.title)
            guard !title.isEmpty else {
                throw ValidationError.emptyTriggerTitle
            }

            let explanation = Self.normalized(trigger.explanation)
            guard !explanation.isEmpty else {
                throw ValidationError.emptyTriggerExplanation
            }

            return CommonTrigger(title: title, explanation: explanation)
        }

        let observedPatterns = try observedPatterns.map { pattern in
            let title = Self.normalized(pattern.title)
            guard !title.isEmpty else {
                throw ValidationError.emptyPatternTitle
            }

            let evidence = Self.normalized(pattern.evidence)
            guard !evidence.isEmpty else {
                throw ValidationError.emptyPatternEvidence
            }

            let linkedTrigger = pattern.linkedTrigger.map(Self.normalized)
                .flatMap { $0.isEmpty ? nil : $0 }
            let contextTags = pattern.contextTags
                .map(Self.normalized)
                .filter { !$0.isEmpty }

            return ObservedPattern(
                title: title,
                evidence: evidence,
                linkedTrigger: linkedTrigger,
                contextTags: contextTags
            )
        }

        let parentSuggestions = try parentSuggestions.map { suggestion in
            let linkedTrigger = Self.normalized(suggestion.linkedTrigger)
            guard !linkedTrigger.isEmpty else {
                throw ValidationError.emptySuggestionLinkedTrigger
            }

            let title = Self.normalized(suggestion.title)
            guard !title.isEmpty else {
                throw ValidationError.emptySuggestionTitle
            }

            let recommendedActivities = suggestion.recommendedActivities
                .map(Self.normalized)
                .filter { !$0.isEmpty }
            guard !recommendedActivities.isEmpty else {
                throw ValidationError.emptyRecommendedActivities
            }

            let whatMayHelp = suggestion.whatMayHelp
                .map(Self.normalized)
                .filter { !$0.isEmpty }
            guard !whatMayHelp.isEmpty else {
                throw ValidationError.emptyWhatMayHelp
            }

            return ParentSuggestion(
                linkedTrigger: linkedTrigger,
                title: title,
                recommendedActivities: recommendedActivities,
                whatMayHelp: whatMayHelp
            )
        }

        let parentReflectionPrompt = Self.normalized(parentReflectionPrompt)
        guard !parentReflectionPrompt.isEmpty else {
            throw ValidationError.emptyParentReflectionPrompt
        }

        let ethicalNote = Self.normalized(ethicalNote)
        guard !ethicalNote.isEmpty else {
            throw ValidationError.emptyEthicalNote
        }

        self.init(
            summary: summary,
            commonTriggers: commonTriggers,
            observedPatterns: observedPatterns,
            parentSuggestions: parentSuggestions,
            parentReflectionPrompt: parentReflectionPrompt,
            ethicalNote: ethicalNote
        )
    }

    nonisolated private static func normalized(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

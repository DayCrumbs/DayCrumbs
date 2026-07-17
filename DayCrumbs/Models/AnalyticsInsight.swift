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

    let summary: String
    let commonTriggers: [CommonTrigger]
    let observedPatterns: [ObservedPattern]
    let parentReflectionPrompt: String
    let ethicalNote: String
}

extension AnalyticsInsight {
    enum ValidationError: Error, Equatable, Sendable {
        case emptySummary
        case emptyTriggerTitle
        case emptyTriggerExplanation
        case emptyPatternTitle
        case emptyPatternEvidence
        case emptyParentReflectionPrompt
        case emptyEthicalNote
    }

    /// Normalizes model-authored whitespace and rejects incomplete typed output.
    init(
        validatingSummary summary: String,
        commonTriggers: [CommonTrigger],
        observedPatterns: [ObservedPattern],
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
            parentReflectionPrompt: parentReflectionPrompt,
            ethicalNote: ethicalNote
        )
    }

    private static func normalized(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

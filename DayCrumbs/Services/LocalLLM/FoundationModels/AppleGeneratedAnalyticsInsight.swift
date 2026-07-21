import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Typed Foundation Models transport. It is mapped immediately into AnalyticsInsight.
@available(iOS 26.0, *)
@Generable(description: "A grounded, non-diagnostic analytics insight from parent-logged story events.")
struct AppleGeneratedAnalyticsInsight {
    @Guide(description: "One concise English paragraph with the overall grounded insight.")
    var summary: String

    @Guide(
        description: "Contextual trigger candidates explicitly reflected in the summary and supported by supplied rows. Never an activity or topic inventory. Use an empty array when the data cannot support a trigger relationship.",
        .maximumCount(5)
    )
    var commonTriggers: [AppleGeneratedCommonTrigger]

    @Guide(
        description: "Concrete observations tied to supplied evidence, never recommendations.",
        .count(1...4)
    )
    var observedPatterns: [AppleGeneratedObservedPattern]

    @Guide(description: "One gentle, non-diagnostic question for the parent in English.")
    var parentReflectionPrompt: String

    @Guide(description: "A short English privacy and non-diagnosis reminder.")
    var ethicalNote: String
}

@available(iOS 26.0, *)
@Generable(description: "A possible contextual trigger reflected in the overall summary and supported by story rows.")
struct AppleGeneratedCommonTrigger {
    @Guide(description: "A short English label for the contextual circumstance tied to a mood or behavior response, not a standalone activity, place, or session.")
    var title: String

    @Guide(description: "A grounded English explanation naming the supplied circumstance and the mood or behavior response observed alongside it, consistent with the summary.")
    var explanation: String
}

@available(iOS 26.0, *)
@Generable(description: "A concrete observation supported by the supplied story rows.")
struct AppleGeneratedObservedPattern {
    @Guide(description: "A short English evidence label, not a recommendation.")
    var title: String

    @Guide(description: "Concrete English evidence tied to count, session, place, mood, time, activity, reflection, or note.")
    var evidence: String

    @Guide(description: "The exact related common-trigger title, or nil when none applies.")
    var linkedTrigger: String?

    @Guide(
        description: "Short English tags copied or explicitly derived from supplied rows.",
        .maximumCount(4)
    )
    var contextTags: [String]
}

@available(iOS 26.0, *)
extension AppleGeneratedAnalyticsInsight {
    func validatedAnalyticsInsight() throws -> AnalyticsInsight {
        try AnalyticsInsight(
            validatingSummary: summary,
            commonTriggers: commonTriggers.map {
                AnalyticsInsight.CommonTrigger(
                    title: $0.title,
                    explanation: $0.explanation
                )
            },
            observedPatterns: observedPatterns.map {
                AnalyticsInsight.ObservedPattern(
                    title: $0.title,
                    evidence: $0.evidence,
                    linkedTrigger: $0.linkedTrigger,
                    contextTags: $0.contextTags
                )
            },
            parentReflectionPrompt: parentReflectionPrompt,
            ethicalNote: ethicalNote
        )
    }
}
#endif

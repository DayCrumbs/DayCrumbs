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
        description: "Specific contextual circumstances reflected in the summary. Never include varied emotions, emotional range, mixed moods, or an activity merely because it was frequent or enjoyable. Include a trigger only when parent text links the circumstance to a response, or the same context-response pair occurs in at least two events. Use an empty array when unsupported.",
        .maximumCount(3)
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
    @Guide(description: "A short English circumstance label using the most specific nouns or actions in the supplied context. Never name a mood, mood variation, clock time, or generic session.")
    var title: String

    @Guide(description: "A tentative English explanation naming both the eligible supplied circumstance and the response observed with it. Never claim that the circumstance caused the response.")
    var explanation: String
}

@available(iOS 26.0, *)
@Generable(description: "A concrete observation supported by the supplied story rows.")
struct AppleGeneratedObservedPattern {
    @Guide(description: "A short English evidence label, not a recommendation.")
    var title: String

    @Guide(description: "Concrete English evidence tied to supplied counts, dates, sessions, places, moods, activities, reflections, or notes. Do not invent or report a clock time.")
    var evidence: String

    @Guide(description: "The exact related common-trigger title, or nil when none applies.")
    var linkedTrigger: String?

    @Guide(
        description: "Short English terms copied from the supplied activity, place, session, parent-authored circumstance, or transition. Preserve the request's specific context together with canonical structured labels so reviewed recommendations can be matched.",
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

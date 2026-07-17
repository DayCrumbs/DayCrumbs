import Testing

@testable import DayCrumbs

@Suite("Parent recommendation catalog")
struct ParentRecommendationCatalogTests {
    private let catalog = ParentRecommendationCatalog()

    @Test("Trigger detail preserves generated fields and adds curated fields")
    func buildsTriggerDetailFromSeparateSources() throws {
        let insight = makeInsight(
            triggerTitle: "Nighttime",
            triggerExplanation: "Nighttime appeared in the supplied rows.",
            patternTitle: "Night observation",
            patternEvidence: "One night entry recorded a sad mood.",
            contextTags: ["night", "sleep"]
        )

        let detail = try #require(catalog.triggerDetails(for: insight).first)

        #expect(detail.title == "Nighttime")
        #expect(detail.explanation == "Nighttime appeared in the supplied rows.")
        #expect(detail.evidence == [
            TriggerDetail.Evidence(
                title: "Night observation",
                explanation: "One night entry recorded a sad mood.",
                contextTags: ["night", "sleep"]
            ),
        ])
        #expect(detail.recommendationTitle == "Predictable bedtime steps")
        #expect(detail.sourceLabels == [.aap, .cdc])
    }

    @Test("Trigger title has priority over explanation and context tags")
    func prioritizesTriggerTitle() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Bedtime change",
            explanation: "The supplied school homework entry may be worth observing."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Learning observation",
            evidence: "Homework appeared after school.",
            linkedTrigger: trigger.title,
            contextTags: ["school", "study"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "Predictable bedtime steps")
    }

    @Test("Linked context tags can select a recommendation")
    func matchesContextTags() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "A possible moment",
            explanation: "This observation came from a supplied row."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Supplied observation",
            evidence: "One entry was recorded.",
            linkedTrigger: trigger.title,
            contextTags: ["school", "study"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "One manageable learning step")
        #expect(recommendation.sourceLabels == [.cdc])
    }

    @Test("Indonesian trigger terms use the same deterministic catalog")
    func matchesLocalizedTrigger() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Waktu tidur",
            explanation: "Momen ini mungkin perlu diamati."
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: []
        )

        #expect(recommendation.title == "Predictable bedtime steps")
    }

    @Test("Unknown text receives the general curated fallback")
    func usesGeneralFallback() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Unclassified observation",
            explanation: "A supplied moment may be worth observing."
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: []
        )

        #expect(recommendation.title == "Observe and connect")
        #expect(recommendation.sourceLabels == [.cdc, .harvard])
    }

    @Test("Summary is used only as the final matching signal")
    func matchesSummaryLast() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "A possible moment",
            explanation: "This observation came from a supplied row."
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [],
            summary: "A school moment may be worth observing."
        )

        #expect(recommendation.title == "One manageable learning step")
    }

    @Test("Unlinked patterns are not presented as trigger evidence")
    func excludesUnlinkedEvidence() throws {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Morning transition",
            explanation: "The morning transition appeared in supplied rows."
        )
        let insight = AnalyticsInsight(
            summary: "A limited observation.",
            commonTriggers: [trigger],
            observedPatterns: [
                AnalyticsInsight.ObservedPattern(
                    title: "Different observation",
                    evidence: "This evidence belongs to another trigger.",
                    linkedTrigger: "Another trigger",
                    contextTags: ["school"]
                ),
            ],
            parentReflectionPrompt: "What would you like to observe next?",
            ethicalNote: "This is not a diagnosis."
        )

        let detail = try #require(catalog.triggerDetails(for: insight).first)

        #expect(detail.evidence.isEmpty)
        #expect(detail.recommendationTitle == "A clear, predictable transition")
    }
}

@Suite("Dashboard trigger detail")
@MainActor
struct DashboardTriggerDetailTests {
    @Test("Opening a trigger uses the existing insight and local catalog")
    func selectsExistingTrigger() throws {
        let viewModel = DashboardViewModel()

        viewModel.selectTriggerDetail(for: "Doing Homework")
        let detail = try #require(viewModel.selectedTriggerDetail)

        #expect(detail.title == "Doing Homework")
        #expect(detail.evidence.first?.title == "Homework observation")
        #expect(detail.recommendationTitle == "One manageable learning step")
    }

    @Test("Unknown trigger does not fabricate detail")
    func rejectsUnknownTrigger() {
        let viewModel = DashboardViewModel()

        viewModel.selectTriggerDetail(for: "Not in the displayed insight")

        #expect(viewModel.selectedTriggerDetail == nil)
    }
}

private func makeInsight(
    triggerTitle: String,
    triggerExplanation: String,
    patternTitle: String,
    patternEvidence: String,
    contextTags: [String]
) -> AnalyticsInsight {
    AnalyticsInsight(
        summary: "A limited observation.",
        commonTriggers: [
            AnalyticsInsight.CommonTrigger(
                title: triggerTitle,
                explanation: triggerExplanation
            ),
        ],
        observedPatterns: [
            AnalyticsInsight.ObservedPattern(
                title: patternTitle,
                evidence: patternEvidence,
                linkedTrigger: triggerTitle,
                contextTags: contextTags
            ),
        ],
        parentReflectionPrompt: "What would you like to observe next?",
        ethicalNote: "This is not a diagnosis."
    )
}

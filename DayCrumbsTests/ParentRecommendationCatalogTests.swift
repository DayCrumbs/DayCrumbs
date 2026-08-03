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
        #expect(detail.recommendationTitle == "Predictable bedtime wind-down")
        #expect(detail.sourceLabels == [.aap, .cdc])
    }

    @Test("A generated Gemma suggestion overrides the static fallback")
    func usesGeneratedSuggestion() throws {
        let triggerTitle = "Cerita seram sebelum tidur"
        let insight = AnalyticsInsight(
            summary: "Cerita seram muncul sebelum rasa takut.",
            commonTriggers: [
                AnalyticsInsight.CommonTrigger(
                    title: triggerTitle,
                    explanation: "Rasa takut terlihat setelah cerita seram."
                ),
            ],
            observedPatterns: [
                AnalyticsInsight.ObservedPattern(
                    title: "Takut menjelang tidur",
                    evidence: "Catatan menghubungkan cerita hantu dengan rasa takut.",
                    linkedTrigger: triggerTitle,
                    contextTags: ["tidur", "cerita"]
                ),
            ],
            parentSuggestions: [
                AnalyticsInsight.ParentSuggestion(
                    linkedTrigger: triggerTitle,
                    title: "Ubah akhir cerita bersama",
                    recommendedActivities: [
                        "Ajak anak menggambar tokoh penolong untuk cerita itu.",
                        "Buat akhir cerita baru yang terasa lucu dan aman.",
                    ],
                    whatMayHelp: [
                        "Pilih cerita tenang menjelang tidur.",
                        "Amati tema cerita yang membuat anak nyaman.",
                    ]
                ),
            ],
            parentReflectionPrompt: "Cerita seperti apa yang terasa nyaman?",
            ethicalNote: "Ini observasi, bukan diagnosis."
        )

        let detail = try #require(catalog.triggerDetails(for: insight).first)

        #expect(detail.recommendationTitle == "Ubah akhir cerita bersama")
        #expect(
            detail.recommendedActivities.first
                == "Ajak anak menggambar tokoh penolong untuk cerita itu."
        )
        #expect(detail.sourceLabels.isEmpty)
    }

    @Test("Indonesian Gemma fallback and section labels stay Indonesian")
    func indonesianPresentationFallback() throws {
        let insight = makeInsight(
            triggerTitle: "Cerita seram sebelum tidur",
            triggerExplanation:
                "Rasa takut terlihat setelah cerita seram.",
            patternTitle: "Takut menjelang tidur",
            patternEvidence:
                "Catatan menghubungkan cerita hantu dengan rasa takut.",
            contextTags: ["tidur", "cerita"]
        )

        let detail = try #require(
            catalog.triggerDetails(
                for: insight,
                responseLanguage: .indonesian
            ).first
        )

        #expect(detail.sectionLabels == .indonesian)
        #expect(detail.recommendationTitle == "Amati dan bangun koneksi")
        #expect(
            detail.recommendedActivities.first?.contains("mengamati")
                == true
        )
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

        #expect(recommendation.title == "Predictable bedtime wind-down")
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

        #expect(recommendation.title == "Predictable bedtime wind-down")
    }

    @Test("Noise-interrupted sleep does not select the bedtime-routine entry")
    func distinguishesSleepNoiseFromBedtimeRoutine() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Gangguan saat tidur",
            explanation: "Tidur siang terganggu oleh kebisingan di sekitar kamar."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Tidur siang berisik",
            evidence: "Satu tidur siang terputus setelah suara keras.",
            linkedTrigger: trigger.title,
            contextTags: ["tidur siang", "kebisingan"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "Reduce avoidable sleep-area noise")
        #expect(recommendation.title != "Predictable bedtime wind-down")
        #expect(recommendation.sourceLabels == [.aap])
    }

    @Test("Gardening evidence overrides a broad outdoor-play label")
    func matchesGardeningEvidenceSpecifically() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Bermain di luar ruangan",
            explanation: "Maya terlihat terlibat saat menyiram tanaman."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Berkebun bersama",
            evidence: "Satu observasi mencatat kegiatan menyiram tanaman.",
            linkedTrigger: trigger.title,
            contextTags: ["luar ruangan", "berkebun", "tanaman"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "Child-led garden and nature exploration")
        #expect(
            recommendation.recommendedActivities[0]
                .contains("watering a plant")
        )
        #expect(recommendation.sourceLabels == [.aap, .cdc, .harvard])
    }

    @Test("Generic outdoor play receives an outdoor-specific action")
    func matchesOutdoorMovement() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Outdoor play",
            explanation: "One supplied row recorded active play outside."
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: []
        )

        #expect(recommendation.title == "Child-led outdoor movement")
        #expect(!recommendation.recommendedActivities.joined().contains("puzzle"))
    }

    @Test("A shared-play title takes priority over an outdoor context tag")
    func prioritizesSharedPlayTitleOverOutdoorContext() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Shared play",
            explanation: "Happiness was observed while playing."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Enjoyed play",
            evidence: "Happiness appeared in two play observations.",
            linkedTrigger: trigger.title,
            contextTags: ["play", "house", "outdoor"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "Child-led shared play")
    }

    @Test("Public-place observations no longer use the shared-play entry")
    func matchesPublicPlaceSeparately() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Keramaian di tempat umum",
            explanation: "Satu observasi terjadi di tempat yang ramai."
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: []
        )

        #expect(recommendation.title == "A manageable public-place pause")
        #expect(recommendation.sourceLabels == [.aap, .cdc])
    }

    @Test("Food refusal selects low-pressure AAP guidance")
    func matchesFoodRefusal() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Menolak makan",
            explanation: "Satu waktu makan mencatat makanan tidak dimakan."
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: []
        )

        #expect(recommendation.title == "Low-pressure mealtime participation")
        #expect(recommendation.sourceLabels == [.aap])
        #expect(recommendation.whatMayHelp[0].contains("Avoid arguing"))
    }

    @Test("Inflected eating context remains connected to mealtime guidance")
    func matchesInflectedMealtimeContext() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Eating a meal",
            explanation: "Disgust was observed during the meal."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Meal observation",
            evidence: "One eating event included a disgust mood.",
            linkedTrigger: trigger.title,
            contextTags: ["eating", "meal"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "Low-pressure mealtime participation")
    }

    @Test("Waking context remains connected to transition guidance")
    func matchesInflectedWakeContext() {
        let trigger = AnalyticsInsight.CommonTrigger(
            title: "Waking transition",
            explanation: "Fear was observed after the child woke."
        )
        let relatedPattern = AnalyticsInsight.ObservedPattern(
            title: "Wake-up observation",
            evidence: "One wake-up event included a fear mood.",
            linkedTrigger: trigger.title,
            contextTags: ["waking", "house"]
        )

        let recommendation = catalog.recommendation(
            for: trigger,
            relatedPatterns: [relatedPattern]
        )

        #expect(recommendation.title == "A clear, predictable transition")
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
    func selectsExistingTrigger() async throws {
        let calendar = makeDashboardTestCalendar()
        let referenceDate = makeDashboardTestDate(
            year: 2026,
            month: 7,
            day: 17,
            hour: 12
        )
        let insight = makeInsight(
            triggerTitle: "Doing Homework",
            triggerExplanation: "Homework appeared in a supplied school observation.",
            patternTitle: "Homework observation",
            patternEvidence: "One supplied school entry linked homework with a sad mood.",
            contextTags: ["school", "study"]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(
                entries: makeDashboardTestEntries(
                    dayOffsets: [0],
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            ),
            generator: DashboardInsightGeneratorFake(
                behaviors: [
                    .immediate(makeDashboardLocalizedResult(insight: insight)),
                ]
            ),
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()

        viewModel.selectTrigger("Doing Homework")
        let detail = try #require(viewModel.selectedTriggerDetail)

        #expect(detail.title == "Doing Homework")
        #expect(detail.evidence.first?.title == "Homework observation")
        #expect(detail.recommendationTitle == "One manageable learning step")
    }

    @Test("Unknown trigger does not fabricate detail")
    func rejectsUnknownTrigger() async {
        let calendar = makeDashboardTestCalendar()
        let referenceDate = makeDashboardTestDate(
            year: 2026,
            month: 7,
            day: 17,
            hour: 12
        )
        let insight = makeInsight(
            triggerTitle: "Morning transition",
            triggerExplanation: "A supplied morning transition may be worth observing.",
            patternTitle: "Morning observation",
            patternEvidence: "One supplied morning entry was observed.",
            contextTags: ["morning", "house"]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(
                entries: makeDashboardTestEntries(
                    dayOffsets: [0],
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            ),
            generator: DashboardInsightGeneratorFake(
                behaviors: [
                    .immediate(makeDashboardLocalizedResult(insight: insight)),
                ]
            ),
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()

        viewModel.selectTrigger("Not in the generated insight")

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

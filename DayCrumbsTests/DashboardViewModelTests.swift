import Foundation
import Testing

@testable import DayCrumbs

@Suite("Dashboard automatic insight orchestration")
@MainActor
struct DashboardViewModelTests {
    private let calendar = makeDashboardTestCalendar()
    private let referenceDate = makeDashboardTestDate(
        year: 2026,
        month: 7,
        day: 17,
        hour: 12
    )

    @Test("Start automatically generates Day once")
    func startGeneratesDayOnce() async {
        let entries = makeDashboardTestEntries(
            dayOffsets: [-6, -1, 0],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let source = DashboardStoryEntrySourceFake(entries: entries)
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(makeDashboardLocalizedResult(summary: "Day insight")),
            ]
        )
        let viewModel = makeDashboardTestViewModel(
            source: source,
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()
        await viewModel.start()

        #expect(viewModel.selectedTimeRange == .day)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.generatedInsight?.summary == "Day insight")
        #expect(source.fetchCallCount == 1)
        #expect(generator.generatedEntries.count == 1)
        #expect(generator.generatedRanges == [.day])
        #expect(generator.generatedEntries[0].count == 1)
        #expect(
            calendar.isDate(
                generator.generatedEntries[0][0].recordedAt,
                inSameDayAs: referenceDate
            )
        )
    }

    @Test("Empty Day stops before generation")
    func emptyDayDoesNotGenerate() async {
        let source = DashboardStoryEntrySourceFake(
            entries: makeDashboardTestEntries(
                dayOffsets: [-1],
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
        let generator = DashboardInsightGeneratorFake(behaviors: [])
        let viewModel = makeDashboardTestViewModel(
            source: source,
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()

        #expect(viewModel.state == .empty)
        #expect(viewModel.generatedInsight == nil)
        #expect(generator.generatedEntries.isEmpty)
    }

    @Test("Range changes generate automatically and the active range is ignored")
    func rangeChangesGenerateAutomatically() async {
        let entries = makeDashboardTestEntries(
            dayOffsets: Array(-29...0),
            referenceDate: referenceDate,
            calendar: calendar
        )
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(makeDashboardLocalizedResult(summary: "Day")),
                .immediate(makeDashboardLocalizedResult(summary: "Week")),
                .immediate(makeDashboardLocalizedResult(summary: "Month")),
            ]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(entries: entries),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()
        await viewModel.selectTimeRange(.week)
        await viewModel.selectTimeRange(.week)
        await viewModel.selectTimeRange(.month)

        #expect(viewModel.selectedTimeRange == .month)
        #expect(viewModel.generatedInsight?.summary == "Month")
        #expect(generator.generatedEntries.map(\.count) == [1, 7, 30])
        #expect(generator.generatedRanges == [.day, .week, .month])
    }

    @Test("Returning to a completed range reuses its Dashboard-session result")
    func completedRangesAreCachedForDashboardSession() async {
        let entries = makeDashboardTestEntries(
            dayOffsets: Array(-29...0),
            referenceDate: referenceDate,
            calendar: calendar
        )
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(makeDashboardLocalizedResult(summary: "Cached Day")),
                .immediate(makeDashboardLocalizedResult(summary: "Cached Week")),
                .immediate(makeDashboardLocalizedResult(summary: "Cached Month")),
            ]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(entries: entries),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()
        await viewModel.selectTimeRange(.week)
        await viewModel.selectTimeRange(.day)

        #expect(viewModel.generatedInsight?.summary == "Cached Day")
        #expect(generator.generatedRanges == [.day, .week])

        await viewModel.selectTimeRange(.week)
        await viewModel.selectTimeRange(.month)
        await viewModel.selectTimeRange(.day)

        #expect(viewModel.generatedInsight?.summary == "Cached Day")
        #expect(generator.generatedRanges == [.day, .week, .month])
        #expect(generator.generatedEntries.map(\.count) == [1, 7, 30])
    }

    @Test("Leaving Dashboard clears completed range results")
    func leavingDashboardClearsRangeCache() async {
        let source = DashboardStoryEntrySourceFake(
            entries: makeDashboardTestEntries(
                dayOffsets: [0],
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(makeDashboardLocalizedResult(summary: "First visit")),
                .immediate(makeDashboardLocalizedResult(summary: "Second visit")),
            ]
        )
        let viewModel = makeDashboardTestViewModel(
            source: source,
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()
        viewModel.endDashboardSession()
        await viewModel.start()

        #expect(source.fetchCallCount == 2)
        #expect(generator.generatedRanges == [.day, .day])
        #expect(viewModel.generatedInsight?.summary == "Second visit")
    }

    @Test("A late cancelled result cannot replace the new range")
    func staleResultIsNotPublished() async {
        let entries = makeDashboardTestEntries(
            dayOffsets: Array(-6...0),
            referenceDate: referenceDate,
            calendar: calendar
        )
        let generator = DashboardInsightGeneratorFake(
            behaviors: [.suspended, .suspended]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(entries: entries),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let initialStart = Task { @MainActor in
            await viewModel.start()
        }
        await waitForDashboardTestCondition {
            generator.generatedEntries.count == 1
        }

        let weekSelection = Task { @MainActor in
            await viewModel.selectTimeRange(.week)
        }
        await waitForDashboardTestCondition {
            viewModel.selectedTimeRange == .week
        }

        // The fake deliberately returns after cancellation to exercise the
        // request-identity guard rather than relying on cooperative cancellation.
        generator.resumeGeneration(
            at: 0,
            with: makeDashboardLocalizedResult(summary: "Late Day")
        )
        await waitForDashboardTestCondition {
            generator.generatedEntries.count == 2
        }

        #expect(viewModel.generatedInsight == nil)

        generator.resumeGeneration(
            at: 1,
            with: makeDashboardLocalizedResult(summary: "Current Week")
        )
        await initialStart.value
        await weekSelection.value

        #expect(viewModel.state == .loaded)
        #expect(viewModel.generatedInsight?.summary == "Current Week")
        #expect(viewModel.selectedTimeRange == .week)
    }

    @Test("Rapid Day Week Month switching waits for the cancelled generation to unwind")
    func rapidRangeSwitchingKeepsOneGenerationInFlight() async {
        let entries = makeDashboardTestEntries(
            dayOffsets: Array(-29...0),
            referenceDate: referenceDate,
            calendar: calendar
        )
        let generator = DashboardInsightGeneratorFake(
            behaviors: [.suspended, .suspended]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(entries: entries),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let initialDay = Task { @MainActor in
            await viewModel.start()
        }
        await waitForDashboardTestCondition {
            generator.generatedRanges == [.day]
        }

        let weekSelection = Task { @MainActor in
            await viewModel.selectTimeRange(.week)
        }
        await waitForDashboardTestCondition {
            viewModel.selectedTimeRange == .week
        }

        let monthSelection = Task { @MainActor in
            await viewModel.selectTimeRange(.month)
        }
        await waitForDashboardTestCondition {
            viewModel.selectedTimeRange == .month
        }

        let finalDaySelection = Task { @MainActor in
            await viewModel.selectTimeRange(.day)
        }
        await waitForDashboardTestCondition {
            viewModel.selectedTimeRange == .day
        }

        // All selectors must still be waiting on the original cancelled task;
        // Week and Month may not start a competing generation.
        #expect(generator.generatedRanges == [.day])
        #expect(generator.maximumConcurrentGenerationCount == 1)

        generator.resumeGeneration(
            at: 0,
            with: makeDashboardLocalizedResult(summary: "Stale Day")
        )
        await waitForDashboardTestCondition {
            generator.generatedRanges.count == 2
        }

        #expect(generator.generatedRanges == [.day, .day])
        #expect(generator.maximumConcurrentGenerationCount == 1)

        generator.resumeGeneration(
            at: 1,
            with: makeDashboardLocalizedResult(summary: "Current Day")
        )
        await initialDay.value
        await weekSelection.value
        await monthSelection.value
        await finalDaySelection.value

        #expect(viewModel.state == .loaded)
        #expect(viewModel.generatedInsight?.summary == "Current Day")
        #expect(viewModel.selectedTimeRange == .day)
        #expect(generator.maximumConcurrentGenerationCount == 1)
    }

    @Test("Cancellation releases the session and publishes no late result")
    func cancellationReleasesSession() async {
        let generator = DashboardInsightGeneratorFake(behaviors: [.suspended])
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(
                entries: makeDashboardTestEntries(
                    dayOffsets: [0],
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            ),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let start = Task { @MainActor in
            await viewModel.start()
        }
        await waitForDashboardTestCondition {
            generator.generatedEntries.count == 1
        }

        viewModel.cancelGeneration()

        #expect(generator.releaseCallCount == 1)

        generator.resumeGeneration(
            at: 0,
            with: makeDashboardLocalizedResult(summary: "Cancelled result")
        )
        await start.value

        #expect(viewModel.generatedInsight == nil)
        #expect(viewModel.state != .loaded)
    }

    @Test("English fallback retries translation without regenerating")
    func retriesOnlyOutputTranslation() async {
        let englishInsight = makeDashboardTestInsight(summary: "English insight")
        let localizedInsight = makeDashboardTestInsight(summary: "Insight Indonesia")
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(
                    makeDashboardLocalizedResult(
                        insight: englishInsight,
                        withEnglishFallback: true
                    )
                ),
            ],
            retryResult: makeDashboardLocalizedResult(insight: localizedInsight)
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(
                entries: makeDashboardTestEntries(
                    dayOffsets: [0],
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            ),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()

        #expect(viewModel.englishFallbackLabel == "English fallback")
        #expect(viewModel.generatedInsight == englishInsight)

        await viewModel.retryOutputTranslation()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.generatedInsight == localizedInsight)
        #expect(viewModel.englishFallback == nil)
        #expect(generator.generatedEntries.count == 1)
        #expect(generator.retryCallCount == 1)
    }

    @Test("Successful translation retry updates the cached range result")
    func translationRetryUpdatesCachedRange() async {
        let englishInsight = makeDashboardTestInsight(summary: "English Day")
        let localizedInsight = makeDashboardTestInsight(summary: "Hari Indonesia")
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(
                    makeDashboardLocalizedResult(
                        insight: englishInsight,
                        withEnglishFallback: true
                    )
                ),
                .immediate(makeDashboardLocalizedResult(summary: "Week result")),
            ],
            retryResult: makeDashboardLocalizedResult(insight: localizedInsight)
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(
                entries: makeDashboardTestEntries(
                    dayOffsets: Array(-6...0),
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            ),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()
        await viewModel.retryOutputTranslation()
        await viewModel.selectTimeRange(.week)
        await viewModel.selectTimeRange(.day)

        #expect(viewModel.generatedInsight == localizedInsight)
        #expect(viewModel.englishFallback == nil)
        #expect(generator.generatedRanges == [.day, .week])
        #expect(generator.retryCallCount == 1)
    }

    @Test("Trigger selection reuses the published localized recommendation")
    func selectsLocalizedRecommendation() async throws {
        let insight = makeDashboardTestInsight(
            summary: "Ringkasan terbatas.",
            triggerTitle: "Transisi pagi",
            triggerExplanation: "Satu transisi pagi tercatat.",
            patternTitle: "Observasi pagi",
            patternEvidence: "Satu kegiatan terjadi pada pagi hari.",
            contextTags: ["pagi", "rumah"]
        )
        let localizedDetail = TriggerDetail(
            title: "Transisi pagi",
            explanation: "Satu transisi pagi tercatat.",
            evidence: [
                TriggerDetail.Evidence(
                    title: "Observasi pagi",
                    explanation: "Satu kegiatan terjadi pada pagi hari.",
                    contextTags: ["pagi", "rumah"]
                ),
            ],
            recommendationTitle: "Langkah transisi yang jelas",
            recommendedActivities: ["Jelaskan satu langkah berikutnya."],
            whatMayHelp: ["Gunakan urutan yang dapat diperkirakan."],
            sourceLabels: [.cdc],
            sectionLabels: TriggerDetail.SectionLabels(
                evidence: "Bukti",
                recommendedActivities: "Aktivitas yang disarankan",
                whatMayHelp: "Yang mungkin membantu",
                curatedSources: "Sumber terkurasi"
            )
        )
        let generator = DashboardInsightGeneratorFake(
            behaviors: [
                .immediate(
                    makeDashboardLocalizedResult(
                        insight: insight,
                        triggerDetails: [localizedDetail]
                    )
                ),
            ]
        )
        let viewModel = makeDashboardTestViewModel(
            source: DashboardStoryEntrySourceFake(
                entries: makeDashboardTestEntries(
                    dayOffsets: [0],
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            ),
            generator: generator,
            referenceDate: referenceDate,
            calendar: calendar
        )

        await viewModel.start()
        viewModel.selectTrigger("Transisi pagi")

        let selectedDetail = try #require(viewModel.selectedTriggerDetail)
        #expect(
            selectedDetail.recommendationTitle
                == "Langkah transisi yang jelas"
        )
        #expect(
            selectedDetail.sectionLabels.recommendedActivities
                == "Aktivitas yang disarankan"
        )
        #expect(selectedDetail.sourceLabels == [.cdc])
        #expect(generator.generatedEntries.count == 1)
    }
}

@MainActor
final class DashboardStoryEntrySourceFake: StoryEntrySource {
    private let entries: [StoryEntry]
    private(set) var fetchCallCount = 0

    init(entries: [StoryEntry]) {
        self.entries = entries
    }

    func fetchEntries() async throws -> [StoryEntry] {
        fetchCallCount += 1
        return entries
    }
}

enum DashboardInsightGeneratorBehavior {
    case immediate(AppleLocalizedAnalyticsInsight)
    case suspended
}

@MainActor
final class DashboardInsightGeneratorFake: AppleLocalizedInsightGenerating {
    private let behaviors: [DashboardInsightGeneratorBehavior]
    private let retryResult: AppleLocalizedAnalyticsInsight?
    private var pendingGenerations: [
        Int: CheckedContinuation<AppleLocalizedAnalyticsInsight, any Error>
    ] = [:]

    private(set) var generatedEntries: [[StoryEntry]] = []
    private(set) var generatedRanges: [TimeRange] = []
    private(set) var retryCallCount = 0
    private(set) var releaseCallCount = 0
    private(set) var maximumConcurrentGenerationCount = 0
    private var concurrentGenerationCount = 0

    init(
        behaviors: [DashboardInsightGeneratorBehavior],
        retryResult: AppleLocalizedAnalyticsInsight? = nil
    ) {
        self.behaviors = behaviors
        self.retryResult = retryResult
    }

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> AppleLocalizedAnalyticsInsight {
        let callIndex = generatedEntries.count
        generatedEntries.append(entries)
        generatedRanges.append(range)
        concurrentGenerationCount += 1
        maximumConcurrentGenerationCount = max(
            maximumConcurrentGenerationCount,
            concurrentGenerationCount
        )
        defer {
            concurrentGenerationCount -= 1
        }

        guard behaviors.indices.contains(callIndex) else {
            throw AppleAnalyticsGenerationError.generationFailed(.unavailableRuntime)
        }

        switch behaviors[callIndex] {
        case .immediate(let result):
            return result
        case .suspended:
            return try await withCheckedThrowingContinuation { continuation in
                pendingGenerations[callIndex] = continuation
            }
        }
    }

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight {
        retryCallCount += 1
        return retryResult ?? AppleLocalizedAnalyticsInsight(
            insight: fallback.englishInsight,
            triggerDetails: fallback.englishTriggerDetails,
            responseLanguage: fallback.translationFallback.targetLanguage,
            englishFallback: fallback
        )
    }

    func releaseSession() {
        releaseCallCount += 1
    }

    func resumeGeneration(
        at callIndex: Int,
        with result: AppleLocalizedAnalyticsInsight
    ) {
        pendingGenerations.removeValue(forKey: callIndex)?.resume(
            returning: result
        )
    }
}

@MainActor
func makeDashboardTestViewModel(
    source: any StoryEntrySource,
    generator: any AppleLocalizedInsightGenerating,
    referenceDate: Date,
    calendar: Calendar
) -> DashboardViewModel {
    DashboardViewModel(
        entrySource: source,
        entrySelectionService: DashboardEntrySelectionService(calendar: calendar),
        generationService: generator,
        executeTranslationBatch: dashboardUnusedTranslationBatchHandler,
        calendar: calendar,
        now: { referenceDate },
        rangeChangeDebounce: .zero
    )
}

@MainActor
func makeDashboardTestEntries(
    dayOffsets: [Int],
    referenceDate: Date,
    calendar: Calendar
) -> [StoryEntry] {
    let child = ChildProfile(name: "Maya", age: 3, gender: .girl)
    let todayStart = calendar.startOfDay(for: referenceDate)
    var sessions: [DailySession] = []

    let entries = dayOffsets.map { dayOffset in
        let dayStart = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: todayStart
        )!
        let recordedAt = calendar.date(
            byAdding: .hour,
            value: 10,
            to: dayStart
        )!
        let session = DailySession(
            startedAt: recordedAt,
            childProfile: child
        )
        let entry = StoryEntry(
            session: .morning,
            mood: .happy,
            activity: .play,
            place: .house,
            recordedAt: recordedAt,
            dailySession: session
        )
        session.entries = [entry]
        sessions.append(session)
        return entry
    }

    child.dailySessions = sessions
    return entries.sorted { $0.recordedAt < $1.recordedAt }
}

func makeDashboardTestInsight(
    summary: String,
    triggerTitle: String = "Morning transition",
    triggerExplanation: String = "A supplied morning transition may be worth observing.",
    patternTitle: String = "Morning observation",
    patternEvidence: String = "One supplied morning entry was observed.",
    contextTags: [String] = ["morning", "house"]
) -> AnalyticsInsight {
    AnalyticsInsight(
        summary: summary,
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
        ethicalNote: "This private observation is not a diagnosis."
    )
}

func makeDashboardLocalizedResult(
    summary: String
) -> AppleLocalizedAnalyticsInsight {
    makeDashboardLocalizedResult(
        insight: makeDashboardTestInsight(summary: summary)
    )
}

func makeDashboardLocalizedResult(
    insight: AnalyticsInsight,
    triggerDetails: [TriggerDetail]? = nil,
    withEnglishFallback: Bool = false
) -> AppleLocalizedAnalyticsInsight {
    let triggerDetails = triggerDetails
        ?? ParentRecommendationCatalog().triggerDetails(for: insight)
    let translationFallback = AppleInsightEnglishFallback(
        englishTexts: [],
        targetLanguage: .indonesian,
        failure: AppleInsightTranslationFailure(
            stage: .output,
            reason: .translationFailed,
            pair: TranslationLanguagePair(
                source: .english,
                target: .indonesian
            )
        )
    )
    let fallback = withEnglishFallback
        ? AppleAnalyticsInsightEnglishFallback(
            englishInsight: insight,
            englishTriggerDetails: triggerDetails,
            translationFallback: translationFallback
        )
        : nil

    return AppleLocalizedAnalyticsInsight(
        insight: insight,
        triggerDetails: triggerDetails,
        responseLanguage: .indonesian,
        englishFallback: fallback
    )
}

let dashboardUnusedTranslationBatchHandler: PreparedNativeTranslationBatchHandler = {
    _, _ in []
}

@MainActor
private func waitForDashboardTestCondition(
    _ condition: () -> Bool
) async {
    for _ in 0..<1_000 {
        if condition() {
            return
        }
        await Task.yield()
    }
}

func makeDashboardTestCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
    return calendar
}

func makeDashboardTestDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int
) -> Date {
    makeDashboardTestCalendar().date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )
    )!
}

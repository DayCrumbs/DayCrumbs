import Foundation
import Observation
import OSLog

nonisolated struct MoodDataPoint: Identifiable {
    let id = UUID()
    let timeLabel: String
    let moodScore: Int
}

/// UI-ready lifecycle state for one selected Dashboard range.
nonisolated enum DashboardPresentationState: Equatable {
    case idle
    case loading(DashboardLoadingPhase)
    case loaded
    case empty
    case failed(message: String)
}

@MainActor
@Observable
final class DashboardViewModel {
    private static let logger = Logger(
        subsystem: "DayCrumbs",
        category: "DashboardGeneration"
    )

    private(set) var selectedTimeRange: TimeRange = .day
    private(set) var state: DashboardPresentationState = .idle
    private(set) var generatedInsight: AnalyticsInsight?
    private(set) var englishFallback: AppleAnalyticsInsightEnglishFallback?
    private(set) var selectedTriggerDetail: TriggerDetail?
    private(set) var childName = ""

    private let entrySource: any StoryEntrySource
    private let entrySelectionService: DashboardEntrySelectionService
    private let generationService: any AppleLocalizedInsightGenerating
    private let recommendationCatalog: ParentRecommendationCatalog
    private let executeTranslationBatch: PreparedNativeTranslationBatchHandler
    private let calendar: Calendar
    private let now: () -> Date
    private let rangeChangeDebounce: Duration

    @ObservationIgnored private var allEntries: [StoryEntry] = []
    @ObservationIgnored private var hasLoadedEntries = false
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var activeReferenceDay: Date?
    @ObservationIgnored private var activeRequestID: UUID?
    @ObservationIgnored private var selectionRevision = UUID()
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var publishedTriggerDetails: [TriggerDetail] = []

    init(
        entrySource: (any StoryEntrySource)? = nil,
        entrySelectionService: DashboardEntrySelectionService? = nil,
        generationService: (any AppleLocalizedInsightGenerating)? = nil,
        recommendationCatalog: ParentRecommendationCatalog = ParentRecommendationCatalog(),
        executeTranslationBatch: @escaping PreparedNativeTranslationBatchHandler,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        rangeChangeDebounce: Duration = .milliseconds(180)
    ) {
        // Main-actor dependencies must be created inside this isolated initializer,
        // not as default argument expressions evaluated by a nonisolated caller.
        self.entrySource = entrySource ?? DummyStoryEntrySource()
        self.entrySelectionService = entrySelectionService ?? DashboardEntrySelectionService()
        self.generationService = generationService ?? AppleLocalizedInsightGenerationService()
        self.recommendationCatalog = recommendationCatalog
        self.executeTranslationBatch = executeTranslationBatch
        self.calendar = calendar
        self.now = now
        self.rangeChangeDebounce = rangeChangeDebounce
    }

    var summaryText: String {
        generatedInsight?.summary ?? ""
    }

    var commonTriggers: [String] {
        generatedInsight?.commonTriggers.map(\.title) ?? []
    }

    var englishFallbackLabel: String? {
        englishFallback?.displayLabel
    }

    /// Fetches once for this ViewModel lifecycle and automatically generates Day.
    func start() async {
        if hasStarted {
            // A disappearance can cancel work while preserving this ViewModel.
            // Restart only that interrupted request, never an already loaded one.
            if generationTask == nil,
               hasLoadedEntries,
               case .loading = state {
                await generateSelectedRange(debounce: false)
            }
            return
        }

        hasStarted = true
        await reloadEntriesAndGenerate()
    }

    /// Range selection is an intent: it owns cancellation, filtering, and regeneration.
    func selectTimeRange(_ range: TimeRange) async {
        guard range != selectedTimeRange else {
            return
        }

        let revision = UUID()
        selectionRevision = revision
        selectedTimeRange = range
        clearPublishedInsight()

        let previousTask = detachActiveGeneration()
        await previousTask?.value

        guard selectionRevision == revision, selectedTimeRange == range else {
            return
        }
        guard hasLoadedEntries else {
            return
        }

        await generateSelectedRange(debounce: true)
    }

    func retryGeneration() async {
        guard hasLoadedEntries else {
            await reloadEntriesAndGenerate()
            return
        }

        let revision = UUID()
        selectionRevision = revision
        clearPublishedInsight()

        let previousTask = detachActiveGeneration()
        await previousTask?.value

        guard selectionRevision == revision else {
            return
        }
        await generateSelectedRange(debounce: false)
    }

    /// Reuses preserved English fields; this path cannot invoke generation again.
    func retryOutputTranslation() async {
        guard let fallback = englishFallback else {
            return
        }

        let range = selectedTimeRange
        let requestID = UUID()
        activeRequestID = requestID
        state = .loading(.outputTranslation)

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let result = await generationService.retryOutputTranslation(
                fallback,
                using: executeTranslationBatch
            )

            guard canPublish(requestID: requestID, range: range) else {
                return
            }
            publish(result)
        }

        generationTask = task
        await task.value
        if activeRequestID == requestID {
            generationTask = nil
        }
    }

    func selectTrigger(_ triggerTitle: String) {
        selectedTriggerDetail = publishedTriggerDetails.first {
            $0.title == triggerTitle
        }
    }

    func dismissTrigger() {
        selectedTriggerDetail = nil
    }

    /// Cancels app-owned work when the stable Dashboard root leaves the foreground.
    func cancelGeneration() {
        selectionRevision = UUID()
        _ = detachActiveGeneration()
    }

    /// A new calendar day changes all rolling range boundaries and requires fresh input.
    func refreshIfRangeBoundaryChanged() async {
        let currentDay = calendar.startOfDay(for: now())
        guard hasStarted else {
            return
        }

        if activeReferenceDay == currentDay {
            if generationTask == nil,
               hasLoadedEntries,
               case .loading = state {
                await generateSelectedRange(debounce: false)
            }
            return
        }

        let revision = UUID()
        selectionRevision = revision
        let previousTask = detachActiveGeneration()
        await previousTask?.value

        guard selectionRevision == revision else {
            return
        }
        await reloadEntriesAndGenerate()
    }

    private func reloadEntriesAndGenerate() async {
        state = .loading(.stories)
        clearPublishedInsight(keepingState: true)
        hasLoadedEntries = false

        do {
            let entries = try await entrySource.fetchEntries()
            try Task.checkCancellation()

            allEntries = entries.sorted { $0.recordedAt < $1.recordedAt }
            hasLoadedEntries = true
            activeReferenceDay = calendar.startOfDay(for: now())
            childName = allEntries.first?.dailySession?.childProfile?.name ?? "Your child"

            await generateSelectedRange(debounce: false)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error(
                "Story loading failed: \(String(describing: error), privacy: .public)"
            )
            state = .failed(
                message: "Stories could not be loaded. Please try again."
            )
        }
    }

    private func generateSelectedRange(debounce: Bool) async {
        let range = selectedTimeRange
        let referenceDate = now()
        let entries: [StoryEntry]

        do {
            entries = try entrySelectionService.entries(
                for: range,
                from: allEntries,
                referenceDate: referenceDate
            )
        } catch {
            Self.logger.error(
                "Range preparation failed for \(range.rawValue, privacy: .public): \(String(describing: error), privacy: .public)"
            )
            state = .failed(
                message: "The selected date range could not be prepared."
            )
            return
        }

        guard !entries.isEmpty else {
            state = .empty
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        state = .loading(.insight)

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                if debounce {
                    try await Task.sleep(for: rangeChangeDebounce)
                }
                try Task.checkCancellation()

                let result = try await generationService.generateInsight(
                    from: entries,
                    for: range,
                    using: executeTranslationBatch
                )

                try Task.checkCancellation()
                guard canPublish(requestID: requestID, range: range) else {
                    return
                }
                publish(result)
            } catch {
                // Translation cancellation can arrive as a domain error. Request
                // identity and Task cancellation therefore take precedence.
                guard !Task.isCancelled,
                      canPublish(requestID: requestID, range: range) else {
                    return
                }
                Self.logger.error(
                    "Generation failed for \(range.rawValue, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                state = .failed(message: userMessage(for: error))
            }
        }

        generationTask = task
        await task.value
        if activeRequestID == requestID {
            generationTask = nil
        }
    }

    private func publish(_ result: AppleLocalizedAnalyticsInsight) {
        generatedInsight = result.insight
        englishFallback = result.englishFallback
        // Legacy/test generators may not provide prelocalized details. Production
        // Apple generation always publishes translated catalog content here.
        publishedTriggerDetails = result.triggerDetails.isEmpty
            ? recommendationCatalog.triggerDetails(for: result.insight)
            : result.triggerDetails
        selectedTriggerDetail = nil
        state = .loaded
    }

    private func canPublish(requestID: UUID, range: TimeRange) -> Bool {
        activeRequestID == requestID && selectedTimeRange == range
    }

    private func detachActiveGeneration() -> Task<Void, Never>? {
        let task = generationTask
        generationTask = nil
        activeRequestID = nil
        task?.cancel()
        generationService.releaseSession()
        return task
    }

    private func clearPublishedInsight(keepingState: Bool = false) {
        generatedInsight = nil
        englishFallback = nil
        publishedTriggerDetails = []
        selectedTriggerDetail = nil
        if !keepingState {
            state = .idle
        }
    }

    private func userMessage(for error: any Error) -> String {
        guard let generationError = error as? AppleAnalyticsGenerationError else {
            return "The on-device insight could not be generated. Please try again."
        }

        switch generationError {
        case .emptyEntries:
            return "There are no stories in this range yet."
        case .invalidEntries:
            return "The selected stories could not be prepared for insight generation."
        case .modelUnavailable:
            return AppleFoundationModelsRuntime.readinessMessage
        case .inputTranslationBlocked(let failure):
            return failure.userMessage
        case .invalidGeneratedInsight:
            return "The generated insight was incomplete. Please try again."
        case .generationFailed(let sessionError):
            return userMessage(for: sessionError)
        case .concurrentRequest:
            return "Another insight request is finishing. Please try again."
        case .cancelled:
            return "Insight generation was cancelled."
        }
    }

    private func userMessage(
        for error: AppleFoundationModelsSessionError
    ) -> String {
        switch error {
        case .assetsUnavailable:
            return "Apple Intelligence is still preparing its on-device model. Please try again later."
        case .guardrailViolation, .refusal:
            return "Apple Intelligence could not create this insight safely."
        case .unsupportedGuide, .unsupportedLanguageOrLocale:
            return "Apple Intelligence could not process this insight format or language."
        case .rateLimited, .concurrentRequest:
            return "Apple Intelligence is busy. Please wait a moment and try again."
        case .exceededContextWindow, .decodingFailure, .unavailableRuntime:
            return "The on-device insight could not be completed. Please try again."
        }
    }

    // Chart fixtures remain independent from the generation pipeline.
    private let dayData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Morning", moodScore: 4),
        MoodDataPoint(timeLabel: "Afternoon", moodScore: 2),
        MoodDataPoint(timeLabel: "Evening", moodScore: 3),
        MoodDataPoint(timeLabel: "Night", moodScore: 5),
    ]

    private let weekData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Mon", moodScore: 2),
        MoodDataPoint(timeLabel: "Tue", moodScore: 3),
        MoodDataPoint(timeLabel: "Wed", moodScore: 4),
        MoodDataPoint(timeLabel: "Thu", moodScore: 3),
        MoodDataPoint(timeLabel: "Fri", moodScore: 5),
        MoodDataPoint(timeLabel: "Sat", moodScore: 4),
        MoodDataPoint(timeLabel: "Sun", moodScore: 6),
    ]

    private let monthData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Week 1", moodScore: 3),
        MoodDataPoint(timeLabel: "Week 2", moodScore: 5),
        MoodDataPoint(timeLabel: "Week 3", moodScore: 2),
        MoodDataPoint(timeLabel: "Week 4", moodScore: 4),
    ]

    var currentChartData: [MoodDataPoint] {
        switch selectedTimeRange {
        case .day:
            dayData
        case .week:
            weekData
        case .month:
            monthData
        }
    }
}

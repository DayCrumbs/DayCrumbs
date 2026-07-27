
import Foundation
import Observation
import OSLog

nonisolated struct MoodDataPoint: Identifiable {
    let id = UUID()
    let timeLabel: String
    let moodScore: Int
}

nonisolated struct MoodBarChartSegment: Identifiable {
    var id: String { "\(timeLabel)-\(mood.rawValue)" }
    let timeLabel: String
    let mood: Moods
    let count: Int
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
    
    private let entrySource: any StoryEntrySourceProtocol
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
    @ObservationIgnored private var generationTaskID: UUID?
    @ObservationIgnored private var selectionRevision = UUID()
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var publishedTriggerDetails: [TriggerDetail] = []
    /// Keeps one complete presentation result per range for this Dashboard visit.
    /// The cache is intentionally in memory so leaving Dashboard starts a fresh visit.
    @ObservationIgnored private var cachedResultsByRange: [
        TimeRange: AppleLocalizedAnalyticsInsight
    ] = [:]
    
    init(
        entrySource: (any StoryEntrySourceProtocol)? = nil,
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

    /// A concise, English date label matching the rolling range used by the chart.
    var selectedDateRangeLabel: String {
        let today = calendar.startOfDay(for: now())
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(selectedTimeRange.dayCount - 1),
            to: today
        ) else {
            return formattedDashboardDate(today, includesYear: false)
        }

        let spansYears = calendar.component(.year, from: startDate)
            != calendar.component(.year, from: today)
        let endLabel = formattedDashboardDate(today, includesYear: spansYears)

        guard selectedTimeRange != .day else {
            return endLabel
        }

        let startLabel = formattedDashboardDate(
            startDate,
            includesYear: spansYears
        )
        return "\(startLabel) – \(endLabel)"
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
        
        if restoreCachedResult(for: range) {
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
        cachedResultsByRange[selectedTimeRange] = nil
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
            publish(result, for: range)
        }
        
        generationTask = task
        generationTaskID = requestID
        await task.value
        finishGenerationTask(requestID: requestID)
    }
    
    func selectTrigger(_ triggerTitle: String) {
        selectedTriggerDetail = publishedTriggerDetails.first {
            $0.title == triggerTitle
        }
    }
    
    func dismissTrigger() {
        selectedTriggerDetail = nil
    }

    private func formattedDashboardDate(
        _ date: Date,
        includesYear: Bool
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = includesYear ? "EEE, d MMM yyyy" : "EEE, d MMM"
        return formatter.string(from: date)
    }
    
    /// Cancels app-owned work when the stable Dashboard root leaves the foreground.
    func cancelGeneration() {
        selectionRevision = UUID()
        _ = detachActiveGeneration()
    }
    
    /// Ends one Dashboard visit. Background cancellation deliberately uses
    /// `cancelGeneration()` instead so completed ranges remain cached on resume.
    func endDashboardSession() {
        selectionRevision = UUID()
        _ = detachActiveGeneration()
        cachedResultsByRange.removeAll()
        clearPublishedInsight()
        allEntries = []
        hasLoadedEntries = false
        hasStarted = false
        activeReferenceDay = nil
        childName = ""
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
        // Day, Week, and Month all receive new rolling boundaries after midnight.
        cachedResultsByRange.removeAll()
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
                publish(result, for: range)
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
        generationTaskID = requestID
        await task.value
        finishGenerationTask(requestID: requestID)
    }
    
    private func restoreCachedResult(for range: TimeRange) -> Bool {
        guard let cachedResult = cachedResultsByRange[range] else {
            return false
        }
        
        publish(cachedResult, for: range)
        return true
    }
    
    private func publish(
        _ result: AppleLocalizedAnalyticsInsight,
        for range: TimeRange
    ) {
        cachedResultsByRange[range] = result
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
        activeRequestID = nil

        // Keep the cancelled task visible until it has actually unwound. Rapid
        // range selections will all await the same task instead of starting a
        // new generation while the previous translation is still finishing.
        if let task, !task.isCancelled {
            task.cancel()
            generationService.releaseSession()
        }
        return task
    }

    private func finishGenerationTask(requestID: UUID) {
        guard generationTaskID == requestID else {
            return
        }

        generationTask = nil
        generationTaskID = nil
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
    
    // MARK: - LOGIKA AGREGASI DATA GRAFIK DINAMIS
    
    /// Data segmen Mood dinamis yang diekstrak secara berkala berdasarkan rentang waktu terpilih [14].
    var currentMoodBarData: [MoodBarChartSegment] {
        let referenceDate = now()
        
        // Saring entri cerita untuk rentang waktu terpilih menggunakan servis bawaan
        guard let selectedEntries = try? entrySelectionService.entries(
            for: selectedTimeRange,
            from: allEntries,
            referenceDate: referenceDate
        ) else {
            return []
        }
        
        return aggregateMoodBarData(from: selectedEntries, for: selectedTimeRange, referenceDate: referenceDate)
    }
    
    /// Mengelompokkan dan menjumlahkan kemunculan mood berdasarkan segmen sumbu X [14].
    private func aggregateMoodBarData(
        from entries: [StoryEntry],
        for range: TimeRange,
        referenceDate: Date
    ) -> [MoodBarChartSegment] {
        // Simpan jumlah akumulasi: [LabelWaktu: [Mood: Jumlah]]
        var counts: [String: [Moods: Int]] = [:]
        
        // Definisikan urutan label sumbu X agar visualisasi grafik tetap runtut
        let orderedLabels: [String]
        switch range {
        case .day:
            orderedLabels = ["Morning", "Afternoon", "Evening", "Night"]
        case .week:
            orderedLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        case .month:
            orderedLabels = ["Week 1", "Week 2", "Week 3", "Week 4"]
        }
        
        // Inisialisasi struktur penampung agar urutan label sumbu X aman
        for label in orderedLabels {
            counts[label] = [:]
        }
        
        // Lakukan pengelompokan (grouping) dan penambahan nilai akumulasi
        for entry in entries {
            let label = timeLabel(for: entry, range: range, referenceDate: referenceDate)
            
            // Jaga-jaga jika label berada di luar orderedLabels default (misal karena penanggalan kalender)
            if counts[label] == nil {
                counts[label] = [:]
            }
            
            counts[label]?[entry.mood, default: 0] += 1
        }
        
        // Bentuk menjadi array MoodBarChartSegment yang diurutkan sesuai orderedLabels
        var segments: [MoodBarChartSegment] = []
        
        // Urutan ini menentukan tumpukan dari bawah ke atas di dalam Bar Chart
        let moodStackOrder: [Moods] = [.angry, .disgust, .fear, .surprise, .sad, .happy]
        
        for label in orderedLabels {
            guard let moodCounts = counts[label] else { continue }
            
            for mood in moodStackOrder {
                if let count = moodCounts[mood], count > 0 {
                    segments.append(
                        MoodBarChartSegment(timeLabel: label, mood: mood, count: count)
                    )
                }
            }
        }
        
        return segments
    }
    
    /// Menghasilkan string label sumbu X berdasarkan rentang waktu terpilih.
    private func timeLabel(
        for entry: StoryEntry,
        range: TimeRange,
        referenceDate: Date
    ) -> String {
        switch range {
        case .day:
            // Sesuai dengan enum Sesi: Morning, Afternoon, Evening, Night
            switch entry.session {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .night: return "Night"
            }
            
        case .week:
            // Ambil singkatan nama hari dalam bahasa Inggris (Mon, Tue, Wed, dst.)
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            formatter.locale = Locale(identifier: "en_US")
            return formatter.string(from: entry.recordedAt)
            
        case .month:
            // Kelompokkan data ke dalam 4 blok minggu presisi (masing-masing tepat 7 hari)
            let startOfEntryDay = calendar.startOfDay(for: entry.recordedAt)
            let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
            
            let daysAgo = calendar.dateComponents(
                [.day],
                from: startOfEntryDay,
                to: startOfReferenceDay
            ).day ?? 0
            
            if daysAgo < 7 {
                return "Week 4"  // Hari ke 1 - 7 (Terbaru / 0 s.d 6 hari yang lalu)
            } else if daysAgo < 14 {
                return "Week 3"  // Hari ke 8 - 14 (7 s.d 13 hari yang lalu)
            } else if daysAgo < 21 {
                return "Week 2"  // Hari ke 15 - 21 (14 s.d 20 hari yang lalu)
            } else if daysAgo < 28 {
                return "Week 1"  // Hari ke 22 - 28 (21 s.d 27 hari yang lalu)
            } else {
                return ""
            }
        }
    }
    
    /// Opsional: Data Score Chart yang juga disesuaikan secara dinamis dari database
    var currentChartData: [MoodDataPoint] {
        let referenceDate = now()
        guard let selectedEntries = try? entrySelectionService.entries(
            for: selectedTimeRange,
            from: allEntries,
            referenceDate: referenceDate
        ) else {
            return []
        }
        
        let grouped = Dictionary(grouping: selectedEntries) { entry in
            timeLabel(for: entry, range: selectedTimeRange, referenceDate: referenceDate)
        }
        
        return grouped.map { label, entriesInLabel in
            MoodDataPoint(timeLabel: label, moodScore: entriesInLabel.count)
        }
    }
}

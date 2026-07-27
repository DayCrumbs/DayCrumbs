
import Charts
import SwiftUI
import SwiftData

struct DashboardView: View {
    #if DEBUG
    private let showsDevelopmentDataButton = true
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    
    @AccessibilityFocusState private var accessibilityFocus: DashboardAccessibilityFocus?
    @State private var viewModel: DashboardViewModel
    @State private var translationTaskHost: AppleTranslationTaskHost
    
    /// Remembers which trigger opened the detail so modal dismissal can restore
    /// VoiceOver to the originating chip in the next presentation step.
    @State private var triggerFocusReturnTarget: String?

    /// Tracks which bar segments show their count annotation.
    /// `.none` means all counts are hidden.
    /// `.segment(id)` shows only that specific segment (from bar tap).
    /// `.mood(mood)` shows all segments of that mood (from legend tap).
    @State private var chartSelection: ChartSelection = .none

    private enum ChartSelection: Equatable {
        case none
        case segment(String)
        case mood(Moods)
    }
    
    init(modelContext: ModelContext) {
        let translationTaskHost = AppleTranslationTaskHost()
        _translationTaskHost = State(initialValue: translationTaskHost)
        _viewModel = State(
            initialValue: DashboardViewModel(
                entrySource: StoryEntrySource(modelContext: modelContext),
                executeTranslationBatch: translationTaskHost.batchHandler
            )
        )

        let basePickerFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let pickerFont = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: basePickerFont,
            maximumPointSize: 28
        )
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor(AppColour.btnKuning)
        appearance.backgroundColor = UIColor(AppColour.btnKuning.opacity(0.2))
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor(AppColour.txtCoklat), .font: pickerFont],
            for: .selected
        )
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor(AppColour.txtCoklat), .font: pickerFont],
            for: .normal
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            sharedDashboardSurface(in: geometry.size)
        }
        .background(
            AppColour.bgPutih
                .ignoresSafeArea()
                .accessibilityHidden(true)
        )
        .toolbar(.hidden, for: .navigationBar)
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if showsDevelopmentDataButton {
                developmentDataButton
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .accessibilityHidden(viewModel.selectedTriggerDetail != nil)
            }
        }
        #endif
        .appleTranslationTaskHost(translationTaskHost)
        .onChange(of: viewModel.state) { _, newState in
            postAccessibilityAnnouncement(for: newState)
        }
        .onChange(of: viewModel.selectedTriggerDetail) { previousDetail, detail in
            updateTriggerDetailAccessibilityFocus(
                from: previousDetail,
                to: detail
            )
        }
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.endDashboardSession()
            translationTaskHost.cancelPendingBatch()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await viewModel.refreshIfRangeBoundaryChanged()
                }
            case .background:
                viewModel.cancelGeneration()
                translationTaskHost.cancelPendingBatch()
            default:
                break
            }
        }
        .overlay {
            if let detail = viewModel.selectedTriggerDetail {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .onTapGesture {
                            viewModel.dismissTrigger()
                        }
                    
                    TriggerAlertView(
                        detail: detail,
                        accessibilityFocus: $accessibilityFocus
                    ) {
                        viewModel.dismissTrigger()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.selectedTriggerDetail)
            }
        }
    }
    
    /// Keeps global Dashboard controls and modal exclusion independent of the
    /// compact or wide visual composition selected below.
    private func sharedDashboardSurface(in size: CGSize) -> some View {
        dashboardContent(in: size)
            .frame(width: size.width, height: size.height)
            .accessibilityHidden(viewModel.selectedTriggerDetail != nil)
    }
    
    /// Selects visual layout only; shared sections own all accessibility behavior.
    @ViewBuilder
    private func dashboardContent(in size: CGSize) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityDashboard(in: size)
            } else if size.width >= 900 {
                wideDashboard(in: size)
            } else {
                compactDashboard(in: size)
            }
        }
    }
    
    private func wideDashboard(in size: CGSize) -> some View {
        let horizontalInset = size.width * 0.07
        let topInset = size.height * 0.098
        let introductionHeight = size.height * 0.122
        let rangeTopSpacing = size.height * 0.034
        let chartTopSpacing = size.height * 0.041
        let chartHeight = size.height * 0.526
        let contentWidth = max(0, size.width - (horizontalInset * 2))
        let triggerColumnWidth = contentWidth * 0.30
        let columnSpacing = contentWidth * 0.047
        let chartWidth = max(0, contentWidth - triggerColumnWidth - columnSpacing)
        
        return VStack(alignment: .leading, spacing: 0) {
            insightSection
                .frame(minHeight: introductionHeight, alignment: .topLeading)
            
            timeRangePicker
                .padding(.top, rangeTopSpacing)
            
            HStack(alignment: .top, spacing: columnSpacing) {
                moodChart(height: chartHeight)
                    .frame(width: chartWidth, height: chartHeight)
                
                VStack(spacing: 16) {
                    dateRangeCard

                    emotionCausesCard(height: nil)
                        .frame(maxHeight: .infinity)

                    addStoryButton
                }
                .frame(width: triggerColumnWidth, height: chartHeight)
            }
            .padding(.top, chartTopSpacing)
        }
        .padding(.top, topInset)
        .padding(.horizontal, horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func accessibilityDashboard(in size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                insightSection

                timeRangePicker

                moodChart(height: max(420, size.height * 0.48))
                    // The chart already has a complete spoken descriptor. Capping
                    // its visual labels prevents axes from consuming the plot.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                dateRangeCard

                emotionCausesCard(height: nil)

                addStoryButton
            }
            .padding(.horizontal, max(24, size.width * 0.05))
            .padding(.vertical, 32)
        }
    }
    
    private func compactDashboard(in size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                insightSection
                
                timeRangePicker
                
                moodChart(height: max(300, size.height * 0.42))
                
                dateRangeCard

                emotionCausesCard(height: 330)
                    .padding(.bottom, 12)
                
                addStoryButton
            }
            .padding(24)
        }
    }
    
    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("On this \(viewModel.selectedTimeRange.rawValue.lowercased()),")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .accessibilityAddTraits(.isHeader)
            
            insightContent
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
        }
    }

    private var dateRangeCard: some View {
        Text(viewModel.selectedDateRangeLabel)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(AppColour.txtCoklat)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 18)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 14 : 8)
            .background(
                AppColour.btnKuning
                    .opacity(0.16)
                    .accessibilityHidden(true)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(viewModel.selectedTimeRange.rawValue) chart date range, \(viewModel.selectedDateRangeLabel)"
            )
            .accessibilityAddTraits(.isHeader)
    }
    
    private var timeRangePicker: some View {
        Picker("Time range", selection: Binding(
            get: { viewModel.selectedTimeRange },
            set: { newRange in
                Task {
                    await viewModel.selectTimeRange(newRange)
                }
            }
        )) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue)
                    .tag(range)
                    .accessibilityLabel("\(range.rawValue) range")
                    .accessibilityHint(timeRangeAccessibilityHint(for: range))
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.extraLarge)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
    
    /// Explains each rolling range without exposing its date calculations.
    private func timeRangeAccessibilityHint(for range: TimeRange) -> String {
        switch range {
        case .day:
            "Generates insight for today."
        case .week:
            "Generates insight for the last 7 days."
        case .month:
            "Generates insight for the last 30 days."
        }
    }
    
    private func moodChart(height: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 14) {
            moodChartLegend
            
            Chart(viewModel.currentMoodBarData) { segment in
                BarMark(
                    x: .value("Time", segment.timeLabel),
                    y: .value("Mood count", segment.count),
                    width: .ratio(0.55), // <--- TAMBAHKAN INI UNTUK MERAMPINGKAN BAR
                    stacking: .standard
                )
                .foregroundStyle(moodBarColour(for: segment.mood))
                .cornerRadius(4)
                .annotation(position: .overlay) {
                    if shouldShowCount(for: segment) {
                        Text("\(segment.count)")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColour.txtCoklat)
                            .accessibilityHidden(true)
                            .transition(.opacity)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYScale(
                domain: 0...moodChartMaximumCount,
                range: .plotDimension(startPadding: 20)
            )
            .chartXAxis {
                AxisMarks { _ in
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(AppColour.txtCoklat.opacity(0.65))
                    AxisValueLabel()
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColour.txtCoklat)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(AppColour.txtCoklat.opacity(0.22))
                }
            }
            
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
            .chartOverlay { chartProxy in
                GeometryReader { geometryProxy in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            selectMood(
                                at: location,
                                chartProxy: chartProxy,
                                geometryProxy: geometryProxy
                            )
                        }
                        .accessibilityHidden(true)
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .accessibilityChartDescriptor(
                DashboardMoodChartDescriptor(
                    timeRange: viewModel.selectedTimeRange,
                    segments: viewModel.currentMoodBarData
                )
            )
        }
        .frame(height: height)
    }

    private func selectMood(
        at location: CGPoint,
        chartProxy: ChartProxy,
        geometryProxy: GeometryProxy
    ) {
        guard let plotFrameAnchor = chartProxy.plotFrame else { return }

        let plotFrame = geometryProxy[plotFrameAnchor]
        guard plotFrame.contains(location) else { return }

        let plotLocation = CGPoint(
            x: location.x - plotFrame.minX,
            y: location.y - plotFrame.minY
        )
        guard
            let timeLabel: String = chartProxy.value(atX: plotLocation.x),
            let count: Double = chartProxy.value(atY: plotLocation.y),
            let barCenterX = chartProxy.position(forX: timeLabel)
        else {
            return
        }

        let categoryWidth = plotFrame.width
            / CGFloat(max(1, Set(viewModel.currentMoodBarData.map(\.timeLabel)).count))
        let barHalfWidth = categoryWidth * 0.55 / 2
        guard abs(plotLocation.x - barCenterX) <= barHalfWidth else { return }

        let segments = viewModel.currentMoodBarData.filter {
            $0.timeLabel == timeLabel
        }
        var cumulativeCount = 0.0
        let tappedSegment = segments.first { segment in
            cumulativeCount += Double(segment.count)
            return count <= cumulativeCount
        }

        guard let tappedSegment else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if chartSelection == .segment(tappedSegment.id) {
                chartSelection = .none
            } else {
                chartSelection = .segment(tappedSegment.id)
            }
        }
    }

    private func shouldShowCount(for segment: MoodBarChartSegment) -> Bool {
        switch chartSelection {
        case .none:
            return false
        case .segment(let id):
            return segment.id == id
        case .mood(let mood):
            return segment.mood == mood
        }
    }
    
    private var moodChartLegend: some View {
        VStack(alignment: .trailing, spacing: 14) {
            ForEach(moodLegendOrder, id: \.self) { mood in
                Button {
                    toggleMoodSegments(mood)
                } label: {
                    HStack(spacing: 10) {
                        Image(mood.expressionImageName(for: storyFlow.childGender))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .accessibilityHidden(true)

                        Circle()
                            .fill(moodBarColour(for: mood))
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background {
                        if isMoodSelected(mood) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(moodBarColour(for: mood).opacity(0.18))
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(mood.accessibilityLabel) mood indicator")
                .accessibilityHint(
                    isMoodSelected(mood)
                        ? "Hides count for \(mood.accessibilityLabel)."
                        : "Shows count for \(mood.accessibilityLabel) on the chart."
                )
                .accessibilityAddTraits(.isButton)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func toggleMoodSegments(_ mood: Moods) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if chartSelection == .mood(mood) {
                chartSelection = .none
            } else {
                chartSelection = .mood(mood)
            }
        }
    }

    private func isMoodSelected(_ mood: Moods) -> Bool {
        chartSelection == .mood(mood)
    }
    
    private var moodLegendOrder: [Moods] {
        [.happy, .sad, .surprise, .fear, .disgust, .angry]
    }
    
    private var moodChartMaximumCount: Int {
        let totalsByTime = Dictionary(grouping: viewModel.currentMoodBarData, by: \.timeLabel)
            .mapValues { segments in segments.reduce(0) { $0 + $1.count } }
        
        return max(1, totalsByTime.values.max() ?? 0)
    }
    
    private func moodBarColour(for mood: Moods) -> Color {
        switch mood {
        case .happy: AppColour.barHappy
        case .sad: AppColour.barSad
        case .angry: AppColour.barAngry
        case .surprise: AppColour.barSurprised
        case .fear: AppColour.barFearful
        case .disgust: AppColour.barDisgusted
        }
    }
    
    private func emotionCausesCard(height: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Emotion Causes")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(
                    $accessibilityFocus,
                    equals: .commonTriggersHeading
                )
            
            if viewModel.commonTriggers.isEmpty {
                Text("No emotion causes yet.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.75))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("No emotion causes yet.")
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    triggerButtons
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        triggerButtons
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            
            if viewModel.commonTriggers.isEmpty {
                Spacer(minLength: 0)
            }
        }
        .padding(34)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height, alignment: .topLeading)
        .background(
            AppColour.btnKuning
                .opacity(0.16)
                .accessibilityHidden(true)
        )
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // Exclude the card wrapper as a readable leaf without hiding its
        // heading, empty message, or trigger buttons from VoiceOver.
        .accessibilityElement(children: .contain)
    }

    private var triggerButtons: some View {
        LazyVStack(spacing: 14) {
            ForEach(viewModel.commonTriggers, id: \.self) { trigger in
                Button {
                    triggerFocusReturnTarget = trigger
                    viewModel.selectTrigger(trigger)
                } label: {
                    Text(trigger)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppColour.txtCoklat)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
                        .overlay {
                            Capsule()
                                .stroke(AppColour.btnKuning, lineWidth: 1.5)
                                .accessibilityHidden(true)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trigger), emotion cause")
                .accessibilityHint(
                    "Shows explanation, evidence, and recommended activities."
                )
                .accessibilityFocused(
                    $accessibilityFocus,
                    equals: .trigger(trigger)
                )
            }
        }
    }
    
    /// Moves VoiceOver only when trigger detail is presented or dismissed.
    private func updateTriggerDetailAccessibilityFocus(
        from previousDetail: TriggerDetail?,
        to detail: TriggerDetail?
    ) {
        switch (previousDetail, detail) {
        case (nil, .some):
            Task { @MainActor in
                // Let SwiftUI insert the modal title before requesting focus.
                await Task.yield()
                guard viewModel.selectedTriggerDetail != nil else { return }
                accessibilityFocus = .triggerDialogTitle
            }
            
        case (.some, nil):
            let returnTarget = triggerFocusReturnTarget
            
            Task { @MainActor in
                // Let the Dashboard re-enter the accessibility tree first.
                await Task.yield()
                guard viewModel.selectedTriggerDetail == nil else { return }
                
                if let returnTarget,
                   viewModel.commonTriggers.contains(returnTarget) {
                    accessibilityFocus = .trigger(returnTarget)
                } else {
                    accessibilityFocus = .commonTriggersHeading
                }
                
                triggerFocusReturnTarget = nil
            }
            
        default:
            break
        }
    }
    
    private var addStoryButton: some View {
        Button {
            storyFlow.startStoryFromDashboard()
        } label: {
            HStack(spacing: 8) {
                Text("Add Story!")
                Image(systemName: "plus")
                    .accessibilityHidden(true)
            }
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(AppColour.txtPutih)
            .frame(maxWidth: .infinity, minHeight: 51)
            .background(
                AppColour.btnCoklat
                    .accessibilityHidden(true)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(storyFlow.isStoryCompletedToday)
        .accessibilityLabel("Add story")
        .accessibilityValue(
            storyFlow.isStoryCompletedToday
                ? "Unavailable"
                : "Available"
        )
        .accessibilityHint(
            storyFlow.isStoryCompletedToday
                ? "Today's story is complete after the end-of-day reflection."
                : "Starts a new story."
        )
    }

    #if DEBUG
    private var developmentDataButton: some View {
        NavigationLink {
            DevelopmentStoryDataView(modelContext: modelContext)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "tablecells")
                        .font(.title2.weight(.semibold))
                        .frame(width: 52, height: 52)
                } else {
                    Label("Story Data", systemImage: "tablecells")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                }
            }
            .foregroundStyle(AppColour.txtCoklat)
            .background(.regularMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open development story data")
        .accessibilityHint("Shows locally stored story entries in a table.")
    }
    #endif
    
    @ViewBuilder
    private var insightContent: some View {
        switch viewModel.state {
        case .idle:
            Text("Preparing your private insight…")
            
        case .loading(let phase):
            HStack(spacing: 10) {
                ProgressView()
                Text(phase.message)
            }
            .accessibilityElement(children: .combine)
            
        case .loaded:
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.summaryText)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(insightAccessibilityLabel)

                Text("This summary is AI-generated from recent activity logs and reflections. Use it as a helpful guide and review it alongside your own observations.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        "AI-generated summary notice. This summary is generated from recent activity logs and reflections. Use it as a helpful guide and review it alongside your own observations."
                    )
                
                if let fallbackLabel = viewModel.englishFallbackLabel {
                    HStack(spacing: 10) {
                        Text(fallbackLabel)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                        
                        Button("Retry Translation") {
                            Task {
                                await viewModel.retryOutputTranslation()
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint(
                            "Translates the existing English insight without generating a new insight."
                        )
                    }
                }
            }
            
        case .empty:
            Text("There are no stories in this range yet.")
            
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                
                Button("Retry") {
                    Task {
                        await viewModel.retryGeneration()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColour.btnKuning)
                .accessibilityHint(
                    "Generates a new insight for the selected range."
                )
            }
        }
    }
    
    /// Adds the child and selected range without duplicating them visually.
    private var insightAccessibilityLabel: String {
        let childName = viewModel.childName.isEmpty
        ? "Your child"
        : viewModel.childName
        
        return "\(viewModel.selectedTimeRange.rawValue) insight for \(childName). \(viewModel.summaryText)"
    }
    
    private func postAccessibilityAnnouncement(
        for state: DashboardPresentationState
    ) {
        guard let announcement = DashboardAccessibilityAnnouncement(
            state: state,
            selectedTimeRange: viewModel.selectedTimeRange,
            hasEnglishFallback: viewModel.englishFallback != nil
        ) else {
            return
        }
        
        // State is Equatable, so onChange posts only for a real lifecycle
        // transition and never for a normal SwiftUI re-render.
        AccessibilityNotification.Announcement(announcement.message).post()
    }
    
}

/*
#Preview {

}
*/

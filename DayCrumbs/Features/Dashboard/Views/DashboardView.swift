
import Charts
import SwiftUI

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    
    @AccessibilityFocusState private var accessibilityFocus: DashboardAccessibilityFocus?
    @State private var viewModel: DashboardViewModel
    @State private var translationTaskHost: AppleTranslationTaskHost
    
    /// Remembers which trigger opened the detail so modal dismissal can restore
    /// VoiceOver to the originating chip in the next presentation step.
    @State private var triggerFocusReturnTarget: String?
    
    init() {
        let translationTaskHost = AppleTranslationTaskHost()
        _translationTaskHost = State(initialValue: translationTaskHost)
        _viewModel = State(
            initialValue: DashboardViewModel(
                executeTranslationBatch: translationTaskHost.batchHandler
            )
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
            if size.width >= 900 {
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
        let triggerCardHeight = chartHeight * 0.72
        let triggerButtonSpacing = max(24, size.height * 0.035)
        
        return VStack(alignment: .leading, spacing: 0) {
            insightSection
                .frame(minHeight: introductionHeight, alignment: .topLeading)
            
            timeRangePicker
                .padding(.top, rangeTopSpacing)
            
            HStack(alignment: .top, spacing: columnSpacing) {
                moodChart(height: chartHeight)
                    .frame(width: chartWidth, height: chartHeight)
                
                VStack(spacing: 0) {
                    commonTriggersCard(height: triggerCardHeight)
                    
                    Spacer(minLength: triggerButtonSpacing)
                    
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
    
    private func compactDashboard(in size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                insightSection
                
                timeRangePicker
                
                moodChart(height: max(300, size.height * 0.42))
                
                commonTriggersCard(height: 330)
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
    
    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    Task {
                        await viewModel.selectTimeRange(range)
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppColour.txtCoklat)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle()) // <--- TAMBAHKAN BARIS INI
                        .background {
                            if viewModel.selectedTimeRange == range {
                                Capsule()
                                    .fill(AppColour.btnKuning)
                                    .accessibilityHidden(true)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(range.rawValue) range")
                .accessibilityAddTraits(
                    viewModel.selectedTimeRange == range ? .isSelected : []
                )
                .accessibilityHint(timeRangeAccessibilityHint(for: range))
            }
        }
        .padding(2)
        .background {
            Capsule()
                .fill(AppColour.btnKuning.opacity(0.18))
                .accessibilityHidden(true)
        }
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
                    Text("\(segment.count)")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColour.txtCoklat)
                        .accessibilityHidden(true)
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
    
    private var moodChartLegend: some View {
        VStack(alignment: .trailing, spacing: 12) {
            ForEach(moodLegendOrder, id: \.self) { mood in
                HStack(spacing: 8) {
                    Image(mood.expressionImageName(for: storyFlow.childGender))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .accessibilityHidden(true)
                    
                    Circle()
                        .fill(moodBarColour(for: mood))
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(mood.accessibilityLabel) colour")
            }
        }
        .accessibilityElement(children: .contain)
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
    
    private func commonTriggersCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Common Triggers")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(
                    $accessibilityFocus,
                    equals: .commonTriggersHeading
                )
            
            if viewModel.commonTriggers.isEmpty {
                Text("No repeated triggers yet.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.75))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("No repeated triggers yet.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.commonTriggers, id: \.self) { trigger in
                            Button {
                                triggerFocusReturnTarget = trigger
                                viewModel.selectTrigger(trigger)
                            } label: {
                                Text(trigger)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(AppColour.txtCoklat)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .padding(.horizontal, 12)
                                    .overlay {
                                        Capsule()
                                            .stroke(AppColour.btnKuning, lineWidth: 1.5)
                                            .accessibilityHidden(true)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(trigger), common trigger")
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .foregroundStyle(AppColour.txtCoklat)
            .frame(maxWidth: .infinity, minHeight: 51)
            .background(
                AppColour.btnKuning
                    .accessibilityHidden(true)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add story")
    }
    
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
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.summaryText)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(insightAccessibilityLabel)
                
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

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(StoryFlowCoordinator())
}

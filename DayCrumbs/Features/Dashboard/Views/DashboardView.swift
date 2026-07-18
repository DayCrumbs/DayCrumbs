import Charts
import SwiftUI

struct DashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: DashboardViewModel
    @State private var translationTaskHost: AppleTranslationTaskHost
    @State private var navigateToSession = false

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
            dashboardContent(in: geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(AppColour.bgPutih.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .appleTranslationTaskHost(translationTaskHost)
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.cancelGeneration()
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
        .navigationDestination(isPresented: $navigateToSession) {
            SessionOptionView()
        }
        .overlay(alignment: .topLeading) {
            CircularBackButton(style: .yellowBtn) {
                dismiss()
            }
            .padding(.top, 24)
            .padding(.leading, 32)
        }
        .overlay {
            if let detail = viewModel.selectedTriggerDetail {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.dismissTrigger()
                        }

                    TriggerAlertView(detail: detail) {
                        viewModel.dismissTrigger()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.selectedTriggerDetail)
            }
        }
    }

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

        return VStack(alignment: .leading, spacing: 0) {
            insightSection
                .frame(minHeight: introductionHeight, alignment: .topLeading)

            timeRangePicker
                .padding(.top, rangeTopSpacing)

            HStack(alignment: .top, spacing: columnSpacing) {
                moodChart(height: chartHeight)
                    .frame(width: chartWidth, height: chartHeight)

                VStack(spacing: 0) {
                    commonTriggersCard(height: chartHeight * 0.74)

                    Spacer(minLength: 0)

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
                        .background {
                            if viewModel.selectedTimeRange == range {
                                Capsule()
                                    .fill(AppColour.btnKuning)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityValue(
                    viewModel.selectedTimeRange == range ? "Selected" : "Not selected"
                )
            }
        }
        .padding(2)
        .background(Capsule().fill(AppColour.btnKuning.opacity(0.18)))
    }

    private func moodChart(height: CGFloat) -> some View {
        Chart(viewModel.currentChartData) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timeLabel),
                y: .value("Mood", dataPoint.moodScore)
            )
            .symbol(Circle())
            .symbolSize(42)
            .interpolationMethod(.linear)
            .foregroundStyle(AppColour.txtCoklat)
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 1...6)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.22))
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.65))
                AxisValueLabel()
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColour.txtCoklat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [1, 2, 3, 4, 5, 6]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisTick(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel(anchor: .trailing) {
                    if let moodScore = value.as(Int.self) {
                        Image(Moods.expressionImageName(forDashboardMoodScore: moodScore))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                    }
                }
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
        .frame(height: height)
    }

    private func commonTriggersCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Common Triggers")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)

            if viewModel.commonTriggers.isEmpty {
                Text("No repeated triggers yet.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.75))
            } else {
                ForEach(Array(viewModel.commonTriggers.prefix(5)), id: \.self) { trigger in
                    Button {
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
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(34)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(AppColour.btnKuning.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    private var addStoryButton: some View {
        Button {
            navigateToSession = true
        } label: {
            HStack(spacing: 8) {
                Text("Add Story!")
                Image(systemName: "plus")
            }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .frame(maxWidth: .infinity, minHeight: 51)
                .background(AppColour.btnKuning)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var insightContent: some View {
        switch viewModel.state {
        case .idle:
            Text("Preparing your private insight…")

        case .loading(let message):
            HStack(spacing: 10) {
                ProgressView()
                Text(message)
            }

        case .loaded:
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.summaryText)

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
            }
        }
    }

}

#Preview {
    NavigationStack {
        DashboardView()
    }
}

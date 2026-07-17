import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: DashboardViewModel
    @State private var translationTaskHost: AppleTranslationTaskHost
    @State private var navigateToSession: Bool = false

    init() {
        // The same host supplies the handler and remains mounted at the stable root.
        let translationTaskHost = AppleTranslationTaskHost()
        _translationTaskHost = State(initialValue: translationTaskHost)
        _viewModel = State(
            initialValue: DashboardViewModel(
                executeTranslationBatch: translationTaskHost.batchHandler
            )
        )
    }

    var body: some View {
        HStack(spacing: 0) {

            // MARK: - BAGIAN KIRI (Placeholder Ilustrasi)
            ZStack {
                AppColour.bgPutih.opacity(0.5)

                Text("Illustration Area")
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(AppColour.txtCoklat.opacity(0.5))
            }
            .frame(maxWidth: .infinity)


            // MARK: - BAGIAN KANAN (Data Analytics)
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                // 1. Judul & Summary (LLM Result)
                VStack(alignment: .leading, spacing: 8) {
                    Text("On this \(viewModel.selectedTimeRange.rawValue.lowercased()),")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundColor(AppColour.txtCoklat)

                    insightContent
                }
                .font(.system(.title3, design: .rounded))
                .foregroundColor(AppColour.txtCoklat)

                // 2. Custom Segmented Picker
                HStack(spacing: 0) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue)
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundColor(viewModel.selectedTimeRange == range ? AppColour.txtCoklat : AppColour.txtCoklat.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedTimeRange == range ? AppColour.btnKuning : Color.clear)
                                    .animation(
                                        .easeInOut(duration: 0.2),
                                        value: viewModel.selectedTimeRange == range
                                    )
                            )
                            .onTapGesture {
                                Task {
                                    await viewModel.selectTimeRange(range)
                                }
                            }
                    }
                }
                // Background luar picker (bisa disesuaikan warnanya)
                .background(Capsule().fill(AppColour.btnKuning.opacity(0.2)))
                .padding(.vertical, 8)

                // 3. Line Chart
                Chart(viewModel.currentChartData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timeLabel),
                        y: .value("Mood", dataPoint.moodScore)
                    )
                    .symbol(Circle())
                    .foregroundStyle(AppColour.txtCoklat)
                    // Session and day labels are categorical, so connect them directly.
                    .interpolationMethod(.linear)
                }
                // Every range shares the same stable scale for the six mood labels.
                .chartYScale(domain: 1...6)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 2, 3, 4, 5, 6]) { value in
                        AxisValueLabel(anchor: .trailing) {
                            if let intValue = value.as(Int.self) {
                                Image(moodImageName(for: intValue))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            }
                        }
                    }
                }
                .transaction { transaction in
                    // Charts cannot safely animate between disjoint String domains.
                    transaction.animation = nil
                }
                .frame(height: 220)
                .padding(.bottom, 24)

                // 4. Common Triggers
                if !viewModel.commonTriggers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Common Triggers")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundColor(AppColour.txtCoklat)

                        HStack(spacing: 12) {
                            ForEach(viewModel.commonTriggers, id: \.self) { trigger in
                                Button(action: {
                                    // Opening a trigger only reads the published local result.
                                    viewModel.selectTrigger(trigger)
                                }) {
                                    Text(trigger)
                                        .font(.system(.subheadline, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Capsule().stroke(AppColour.btnKuning, lineWidth: 1.5))
                                        .foregroundColor(AppColour.txtCoklat)
                                }
                            }
                        }
                    }
                }

                Spacer()

                // 5. Add Story Button
                HStack {
                    Spacer()

                    Button(action: {
                        navigateToSession = true
                    }) {
                        HStack(spacing: 8) {
                            Text("Add Story!")
                            Image(systemName: "plus")
                        }
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundColor(AppColour.txtCoklat)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(AppColour.btnKuning)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .background(AppColour.bgPutih)
        // Keep TranslationSession anchored to the stable Dashboard root.
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
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToSession) {
            SessionOptionView()
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
                            .font(.system(.caption, design: .rounded).bold())

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

    // MARK: - Helper Function
    private func moodImageName(for score: Int) -> String {
        switch score {
        case 6: return "ExpressionHappyFace_Girl"
        case 5: return "ExpressionSadFace_Girl"
        case 4: return "ExpressionSurpriseFace_Girl"
        case 3: return "ExpressionFearFace_Girl"
        case 2: return "ExpressionDisgustFace_Girl"
        case 1: return "ExpressionAngryFace_Girl"
        default: return "ExpressionHappyFace_Girl"
        }
    }
}

#Preview {
    DashboardView()
}

import SwiftUI
import Charts

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var navigateToSession: Bool = false
    
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
                    
                    Text("\(Text(viewModel.childName).underline()) \(viewModel.summaryText)")
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
                            )
                        // Animasi perpindahan tab
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedTimeRange = range
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
                    .interpolationMethod(.monotone)
                }
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
                .frame(height: 220)
                .padding(.bottom, 24)
                
                // 4. Common Triggers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Common Triggers")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundColor(AppColour.txtCoklat)
                    
                    HStack(spacing: 12) {
                        ForEach(viewModel.commonTriggers, id: \.self) { trigger in
                            Button(action: {
                                // Memicu pemanggilan data LLM
                                viewModel.fetchTriggerDetail(for: trigger)
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
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToSession) {
            SessionOptionView()
        }
        .overlay {
            // Jika ada data detail trigger, munculkan alert
            if let detail = viewModel.selectedTriggerDetail {
                ZStack {
                    // Latar belakang hitam transparan untuk menggelapkan layar
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Menutup alert jika area luar diklik
                            viewModel.dismissTriggerAlert()
                        }
                    
                    // Memanggil komponen alert yang kita buat di Langkah 2
                    TriggerAlertView(detail: detail) {
                        viewModel.dismissTriggerAlert()
                    }
                }
                // Animasi halus saat muncul/hilang
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.selectedTriggerDetail)
            }
        }
    }
    
    // MARK: - Helper Function
    private func moodImageName(for score: Int) -> String {
        switch score {
        case 6: return "HappyFace"
        case 5: return "SadFace"
        case 4: return "SurpriseFace"
        case 3: return "FearFace"
        case 2: return "DisgustFace"
        case 1: return "AngryFace"
        default: return "HappyFace"
        }
    }
}

#Preview {
    DashboardView()
}

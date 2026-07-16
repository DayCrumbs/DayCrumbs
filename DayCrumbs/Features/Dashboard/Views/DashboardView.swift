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
                
                // 2. Segmented Picker
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                // 3. Line Chart
                Chart(viewModel.chartData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timeLabel),
                        y: .value("Mood", dataPoint.moodScore)
                    )
                    .symbol(Circle())
                    .foregroundStyle(AppColour.txtCoklat)
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
                
                // 4. Common Triggers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Common Triggers")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundColor(AppColour.txtCoklat)
                    
                    HStack(spacing: 12) {
                        ForEach(viewModel.commonTriggers, id: \.self) { trigger in
                            Text(trigger)
                                .font(.system(.subheadline, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().stroke(AppColour.btnKuning, lineWidth: 1.5))
                                .foregroundColor(AppColour.txtCoklat)
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

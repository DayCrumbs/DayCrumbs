import Foundation
import Observation

struct MoodDataPoint: Identifiable {
    let id = UUID()
    let timeLabel: String
    let moodScore: Int
}

// Struktur data khusus untuk menampung hasil LLM di Alert
struct TriggerDetail: Equatable {
    let title: String
    let description: String
    let recommendedActivities: [String]
    let preventions: [String]
}

@Observable
class DashboardViewModel {
    var selectedTimeRange: TimeRange = .day
    
    var childName: String = "Melissa"
    var summaryText: String = "has been feeling down, mainly due to school homework"
    var commonTriggers: [String] = ["Nighttime", "Doing Homework", "Sports Activity"]
    
    // 1. Dummy Data untuk 'Day' (Menggunakan Sessions yang ada di modelmu)
    private var dayData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Morning", moodScore: 4),
        MoodDataPoint(timeLabel: "Afternoon", moodScore: 2),
        MoodDataPoint(timeLabel: "Evening", moodScore: 3),
        MoodDataPoint(timeLabel: "Night", moodScore: 5)
    ]
    
    // 2. Dummy Data untuk 'Week' (Menggunakan Hari)
    private var weekData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Mon", moodScore: 2),
        MoodDataPoint(timeLabel: "Tue", moodScore: 3),
        MoodDataPoint(timeLabel: "Wed", moodScore: 4),
        MoodDataPoint(timeLabel: "Thu", moodScore: 3),
        MoodDataPoint(timeLabel: "Fri", moodScore: 5),
        MoodDataPoint(timeLabel: "Sat", moodScore: 4),
        MoodDataPoint(timeLabel: "Sun", moodScore: 6)
    ]
    
    // 3. Dummy Data untuk 'Month' (Menggunakan Minggu)
    private var monthData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Week 1", moodScore: 3),
        MoodDataPoint(timeLabel: "Week 2", moodScore: 5),
        MoodDataPoint(timeLabel: "Week 3", moodScore: 2),
        MoodDataPoint(timeLabel: "Week 4", moodScore: 4)
    ]
    
    // MARK: - Dynamic Data Provider
    // Variabel ini akan otomatis berganti isi setiap kali pengguna memilih TimeRange
    var currentChartData: [MoodDataPoint] {
        switch selectedTimeRange {
        case .day: return dayData
        case .week: return weekData
        case .month: return monthData
        }
    }
    
    // MARK: - Trigger Alert
    // Variabel state untuk menampilkan/menyembunyikan alert
        var selectedTriggerDetail: TriggerDetail? = nil
        
        // Fungsi yang dipanggil saat tombol Trigger di-klik
        func fetchTriggerDetail(for trigger: String) {
            // INI ADALAH DUMMY DATA.
            // Nanti temanmu (Tim LLM) akan menghapus isi fungsi ini dan
            // menggantinya dengan logika pemanggilan Gemma.
            self.selectedTriggerDetail = TriggerDetail(
                title: trigger,
                description: "Melissa often feels sad when it's \(trigger.lowercased()) because she prefers the daytime where she can do various activities.",
                recommendedActivities: [
                    "Read a story together",
                    "Listen to calming music"
                ],
                preventions: [
                    "Keeps a consistent bedtime routine",
                    "Provide reassurance and comfort"
                ]
            )
        }
        
        func dismissTriggerAlert() {
            self.selectedTriggerDetail = nil
        }
}

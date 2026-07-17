import Foundation
import Observation

struct MoodDataPoint: Identifiable {
    let id = UUID()
    let timeLabel: String
    let moodScore: Int
}

@Observable
class DashboardViewModel {
    var selectedTimeRange: TimeRange = .day
    
    var childName: String = "Melissa"
    var summaryText: String = "has been feeling down, mainly due to school homework"

    private let recommendationCatalog = ParentRecommendationCatalog()

    // Section 5 replaces this fixture with the automatically generated insight.
    // Trigger selection already uses the final local catalog path and never calls an LLM.
    private let displayedInsight = AnalyticsInsight(
        summary: "Melissa has several moments that may be worth observing.",
        commonTriggers: [
            AnalyticsInsight.CommonTrigger(
                title: "Nighttime",
                explanation: "Nighttime appeared alongside a lower mood in the supplied story rows."
            ),
            AnalyticsInsight.CommonTrigger(
                title: "Doing Homework",
                explanation: "Homework appeared in a supplied school-related observation."
            ),
            AnalyticsInsight.CommonTrigger(
                title: "Sports Activity",
                explanation: "Outdoor sports appeared in a supplied activity observation."
            ),
        ],
        observedPatterns: [
            AnalyticsInsight.ObservedPattern(
                title: "Night observation",
                evidence: "One supplied nighttime entry recorded a sad mood.",
                linkedTrigger: "Nighttime",
                contextTags: ["night", "sleep"]
            ),
            AnalyticsInsight.ObservedPattern(
                title: "Homework observation",
                evidence: "One supplied school entry linked homework with a sad mood.",
                linkedTrigger: "Doing Homework",
                contextTags: ["school", "study"]
            ),
            AnalyticsInsight.ObservedPattern(
                title: "Outdoor activity observation",
                evidence: "One supplied outdoor entry included a sports activity.",
                linkedTrigger: "Sports Activity",
                contextTags: ["outdoor", "play"]
            ),
        ],
        parentReflectionPrompt: "What felt different during these moments?",
        ethicalNote: "This private observation is not a diagnosis."
    )

    var commonTriggers: [String] {
        displayedInsight.commonTriggers.map(\.title)
    }
    
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
    
    // MARK: - Trigger Detail
    var selectedTriggerDetail: TriggerDetail?

    func selectTriggerDetail(for triggerTitle: String) {
        guard let trigger = displayedInsight.commonTriggers.first(where: {
            $0.title == triggerTitle
        }) else {
            selectedTriggerDetail = nil
            return
        }

        selectedTriggerDetail = recommendationCatalog.triggerDetail(
            for: trigger,
            in: displayedInsight
        )
    }

    func dismissTriggerAlert() {
        selectedTriggerDetail = nil
    }
}

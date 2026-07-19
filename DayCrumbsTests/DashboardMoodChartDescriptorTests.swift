import Accessibility
import Testing

@testable import DayCrumbs

@Suite("Dashboard mood chart accessibility")
@MainActor
struct DashboardMoodChartDescriptorTests {
    @Test("Descriptor names the range and categorical axis")
    func descriptorTitles() {
        let descriptor = DashboardMoodChartDescriptor(
            timeRange: .day,
            dataPoints: [
                MoodDataPoint(timeLabel: "Morning", moodScore: 4),
            ]
        ).makeChartDescriptor()

        #expect(descriptor.title == "Mood trend for Day.")
        #expect(descriptor.xAxis.title == "Session")
        #expect(descriptor.yAxis?.title == "Mood")
    }

    @Test("Mood scores are spoken only as canonical mood labels")
    func moodValueDescriptions() throws {
        let descriptor = DashboardMoodChartDescriptor(
            timeRange: .week,
            dataPoints: []
        ).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)
        let expectedLabels = [
            "Angry mood",
            "Disgust mood",
            "Fear mood",
            "Surprise mood",
            "Sad mood",
            "Happy mood",
        ]

        for (score, expectedLabel) in zip(1...6, expectedLabels) {
            let spokenValue = yAxis.valueDescriptionProvider(Double(score))

            #expect(spokenValue == expectedLabel)
            #expect(!spokenValue.contains(String(score)))
        }

        #expect(yAxis.valueDescriptionProvider(.nan) == "Mood")
    }

    @Test("Descriptor preserves every chart data point")
    func descriptorDataPoints() throws {
        let descriptor = DashboardMoodChartDescriptor(
            timeRange: .month,
            dataPoints: [
                MoodDataPoint(timeLabel: "Week 1", moodScore: 3),
                MoodDataPoint(timeLabel: "Week 2", moodScore: 5),
            ]
        ).makeChartDescriptor()
        let series = try #require(descriptor.series.first)

        #expect(series.name == "Mood trend")
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == 2)
    }
}

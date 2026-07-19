import Accessibility
import SwiftUI

/// VoiceOver representation of the visual mood trend chart.
struct DashboardMoodChartDescriptor: AXChartDescriptorRepresentable {
    let timeRange: TimeRange
    let dataPoints: [MoodDataPoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: xAxisTitle,
            categoryOrder: dataPoints.map(\.timeLabel)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Mood",
            range: 1...6,
            gridlinePositions: []
        ) { value in
            // VoiceOver receives a canonical mood, never the internal score.
            Moods.dashboardAccessibilityLabel(forScore: value)
        }
        let series = AXDataSeriesDescriptor(
            name: "Mood trend",
            isContinuous: true,
            dataPoints: dataPoints.map { dataPoint in
                AXDataPoint(
                    x: dataPoint.timeLabel,
                    y: Double(dataPoint.moodScore)
                )
            }
        )

        return AXChartDescriptor(
            title: "Mood trend for \(timeRange.rawValue).",
            summary: chartSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }

    private var xAxisTitle: String {
        switch timeRange {
        case .day:
            "Session"
        case .week:
            "Day"
        case .month:
            "Week"
        }
    }

    private var chartSummary: String {
        "Shows the observed mood for each \(xAxisTitle.lowercased()) in this range."
    }
}

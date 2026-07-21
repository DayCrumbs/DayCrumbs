import Accessibility
import SwiftUI

/// VoiceOver representation of the stacked mood-count chart.
struct DashboardMoodChartDescriptor: AXChartDescriptorRepresentable {
    let timeRange: TimeRange
    let segments: [MoodBarChartSegment]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: xAxisTitle,
            categoryOrder: orderedTimeLabels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Mood count",
            range: 0...Double(maximumCount),
            gridlinePositions: []
        ) { value in
            "\(Int(value)) logged moods"
        }
        let series = Moods.allCases.compactMap { mood -> AXDataSeriesDescriptor? in
            let moodSegments = segments.filter { $0.mood == mood }
            guard !moodSegments.isEmpty else { return nil }

            return AXDataSeriesDescriptor(
                name: mood.accessibilityLabel,
                isContinuous: false,
                dataPoints: moodSegments.map { segment in
                    AXDataPoint(
                        x: segment.timeLabel,
                        y: Double(segment.count)
                    )
                }
            )
        }

        return AXChartDescriptor(
            title: "Mood counts for \(timeRange.rawValue).",
            summary: chartSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: series
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
        "Shows the number of each observed mood for every \(xAxisTitle.lowercased()) in this range."
    }

    private var orderedTimeLabels: [String] {
        var labels: [String] = []
        for segment in segments where !labels.contains(segment.timeLabel) {
            labels.append(segment.timeLabel)
        }
        return labels
    }

    private var maximumCount: Int {
        let totalsByTime = Dictionary(grouping: segments, by: \.timeLabel)
            .mapValues { values in values.reduce(0) { $0 + $1.count } }

        return max(1, totalsByTime.values.max() ?? 0)
    }
}

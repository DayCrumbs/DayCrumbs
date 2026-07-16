//
//  DashboardViewModel.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/16/26.
//

import Foundation
import Observation

// Enum untuk Segmented Picker
enum TimeRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

// Model data untuk titik di dalam grafik
struct MoodDataPoint: Identifiable {
    let id = UUID()
    let timeLabel: String
    let moodScore: Int // Skala 1-6 untuk mewakili 6 jenis mood
}

@Observable
class DashboardViewModel {
    var selectedTimeRange: TimeRange = .week
    
    // Variabel ini akan diisi oleh teks dari Gemma (LLM)
    var childName: String = "Melissa"
    var summaryText: String = "has been feeling down, mainly due to school homework"
    
    // Variabel untuk Common Triggers
    var commonTriggers: [String] = ["Nighttime", "Doing Homework", "Sports Activity"]
    
    // Dummy Data untuk Line Chart
    var chartData: [MoodDataPoint] = [
        MoodDataPoint(timeLabel: "Mon", moodScore: 2),
        MoodDataPoint(timeLabel: "Tue", moodScore: 3),
        MoodDataPoint(timeLabel: "Wed", moodScore: 4),
        MoodDataPoint(timeLabel: "Thu", moodScore: 3),
        MoodDataPoint(timeLabel: "Fri", moodScore: 5),
        MoodDataPoint(timeLabel: "Sat", moodScore: 4),
        MoodDataPoint(timeLabel: "Sun", moodScore: 6)
    ]
}

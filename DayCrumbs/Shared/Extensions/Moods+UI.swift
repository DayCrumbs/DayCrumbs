import Foundation

extension Moods {
    nonisolated var accessibilityLabel: String {
        "\(rawValue.capitalized) mood"
    }

    var expressionImageName: String {
        switch self {
        case .angry: return "ExpressionAngryFace_Girl"
        case .disgust: return "ExpressionDisgustFace_Girl"
        case .fear: return "ExpressionFearFace_Girl"
        case .happy: return "ExpressionHappyFace_Girl"
        case .sad: return "ExpressionSadFace_Girl"
        case .surprise: return "ExpressionSurpriseFace_Girl"
        }
    }

    /// Maps the chart's internal visual score to the existing mood vocabulary.
    nonisolated static func dashboardMood(forScore score: Int) -> Moods {
        switch score {
        case 6: .happy
        case 5: .sad
        case 4: .surprise
        case 3: .fear
        case 2: .disgust
        default: .angry
        }
    }

    /// Converts the chart's internal score into a VoiceOver-safe mood label.
    nonisolated static func dashboardAccessibilityLabel(forScore value: Double) -> String {
        // Accessibility may probe the formatter with a non-finite sentinel while
        // validating the descriptor, so guard before converting to an integer.
        guard value.isFinite else { return "Mood" }

        let boundedScore = min(max(value.rounded(), 1), 6)
        return dashboardMood(forScore: Int(boundedScore)).accessibilityLabel
    }

    static func expressionImageName(forDashboardMoodScore score: Int) -> String {
        dashboardMood(forScore: score).expressionImageName
    }
}

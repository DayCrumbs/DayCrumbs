import Foundation

extension Moods {
    nonisolated var accessibilityLabel: String {
        "\(rawValue.capitalized) mood"
    }

    var expressionImageName: String {
        expressionImageName(for: .girl)
    }

    func expressionImageName(for gender: ChildGender) -> String {
        switch (self, gender) {
        case (.angry, .girl): return "ExpressionAngryFace_Girl"
        case (.disgust, .girl): return "ExpressionDisgustFace_Girl"
        case (.fear, .girl): return "ExpressionFearFace_Girl"
        case (.happy, .girl): return "ExpressionHappyFace_Girl"
        case (.sad, .girl): return "ExpressionSadFace_Girl"
        case (.surprise, .girl): return "ExpressionSurpriseFace_Girl"
        case (.angry, .boy): return "ExpressionAngryFace_Boy"
        case (.disgust, .boy): return "ExpressionDisgustFace_Boy"
        case (.fear, .boy): return "ExrpessionFearFace_Boy"
        case (.happy, .boy): return "ExpressionHappyFace_Boy"
        case (.sad, .boy): return "ExrpessionSadFace_Boy"
        case (.surprise, .boy): return "ExpressionSurpriseFace_Boy"
        }
    }

    func clothedExpressionImageName(for gender: ChildGender) -> String {
        switch (self, gender) {
        case (.angry, .girl): return "ExpressionAngryFace_Girl_PakeBaju"
        case (.disgust, .girl): return "ExpressionDisgustFace_Girl_PakeBaju"
        case (.fear, .girl): return "ExpressionFearFace_Girl_PakeBaju"
        case (.happy, .girl): return "ExpressionHappyFace_Girl_PakeBaju"
        case (.sad, .girl): return "ExpressionSadFace_Girl_PakeBaju"
        case (.surprise, .girl): return "ExpressionSurpriseFace_Girl_PakeBaju"
        case (.angry, .boy): return "ExpressionAngryFace_Boy_PakeBaju"
        case (.disgust, .boy): return "ExpressionDisgustFace_Boy_PakeBaju"
        case (.fear, .boy): return "ExpressionFearFace_Boy_PakeBaju"
        case (.happy, .boy): return "ExpressionHappyFace_Boy_PakeBaju"
        case (.sad, .boy): return "ExpressionSadFace_Boy_PakeBaju"
        case (.surprise, .boy): return "ExpressionSurpriseFace_Boy_PakeBaju"
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

    static func expressionImageName(
        forDashboardMoodScore score: Int,
        gender: ChildGender = .girl
    ) -> String {
        dashboardMood(forScore: score).expressionImageName(for: gender)
    }
}

import Foundation

extension Moods {
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

    static func expressionImageName(forDashboardMoodScore score: Int) -> String {
        let mood: Moods

        switch score {
        case 6: mood = .happy
        case 5: mood = .sad
        case 4: mood = .surprise
        case 3: mood = .fear
        case 2: mood = .disgust
        default: mood = .angry
        }

        return mood.expressionImageName
    }
}

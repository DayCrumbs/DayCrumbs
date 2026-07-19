import Foundation

/// Distinguishes work that shares the same visual loading treatment.
nonisolated enum DashboardLoadingPhase: Equatable {
    case stories
    case insight
    case outputTranslation

    nonisolated var message: String {
        switch self {
        case .stories:
            "Loading stories…"
        case .insight:
            "Generating a private on-device insight…"
        case .outputTranslation:
            "Retrying on-device translation…"
        }
    }
}

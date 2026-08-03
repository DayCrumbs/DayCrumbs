import Foundation

/// Internally resolved analytics runtime. This is never a user preference.
nonisolated enum AnalysisEngine: String, Codable, Equatable, Sendable {
    case appleFoundationModels
    case gemma4E2B
}

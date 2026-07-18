import Foundation

/// A non-diagnostic action selected from the app's curated local catalog.
nonisolated struct ParentRecommendation: Equatable, Sendable {
    enum SourceLabel: String, CaseIterable, Equatable, Hashable, Sendable {
        case cdc = "CDC"
        case aap = "AAP"
        case harvard = "Harvard"
    }

    let title: String
    let recommendedActivities: [String]
    let whatMayHelp: [String]
    let sourceLabels: [SourceLabel]
}

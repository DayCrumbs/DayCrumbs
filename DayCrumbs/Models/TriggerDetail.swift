import Foundation

/// Combines generated observations with a separately curated recommendation.
nonisolated struct TriggerDetail: Equatable, Sendable {
    struct Evidence: Equatable, Sendable {
        let title: String
        let explanation: String
        let contextTags: [String]
    }

    let title: String
    let explanation: String
    let evidence: [Evidence]
    let recommendationTitle: String
    let recommendedActivities: [String]
    let whatMayHelp: [String]
    let sourceLabels: [ParentRecommendation.SourceLabel]
}

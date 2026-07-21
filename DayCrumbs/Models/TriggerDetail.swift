import Foundation

/// Combines generated observations with a separately curated recommendation.
nonisolated struct TriggerDetail: Equatable, Sendable {
    /// Runtime-translated presentation labels for trigger-detail sections.
    struct SectionLabels: Equatable, Sendable {
        let evidence: String
        let recommendedActivities: String
        let whatMayHelp: String
        let curatedSources: String

        nonisolated static let english = SectionLabels(
            evidence: "Evidence",
            recommendedActivities: "Recommended Activities",
            whatMayHelp: "What may help",
            curatedSources: "Curated sources"
        )
    }

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
    let sectionLabels: SectionLabels
}

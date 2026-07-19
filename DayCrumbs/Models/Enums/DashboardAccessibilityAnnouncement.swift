import Foundation

/// Meaningful Dashboard lifecycle changes that VoiceOver should announce.
nonisolated enum DashboardAccessibilityAnnouncement: Equatable {
    case generatingInsight(TimeRange)
    case insightReady(TimeRange)
    case emptyRange
    case failure(String)
    case englishFallback

    nonisolated init?(
        state: DashboardPresentationState,
        selectedTimeRange: TimeRange,
        hasEnglishFallback: Bool
    ) {
        switch state {
        case .loading(.insight):
            self = .generatingInsight(selectedTimeRange)
        case .loaded where hasEnglishFallback:
            self = .englishFallback
        case .loaded:
            self = .insightReady(selectedTimeRange)
        case .empty:
            self = .emptyRange
        case .failed(let message):
            self = .failure(message)
        case .idle, .loading(.stories), .loading(.outputTranslation):
            return nil
        }
    }

    nonisolated var message: String {
        switch self {
        case .generatingInsight(let range):
            "Generating \(range.rawValue) insight."
        case .insightReady(let range):
            "\(range.rawValue) insight is ready."
        case .emptyRange:
            "There are no stories for this range."
        case .failure(let message):
            message
        case .englishFallback:
            "Insight is available in English. Translation can be retried."
        }
    }
}

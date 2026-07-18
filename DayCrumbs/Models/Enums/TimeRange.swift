import Foundation

/// Rolling date scopes supported by the Dashboard.
enum TimeRange: String, CaseIterable, Equatable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    /// The number of calendar days included in the rolling range.
    var dayCount: Int {
        switch self {
        case .day:
            1
        case .week:
            7
        case .month:
            30
        }
    }
}

import Foundation

/// Applies the Dashboard's rolling, half-open date scopes to fetched entries.
@MainActor
struct DashboardEntrySelectionService {
    enum SelectionError: Error, Equatable {
        case invalidDateBoundary
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func entries(
        for timeRange: TimeRange,
        from entries: [StoryEntry],
        referenceDate: Date = .now
    ) throws -> [StoryEntry] {
        let todayStart = calendar.startOfDay(for: referenceDate)

        guard
            let rangeStart = calendar.date(
                byAdding: .day,
                value: -(timeRange.dayCount - 1),
                to: todayStart
            ),
            let nextDayStart = calendar.date(
                byAdding: .day,
                value: 1,
                to: todayStart
            )
        else {
            throw SelectionError.invalidDateBoundary
        }

        // A half-open range avoids counting midnight in two adjacent scopes.
        return entries
            .filter { entry in
                entry.recordedAt >= rangeStart && entry.recordedAt < nextDayStart
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }
}

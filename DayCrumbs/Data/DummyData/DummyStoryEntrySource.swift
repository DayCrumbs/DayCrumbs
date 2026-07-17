import Foundation

/// Supplies the rolling 30-day fixture while persistence wiring is pending.
@MainActor
final class DummyStoryEntrySource: StoryEntrySource {
    private let referenceDate: Date
    private let calendar: Calendar

    init(
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    func fetchEntries() async throws -> [StoryEntry] {
        // One profile owns every generated session and entry, matching the
        // production single-child invariant.
        let childProfile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        let sessions = DummyStory.generateSessions(
            for: childProfile,
            referenceDate: referenceDate,
            calendar: calendar
        )

        childProfile.dailySessions = sessions

        return sessions
            .flatMap(\.entries)
            .sorted { $0.recordedAt < $1.recordedAt }
    }
}

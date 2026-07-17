import Foundation

/// Supplies the rolling 30-day fixture while persistence wiring is pending.
@MainActor
final class DummyStoryEntrySource: StoryEntrySource {
    private let fixedReferenceDate: Date?
    private let calendar: Calendar

    init(
        referenceDate: Date? = nil,
        calendar: Calendar = .current
    ) {
        fixedReferenceDate = referenceDate
        self.calendar = calendar
    }

    func fetchEntries() async throws -> [StoryEntry] {
        // Production resolves today per fetch so a next-day refresh receives
        // fresh rolling fixture boundaries. Tests can still inject a fixed date.
        let referenceDate = fixedReferenceDate ?? .now

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

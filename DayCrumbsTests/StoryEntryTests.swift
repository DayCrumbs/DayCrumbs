import Foundation
import Testing

@testable import DayCrumbs

@Suite("Story entries")
struct StoryEntryTests {
    @Test("A built-in entry preserves its structured values")
    func builtInEntry() {
        let date = Date(timeIntervalSince1970: 200)
        let notes = AfterActivityNotes(text: "Finished lunch")
        let entry = StoryEntry(
            session: .afternoon,
            mood: .happy,
            activity: .eat,
            place: .school,
            afterActivityNotes: notes,
            recordedAt: date
        )

        #expect(entry.session == .afternoon)
        #expect(entry.mood == .happy)
        #expect(entry.activity == .eat)
        #expect(entry.place == .school)
        #expect(entry.customActivity == nil)
        #expect(entry.customPlace == nil)
        #expect(entry.afterActivityNotes === notes)
        #expect(entry.recordedAt == date)
    }

    @Test("A custom entry preserves custom activity and place")
    func customEntry() {
        let activity = CustomActivity(name: "Painting")
        let place = CustomPlace(name: "Art studio")
        let entry = StoryEntry(
            session: .evening,
            mood: .surprise,
            customActivity: activity,
            customPlace: place
        )

        #expect(entry.activity == nil)
        #expect(entry.place == nil)
        #expect(entry.customActivity === activity)
        #expect(entry.customPlace === place)
    }

    @Test("Built-in values take precedence over conflicting custom values")
    func builtInValuesTakePrecedence() {
        let entry = StoryEntry(
            session: .morning,
            mood: .happy,
            activity: .wakeUp,
            place: .house,
            customActivity: CustomActivity(name: "Conflicting activity"),
            customPlace: CustomPlace(name: "Conflicting place")
        )

        #expect(entry.activity == .wakeUp)
        #expect(entry.place == .house)
        #expect(entry.customActivity == nil)
        #expect(entry.customPlace == nil)
    }

    @Test("Selecting a built-in value clears its custom value")
    func switchingToBuiltInValues() {
        let entry = StoryEntry(
            session: .night,
            mood: .sad,
            customActivity: CustomActivity(name: "Bedtime story"),
            customPlace: CustomPlace(name: "Guest room")
        )

        entry.activity = .sleep
        entry.place = .house

        #expect(entry.activity == .sleep)
        #expect(entry.place == .house)
        #expect(entry.customActivity == nil)
        #expect(entry.customPlace == nil)
    }
}

@Suite("Daily sessions")
struct DailySessionTests {
    @Test("Entries are returned chronologically")
    func chronologicalEntries() {
        let session = DailySession()
        let later = StoryEntry(
            session: .night,
            mood: .happy,
            recordedAt: Date(timeIntervalSince1970: 300)
        )
        let earlier = StoryEntry(
            session: .morning,
            mood: .happy,
            recordedAt: Date(timeIntervalSince1970: 100)
        )
        session.entries = [later, earlier]

        #expect(session.chronologicalEntries.map(\.recordedAt) == [
            earlier.recordedAt, later.recordedAt
        ])
    }

    @Test("A session requires an end time and reflection content")
    func completionRequirements() {
        let session = DailySession()
        session.endedAt = .now
        session.endOfDayReflection = EndOfDayReflection(text: "  ")

        #expect(!session.isCompleted)

        session.endOfDayReflection?.text = "Playing outside improved the afternoon."
        #expect(session.isCompleted)
    }
}

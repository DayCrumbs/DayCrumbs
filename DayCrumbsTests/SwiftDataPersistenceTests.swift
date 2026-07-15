import Foundation
import SwiftData
import Testing

@testable import DayCrumbs

@Suite("SwiftData model persistence")
@MainActor
struct SwiftDataPersistenceTests {
    @Test("A complete daily story survives an in-memory SwiftData round trip")
    func dailyStoryRoundTrip() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = container.mainContext
        let profile = ChildProfile(name: "Mika", age: 4, gender: .girl)
        let session = DailySession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            childProfile: profile
        )
        let notes = AfterActivityNotes(text: "Asked for another turn")
        let entry = StoryEntry(
            session: .afternoon,
            mood: .happy,
            activity: .play,
            place: .outdoor,
            afterActivityNotes: notes,
            recordedAt: Date(timeIntervalSince1970: 1_100),
            dailySession: session
        )
        let reflection = EndOfDayReflection(
            transcribedText: "Outdoor play was the happiest part of the day.",
            dailySession: session
        )

        session.entries.append(entry)
        session.endOfDayReflection = reflection
        session.endedAt = Date(timeIntervalSince1970: 1_200)
        context.insert(profile)
        try context.save()

        let fetchedSessions = try context.fetch(FetchDescriptor<DailySession>())
        let fetchedSession = try #require(fetchedSessions.first)
        let fetchedEntry = try #require(fetchedSession.entries.first)

        #expect(fetchedSession.childProfile?.name == "Mika")
        #expect(fetchedSession.isCompleted)
        #expect(fetchedEntry.session == .afternoon)
        #expect(fetchedEntry.mood == .happy)
        #expect(fetchedEntry.activity == .play)
        #expect(fetchedEntry.place == .outdoor)
        #expect(fetchedEntry.afterActivityNotes?.text == "Asked for another turn")
        #expect(
            fetchedSession.endOfDayReflection?.transcribedText
                == "Outdoor play was the happiest part of the day."
        )
    }
}

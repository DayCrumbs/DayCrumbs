import Foundation
import SwiftData
import Testing

@testable import DayCrumbs

@Suite("SwiftData model persistence")
@MainActor
struct SwiftDataPersistenceTests {
    @Test("The in-memory container uses the complete production schema")
    func inMemoryContainerUsesCompleteSchema() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let configurationsAreInMemory = container.configurations.allSatisfy {
            $0.isStoredInMemoryOnly
        }

        #expect(configurationsAreInMemory)
        #expect(container.schema.entity(for: ChildProfile.self) != nil)
        #expect(container.schema.entity(for: DailySession.self) != nil)
        #expect(container.schema.entity(for: StoryEntry.self) != nil)
        #expect(container.schema.entity(for: AfterActivityNotes.self) != nil)
        #expect(container.schema.entity(for: EndOfDayReflection.self) != nil)
        #expect(container.schema.entity(for: CustomActivity.self) != nil)
        #expect(container.schema.entity(for: CustomPlace.self) != nil)
    }

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

        let fetchContext = ModelContext(container)
        let fetchedSessions = try fetchContext.fetch(
            FetchDescriptor<DailySession>()
        )
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

    @Test("An ended session can persist without an end-of-day reflection")
    func sessionWithoutReflectionRoundTrip() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = container.mainContext
        let session = DailySession(
            startedAt: Date(timeIntervalSince1970: 2_000)
        )
        session.endedAt = Date(timeIntervalSince1970: 2_100)

        context.insert(session)
        try context.save()

        let fetchContext = ModelContext(container)
        let fetchedSessions = try fetchContext.fetch(
            FetchDescriptor<DailySession>()
        )
        let fetchedSession = try #require(fetchedSessions.first)

        #expect(fetchedSession.endOfDayReflection == nil)
        #expect(!fetchedSession.isCompleted)
    }

    @Test("End-of-day reflection content and session relationship persist")
    func reflectionRoundTrip() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 3_000)
        let session = DailySession(startedAt: startedAt)
        let reflection = EndOfDayReflection(
            text: "Transitions felt easier today.",
            transcribedText: "Outdoor play helped before dinner.",
            createdAt: Date(timeIntervalSince1970: 3_100),
            dailySession: session
        )
        session.endOfDayReflection = reflection

        context.insert(session)
        try context.save()

        let fetchContext = ModelContext(container)
        let fetchedReflections = try fetchContext.fetch(
            FetchDescriptor<EndOfDayReflection>()
        )
        let fetchedReflection = try #require(fetchedReflections.first)

        #expect(fetchedReflection.text == "Transitions felt easier today.")
        #expect(
            fetchedReflection.transcribedText
                == "Outdoor play helped before dinner."
        )
        #expect(fetchedReflection.dailySession?.startedAt == startedAt)
        #expect(
            fetchedReflection.dailySession?.endOfDayReflection?.persistentModelID
                == fetchedReflection.persistentModelID
        )
    }

    @Test("In-memory containers do not share records")
    func inMemoryContainersAreIsolated() throws {
        let firstContainer = try DayCrumbsModelContainer.makeInMemoryContainer()
        let secondContainer = try DayCrumbsModelContainer.makeInMemoryContainer()
        let firstContext = firstContainer.mainContext
        let secondContext = secondContainer.mainContext
        let descriptor = FetchDescriptor<ChildProfile>()

        let initialFirstCount = try firstContext.fetchCount(descriptor)
        let initialSecondCount = try secondContext.fetchCount(descriptor)

        #expect(initialFirstCount == 0)
        #expect(initialSecondCount == 0)

        firstContext.insert(
            ChildProfile(name: "Mika", age: 4, gender: .girl)
        )
        try firstContext.save()

        let savedFirstCount = try firstContext.fetchCount(descriptor)
        let unchangedSecondCount = try secondContext.fetchCount(descriptor)

        #expect(savedFirstCount == 1)
        #expect(unchangedSecondCount == 0)
    }
}

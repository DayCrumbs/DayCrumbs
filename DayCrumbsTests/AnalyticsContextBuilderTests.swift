import Foundation
import Testing

@testable import DayCrumbs

@Suite("Analytics context builder")
@MainActor
struct AnalyticsContextBuilderTests {
    @Test("Empty input is rejected")
    func emptyInput() {
        #expect(throws: AnalyticsContextBuilder.BuildError.emptyEntries) {
            try AnalyticsContextBuilder().build(from: [])
        }
    }

    @Test("Entries without a child profile are rejected")
    func missingProfile() {
        let session = DailySession()
        let entry = makeEntry(
            in: session,
            recordedAt: Date(timeIntervalSince1970: 1)
        )

        #expect(throws: AnalyticsContextBuilder.BuildError.missingChildProfile) {
            try AnalyticsContextBuilder().build(from: [entry])
        }
    }

    @Test("Entries for different children are rejected")
    func mixedChildren() {
        let firstSession = makeSession(
            profile: ChildProfile(name: "Ari", age: 3, gender: .boy),
            startedAt: Date(timeIntervalSince1970: 1)
        )
        let secondSession = makeSession(
            profile: ChildProfile(name: "Nia", age: 4, gender: .girl),
            startedAt: Date(timeIntervalSince1970: 2)
        )
        let entries = [
            makeEntry(in: firstSession, recordedAt: Date(timeIntervalSince1970: 10)),
            makeEntry(in: secondSession, recordedAt: Date(timeIntervalSince1970: 20)),
        ]

        #expect(throws: AnalyticsContextBuilder.BuildError.mixedChildren) {
            try AnalyticsContextBuilder().build(from: entries)
        }
    }

    @Test("Entries are chronological after retaining the most recent configured rows")
    func chronologicalPrimaryAndRetryLimits() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(profile: profile, startedAt: .distantPast)
        let entries = (0..<30).map { index in
            makeEntry(
                in: session,
                recordedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }.reversed()
        let builder = AnalyticsContextBuilder()

        let primary = try builder.build(from: Array(entries), eventLimit: .primary)
        let retry = try builder.build(from: Array(entries), eventLimit: .retry)

        #expect(primary.events.count == 24)
        #expect(primary.events.first?.recordedAt == Date(timeIntervalSince1970: 6))
        #expect(primary.events.last?.recordedAt == Date(timeIntervalSince1970: 29))
        #expect(retry.events.count == 10)
        #expect(retry.events.first?.recordedAt == Date(timeIntervalSince1970: 20))
        #expect(retry.events.last?.recordedAt == Date(timeIntervalSince1970: 29))
    }

    @Test("Context rows preserve the current domain vocabulary")
    func currentEnumVocabulary() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let dailySession = makeSession(profile: profile, startedAt: .distantPast)
        let sessions: [Sessions] = [
            .morning, .afternoon, .evening, .night, .morning, .afternoon,
        ]
        let moods: [Moods] = [.angry, .disgust, .fear, .happy, .sad, .surprise]
        let activities: [Activity.BuiltInActivity] = [
            .play, .sleep, .study, .eat, .getReady, .wakeUp,
        ]
        let places: [Place.BuiltInPlace] = [
            .house, .outdoor, .school, .publicPlace, .house, .outdoor,
        ]
        let entries = activities.indices.map { index in
            StoryEntry(
                session: sessions[index],
                mood: moods[index],
                activity: activities[index],
                place: places[index],
                recordedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                dailySession: dailySession
            )
        }

        let context = try AnalyticsContextBuilder().build(from: entries)

        #expect(context.events.map(\.session) == sessions.map(\.rawValue))
        #expect(context.events.map(\.mood) == moods.map(\.rawValue))
        #expect(context.events.compactMap(\.activity) == activities.map(\.rawValue))
        #expect(context.events.compactMap(\.place) == places.map(\.rawValue))
    }

    @Test("Custom and missing activity and place values are resolved safely")
    func customAndMissingActivityPlace() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(profile: profile, startedAt: .distantPast)
        let custom = StoryEntry(
            session: .afternoon,
            mood: .happy,
            customActivity: CustomActivity(name: "  Finger   painting "),
            customPlace: CustomPlace(name: " Art\nroom "),
            recordedAt: Date(timeIntervalSince1970: 1),
            dailySession: session
        )
        let missing = makeEntry(
            in: session,
            recordedAt: Date(timeIntervalSince1970: 2)
        )

        let context = try AnalyticsContextBuilder().build(from: [missing, custom])

        #expect(context.events[0].activity == "Finger painting")
        #expect(context.events[0].place == "Art room")
        #expect(context.events[1].activity == nil)
        #expect(context.events[1].place == nil)
    }

    @Test("Typed notes take precedence and transcription is the fallback")
    func notePrecedenceAndFallback() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(profile: profile, startedAt: .distantPast)
        let typed = StoryEntry(
            session: .morning,
            mood: .happy,
            afterActivityNotes: AfterActivityNotes(
                text: " Typed   note ",
                transcribedText: "Ignored transcript"
            ),
            recordedAt: Date(timeIntervalSince1970: 1),
            dailySession: session
        )
        let transcribed = StoryEntry(
            session: .afternoon,
            mood: .surprise,
            afterActivityNotes: AfterActivityNotes(
                text: " \n ",
                transcribedText: " Spoken\n note "
            ),
            recordedAt: Date(timeIntervalSince1970: 2),
            dailySession: session
        )

        let context = try AnalyticsContextBuilder().build(from: [transcribed, typed])

        #expect(context.events.map(\.afterActivityNote) == ["Typed note", "Spoken note"])
    }

    @Test("Whitespace-only notes are treated as absent")
    func whitespaceOnlyNoteIsAbsent() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(profile: profile, startedAt: .distantPast)
        let entry = StoryEntry(
            session: .morning,
            mood: .happy,
            afterActivityNotes: AfterActivityNotes(
                text: " \n ",
                transcribedText: " \t "
            ),
            recordedAt: .now,
            dailySession: session
        )

        let context = try AnalyticsContextBuilder().build(from: [entry])

        #expect(context.events.first?.afterActivityNote == nil)
        #expect(context.text.contains("afterActivityNote: absent"))
    }

    @Test("Missing reflections do not prevent context construction")
    func missingReflection() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(profile: profile, startedAt: .distantPast)
        let entry = makeEntry(in: session, recordedAt: .now)

        let context = try AnalyticsContextBuilder().build(from: [entry])

        #expect(context.reflections.isEmpty)
        #expect(context.text.contains("END_OF_DAY_REFLECTIONS: 0"))
    }

    @Test("Each selected session contributes its reflection only once")
    func reflectionPrecedenceDeduplicationAndScope() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let firstSelectedSession = makeSession(
            profile: profile,
            startedAt: Date(timeIntervalSince1970: 1),
            reflectionText: " Typed   reflection ",
            reflectionTranscript: "Ignored transcript"
        )
        let secondSelectedSession = makeSession(
            profile: profile,
            startedAt: Date(timeIntervalSince1970: 2),
            reflectionText: "Second selected reflection"
        )
        _ = makeSession(
            profile: profile,
            startedAt: Date(timeIntervalSince1970: 3),
            reflectionText: "Unrelated reflection"
        )
        let entries = [
            makeEntry(
                in: firstSelectedSession,
                recordedAt: Date(timeIntervalSince1970: 10)
            ),
            makeEntry(
                in: firstSelectedSession,
                recordedAt: Date(timeIntervalSince1970: 20)
            ),
            makeEntry(
                in: secondSelectedSession,
                recordedAt: Date(timeIntervalSince1970: 30)
            ),
        ]

        let context = try AnalyticsContextBuilder().build(from: entries)

        #expect(context.reflections.count == 2)
        #expect(context.reflections.map(\.content) == [
            "Typed reflection", "Second selected reflection",
        ])
        #expect(!context.text.contains("Unrelated reflection"))
    }

    @Test("Reflection transcription is used when typed text is blank")
    func reflectionTranscriptionFallback() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(
            profile: profile,
            startedAt: .distantPast,
            reflectionText: "  ",
            reflectionTranscript: " Spoken reflection "
        )
        let entry = makeEntry(in: session, recordedAt: .now)

        let context = try AnalyticsContextBuilder().build(from: [entry])

        #expect(context.reflections.first?.content == "Spoken reflection")
    }

    @Test("Whitespace-only reflections are treated as missing")
    func whitespaceOnlyReflectionIsMissing() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(
            profile: profile,
            startedAt: .distantPast,
            reflectionText: " \n ",
            reflectionTranscript: " \t "
        )
        let entry = makeEntry(in: session, recordedAt: .now)

        let context = try AnalyticsContextBuilder().build(from: [entry])

        #expect(context.reflections.isEmpty)
        #expect(context.text.contains("END_OF_DAY_REFLECTIONS: 0"))
    }

    @Test("Parent text is normalized and truncated by shared configuration")
    func normalizationAndTruncation() throws {
        let configuration = try LocalLLMConfiguration(
            noteCharacterLimit: 12,
            reflectionCharacterLimit: 12
        )
        let profile = ChildProfile(name: "  Ari   Putra ", age: 3, gender: .boy)
        let session = makeSession(
            profile: profile,
            startedAt: .distantPast,
            reflectionText: " Daily   reflection continues "
        )
        let entry = StoryEntry(
            session: .night,
            mood: .happy,
            afterActivityNotes: AfterActivityNotes(
                text: " Activity   note continues "
            ),
            recordedAt: .now,
            dailySession: session
        )

        let context = try AnalyticsContextBuilder(configuration: configuration)
            .build(from: [entry])

        #expect(context.child.name == "Ari Putra")
        #expect(context.events.first?.afterActivityNote == "Activity not")
        #expect(context.reflections.first?.content == "Daily reflec")
    }

    @Test("Equivalent input produces deterministic context and text")
    func deterministicOutput() throws {
        let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
        let session = makeSession(
            profile: profile,
            startedAt: Date(timeIntervalSince1970: 1),
            reflectionText: "A steady day"
        )
        let first = StoryEntry(
            session: .evening,
            mood: .sad,
            activity: .play,
            place: .outdoor,
            recordedAt: Date(timeIntervalSince1970: 10),
            dailySession: session
        )
        let second = StoryEntry(
            session: .morning,
            mood: .happy,
            activity: .wakeUp,
            place: .house,
            recordedAt: Date(timeIntervalSince1970: 10),
            dailySession: session
        )
        let builder = AnalyticsContextBuilder()

        let forward = try builder.build(from: [first, second])
        let reversed = try builder.build(from: [second, first])

        #expect(forward == reversed)
        #expect(forward.text == reversed.text)
    }
}

@MainActor
private func makeSession(
    profile: ChildProfile,
    startedAt: Date,
    reflectionText: String? = nil,
    reflectionTranscript: String? = nil
) -> DailySession {
    let session = DailySession(startedAt: startedAt, childProfile: profile)

    if reflectionText != nil || reflectionTranscript != nil {
        session.endOfDayReflection = EndOfDayReflection(
            text: reflectionText,
            transcribedText: reflectionTranscript,
            dailySession: session
        )
    }

    return session
}

@MainActor
private func makeEntry(
    in dailySession: DailySession,
    recordedAt: Date
) -> StoryEntry {
    StoryEntry(
        session: .morning,
        mood: .happy,
        recordedAt: recordedAt,
        dailySession: dailySession
    )
}

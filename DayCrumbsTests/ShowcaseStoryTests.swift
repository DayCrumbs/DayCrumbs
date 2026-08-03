import Foundation
import SwiftData
import Testing

@testable import DayCrumbs

@Suite("Showcase story")
@MainActor
struct ShowcaseStoryTests {
    private let calendar = showcaseCalendar()
    private let referenceDate = showcaseDate(
        year: 2026,
        month: 8,
        day: 1,
        hour: 12
    )

    @Test("Source spans today through 15 days ahead with four sessions per day")
    func sourceDateContract() async throws {
        let source = ShowcaseStoryEntrySource(
            referenceDate: referenceDate,
            calendar: calendar
        )

        let entries = try await source.fetchEntries()
        let profileIDs = Set(entries.compactMap {
            $0.dailySession?.childProfile?.persistentModelID
        })
        let entryDays = Set(entries.map {
            calendar.startOfDay(for: $0.recordedAt)
        })
        let expectedLastDay = try #require(
            calendar.date(
                byAdding: .day,
                value: 15,
                to: calendar.startOfDay(for: referenceDate)
            )
        )

        #expect(entries.count == 64)
        #expect(entryDays.count == 16)
        #expect(profileIDs.count == 1)
        #expect(entries.map(\.recordedAt) == entries.map(\.recordedAt).sorted())
        #expect(entryDays.min() == calendar.startOfDay(for: referenceDate))
        #expect(entryDays.max() == expectedLastDay)
    }

    @Test("Every day uses the four canonical sessions and Indonesian parent text")
    func dailySessionContract() {
        let profile = ChildProfile(name: "Arya", age: 3, gender: .boy)
        let sessions = ShowcaseStory.generateSessions(
            for: profile,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sessions.count == 16)
        for session in sessions {
            #expect(session.entries.map(\.session.rawValue) == [
                Sessions.morning.rawValue,
                Sessions.afternoon.rawValue,
                Sessions.evening.rawValue,
                Sessions.night.rawValue,
            ])
            #expect(session.entries.allSatisfy {
                $0.afterActivityNotes?.text?.isEmpty == false
            })
            #expect(session.endOfDayReflection?.text?.isEmpty == false)
        }
    }

    @Test("The initial Day range contains grounded trigger evidence")
    func initialDaySignal() throws {
        let profile = ChildProfile(name: "Arya", age: 3, gender: .boy)
        let sessions = ShowcaseStory.generateSessions(
            for: profile,
            referenceDate: referenceDate,
            calendar: calendar
        )
        profile.dailySessions = sessions
        let entries = sessions.flatMap(\.entries)

        let todayEntries = try DashboardEntrySelectionService(calendar: calendar)
            .entries(
                for: .day,
                from: entries,
                referenceDate: referenceDate
            )
        let context = try AnalyticsContextBuilder().build(from: todayEntries)
        let notes = context.events.compactMap(\.afterActivityNote)
            .joined(separator: " ")
            .lowercased()
        let reflections = context.reflections.map(\.content)
            .joined(separator: " ")
            .lowercased()

        #expect(todayEntries.count == 4)
        #expect(todayEntries.map(\.mood.rawValue).contains(Moods.angry.rawValue))
        #expect(todayEntries.map(\.mood.rawValue).contains(Moods.fear.rawValue))
        #expect(notes.contains("urutan bersiap"))
        #expect(notes.contains("kamar dipadamkan"))
        #expect(reflections.contains("perubahan urutan bersiap"))
        #expect(reflections.contains("kamar gelap"))
    }

    @Test("Every six-day model window retains the recurring showcase signals")
    func everyPrimaryContextWindowHasSignals() {
        let templates = ShowcaseStory.templates

        for startIndex in 0...(templates.count - 6) {
            let window = templates[startIndex..<(startIndex + 6)]
            let text = window.flatMap { template in
                template.entries.compactMap(\.noteText)
                    + [template.reflectionText]
            }
            .joined(separator: " ")
            .lowercased()

            #expect(text.contains("urutan"))
            #expect(text.contains("tekstur"))
            #expect(text.contains("gelap") || text.contains("suara"))
            #expect(
                text.contains("berlari")
                    || text.contains("bergerak")
                    || text.contains("gerak")
            )
        }
    }

    @Test("Primary context keeps six complete recent showcase days")
    func primaryContextBudget() throws {
        let profile = ChildProfile(name: "Arya", age: 3, gender: .boy)
        let sessions = ShowcaseStory.generateSessions(
            for: profile,
            referenceDate: referenceDate,
            calendar: calendar
        )
        profile.dailySessions = sessions
        let entries = sessions.flatMap(\.entries)

        let context = try AnalyticsContextBuilder().build(
            from: entries,
            eventLimit: .primary
        )

        #expect(context.events.count == 24)
        #expect(context.reflections.count == 6)
        #expect(
            calendar.startOfDay(for: context.events[0].recordedAt)
                == calendar.date(
                    byAdding: .day,
                    value: 10,
                    to: calendar.startOfDay(for: referenceDate)
                )
        )
        #expect(
            calendar.startOfDay(for: context.events[23].recordedAt)
                == calendar.date(
                    byAdding: .day,
                    value: 15,
                    to: calendar.startOfDay(for: referenceDate)
                )
        )
    }
}

private func showcaseCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
    return calendar
}

private func showcaseDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int
) -> Date {
    showcaseCalendar().date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )
    )!
}

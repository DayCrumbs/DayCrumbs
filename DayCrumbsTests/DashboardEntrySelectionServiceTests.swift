import Foundation
import SwiftData
import Testing

@testable import DayCrumbs

@Suite("Dashboard entry selection")
@MainActor
struct DashboardEntrySelectionServiceTests {
    private let calendar = makeCalendar()
    private let referenceDate = makeDate(
        year: 2026,
        month: 7,
        day: 17,
        hour: 12
    )

    @Test("Day uses today's half-open boundary and keeps one entry valid")
    func dayBoundary() throws {
        let start = calendar.startOfDay(for: referenceDate)
        let nextStart = calendar.date(byAdding: .day, value: 1, to: start)!
        let entries = [
            makeEntry(at: start.addingTimeInterval(-1)),
            makeEntry(at: start),
            makeEntry(at: nextStart.addingTimeInterval(-1)),
            makeEntry(at: nextStart),
        ]

        let selected = try DashboardEntrySelectionService(calendar: calendar)
            .entries(for: .day, from: entries, referenceDate: referenceDate)

        #expect(selected.map(\.recordedAt) == [
            start,
            nextStart.addingTimeInterval(-1),
        ])
    }

    @Test("Week is a rolling seven-day range rather than a calendar week")
    func rollingWeek() throws {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let rangeStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
        let entries = [
            makeEntry(at: rangeStart.addingTimeInterval(-1)),
            makeEntry(at: rangeStart),
            makeEntry(at: todayStart.addingTimeInterval(12 * 60 * 60)),
        ]

        let selected = try DashboardEntrySelectionService(calendar: calendar)
            .entries(for: .week, from: entries, referenceDate: referenceDate)

        #expect(selected.count == 2)
        #expect(selected.first?.recordedAt == rangeStart)
    }

    @Test("Month is rolling 30 days and output is chronological")
    func rollingMonthChronology() throws {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let rangeStart = calendar.date(byAdding: .day, value: -29, to: todayStart)!
        let entries = [
            makeEntry(at: todayStart.addingTimeInterval(20 * 60 * 60)),
            makeEntry(at: rangeStart),
            makeEntry(at: todayStart.addingTimeInterval(8 * 60 * 60)),
        ]

        let selected = try DashboardEntrySelectionService(calendar: calendar)
            .entries(for: .month, from: entries, referenceDate: referenceDate)

        #expect(selected.map(\.recordedAt) == selected.map(\.recordedAt).sorted())
        #expect(selected.first?.recordedAt == rangeStart)
    }

    @Test("A range without entries remains empty")
    func emptyRange() throws {
        let oldEntry = makeEntry(
            at: calendar.date(byAdding: .day, value: -1, to: referenceDate)!
        )

        let selected = try DashboardEntrySelectionService(calendar: calendar)
            .entries(for: .day, from: [oldEntry], referenceDate: referenceDate)

        #expect(selected.isEmpty)
    }
}

@Suite("Dummy story entry source")
@MainActor
struct DummyStoryEntrySourceTests {
    @Test("Dummy source returns one profile and 30 chronological days")
    func sourceContract() async throws {
        let calendar = makeCalendar()
        let referenceDate = makeDate(
            year: 2026,
            month: 7,
            day: 17,
            hour: 12
        )
        let source = DummyStoryEntrySource(
            referenceDate: referenceDate,
            calendar: calendar
        )

        let entries = try await source.fetchEntries()
        let profileIDs = Set(entries.compactMap {
            $0.dailySession?.childProfile?.persistentModelID
        })
        let newestDay = entries.map(\.recordedAt).max().map {
            calendar.startOfDay(for: $0)
        }

        #expect(entries.count == 120)
        #expect(profileIDs.count == 1)
        #expect(entries.map(\.recordedAt) == entries.map(\.recordedAt).sorted())
        #expect(newestDay == calendar.startOfDay(for: referenceDate))
    }
}

@MainActor
private func makeEntry(at date: Date) -> StoryEntry {
    StoryEntry(session: .morning, mood: .happy, recordedAt: date)
}

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
    return calendar
}

private func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int
) -> Date {
    makeCalendar().date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )
    )!
}

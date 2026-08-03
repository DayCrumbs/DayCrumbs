//
//  ShowcaseStoryEntrySource.swift
//  DayCrumbs
//
//  Entry source that delivers the 16-day Indonesian showcase dataset
//  for app demonstration without requiring SwiftData.
//

import Foundation

/// Showcase `StoryEntrySourceProtocol` that delivers Indonesian dummy data from
/// the reference calendar day through 15 days ahead.
///
/// Uses `ShowcaseStory` and `ShowcaseProfile.arya` instead of the
/// test-oriented `DummyStory` / `DummyProfile.maya`.
@MainActor
final class ShowcaseStoryEntrySource: StoryEntrySourceProtocol {
    private let fixedReferenceDate: Date?
    private let calendar: Calendar

    /// - Parameters:
    ///   - referenceDate: Anchor date whose calendar day is template day 1.
    ///     Defaults to `.now`. Inject a fixed date for deterministic tests.
    ///   - calendar: Calendar and timezone used for date boundaries.
    init(
        referenceDate: Date? = nil,
        calendar: Calendar = .current
    ) {
        fixedReferenceDate = referenceDate
        self.calendar = calendar
    }

    func fetchEntries() async throws -> [StoryEntry] {
        let referenceDate = fixedReferenceDate ?? .now

        let childProfile = ShowcaseProfile.arya
        let sessions = ShowcaseStory.generateSessions(
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

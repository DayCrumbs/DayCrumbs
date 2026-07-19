//
//  DailySession.swift
//  DayCrumbs
//

import Foundation
import SwiftData

@Model
final class DailySession {
    var startedAt: Date
    var endedAt: Date?
    var childProfile: ChildProfile?

    @Relationship(deleteRule: .cascade, inverse: \EndOfDayReflection.dailySession)
    var endOfDayReflection: EndOfDayReflection?

    @Relationship(deleteRule: .cascade, inverse: \StoryEntry.dailySession)
    var entries: [StoryEntry] = []

    var chronologicalEntries: [StoryEntry] {
        entries.sorted { $0.recordedAt < $1.recordedAt }
    }

    var isCompleted: Bool {
        endedAt != nil && endOfDayReflection?.hasContent == true
    }

    init(startedAt: Date = .now, childProfile: ChildProfile? = nil) {
        self.startedAt = startedAt
        self.childProfile = childProfile
    }
}

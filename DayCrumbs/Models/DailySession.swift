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

    @Relationship(deleteRule: .cascade, inverse: \AfterActivityNotes.dailySession)
    var afterActivityNotes: [AfterActivityNotes] = []

    private var activityRawValues: [String] = []
    private var placeRawValues: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \CustomPlace.dailySession)
    var customPlaces: [CustomPlace] = []

    @Relationship(deleteRule: .cascade, inverse: \CustomActivity.dailySession)
    var customActivities: [CustomActivity] = []

    var activities: [Activity.BuiltInActivity] {
        get { activityRawValues.compactMap(Activity.BuiltInActivity.init(rawValue:)) }
        set { activityRawValues = newValue.map(\.rawValue) }
    }

    var places: [Place.BuiltInPlace] {
        get { placeRawValues.compactMap(Place.BuiltInPlace.init(rawValue:)) }
        set { placeRawValues = newValue.map(\.rawValue) }
    }

    var isCompleted: Bool {
        endedAt != nil && endOfDayReflection?.hasContent == true
    }

    init(startedAt: Date = .now, childProfile: ChildProfile? = nil) {
        self.startedAt = startedAt
        self.childProfile = childProfile
    }
}

//
//  StoryEntry.swift
//  DayCrumbs
//

import Foundation
import SwiftData

@Model
final class StoryEntry {
    var recordedAt: Date
    private var sessionRawValue: String
    private var moodRawValue: String
    private var activityRawValue: String?
    private var placeRawValue: String?
    var dailySession: DailySession?

    @Relationship(deleteRule: .cascade, inverse: \AfterActivityNotes.storyEntry)
    var afterActivityNotes: AfterActivityNotes?

    @Relationship(deleteRule: .cascade, inverse: \CustomActivity.storyEntry)
    var customActivity: CustomActivity?

    @Relationship(deleteRule: .cascade, inverse: \CustomPlace.storyEntry)
    var customPlace: CustomPlace?

    var session: Sessions {
        get { Sessions(rawValue: sessionRawValue) ?? .morning }
        set { sessionRawValue = newValue.rawValue }
    }

    var mood: Moods {
        get { Moods(rawValue: moodRawValue) ?? .happy }
        set { moodRawValue = newValue.rawValue }
    }

    var activity: Activity.BuiltInActivity? {
        get { activityRawValue.flatMap(Activity.BuiltInActivity.init(rawValue:)) }
        set {
            activityRawValue = newValue?.rawValue
            if newValue != nil {
                customActivity = nil
            }
        }
    }

    var place: Place.BuiltInPlace? {
        get { placeRawValue.flatMap(Place.BuiltInPlace.init(rawValue:)) }
        set {
            placeRawValue = newValue?.rawValue
            if newValue != nil {
                customPlace = nil
            }
        }
    }

    init(
        session: Sessions,
        mood: Moods,
        activity: Activity.BuiltInActivity? = nil,
        place: Place.BuiltInPlace? = nil,
        customActivity: CustomActivity? = nil,
        customPlace: CustomPlace? = nil,
        afterActivityNotes: AfterActivityNotes? = nil,
        recordedAt: Date = .now,
        dailySession: DailySession? = nil
    ) {
        self.sessionRawValue = session.rawValue
        self.moodRawValue = mood.rawValue
        self.activityRawValue = activity?.rawValue
        self.placeRawValue = place?.rawValue
        self.customActivity = activity == nil ? customActivity : nil
        self.customPlace = place == nil ? customPlace : nil
        self.afterActivityNotes = afterActivityNotes
        self.recordedAt = recordedAt
        self.dailySession = dailySession
    }
}

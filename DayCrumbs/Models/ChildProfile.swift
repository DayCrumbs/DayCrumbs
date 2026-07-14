//
//  ChildProfile.swift
//  DayCrumbs
//

import SwiftData

@Model
final class ChildProfile {
    var name: String
    var age: Int
    private var genderRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \DailySession.childProfile)
    var dailySessions: [DailySession] = []

    var gender: ChildGender {
        get { ChildGender(rawValue: genderRawValue) ?? .boy }
        set { genderRawValue = newValue.rawValue }
    }

    init(name: String, age: Int, gender: ChildGender) {
        self.name = name
        self.age = age
        self.genderRawValue = gender.rawValue
    }
}

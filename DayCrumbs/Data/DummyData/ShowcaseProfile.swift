//
//  ShowcaseProfile.swift
//  DayCrumbs
//
//  Showcase child profile for app demonstration.
//  Uses a separate profile from DummyProfile so test fixtures remain untouched.
//

import Foundation

/// Single showcase child profile for demonstration and presentation.
/// Arya is a 3-year-old boy living in Indonesia.
enum ShowcaseProfile {
    static let arya = ChildProfile(name: "Arya", age: 3, gender: .boy)
}

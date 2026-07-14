//
//  Place.swift
//  DayCrumbs
//

enum Place {
    enum BuiltInPlace: String, CaseIterable {
        case house
        case outdoor
        case school
        case publicPlace
    }

    enum CustomPlace: String {
        case customPlace
    }
}

//
//  Activity.swift
//  DayCrumbs
//

enum Activity {
    enum BuiltInActivity: String, CaseIterable {
        case play
        case sleep
        case study
        case eat
        case getReady
        case wakeUp
    }

    enum CustomActivity: String {
        case customActivity
    }
}

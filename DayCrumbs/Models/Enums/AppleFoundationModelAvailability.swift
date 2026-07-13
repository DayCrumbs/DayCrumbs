//
//  AppleFoundationModelAvailability.swift
//  DayCrumbs
//

import Foundation

enum AppleFoundationModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOS
    case unavailable

    var isAvailable: Bool {
        self == .available
    }
}

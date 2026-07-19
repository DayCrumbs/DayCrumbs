//
//  AppleFoundationModelAvailability.swift
//  DayCrumbs
//

import Foundation

nonisolated enum AppleFoundationModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOS
    case unavailable

    nonisolated var isAvailable: Bool {
        self == .available
    }
}

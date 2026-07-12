//
//  AppleFoundationModelsRuntime.swift
//  DayCrumbs
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationModelsRuntime {
    static let displayName = "Apple Foundation Models"

    static var availability: AppleFoundationModelAvailability {
#if canImport(FoundationModels)
        // iPadOS uses the iOS availability platform name in Swift.
        guard #available(iOS 26.0, *) else {
            return .unsupportedOS
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        @unknown default:
            return .unavailable
        }
#else
        return .unsupportedOS
#endif
    }

    static var isAvailable: Bool {
        availability.isAvailable
    }

    static var readinessMessage: String {
        switch availability {
        case .available:
            "Apple Intelligence is ready for private, on-device insights."
        case .deviceNotEligible:
            "Apple Foundation Models are not supported on this device. Gemma will be available as the on-device fallback in a later phase."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off. Enable it in Settings, or use the Gemma fallback when it becomes available."
        case .modelNotReady:
            "Apple Intelligence is still preparing its on-device model. Check again later, or use the Gemma fallback when it becomes available."
        case .unsupportedOS:
            "Apple Foundation Models require a supported version of iOS or iPadOS. Gemma will be available as the on-device fallback in a later phase."
        case .unavailable:
            "Apple Foundation Models are not currently available. Gemma will be available as the on-device fallback in a later phase."
        }
    }
}

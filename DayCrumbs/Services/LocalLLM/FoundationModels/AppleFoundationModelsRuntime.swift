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
            "Apple Foundation Models are not supported on this device. Gemma can provide private on-device insights when downloaded."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off. Enable it in Settings, or download Gemma for private on-device insights."
        case .modelNotReady:
            "Apple Intelligence is still preparing its on-device model. Check again later, or download Gemma."
        case .unsupportedOS:
            "Apple Foundation Models require a supported version of iOS or iPadOS. Gemma can provide the on-device fallback."
        case .unavailable:
            "Apple Foundation Models are not currently available. Download Gemma for private on-device insights."
        }
    }
}

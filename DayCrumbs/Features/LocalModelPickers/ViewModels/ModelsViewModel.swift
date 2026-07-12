//
//  ModelsViewModel.swift
//  DayCrumbs
//

import Foundation
import Observation

@MainActor
@Observable
final class ModelsViewModel {
    private(set) var availability: AppleFoundationModelAvailability = .unavailable
    private(set) var readinessMessage = "Checking Apple Intelligence readiness…"

    var isAppleFoundationModelsAvailable: Bool {
        availability.isAvailable
    }

    func refreshAvailability() {
        availability = AppleFoundationModelsRuntime.availability
        readinessMessage = AppleFoundationModelsRuntime.readinessMessage
    }
}

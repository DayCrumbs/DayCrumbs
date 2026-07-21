//
//  DayCrumbsApp.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/9/26.
//

import SwiftData
import SwiftUI

@main
struct DayCrumbsApp: App {
    // Keep startup failures helpful to parents instead of exposing storage details.
    static let storageErrorMessage =
        "We couldn't load your stories right now. Please close and reopen DayCrumbs."

    private let modelContainer: ModelContainer?
    let startupErrorMessage: String?

    init() {
        self.init(modelContainerFactory: DayCrumbsModelContainer.makeProductionContainer)
    }
    // The factory keeps the failure path easy to exercise in Swift Testing.
    init(modelContainerFactory: () throws -> ModelContainer) {
        do {
            modelContainer = try modelContainerFactory()
            startupErrorMessage = nil
        } catch {
            modelContainer = nil
            startupErrorMessage = Self.storageErrorMessage
        }
    }

    var isShowingStartupError: Bool {
        modelContainer == nil
    }
    // Keep the app open with recovery guidance when persistence is unavailable.
    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
            } else {
                StartupErrorView(message: startupErrorMessage ?? Self.storageErrorMessage)
            }
        }
    }
}

// A startup failure should be recoverable without closing the app.
private struct StartupErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .accessibilityHidden(true)

            Text("DayCrumbs couldn't load your stories")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

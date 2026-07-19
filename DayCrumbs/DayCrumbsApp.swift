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
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try DayCrumbsModelContainer.makeProductionContainer()
        } catch {
            fatalError("Failed to open the DayCrumbs persistent store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

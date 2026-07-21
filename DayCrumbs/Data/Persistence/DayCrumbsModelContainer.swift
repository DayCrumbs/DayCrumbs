//
//  DayCrumbsModelContainer.swift
//  DayCrumbs
//

import Foundation
import SwiftData

nonisolated enum DayCrumbsModelContainer {
    static let schema = Schema([
        ChildProfile.self,
        DailySession.self,
        StoryEntry.self,
        AfterActivityNotes.self,
        EndOfDayReflection.self,
        CustomActivity.self,
        CustomPlace.self,
    ])

    static func makeProductionContainer() throws -> ModelContainer {
        // A fresh installation may not have created Application Support yet.
        // Preparing it first prevents Core Data from entering noisy store recovery.
        try prepareProductionStorageDirectory()
        return try makeContainer(isStoredInMemoryOnly: false)
    }

    static func prepareProductionStorageDirectory(
        at directory: URL = .applicationSupportDirectory,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    private static func makeContainer(
        isStoredInMemoryOnly: Bool
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(
            for: schema,
            configurations: configuration
        )
    }
}

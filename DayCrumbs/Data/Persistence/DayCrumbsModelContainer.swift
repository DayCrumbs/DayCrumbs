//
//  DayCrumbsModelContainer.swift
//  DayCrumbs
//

import SwiftData

enum DayCrumbsModelContainer {
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
        try makeContainer(isStoredInMemoryOnly: false)
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

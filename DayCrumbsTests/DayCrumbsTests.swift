//
//  DayCrumbsTests.swift
//  DayCrumbsTests
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import Testing

@testable import DayCrumbs

@Suite("DayCrumbs model smoke tests")
struct DayCrumbsTests {
    @Test("A new daily session starts incomplete")
    func newDailySessionStartsIncomplete() {
        let session = DailySession()

        #expect(session.endedAt == nil)
        #expect(session.entries.isEmpty)
        #expect(session.endOfDayReflection == nil)
        #expect(!session.isCompleted)
    }

    @Test("A storage failure shows friendly recovery guidance")
    @MainActor
    func storageFailureShowsRecoveryGuidance() {
        // Simulate a failed persistent store without terminating the test process.
        let app = DayCrumbsApp(modelContainerFactory: {
            throw TestStorageError.unavailable
        })

        #expect(app.isShowingStartupError)
        #expect(app.startupErrorMessage == DayCrumbsApp.storageErrorMessage)
        #expect(app.startupErrorMessage?.contains("close and reopen") == true)
        #expect(app.startupErrorMessage?.contains("ModelContainer") == false)
    }

    @Test("A working storage container keeps the app ready")
    @MainActor
    func workingStorageContainerKeepsAppReady() throws {
        // In-memory storage verifies that normal startup still uses the main content.
        let app = DayCrumbsApp(
            modelContainerFactory: DayCrumbsModelContainer.makeInMemoryContainer
        )

        #expect(!app.isShowingStartupError)
        #expect(app.startupErrorMessage == nil)
    }
}

private enum TestStorageError: Error {
    case unavailable
}

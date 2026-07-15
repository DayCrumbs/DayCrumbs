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
}

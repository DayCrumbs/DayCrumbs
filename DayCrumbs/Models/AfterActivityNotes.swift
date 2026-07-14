//
//  AfterActivityNotes.swift
//  DayCrumbs
//

import Foundation
import SwiftData

@Model
final class AfterActivityNotes {
    var text: String?
    var transcribedText: String?
    var createdAt: Date
    var dailySession: DailySession?

    init(
        text: String? = nil,
        transcribedText: String? = nil,
        createdAt: Date = .now,
        dailySession: DailySession? = nil
    ) {
        self.text = text
        self.transcribedText = transcribedText
        self.createdAt = createdAt
        self.dailySession = dailySession
    }
}

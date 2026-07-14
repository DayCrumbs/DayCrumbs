//
//  EndOfDayReflection.swift
//  DayCrumbs
//

import Foundation
import SwiftData

@Model
final class EndOfDayReflection {
    var text: String?
    var transcribedText: String?
    var createdAt: Date
    var updatedAt: Date
    var dailySession: DailySession?

    var hasContent: Bool {
        [text, transcribedText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { !$0.isEmpty }
    }

    init(
        text: String? = nil,
        transcribedText: String? = nil,
        createdAt: Date = .now,
        dailySession: DailySession? = nil
    ) {
        self.text = text
        self.transcribedText = transcribedText
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.dailySession = dailySession
    }
}

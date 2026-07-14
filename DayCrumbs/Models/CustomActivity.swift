//
//  CustomActivity.swift
//  DayCrumbs
//

import Foundation
import SwiftData

@Model
final class CustomActivity {
    var name: String

    @Attribute(.externalStorage)
    var imageData: Data?

    var recordedAt: Date
    var dailySession: DailySession?

    init(
        name: String,
        imageData: Data? = nil,
        recordedAt: Date = .now,
        dailySession: DailySession? = nil
    ) {
        self.name = name
        self.imageData = imageData
        self.recordedAt = recordedAt
        self.dailySession = dailySession
    }
}

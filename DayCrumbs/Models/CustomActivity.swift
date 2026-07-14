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
    var storyEntry: StoryEntry?

    init(
        name: String,
        imageData: Data? = nil,
        recordedAt: Date = .now,
        storyEntry: StoryEntry? = nil
    ) {
        self.name = name
        self.imageData = imageData
        self.recordedAt = recordedAt
        self.storyEntry = storyEntry
    }
}

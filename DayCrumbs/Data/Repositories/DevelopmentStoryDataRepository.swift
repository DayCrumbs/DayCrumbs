#if DEBUG
import Foundation
import SwiftData

@MainActor
protocol DevelopmentStoryDataRepositoryProtocol {
    func fetchEntries() throws -> [StoryEntry]
    func delete(_ entry: StoryEntry) throws
}

@MainActor
final class DevelopmentStoryDataRepository: DevelopmentStoryDataRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchEntries() throws -> [StoryEntry] {
        let descriptor = FetchDescriptor<StoryEntry>(
            sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func delete(_ entry: StoryEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }
}

@MainActor
final class ShowcaseDevelopmentStoryDataRepository: DevelopmentStoryDataRepositoryProtocol {
    private var inMemoryEntries: [StoryEntry]?

    init() {}

    func fetchEntries() throws -> [StoryEntry] {
        if let existing = inMemoryEntries {
            return existing
        }
        let childProfile = ShowcaseProfile.arya
        let sessions = ShowcaseStory.generateSessions(
            for: childProfile,
            referenceDate: .now,
            calendar: .current
        )
        childProfile.dailySessions = sessions
        let entries = sessions
            .flatMap(\.entries)
            .sorted { $0.recordedAt < $1.recordedAt }
        inMemoryEntries = entries
        return entries
    }

    func delete(_ entry: StoryEntry) throws {
        inMemoryEntries?.removeAll { $0 === entry }
    }
}
#endif


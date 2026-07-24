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
#endif

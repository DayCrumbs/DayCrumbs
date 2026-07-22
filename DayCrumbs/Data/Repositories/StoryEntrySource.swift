import Foundation
import SwiftData

@MainActor
protocol StoryEntrySourceProtocol {
    func fetchEntries() async throws -> [StoryEntry]
}

/// Mengambil entri cerita nyata dari penyimpanan lokal SwiftData.
@MainActor
final class StoryEntrySource: StoryEntrySourceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Mengambil seluruh StoryEntry nyata dari database lokal yang terurut berdasarkan tanggal.
    func fetchEntries() async throws -> [StoryEntry] {
        let descriptor = FetchDescriptor<StoryEntry>(
            sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
        )
        let entries = try modelContext.fetch(descriptor)
        return entries
    }
}

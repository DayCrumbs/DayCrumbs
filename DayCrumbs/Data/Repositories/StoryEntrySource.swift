import Foundation

/// Read boundary for Dashboard story entries.
///
/// A SwiftData repository can replace the dummy implementation without changing
/// the range-selection or generation pipeline.
@MainActor
protocol StoryEntrySource {
    func fetchEntries() async throws -> [StoryEntry]
}

#if DEBUG
import Foundation
import Observation

struct DevelopmentStoryDataRow: Identifiable {
    let id: String
    let recordedAt: String
    let session: String
    let place: String
    let activity: String
    let mood: String
    let afterActivityNote: String
    let endOfDayReflection: String
}

@MainActor
@Observable
final class DevelopmentStoryDataViewModel {
    enum State {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var rows: [DevelopmentStoryDataRow] = []
    private(set) var state: State = .loading
    private(set) var deletingRowID: String?
    private(set) var deletionErrorMessage: String?

    private let repository: any DevelopmentStoryDataRepositoryProtocol
    private var entriesByRowID: [String: StoryEntry] = [:]

    init(repository: any DevelopmentStoryDataRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        state = .loading

        do {
            let entries = try repository.fetchEntries()
            var mappedEntries: [String: StoryEntry] = [:]
            rows = entries.enumerated().map { index, entry in
                let rowID = "\(entry.recordedAt.timeIntervalSinceReferenceDate)-\(index)"
                mappedEntries[rowID] = entry

                return DevelopmentStoryDataRow(
                    id: rowID,
                    recordedAt: entry.recordedAt.formatted(
                        .dateTime.year().month().day().hour().minute().second()
                    ),
                    session: entry.session.rawValue,
                    place: entry.place?.rawValue
                        ?? entry.customPlace?.name
                        ?? "NULL",
                    activity: entry.activity?.rawValue
                        ?? entry.customActivity?.name
                        ?? "NULL",
                    mood: entry.mood.rawValue,
                    afterActivityNote: Self.combinedText(
                        entry.afterActivityNotes?.text,
                        entry.afterActivityNotes?.transcribedText
                    ),
                    endOfDayReflection: Self.combinedText(
                        entry.dailySession?.endOfDayReflection?.text,
                        entry.dailySession?.endOfDayReflection?.transcribedText
                    )
                )
            }
            entriesByRowID = mappedEntries
            state = .loaded
        } catch {
            rows = []
            entriesByRowID = [:]
            state = .failed(error.localizedDescription)
        }
    }

    func deleteRow(id: String) {
        guard deletingRowID == nil, let entry = entriesByRowID[id] else {
            return
        }

        deletingRowID = id
        deletionErrorMessage = nil

        do {
            try repository.delete(entry)
            entriesByRowID[id] = nil
            rows.removeAll { $0.id == id }
        } catch {
            deletionErrorMessage = error.localizedDescription
        }

        deletingRowID = nil
    }

    func clearDeletionError() {
        deletionErrorMessage = nil
    }

    private static func combinedText(_ values: String?...) -> String {
        let content = values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")

        return content.isEmpty ? "NULL" : content
    }
}
#endif

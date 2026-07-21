import Foundation
import SwiftData

@MainActor
protocol StoryFlowRepositoryProtocol {
    func saveActivity(
        for profile: ChildProfile,
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        mood: Moods,
        discussion: String?
    ) throws
    func saveEndOfDayReflection(
        _ reflection: String,
        for profile: ChildProfile
    ) throws
}

@MainActor
final class StoryFlowRepository: StoryFlowRepositoryProtocol {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContext: ModelContext, calendar: Calendar = .current) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    func saveActivity(
        for profile: ChildProfile,
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        mood: Moods,
        discussion: String?
    ) throws {
        let dailySession = try currentDaySession(for: profile)
        let trimmedDiscussion = discussion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = trimmedDiscussion.flatMap { text in
            text.isEmpty ? nil : AfterActivityNotes(text: text)
        }

        let entry = StoryEntry(
            session: session,
            mood: mood,
            activity: activity,
            place: place,
            afterActivityNotes: notes,
            dailySession: dailySession
        )
        modelContext.insert(entry)
        try modelContext.save()
    }

    func saveEndOfDayReflection(
        _ reflection: String,
        for profile: ChildProfile
    ) throws {
        let dailySession = try currentDaySession(for: profile)
        let trimmedReflection = reflection.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingReflection = dailySession.endOfDayReflection {
            existingReflection.text = trimmedReflection
            existingReflection.updatedAt = .now
        } else {
            dailySession.endOfDayReflection = EndOfDayReflection(
                text: trimmedReflection,
                dailySession: dailySession
            )
        }

        dailySession.endedAt = .now
        try modelContext.save()
    }

    private func currentDaySession(for profile: ChildProfile) throws -> DailySession {
        let descriptor = FetchDescriptor<DailySession>()
        let existingSession = try modelContext.fetch(descriptor)
            .filter { dailySession in
                dailySession.childProfile?.persistentModelID == profile.persistentModelID &&
                calendar.isDate(dailySession.startedAt, inSameDayAs: .now)
            }
            .sorted { $0.startedAt < $1.startedAt }
            .first

        if let existingSession {
            return existingSession
        }

        let dailySession = DailySession(childProfile: profile)
        modelContext.insert(dailySession)
        return dailySession
    }
}

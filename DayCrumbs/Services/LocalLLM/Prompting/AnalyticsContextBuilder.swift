//
//  AnalyticsContextBuilder.swift
//  DayCrumbs
//

import Foundation
import SwiftData

/// Engine-neutral, deterministic input for an analytics-generation request.
nonisolated struct AnalyticsContext: Equatable, Sendable {
    struct Child: Equatable, Sendable {
        let name: String
        let age: Int
        let gender: String
    }

    struct Event: Equatable, Sendable {
        let recordedAt: Date
        let session: String
        let mood: String
        let activity: String?
        let place: String?
        let afterActivityNote: String?
    }

    struct Reflection: Equatable, Sendable {
        let sessionStartedAt: Date
        let content: String
    }

    let child: Child
    let events: [Event]
    let reflections: [Reflection]

    /// Stable plain-text representation shared by both runtime adapters.
    var text: String {
        var lines = [
            "CHILD_PROFILE",
            "name: \(child.name)",
            "age: \(child.age)",
            "gender: \(child.gender)",
            "STORY_EVENTS: \(events.count)",
        ]

        for (index, event) in events.enumerated() {
            lines.append("EVENT_\(index + 1)")
            lines.append("recordedDate: \(Self.calendarDate(event.recordedAt))")
            lines.append("session: \(event.session)")
            lines.append("mood: \(event.mood)")
            lines.append("activity: \(event.activity ?? "absent")")
            lines.append("place: \(event.place ?? "absent")")
            lines.append("afterActivityNote: \(event.afterActivityNote ?? "absent")")
        }

        lines.append("END_OF_DAY_REFLECTIONS: \(reflections.count)")
        for (index, reflection) in reflections.enumerated() {
            lines.append("REFLECTION_\(index + 1)")
            lines.append(
                "sessionDate: \(Self.calendarDate(reflection.sessionStartedAt))"
            )
            lines.append("content: \(reflection.content)")
        }

        return lines.joined(separator: "\n")
    }

    /// The model needs calendar-day grouping and chronology, not incidental
    /// capture times. Omitting clock components prevents them from being
    /// misrepresented as meaningful evidence.
    private static func calendarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Builds analytics context from entries already selected by the caller.
///
/// The builder deliberately performs no fetching, scope selection, inference, or
/// analytics. Its only responsibilities are validation and deterministic shaping.
@MainActor
struct AnalyticsContextBuilder {
    enum EventLimit: Equatable, Sendable {
        case primary
        case retry
    }

    enum BuildError: Error, Equatable, Sendable {
        case emptyEntries
        case missingChildProfile
        case mixedChildren
    }

    private let configuration: LocalLLMConfiguration

    init(configuration: LocalLLMConfiguration = .default) {
        self.configuration = configuration
    }

    func build(
        from entries: [StoryEntry],
        eventLimit: EventLimit = .primary
    ) throws -> AnalyticsContext {
        guard !entries.isEmpty else {
            throw BuildError.emptyEntries
        }

        let profiles = try entries.map { entry in
            guard let profile = entry.dailySession?.childProfile else {
                throw BuildError.missingChildProfile
            }
            return profile
        }

        guard let childProfile = profiles.first else {
            throw BuildError.emptyEntries
        }
        let childIdentifier = childProfile.persistentModelID
        guard profiles.dropFirst().allSatisfy({
            $0.persistentModelID == childIdentifier
        }) else {
            throw BuildError.mixedChildren
        }

        let maximumEventCount = switch eventLimit {
        case .primary:
            configuration.primaryEventLimit
        case .retry:
            configuration.retryEventLimit
        }

        let selectedEntries = Array(
            entries
                .sorted(by: isOrderedBefore)
                .suffix(maximumEventCount)
        )

        let contextEvents = selectedEntries.map(makeContextEvent)
        let reflections = makeReflections(from: selectedEntries)

        return AnalyticsContext(
            child: AnalyticsContext.Child(
                name: normalize(childProfile.name),
                age: childProfile.age,
                gender: childProfile.gender.rawValue
            ),
            events: contextEvents,
            reflections: reflections
        )
    }

    private func makeContextEvent(from entry: StoryEntry) -> AnalyticsContext.Event {
        AnalyticsContext.Event(
            recordedAt: entry.recordedAt,
            session: entry.session.rawValue,
            mood: entry.mood.rawValue,
            activity: resolvedActivity(for: entry),
            place: resolvedPlace(for: entry),
            afterActivityNote: preferredContent(
                text: entry.afterActivityNotes?.text,
                transcribedText: entry.afterActivityNotes?.transcribedText,
                characterLimit: configuration.noteCharacterLimit
            )
        )
    }

    private func makeReflections(
        from selectedEntries: [StoryEntry]
    ) -> [AnalyticsContext.Reflection] {
        var selectedSessions: [DailySession] = []

        for entry in selectedEntries {
            guard let dailySession = entry.dailySession else {
                continue
            }
            let sessionIdentifier = dailySession.persistentModelID
            guard !selectedSessions.contains(where: {
                $0.persistentModelID == sessionIdentifier
            }) else {
                continue
            }
            selectedSessions.append(dailySession)
        }

        return selectedSessions
            .compactMap { dailySession -> AnalyticsContext.Reflection? in
                guard let reflection = dailySession.endOfDayReflection else {
                    return nil
                }
                guard let content = preferredContent(
                    text: reflection.text,
                    transcribedText: reflection.transcribedText,
                    characterLimit: configuration.reflectionCharacterLimit
                ) else {
                    return nil
                }

                return AnalyticsContext.Reflection(
                    sessionStartedAt: dailySession.startedAt,
                    content: content
                )
            }
            .sorted { first, second in
                if first.sessionStartedAt != second.sessionStartedAt {
                    return first.sessionStartedAt < second.sessionStartedAt
                }
                return first.content < second.content
            }
    }

    private func isOrderedBefore(_ first: StoryEntry, _ second: StoryEntry) -> Bool {
        if first.recordedAt != second.recordedAt {
            return first.recordedAt < second.recordedAt
        }
        return deterministicKey(for: first).lexicographicallyPrecedes(
            deterministicKey(for: second)
        )
    }

    private func deterministicKey(for entry: StoryEntry) -> [String] {
        let reflection = entry.dailySession?.endOfDayReflection

        return [
            entry.dailySession?.startedAt.timeIntervalSinceReferenceDate.description ?? "",
            entry.session.rawValue,
            entry.mood.rawValue,
            resolvedActivity(for: entry) ?? "",
            resolvedPlace(for: entry) ?? "",
            preferredContent(
                text: entry.afterActivityNotes?.text,
                transcribedText: entry.afterActivityNotes?.transcribedText,
                characterLimit: configuration.noteCharacterLimit
            ) ?? "",
            preferredContent(
                text: reflection?.text,
                transcribedText: reflection?.transcribedText,
                characterLimit: configuration.reflectionCharacterLimit
            ) ?? "",
        ]
    }

    private func resolvedActivity(for entry: StoryEntry) -> String? {
        if let activity = entry.activity {
            return activity.rawValue
        }
        return normalizedNonempty(entry.customActivity?.name)
    }

    private func resolvedPlace(for entry: StoryEntry) -> String? {
        if let place = entry.place {
            return place.rawValue
        }
        return normalizedNonempty(entry.customPlace?.name)
    }

    private func preferredContent(
        text: String?,
        transcribedText: String?,
        characterLimit: Int
    ) -> String? {
        let preferred = normalizedNonempty(text) ?? normalizedNonempty(transcribedText)
        guard let preferred else {
            return nil
        }

        return normalize(String(preferred.prefix(characterLimit)))
    }

    private func normalizedNonempty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = normalize(value)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalize(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

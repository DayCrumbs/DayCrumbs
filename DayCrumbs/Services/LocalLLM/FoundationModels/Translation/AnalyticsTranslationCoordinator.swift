//
//  AnalyticsTranslationCoordinator.swift
//  DayCrumbs
//

import Foundation

/// Coordinates Apple-only language preparation without mutating persisted story data.
@MainActor
protocol AnalyticsTranslationCoordinating {
    func translateInputContext(
        _ context: AnalyticsContext,
        using translateBatch: NativeTranslationBatchHandler
    ) async throws -> AnalyticsInputTranslation

    func translateIdentifiedTexts(
        _ texts: [IdentifiedTranslationText],
        from sourceLanguage: LanguageIdentifier,
        to targetLanguage: LanguageIdentifier,
        using translateBatch: NativeTranslationBatchHandler
    ) async throws -> [IdentifiedTranslationText]
}

/// Prepares parent-authored analytics text for Apple Foundation Models.
///
/// Gemma must continue using the original AnalyticsContext and must not call this service.
@MainActor
struct AnalyticsTranslationCoordinator: AnalyticsTranslationCoordinating {
    private enum RequestID {
        static func eventNote(at index: Int) -> String {
            "event-note-\(index)"
        }

        static func reflection(at index: Int) -> String {
            "reflection-\(index)"
        }
    }

    private let languageDetectionService: any LanguageDetectionService
    private let nativeTranslationService: any NativeTranslationService

    init() {
        languageDetectionService = NaturalLanguageDetectionService()
        nativeTranslationService = AppleNativeTranslationService()
    }

    init(
        languageDetectionService: any LanguageDetectionService,
        nativeTranslationService: any NativeTranslationService
    ) {
        self.languageDetectionService = languageDetectionService
        self.nativeTranslationService = nativeTranslationService
    }

    func translateInputContext(
        _ context: AnalyticsContext,
        using translateBatch: NativeTranslationBatchHandler
    ) async throws -> AnalyticsInputTranslation {
        let parentTexts = parentAuthoredTexts(in: context)
        let detectionRequests = parentTexts.map {
            LanguageDetectionRequest(id: $0.id, text: $0.text)
        }
        let detection = try languageDetectionService.detectLanguages(
            in: detectionRequests
        )
        let detectedLanguages = try detectedLanguagesByIdentifier(
            from: detection,
            matching: detectionRequests
        )

        let translationRequests: [NativeTranslationRequest] = parentTexts
            .compactMap { parentText in
                guard let sourceLanguage = detectedLanguages[parentText.id],
                      sourceLanguage != .english else {
                    return nil
                }
                return NativeTranslationRequest(
                    id: parentText.id,
                    text: parentText.text,
                    sourceLanguage: sourceLanguage
                )
            }

        let translatedTexts = try await translate(
            translationRequests,
            targetLanguage: .english,
            using: translateBatch
        )
        let englishContext = replacingParentText(
            in: context,
            with: translatedTexts
        )

        return AnalyticsInputTranslation(
            englishContext: englishContext,
            responseLanguage: detection.responseLanguage,
            didTranslateParentText: !translationRequests.isEmpty
        )
    }

    func translateIdentifiedTexts(
        _ texts: [IdentifiedTranslationText],
        from sourceLanguage: LanguageIdentifier,
        to targetLanguage: LanguageIdentifier,
        using translateBatch: NativeTranslationBatchHandler
    ) async throws -> [IdentifiedTranslationText] {
        try validate(texts)

        // Avoid invoking Translation when the generated language already matches the parent.
        guard sourceLanguage != targetLanguage else {
            return texts
        }

        let requests = texts.map {
            NativeTranslationRequest(
                id: $0.id,
                text: $0.text,
                sourceLanguage: sourceLanguage
            )
        }
        let translatedTexts = try await translate(
            requests,
            targetLanguage: targetLanguage,
            using: translateBatch
        )

        return try texts.map { text in
            guard let translatedText = translatedTexts[text.id] else {
                throw AnalyticsTranslationError.missingTranslation(text.id)
            }
            return IdentifiedTranslationText(
                id: text.id,
                text: translatedText
            )
        }
    }

    private func parentAuthoredTexts(
        in context: AnalyticsContext
    ) -> [IdentifiedTranslationText] {
        let eventNotes = context.events.enumerated()
            .compactMap { index, event in
                makeParentText(
                    id: RequestID.eventNote(at: index),
                    text: event.afterActivityNote
                )
            }
        let reflections = context.reflections.enumerated()
            .compactMap { index, reflection in
                makeParentText(
                    id: RequestID.reflection(at: index),
                    text: reflection.content
                )
            }
        return eventNotes + reflections
    }

    private func makeParentText(
        id: String,
        text: String?
    ) -> IdentifiedTranslationText? {
        guard let text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return IdentifiedTranslationText(id: id, text: text)
    }

    private func detectedLanguagesByIdentifier(
        from detection: LanguageDetectionResult,
        matching requests: [LanguageDetectionRequest]
    ) throws -> [String: LanguageIdentifier] {
        let expectedIdentifiers = Set(requests.map(\.id))
        var languagesByIdentifier: [String: LanguageIdentifier] = [:]

        for segment in detection.segments {
            guard expectedIdentifiers.contains(segment.requestID) else {
                throw AnalyticsTranslationError.unexpectedDetectedLanguage(
                    segment.requestID
                )
            }
            guard languagesByIdentifier[segment.requestID] == nil else {
                throw AnalyticsTranslationError.duplicateDetectedLanguage(
                    segment.requestID
                )
            }
            languagesByIdentifier[segment.requestID] = segment.language
        }

        for request in requests where languagesByIdentifier[request.id] == nil {
            throw AnalyticsTranslationError.missingDetectedLanguage(request.id)
        }
        return languagesByIdentifier
    }

    private func translate(
        _ requests: [NativeTranslationRequest],
        targetLanguage: LanguageIdentifier,
        using translateBatch: NativeTranslationBatchHandler
    ) async throws -> [String: String] {
        guard !requests.isEmpty else {
            return [:]
        }

        let batches = try nativeTranslationService.makeBatches(
            from: requests,
            targetLanguage: targetLanguage
        )
        let expectedIdentifiers = Set(requests.map(\.id))
        var translatedTexts: [String: String] = [:]

        for batch in batches {
            let responses = try await translateBatch(batch)
            for response in responses {
                guard expectedIdentifiers.contains(response.id) else {
                    throw AnalyticsTranslationError.unexpectedTranslation(response.id)
                }
                guard translatedTexts[response.id] == nil else {
                    throw AnalyticsTranslationError.duplicateTranslation(response.id)
                }
                translatedTexts[response.id] = response.text
            }
        }

        for request in requests where translatedTexts[request.id] == nil {
            throw AnalyticsTranslationError.missingTranslation(request.id)
        }
        return translatedTexts
    }

    private func replacingParentText(
        in context: AnalyticsContext,
        with translatedTexts: [String: String]
    ) -> AnalyticsContext {
        let events = context.events.enumerated().map { index, event in
            AnalyticsContext.Event(
                recordedAt: event.recordedAt,
                session: event.session,
                mood: event.mood,
                activity: event.activity,
                place: event.place,
                afterActivityNote: translatedTexts[RequestID.eventNote(at: index)]
                    ?? event.afterActivityNote
            )
        }
        let reflections = context.reflections.enumerated().map { index, reflection in
            AnalyticsContext.Reflection(
                sessionStartedAt: reflection.sessionStartedAt,
                content: translatedTexts[RequestID.reflection(at: index)]
                    ?? reflection.content
            )
        }

        return AnalyticsContext(
            child: context.child,
            events: events,
            reflections: reflections
        )
    }

    private func validate(_ texts: [IdentifiedTranslationText]) throws {
        var identifiers: Set<String> = []
        for text in texts {
            guard !text.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AnalyticsTranslationError.emptyTextIdentifier
            }
            guard identifiers.insert(text.id).inserted else {
                throw AnalyticsTranslationError.duplicateTextIdentifier(text.id)
            }
            guard !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AnalyticsTranslationError.emptyText(text.id)
            }
        }
    }
}

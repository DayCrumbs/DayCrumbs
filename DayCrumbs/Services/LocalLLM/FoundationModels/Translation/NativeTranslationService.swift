//
//  NativeTranslationService.swift
//  DayCrumbs
//

import Foundation
import Translation

/// Apple-only translation behavior used before and after Foundation Models generation.
@MainActor
protocol NativeTranslationService {
    func readiness(
        for pair: TranslationLanguagePair
    ) async -> NativeTranslationReadiness

    func makeBatches(
        from requests: [NativeTranslationRequest],
        targetLanguage: LanguageIdentifier
    ) throws -> [NativeTranslationBatch]

    func configuration(
        for pair: TranslationLanguagePair
    ) -> TranslationSession.Configuration

    func prepareTranslation(
        for pair: TranslationLanguagePair,
        using session: any NativeTranslationSession
    ) async throws -> NativeTranslationPreparationState

    func translate(
        _ batch: NativeTranslationBatch,
        using session: any NativeTranslationSession
    ) async throws -> [NativeTranslatedText]
}

/// Production service using traditional, system-managed on-device translation models.
@MainActor
struct AppleNativeTranslationService: NativeTranslationService {
    typealias CheckAvailability = @MainActor @Sendable (
        TranslationLanguagePair
    ) async -> LanguageAvailability.Status

    private let checkAvailability: CheckAvailability

    init() {
        checkAvailability = { pair in
            let availability = LanguageAvailability(preferredStrategy: .lowLatency)
            return await availability.status(
                from: pair.source.localeLanguage,
                to: pair.target.localeLanguage
            )
        }
    }

    /// Internal injection keeps status-policy tests independent of installed assets.
    init(checkAvailability: @escaping CheckAvailability) {
        self.checkAvailability = checkAvailability
    }

    func readiness(
        for pair: TranslationLanguagePair
    ) async -> NativeTranslationReadiness {
        let availability = await mappedAvailability(for: pair)
        let preparationState: NativeTranslationPreparationState = switch availability {
        case .installed:
            .ready
        case .supported:
            .downloadRequired
        case .unsupported:
            .unsupported
        }

        return NativeTranslationReadiness(
            pair: pair,
            availability: availability,
            preparationState: preparationState
        )
    }

    func makeBatches(
        from requests: [NativeTranslationRequest],
        targetLanguage: LanguageIdentifier
    ) throws -> [NativeTranslationBatch] {
        var requestIdentifiers: Set<String> = []
        var sourceLanguageOrder: [LanguageIdentifier] = []
        var requestsBySource: [LanguageIdentifier: [NativeTranslationRequest]] = [:]

        for request in requests {
            guard !request.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NativeTranslationError.emptyRequestIdentifier
            }
            guard requestIdentifiers.insert(request.id).inserted else {
                throw NativeTranslationError.duplicateRequestIdentifier(request.id)
            }
            guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NativeTranslationError.emptyRequestText(request.id)
            }
            guard request.sourceLanguage != targetLanguage else {
                throw NativeTranslationError.identicalSourceAndTarget(targetLanguage)
            }

            if requestsBySource[request.sourceLanguage] == nil {
                sourceLanguageOrder.append(request.sourceLanguage)
                requestsBySource[request.sourceLanguage] = []
            }
            requestsBySource[request.sourceLanguage, default: []].append(request)
        }

        return sourceLanguageOrder.map { sourceLanguage in
            NativeTranslationBatch(
                pair: TranslationLanguagePair(
                    source: sourceLanguage,
                    target: targetLanguage
                ),
                requests: requestsBySource[sourceLanguage, default: []]
            )
        }
    }

    func configuration(
        for pair: TranslationLanguagePair
    ) -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: pair.source.localeLanguage,
            target: pair.target.localeLanguage,
            preferredStrategy: .lowLatency
        )
    }

    func prepareTranslation(
        for pair: TranslationLanguagePair,
        using session: any NativeTranslationSession
    ) async throws -> NativeTranslationPreparationState {
        try validate(session: session, for: pair)
        try await session.prepareTranslation()
        return .ready
    }

    func translate(
        _ batch: NativeTranslationBatch,
        using session: any NativeTranslationSession
    ) async throws -> [NativeTranslatedText] {
        try validate(session: session, for: batch.pair)

        let sessionRequests = batch.requests.map {
            NativeTranslationSessionRequest(
                clientIdentifier: $0.id,
                sourceText: $0.text
            )
        }
        let responses = try await session.translations(from: sessionRequests)
        return try orderedTranslations(
            from: responses,
            matching: batch.requests
        )
    }

    private func mappedAvailability(
        for pair: TranslationLanguagePair
    ) async -> NativeTranslationAvailability {
        switch await checkAvailability(pair) {
        case .installed:
            .installed
        case .supported:
            .supported
        case .unsupported:
            .unsupported
        @unknown default:
            .unsupported
        }
    }

    private func validate(
        session: any NativeTranslationSession,
        for pair: TranslationLanguagePair
    ) throws {
        guard session.sourceLanguage == pair.source,
              session.targetLanguage == pair.target else {
            throw NativeTranslationError.sessionLanguageMismatch(
                expected: pair,
                actualSource: session.sourceLanguage,
                actualTarget: session.targetLanguage
            )
        }
    }

    private func orderedTranslations(
        from responses: [NativeTranslationSessionResponse],
        matching requests: [NativeTranslationRequest]
    ) throws -> [NativeTranslatedText] {
        let expectedIdentifiers = Set(requests.map(\.id))
        var translationsByIdentifier: [String: String] = [:]

        for response in responses {
            guard let identifier = response.clientIdentifier else {
                throw NativeTranslationError.missingResponseIdentifier
            }
            guard expectedIdentifiers.contains(identifier) else {
                throw NativeTranslationError.unexpectedResponseIdentifier(identifier)
            }
            guard translationsByIdentifier[identifier] == nil else {
                throw NativeTranslationError.duplicateResponseIdentifier(identifier)
            }
            translationsByIdentifier[identifier] = response.targetText
        }

        return try requests.map { request in
            guard let translatedText = translationsByIdentifier[request.id] else {
                throw NativeTranslationError.missingResponse(request.id)
            }
            return NativeTranslatedText(id: request.id, text: translatedText)
        }
    }
}

private extension LanguageIdentifier {
    var localeLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }
}

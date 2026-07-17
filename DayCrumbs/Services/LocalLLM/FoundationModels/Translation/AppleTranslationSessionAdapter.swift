//
//  AppleTranslationSessionAdapter.swift
//  DayCrumbs
//

import Foundation
import Translation

/// Adapts the session supplied by `.translationTask` without owning it beyond that task.
///
/// Create this value inside the task closure, await one operation, and then discard it.
@MainActor
final class AppleTranslationSessionAdapter: NativeTranslationSession {
    private let session: TranslationSession

    init(viewBoundSession session: TranslationSession) {
        self.session = session
    }

    var sourceLanguage: LanguageIdentifier? {
        session.sourceLanguage.map {
            LanguageIdentifier(rawValue: $0.minimalIdentifier)
        }
    }

    var targetLanguage: LanguageIdentifier? {
        session.targetLanguage.map {
            LanguageIdentifier(rawValue: $0.minimalIdentifier)
        }
    }

    func prepareTranslation() async throws {
        try await session.prepareTranslation()
    }

    func translations(
        from requests: [NativeTranslationSessionRequest]
    ) async throws -> [NativeTranslationSessionResponse] {
        let appleRequests = requests.map {
            TranslationSession.Request(
                sourceText: $0.sourceText,
                clientIdentifier: $0.clientIdentifier
            )
        }
        let responses = try await session.translations(from: appleRequests)

        return responses.map {
            NativeTranslationSessionResponse(
                clientIdentifier: $0.clientIdentifier,
                targetText: $0.targetText
            )
        }
    }
}

//
//  NativeTranslationTypes.swift
//  DayCrumbs
//

import Foundation

/// A source-target pairing supported by one view-bound translation session.
nonisolated struct TranslationLanguagePair: Equatable, Hashable, Sendable {
    let source: LanguageIdentifier
    let target: LanguageIdentifier
}

nonisolated enum NativeTranslationAvailability: Equatable, Sendable {
    case installed
    case supported
    case unsupported
}

/// UI-ready lifecycle states for a future `.translationTask` host.
nonisolated enum NativeTranslationPreparationState: Equatable, Sendable {
    case idle
    case checking
    case ready
    case downloadRequired
    case preparing
    case unsupported
    case failed
}

nonisolated struct NativeTranslationReadiness: Equatable, Sendable {
    let pair: TranslationLanguagePair
    let availability: NativeTranslationAvailability
    let preparationState: NativeTranslationPreparationState
}

/// Text that has already been assigned a source language by language detection.
nonisolated struct NativeTranslationRequest: Equatable, Sendable {
    let id: String
    let text: String
    let sourceLanguage: LanguageIdentifier
}

/// Requests in a batch always share exactly one source-target language pair.
nonisolated struct NativeTranslationBatch: Equatable, Sendable {
    let pair: TranslationLanguagePair
    let requests: [NativeTranslationRequest]

    init(
        pair: TranslationLanguagePair,
        requests: [NativeTranslationRequest]
    ) {
        self.pair = pair
        self.requests = requests
    }
}

nonisolated struct NativeTranslatedText: Equatable, Sendable {
    let id: String
    let text: String
}

nonisolated enum NativeTranslationError: Error, Equatable, Sendable {
    case emptyRequestIdentifier
    case duplicateRequestIdentifier(String)
    case emptyRequestText(String)
    case identicalSourceAndTarget(LanguageIdentifier)
    case sessionLanguageMismatch(
        expected: TranslationLanguagePair,
        actualSource: LanguageIdentifier?,
        actualTarget: LanguageIdentifier?
    )
    case missingResponseIdentifier
    case unexpectedResponseIdentifier(String)
    case duplicateResponseIdentifier(String)
    case missingResponse(String)
}

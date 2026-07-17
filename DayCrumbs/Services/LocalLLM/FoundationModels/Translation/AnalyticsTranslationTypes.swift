//
//  AnalyticsTranslationTypes.swift
//  DayCrumbs
//

import Foundation

/// Text with a stable identifier that can be translated without knowing its domain model.
nonisolated struct IdentifiedTranslationText: Equatable, Sendable {
    let id: String
    let text: String
}

/// In-memory input prepared specifically for Apple Foundation Models generation.
nonisolated struct AnalyticsInputTranslation: Equatable, Sendable {
    let englishContext: AnalyticsContext
    let responseLanguage: LanguageIdentifier
    let didTranslateParentText: Bool
}

/// The future view-bound host fulfills one batch with its matching TranslationSession.
typealias NativeTranslationBatchHandler = @MainActor @Sendable (
    NativeTranslationBatch
) async throws -> [NativeTranslatedText]

nonisolated enum AnalyticsTranslationError: Error, Equatable, Sendable {
    case emptyTextIdentifier
    case duplicateTextIdentifier(String)
    case emptyText(String)
    case missingDetectedLanguage(String)
    case unexpectedDetectedLanguage(String)
    case duplicateDetectedLanguage(String)
    case missingTranslation(String)
    case unexpectedTranslation(String)
    case duplicateTranslation(String)
}

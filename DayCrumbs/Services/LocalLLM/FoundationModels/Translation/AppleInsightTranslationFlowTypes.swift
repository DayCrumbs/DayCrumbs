//
//  AppleInsightTranslationFlowTypes.swift
//  DayCrumbs
//

import Foundation

/// Tells the future `.translationTask` host whether it must prepare language assets.
nonisolated enum NativeTranslationBatchExecutionMode: Equatable, Sendable {
    case translateInstalled
    case prepareThenTranslate
}

/// Failures that the view-bound batch host must normalize from Apple Translation.
nonisolated enum NativeTranslationBatchExecutionError: Error, Equatable, Sendable {
    case downloadDenied
    case cancelled
    case transientSessionFailure
    case preparationFailed
    case translationFailed
}

/// Performs one batch inside the matching view-bound TranslationSession operation.
typealias PreparedNativeTranslationBatchHandler = @MainActor @Sendable (
    NativeTranslationBatch,
    NativeTranslationBatchExecutionMode
) async throws -> [NativeTranslatedText]

nonisolated struct AppleInsightTranslationFailure: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case input
        case output
    }

    enum Reason: Equatable, Sendable {
        case undeterminedLanguage
        case unsupportedLanguagePair
        case downloadDenied
        case cancelled
        case transientSessionFailure
        case preparationFailed
        case translationFailed
        case invalidTranslationData
    }

    let stage: Stage
    let reason: Reason
    let pair: TranslationLanguagePair?

    /// UI-ready copy keeps technical framework errors out of Views.
    var userMessage: String {
        switch reason {
        case .undeterminedLanguage:
            "The language in the parent notes could not be determined. Please add a little more detail and try again."
        case .unsupportedLanguagePair:
            "On-device translation is not available for one of the detected languages."
        case .downloadDenied:
            if stage == .input {
                "The language download was not approved, so private insight generation did not continue."
            } else {
                "The language download was not approved. The generated insight is shown in English and translation can be retried."
            }
        case .cancelled:
            if stage == .input {
                "Translation was cancelled. You can try insight generation again when you are ready."
            } else {
                "Output translation was cancelled. The generated insight remains available in English."
            }
        case .transientSessionFailure:
            "The on-device translation session was interrupted. Please try again."
        case .preparationFailed:
            "The required on-device language could not be prepared. Please try again."
        case .translationFailed:
            "The text could not be translated on this device. Please try again."
        case .invalidTranslationData:
            "The translated text could not be matched safely to the original fields."
        }
    }
}

/// Only `.ready` allows the caller to start Apple Foundation Models generation.
nonisolated enum AppleInsightInputPreparationResult: Equatable, Sendable {
    case ready(AnalyticsInputTranslation)
    case blocked(AppleInsightTranslationFailure)

    var allowsGeneration: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
}

/// Keeps the English generation result available when output localization fails.
nonisolated struct AppleInsightEnglishFallback: Equatable, Sendable {
    let englishTexts: [IdentifiedTranslationText]
    let targetLanguage: LanguageIdentifier
    let failure: AppleInsightTranslationFailure

    let displayLabel = "English fallback"
    let canRetryTranslation = true
}

nonisolated enum AppleInsightOutputTranslationResult: Equatable, Sendable {
    case localized([IdentifiedTranslationText])
    case englishFallback(AppleInsightEnglishFallback)
}

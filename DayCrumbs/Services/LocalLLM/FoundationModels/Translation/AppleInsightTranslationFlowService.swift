//
//  AppleInsightTranslationFlowService.swift
//  DayCrumbs
//

import Foundation

/// Defines translation policy around a future Apple Foundation Models request.
@MainActor
protocol AppleInsightTranslationFlow {
    func prepareInputContext(
        _ context: AnalyticsContext,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightInputPreparationResult

    func localizeGeneratedTexts(
        _ englishTexts: [IdentifiedTranslationText],
        to targetLanguage: LanguageIdentifier,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightOutputTranslationResult

    func retryOutputTranslation(
        _ fallback: AppleInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightOutputTranslationResult
}

/// Apple-only orchestration boundary; it never starts generation or touches Gemma.
@MainActor
struct AppleInsightTranslationFlowService: AppleInsightTranslationFlow {
    private struct FlowFailure: Error {
        let reason: AppleInsightTranslationFailure.Reason
        let pair: TranslationLanguagePair?
    }

    private let translationCoordinator: any AnalyticsTranslationCoordinating
    private let nativeTranslationService: any NativeTranslationService

    init() {
        let nativeTranslationService = AppleNativeTranslationService()
        self.nativeTranslationService = nativeTranslationService
        translationCoordinator = AnalyticsTranslationCoordinator(
            languageDetectionService: NaturalLanguageDetectionService(),
            nativeTranslationService: nativeTranslationService
        )
    }

    init(
        translationCoordinator: any AnalyticsTranslationCoordinating,
        nativeTranslationService: any NativeTranslationService
    ) {
        self.translationCoordinator = translationCoordinator
        self.nativeTranslationService = nativeTranslationService
    }

    func prepareInputContext(
        _ context: AnalyticsContext,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightInputPreparationResult {
        do {
            let translation = try await translationCoordinator.translateInputContext(
                context
            ) { batch in
                try await executeReadyBatch(batch, using: executeBatch)
            }
            return .ready(translation)
        } catch {
            return .blocked(makeFailure(from: error, stage: .input))
        }
    }

    func localizeGeneratedTexts(
        _ englishTexts: [IdentifiedTranslationText],
        to targetLanguage: LanguageIdentifier,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightOutputTranslationResult {
        do {
            let localizedTexts = try await translationCoordinator.translateIdentifiedTexts(
                englishTexts,
                from: .english,
                to: targetLanguage
            ) { batch in
                try await executeReadyBatch(batch, using: executeBatch)
            }
            return .localized(localizedTexts)
        } catch {
            let failure = makeFailure(from: error, stage: .output)
            return .englishFallback(
                AppleInsightEnglishFallback(
                    englishTexts: englishTexts,
                    targetLanguage: targetLanguage,
                    failure: failure
                )
            )
        }
    }

    func retryOutputTranslation(
        _ fallback: AppleInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightOutputTranslationResult {
        // Retry uses the preserved English fields and never requests another generation.
        await localizeGeneratedTexts(
            fallback.englishTexts,
            to: fallback.targetLanguage,
            using: executeBatch
        )
    }

    private func executeReadyBatch(
        _ batch: NativeTranslationBatch,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> [NativeTranslatedText] {
        let readiness = await nativeTranslationService.readiness(for: batch.pair)
        let executionMode: NativeTranslationBatchExecutionMode

        switch readiness.availability {
        case .installed:
            executionMode = .translateInstalled
        case .supported:
            // The view-bound host asks for approval, prepares assets, then resumes this batch.
            executionMode = .prepareThenTranslate
        case .unsupported:
            throw FlowFailure(
                reason: .unsupportedLanguagePair,
                pair: batch.pair
            )
        }

        do {
            return try await executeBatch(batch, executionMode)
        } catch is CancellationError {
            throw FlowFailure(reason: .cancelled, pair: batch.pair)
        } catch let error as NativeTranslationBatchExecutionError {
            throw FlowFailure(
                reason: reason(for: error),
                pair: batch.pair
            )
        } catch {
            throw FlowFailure(reason: .translationFailed, pair: batch.pair)
        }
    }

    private func reason(
        for error: NativeTranslationBatchExecutionError
    ) -> AppleInsightTranslationFailure.Reason {
        switch error {
        case .downloadDenied:
            .downloadDenied
        case .cancelled:
            .cancelled
        case .preparationFailed:
            .preparationFailed
        case .translationFailed:
            .translationFailed
        }
    }

    private func makeFailure(
        from error: any Error,
        stage: AppleInsightTranslationFailure.Stage
    ) -> AppleInsightTranslationFailure {
        if let failure = error as? FlowFailure {
            return AppleInsightTranslationFailure(
                stage: stage,
                reason: failure.reason,
                pair: failure.pair
            )
        }
        if error is CancellationError {
            return AppleInsightTranslationFailure(
                stage: stage,
                reason: .cancelled,
                pair: nil
            )
        }
        if let detectionError = error as? LanguageDetectionError,
           detectionError == .undeterminedLanguage {
            return AppleInsightTranslationFailure(
                stage: stage,
                reason: .undeterminedLanguage,
                pair: nil
            )
        }

        // Identifier and reconstruction failures must never be passed to generation.
        return AppleInsightTranslationFailure(
            stage: stage,
            reason: .invalidTranslationData,
            pair: nil
        )
    }
}

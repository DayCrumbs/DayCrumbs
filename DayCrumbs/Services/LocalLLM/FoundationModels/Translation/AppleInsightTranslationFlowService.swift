//
//  AppleInsightTranslationFlowService.swift
//  DayCrumbs
//

import Foundation
import OSLog

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
    private static let logger = Logger(
        subsystem: "DayCrumbs",
        category: "AppleTranslationFlow"
    )

    private struct FlowFailure: Error {
        let reason: AppleInsightTranslationFailure.Reason
        let pair: TranslationLanguagePair?
    }

    private let translationCoordinator: any AnalyticsTranslationCoordinating
    private let nativeTranslationService: any NativeTranslationService
    private let unsupportedReadinessRetryDelays: [Duration]

    init() {
        let nativeTranslationService = AppleNativeTranslationService()
        self.nativeTranslationService = nativeTranslationService
        translationCoordinator = AnalyticsTranslationCoordinator(
            languageDetectionService: NaturalLanguageDetectionService(),
            nativeTranslationService: nativeTranslationService
        )
        unsupportedReadinessRetryDelays = [
            .milliseconds(250),
            .milliseconds(750),
        ]
    }

    init(
        translationCoordinator: any AnalyticsTranslationCoordinating,
        nativeTranslationService: any NativeTranslationService,
        unsupportedReadinessRetryDelays: [Duration] = [
            .milliseconds(250),
            .milliseconds(750),
        ]
    ) {
        self.translationCoordinator = translationCoordinator
        self.nativeTranslationService = nativeTranslationService
        self.unsupportedReadinessRetryDelays = unsupportedReadinessRetryDelays
    }

    func prepareInputContext(
        _ context: AnalyticsContext,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightInputPreparationResult {
        do {
            let translation = try await translationCoordinator.translateInputContext(
                context
            ) { batch in
                try await executeReadyBatch(
                    batch,
                    stage: .input,
                    using: executeBatch
                )
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
                try await executeReadyBatch(
                    batch,
                    stage: .output,
                    using: executeBatch
                )
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
        stage: AppleInsightTranslationFailure.Stage,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> [NativeTranslatedText] {
        let readiness = try await stabilizedReadiness(
            for: batch.pair,
            stage: stage
        )
        let executionMode: NativeTranslationBatchExecutionMode

        Self.logger.debug(
            "Translation readiness stage=\(stageLabel(stage), privacy: .public) pair=\(batch.pair.source.rawValue, privacy: .public)->\(batch.pair.target.rawValue, privacy: .public) availability=\(availabilityLabel(readiness.availability), privacy: .public)"
        )

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
        } catch {
            guard let executionError = error as? NativeTranslationBatchExecutionError,
                  shouldRecheckReadiness(after: executionError) else {
                throw flowFailure(from: error, pair: batch.pair)
            }

            let updatedReadiness = await nativeTranslationService.readiness(
                for: batch.pair
            )
            Self.logger.notice(
                "Translation readiness recheck stage=\(stageLabel(stage), privacy: .public) pair=\(batch.pair.source.rawValue, privacy: .public)->\(batch.pair.target.rawValue, privacy: .public) failure=\(errorLabel(executionError), privacy: .public) availability=\(availabilityLabel(updatedReadiness.availability), privacy: .public)"
            )

            guard updatedReadiness.availability == .installed else {
                throw flowFailure(from: executionError, pair: batch.pair)
            }

            try Task.checkCancellation()
            Self.logger.notice(
                "Retrying translation batch once with a fresh installed session stage=\(stageLabel(stage), privacy: .public) pair=\(batch.pair.source.rawValue, privacy: .public)->\(batch.pair.target.rawValue, privacy: .public)"
            )

            do {
                return try await executeBatch(batch, .translateInstalled)
            } catch {
                throw flowFailure(from: error, pair: batch.pair)
            }
        }
    }

    /// Translation's XPC service can briefly report an installed pair as
    /// unsupported while it restarts. Rechecking is bounded so a genuinely
    /// unsupported language still becomes a blocking result without looping.
    private func stabilizedReadiness(
        for pair: TranslationLanguagePair,
        stage: AppleInsightTranslationFailure.Stage
    ) async throws -> NativeTranslationReadiness {
        try Task.checkCancellation()
        var readiness = await nativeTranslationService.readiness(for: pair)

        for (index, delay) in unsupportedReadinessRetryDelays.enumerated() {
            guard readiness.availability == .unsupported else {
                break
            }

            try Task.checkCancellation()
            Self.logger.notice(
                "Translation readiness returned unsupported; scheduling bounded recheck stage=\(stageLabel(stage), privacy: .public) pair=\(pair.source.rawValue, privacy: .public)->\(pair.target.rawValue, privacy: .public) attempt=\(index + 1, privacy: .public)"
            )
            try await Task.sleep(for: delay)
            try Task.checkCancellation()
            readiness = await nativeTranslationService.readiness(for: pair)
        }

        try Task.checkCancellation()
        return readiness
    }

    private func shouldRecheckReadiness(
        after error: NativeTranslationBatchExecutionError
    ) -> Bool {
        switch error {
        case .transientSessionFailure, .preparationFailed:
            true
        case .downloadDenied, .cancelled, .translationFailed:
            false
        }
    }

    private func flowFailure(
        from error: any Error,
        pair: TranslationLanguagePair
    ) -> FlowFailure {
        if error is CancellationError {
            return FlowFailure(reason: .cancelled, pair: pair)
        }
        if let executionError = error as? NativeTranslationBatchExecutionError {
            return FlowFailure(reason: reason(for: executionError), pair: pair)
        }
        return FlowFailure(reason: .translationFailed, pair: pair)
    }

    private func reason(
        for error: NativeTranslationBatchExecutionError
    ) -> AppleInsightTranslationFailure.Reason {
        switch error {
        case .downloadDenied:
            .downloadDenied
        case .cancelled:
            .cancelled
        case .transientSessionFailure:
            .transientSessionFailure
        case .preparationFailed:
            .preparationFailed
        case .translationFailed:
            .translationFailed
        }
    }

    private func stageLabel(
        _ stage: AppleInsightTranslationFailure.Stage
    ) -> String {
        switch stage {
        case .input:
            "input"
        case .output:
            "output"
        }
    }

    private func availabilityLabel(
        _ availability: NativeTranslationAvailability
    ) -> String {
        switch availability {
        case .installed:
            "installed"
        case .supported:
            "supported"
        case .unsupported:
            "unsupported"
        }
    }

    private func errorLabel(
        _ error: NativeTranslationBatchExecutionError
    ) -> String {
        switch error {
        case .downloadDenied:
            "downloadDenied"
        case .cancelled:
            "cancelled"
        case .transientSessionFailure:
            "transientSessionFailure"
        case .preparationFailed:
            "preparationFailed"
        case .translationFailed:
            "translationFailed"
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

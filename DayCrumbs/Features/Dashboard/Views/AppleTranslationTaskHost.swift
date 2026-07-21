import Observation
import OSLog
import SwiftUI
import Translation

typealias TranslationOperationTimeoutSleeper = @MainActor @Sendable (
    Duration
) async throws -> Void

/// Bridges service batch requests into the TranslationSession owned by Dashboard's root.
@MainActor
@Observable
final class AppleTranslationTaskHost {
    private static let logger = Logger(
        subsystem: "DayCrumbs",
        category: "AppleTranslationHost"
    )

    private struct PendingOperation {
        let id: UUID
        let batch: NativeTranslationBatch
        let executionMode: NativeTranslationBatchExecutionMode
        let continuation: CheckedContinuation<
            [NativeTranslatedText],
            any Error
        >
    }

    private let nativeTranslationService: any NativeTranslationService
    private let operationTimeout: Duration
    private let operationTimeoutSleeper: TranslationOperationTimeoutSleeper
    @ObservationIgnored private var pendingOperation: PendingOperation?
    @ObservationIgnored private weak var activeSession: (
        any NativeTranslationSession
    )?
    @ObservationIgnored private var activeOperationID: UUID?
    @ObservationIgnored private var operationTimeoutTask: Task<Void, Never>?

    private(set) var configuration: TranslationSession.Configuration?

    init() {
        nativeTranslationService = AppleNativeTranslationService()
        operationTimeout = .seconds(30)
        operationTimeoutSleeper = { duration in
            try await Task.sleep(for: duration)
        }
    }

    init(
        nativeTranslationService: any NativeTranslationService,
        operationTimeout: Duration = .seconds(30),
        operationTimeoutSleeper: @escaping TranslationOperationTimeoutSleeper = {
            duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.nativeTranslationService = nativeTranslationService
        self.operationTimeout = operationTimeout
        self.operationTimeoutSleeper = operationTimeoutSleeper
    }

    var batchHandler: PreparedNativeTranslationBatchHandler {
        { [weak self] batch, executionMode in
            guard let self else {
                throw NativeTranslationBatchExecutionError.cancelled
            }
            return try await self.execute(
                batch,
                executionMode: executionMode
            )
        }
    }

    /// Schedules one pair; the stable root modifier supplies its matching session.
    func execute(
        _ batch: NativeTranslationBatch,
        executionMode: NativeTranslationBatchExecutionMode
    ) async throws -> [NativeTranslatedText] {
        try Task.checkCancellation()
        guard pendingOperation == nil else {
            throw NativeTranslationBatchExecutionError.translationFailed
        }

        let operationID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(
                        throwing: NativeTranslationBatchExecutionError.cancelled
                    )
                    return
                }

                pendingOperation = PendingOperation(
                    id: operationID,
                    batch: batch,
                    executionMode: executionMode,
                    continuation: continuation
                )
                startTimeout(for: operationID)
                activateConfiguration(for: batch.pair)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(operationID: operationID)
            }
        }
    }

    /// Called only inside `.translationTask`; the adapter is discarded on return.
    func performPending(using session: any NativeTranslationSession) async {
        guard let operation = pendingOperation else {
            return
        }
        guard session.sourceLanguage == operation.batch.pair.source,
              session.targetLanguage == operation.batch.pair.target else {
            // A cancelled configuration may deliver its old session after a new batch starts.
            return
        }

        activeOperationID = operation.id
        activeSession = session
        defer {
            if activeOperationID == operation.id {
                activeOperationID = nil
                activeSession = nil
            }
        }

        do {
            let sessionIsReady = await session.isReady
            Self.logger.debug(
                "Translation operation \(operation.id, privacy: .public) pair=\(operation.batch.pair.source.rawValue, privacy: .public)->\(operation.batch.pair.target.rawValue, privacy: .public) mode=\(self.modeLabel(operation.executionMode), privacy: .public) sessionReady=\(sessionIsReady, privacy: .public)"
            )

            if operation.executionMode == .prepareThenTranslate {
                if !sessionIsReady {
                    do {
                        _ = try await nativeTranslationService.prepareTranslation(
                            for: operation.batch.pair,
                            using: session
                        )
                    } catch {
                        log(
                            error,
                            stage: "preparation",
                            operation: operation,
                            sessionIsReady: sessionIsReady
                        )
                        throw preparationError(from: error)
                    }
                }
            }

            let translations: [NativeTranslatedText]
            do {
                translations = try await nativeTranslationService.translate(
                    operation.batch,
                    using: session
                )
            } catch {
                log(
                    error,
                    stage: "translation",
                    operation: operation,
                    sessionIsReady: sessionIsReady
                )
                throw translationError(from: error)
            }

            complete(operationID: operation.id, with: .success(translations))
        } catch let error as NativeTranslationBatchExecutionError {
            complete(operationID: operation.id, with: .failure(error))
        } catch {
            complete(
                operationID: operation.id,
                with: .failure(.translationFailed)
            )
        }
    }

    func cancelPendingBatch() {
        guard let operation = pendingOperation else {
            configuration = nil
            return
        }
        cancel(operationID: operation.id)
    }

    private func activateConfiguration(for pair: TranslationLanguagePair) {
        var nextConfiguration = nativeTranslationService.configuration(for: pair)
        if configuration == nextConfiguration {
            // Invalidating reruns `.translationTask` for new content with the same pair.
            nextConfiguration.invalidate()
        }
        configuration = nextConfiguration
    }

    private func cancel(operationID: UUID) {
        guard let operation = pendingOperation,
              operation.id == operationID else {
            return
        }

        operationTimeoutTask?.cancel()
        operationTimeoutTask = nil
        if activeOperationID == operation.id {
            activeSession?.cancel()
            activeOperationID = nil
            activeSession = nil
        }
        pendingOperation = nil
        configuration = nil
        operation.continuation.resume(
            throwing: NativeTranslationBatchExecutionError.cancelled
        )
    }

    private func complete(
        operationID: UUID,
        with result: Result<
            [NativeTranslatedText],
            NativeTranslationBatchExecutionError
        >
    ) {
        guard let operation = pendingOperation,
              operation.id == operationID else {
            return
        }

        operationTimeoutTask?.cancel()
        operationTimeoutTask = nil
        pendingOperation = nil
        operation.continuation.resume(with: result)
    }

    /// Prevents a crashed or disconnected translation daemon from leaving the
    /// Dashboard generation continuation suspended forever.
    private func startTimeout(for operationID: UUID) {
        operationTimeoutTask?.cancel()
        operationTimeoutTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await operationTimeoutSleeper(operationTimeout)
            } catch {
                return
            }

            timeOut(operationID: operationID)
        }
    }

    private func timeOut(operationID: UUID) {
        guard let operation = pendingOperation,
              operation.id == operationID else {
            return
        }

        Self.logger.error(
            "Translation operation timed out operation=\(operation.id, privacy: .public) pair=\(operation.batch.pair.source.rawValue, privacy: .public)->\(operation.batch.pair.target.rawValue, privacy: .public) mode=\(self.modeLabel(operation.executionMode), privacy: .public)"
        )

        operationTimeoutTask = nil
        if activeOperationID == operation.id {
            activeSession?.cancel()
            activeOperationID = nil
            activeSession = nil
        }
        pendingOperation = nil
        configuration = nil
        operation.continuation.resume(
            throwing: NativeTranslationBatchExecutionError.transientSessionFailure
        )
    }

    private func preparationError(
        from error: any Error
    ) -> NativeTranslationBatchExecutionError {
        if error is CancellationError || TranslationError.alreadyCancelled ~= error {
            return .cancelled
        }
        if TranslationError.notInstalled ~= error {
            return .downloadDenied
        }
        if isTransientSessionError(error) {
            return .transientSessionFailure
        }
        return .preparationFailed
    }

    private func translationError(
        from error: any Error
    ) -> NativeTranslationBatchExecutionError {
        if error is CancellationError || TranslationError.alreadyCancelled ~= error {
            return .cancelled
        }
        if TranslationError.notInstalled ~= error {
            return .downloadDenied
        }
        if isTransientSessionError(error) {
            return .transientSessionFailure
        }
        return .translationFailed
    }

    private func isTransientSessionError(_ error: any Error) -> Bool {
        if TranslationError.internalError ~= error {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           [
               NSXPCConnectionInterrupted,
               NSXPCConnectionInvalid,
               NSXPCConnectionReplyInvalid,
           ].contains(nsError.code) {
            return true
        }

        guard let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error else {
            return false
        }
        return isTransientSessionError(underlyingError)
    }

    private func log(
        _ error: any Error,
        stage: String,
        operation: PendingOperation,
        sessionIsReady: Bool
    ) {
        let nsError = error as NSError
        Self.logger.error(
            "Translation \(stage, privacy: .public) failed operation=\(operation.id, privacy: .public) pair=\(operation.batch.pair.source.rawValue, privacy: .public)->\(operation.batch.pair.target.rawValue, privacy: .public) mode=\(self.modeLabel(operation.executionMode), privacy: .public) sessionReady=\(sessionIsReady, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    private func modeLabel(
        _ mode: NativeTranslationBatchExecutionMode
    ) -> String {
        switch mode {
        case .translateInstalled:
            "translateInstalled"
        case .prepareThenTranslate:
            "prepareThenTranslate"
        }
    }
}

private struct AppleTranslationTaskHostModifier: ViewModifier {
    let host: AppleTranslationTaskHost

    func body(content: Content) -> some View {
        content.translationTask(host.configuration) { session in
            // The framework-owned session never leaves this view-bound operation.
            let adapter = AppleTranslationSessionAdapter(viewBoundSession: session)
            await host.performPending(using: adapter)
        }
    }
}

extension View {
    func appleTranslationTaskHost(
        _ host: AppleTranslationTaskHost
    ) -> some View {
        modifier(AppleTranslationTaskHostModifier(host: host))
    }
}

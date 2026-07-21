import Foundation
import Testing
import Translation

@testable import DayCrumbs

@Suite("Apple insight translation flow")
@MainActor
struct AppleInsightTranslationFlowServiceTests {
    private let indonesianToEnglish = TranslationLanguagePair(
        source: .indonesian,
        target: .english
    )

    @Test("Installed input translation becomes ready for Apple generation")
    func installedInputIsReady() async throws {
        let executor = BatchExecutorFake(
            behaviors: [
                .translate(["Catatan dalam bahasa Indonesia": "An Indonesian note"]),
            ]
        )
        let flow = makeFlow(status: .installed)

        let result = await flow.prepareInputContext(
            makeContext(note: "Catatan dalam bahasa Indonesia"),
            using: executor.handler
        )

        let translation = try #require(readyTranslation(from: result))
        #expect(result.allowsGeneration)
        #expect(translation.englishContext.events[0].afterActivityNote == "An Indonesian note")
        #expect(translation.responseLanguage == .indonesian)
        #expect(executor.modes == [.translateInstalled])
    }

    @Test("Supported input requests preparation and resumes the pending batch")
    func supportedInputPreparesThenResumes() async throws {
        let executor = BatchExecutorFake(
            behaviors: [
                .translate(["Catatan dalam bahasa Indonesia": "An Indonesian note"]),
            ]
        )
        let flow = makeFlow(status: .supported)

        let result = await flow.prepareInputContext(
            makeContext(note: "Catatan dalam bahasa Indonesia"),
            using: executor.handler
        )

        let translation = try #require(readyTranslation(from: result))
        #expect(result.allowsGeneration)
        #expect(translation.englishContext.events[0].afterActivityNote == "An Indonesian note")
        #expect(executor.modes == [.prepareThenTranslate])
        #expect(executor.batches.map(\.pair) == [indonesianToEnglish])
    }

    @Test("A transient unsupported readiness recovers before blocking generation")
    func transientUnsupportedReadinessRecovers() async throws {
        let executor = BatchExecutorFake(
            behaviors: [
                .translate(["Catatan dalam bahasa Indonesia": "An Indonesian note"]),
            ]
        )
        let flow = makeFlow(
            statuses: [.unsupported, .installed],
            readinessRetryDelays: [.zero]
        )

        let result = await flow.prepareInputContext(
            makeContext(note: "Catatan dalam bahasa Indonesia"),
            using: executor.handler
        )

        let translation = try #require(readyTranslation(from: result))
        #expect(
            translation.englishContext.events[0].afterActivityNote
                == "An Indonesian note"
        )
        #expect(executor.modes == [.translateInstalled])
        #expect(executor.batches.count == 1)
    }

    @Test("Cancelling a readiness recheck stops before translation execution")
    func readinessRecheckHonorsCancellation() async throws {
        let executor = BatchExecutorFake(behaviors: [])
        let flow = makeFlow(
            status: .unsupported,
            readinessRetryDelays: [.seconds(5)]
        )

        let preparation = Task { @MainActor in
            await flow.prepareInputContext(
                makeContext(note: "Catatan dalam bahasa Indonesia"),
                using: executor.handler
            )
        }
        await Task.yield()
        preparation.cancel()

        let result = await preparation.value
        let failure = try #require(blockingFailure(from: result))
        #expect(failure.reason == .cancelled)
        #expect(executor.batches.isEmpty)
    }

    @Test("Preparation and transient failures retry once after assets become installed")
    func transientPreparationFailuresRetryAfterInstallation() async throws {
        let retryableErrors: [NativeTranslationBatchExecutionError] = [
            .preparationFailed,
            .transientSessionFailure,
        ]

        for retryableError in retryableErrors {
            let executor = BatchExecutorFake(
                behaviors: [
                    .fail(retryableError),
                    .translate([
                        "Catatan dalam bahasa Indonesia": "An Indonesian note",
                    ]),
                ]
            )
            let flow = makeFlow(statuses: [.supported, .installed])

            let result = await flow.prepareInputContext(
                makeContext(note: "Catatan dalam bahasa Indonesia"),
                using: executor.handler
            )

            let translation = try #require(readyTranslation(from: result))
            #expect(
                translation.englishContext.events[0].afterActivityNote
                    == "An Indonesian note"
            )
            #expect(executor.modes == [
                .prepareThenTranslate,
                .translateInstalled,
            ])
            #expect(executor.batches.count == 2)
        }
    }

    @Test("A failed recovery is not retried more than once")
    func transientRecoveryIsLimitedToOneRetry() async throws {
        let executor = BatchExecutorFake(
            behaviors: [
                .fail(.preparationFailed),
                .fail(.transientSessionFailure),
            ]
        )
        let flow = makeFlow(statuses: [.supported, .installed])

        let result = await flow.prepareInputContext(
            makeContext(note: "Catatan dalam bahasa Indonesia"),
            using: executor.handler
        )

        let failure = try #require(blockingFailure(from: result))
        #expect(failure.reason == .transientSessionFailure)
        #expect(executor.modes == [
            .prepareThenTranslate,
            .translateInstalled,
        ])
        #expect(executor.batches.count == 2)
    }

    @Test("Unsupported input blocks before the view-bound executor")
    func unsupportedInputIsBlocked() async throws {
        let executor = BatchExecutorFake(behaviors: [])
        let flow = makeFlow(status: .unsupported)

        let result = await flow.prepareInputContext(
            makeContext(note: "Catatan dalam bahasa Indonesia"),
            using: executor.handler
        )

        let failure = try #require(blockingFailure(from: result))
        #expect(!result.allowsGeneration)
        #expect(failure == AppleInsightTranslationFailure(
            stage: .input,
            reason: .unsupportedLanguagePair,
            pair: indonesianToEnglish
        ))
        #expect(executor.batches.isEmpty)
    }

    @Test("Input execution failures remain blocking typed states")
    func inputExecutionFailuresAreBlocked() async throws {
        let cases: [(
            NativeTranslationBatchExecutionError,
            AppleInsightTranslationFailure.Reason
        )] = [
            (.downloadDenied, .downloadDenied),
            (.cancelled, .cancelled),
            (.transientSessionFailure, .transientSessionFailure),
            (.preparationFailed, .preparationFailed),
            (.translationFailed, .translationFailed),
        ]

        for (executionError, expectedReason) in cases {
            let executor = BatchExecutorFake(behaviors: [.fail(executionError)])
            let result = await makeFlow(status: .supported).prepareInputContext(
                makeContext(note: "Catatan dalam bahasa Indonesia"),
                using: executor.handler
            )

            let failure = try #require(blockingFailure(from: result))
            #expect(!result.allowsGeneration)
            #expect(failure.stage == .input)
            #expect(failure.reason == expectedReason)
            #expect(failure.pair == indonesianToEnglish)
            #expect(!failure.userMessage.isEmpty)
            #expect(executor.batches.count == 1)
        }
    }

    @Test("Task cancellation is normalized as a blocking input cancellation")
    func taskCancellationIsBlocked() async throws {
        let executor = BatchExecutorFake(behaviors: [.cancelTask])

        let result = await makeFlow(status: .installed).prepareInputContext(
            makeContext(note: "Catatan dalam bahasa Indonesia"),
            using: executor.handler
        )

        let failure = try #require(blockingFailure(from: result))
        #expect(failure.stage == .input)
        #expect(failure.reason == .cancelled)
        #expect(failure.pair == indonesianToEnglish)
    }

    @Test("Undetermined input language blocks before translation")
    func undeterminedLanguageIsBlocked() async throws {
        let executor = BatchExecutorFake(behaviors: [])
        let flow = makeFlow(
            status: .installed,
            detector: UndeterminedLanguageDetectionService()
        )

        let result = await flow.prepareInputContext(
            makeContext(note: "Very unclear text"),
            using: executor.handler
        )

        let failure = try #require(blockingFailure(from: result))
        #expect(!result.allowsGeneration)
        #expect(failure.stage == .input)
        #expect(failure.reason == .undeterminedLanguage)
        #expect(failure.pair == nil)
        #expect(executor.batches.isEmpty)
    }

    @Test("Output failure preserves English fields for translation-only retry")
    func outputFailurePreservesEnglishAndRetries() async throws {
        let englishTexts = [
            IdentifiedTranslationText(id: "summary", text: "A possible pattern"),
            IdentifiedTranslationText(id: "reflection", text: "What changed today?"),
        ]
        let translatedTexts = [
            "A possible pattern": "Pola yang mungkin",
            "What changed today?": "Apa yang berubah hari ini?",
        ]
        let executor = BatchExecutorFake(
            behaviors: [
                .fail(.translationFailed),
                .translate(translatedTexts),
            ]
        )
        let flow = makeFlow(status: .installed)

        let firstResult = await flow.localizeGeneratedTexts(
            englishTexts,
            to: .indonesian,
            using: executor.handler
        )
        let fallback = try #require(englishFallback(from: firstResult))

        #expect(fallback.englishTexts == englishTexts)
        #expect(fallback.targetLanguage == .indonesian)
        #expect(fallback.displayLabel == "English fallback")
        #expect(fallback.canRetryTranslation)
        #expect(fallback.failure.stage == .output)
        #expect(fallback.failure.reason == .translationFailed)

        let retryResult = await flow.retryOutputTranslation(
            fallback,
            using: executor.handler
        )
        let localizedOutput = try #require(localizedTexts(from: retryResult))

        #expect(localizedOutput == [
            IdentifiedTranslationText(id: "summary", text: "Pola yang mungkin"),
            IdentifiedTranslationText(id: "reflection", text: "Apa yang berubah hari ini?"),
        ])
        #expect(executor.batches.count == 2)
        #expect(executor.batches[0].requests.map(\.text) == englishTexts.map(\.text))
        #expect(executor.batches[1].requests.map(\.text) == englishTexts.map(\.text))
    }

    @Test("English output bypasses translation readiness and execution")
    func englishOutputBypassesTranslation() async throws {
        let englishTexts = [
            IdentifiedTranslationText(id: "summary", text: "A possible pattern"),
        ]
        let executor = BatchExecutorFake(behaviors: [])

        let result = await makeFlow(status: .unsupported).localizeGeneratedTexts(
            englishTexts,
            to: .english,
            using: executor.handler
        )

        #expect(try #require(localizedTexts(from: result)) == englishTexts)
        #expect(executor.batches.isEmpty)
    }

    private func makeFlow(
        status: LanguageAvailability.Status,
        detector: any LanguageDetectionService = IndonesianLanguageDetectionService(),
        readinessRetryDelays: [Duration] = []
    ) -> AppleInsightTranslationFlowService {
        let nativeTranslationService = AppleNativeTranslationService { _ in status }
        let coordinator = AnalyticsTranslationCoordinator(
            languageDetectionService: detector,
            nativeTranslationService: nativeTranslationService
        )
        return AppleInsightTranslationFlowService(
            translationCoordinator: coordinator,
            nativeTranslationService: nativeTranslationService,
            unsupportedReadinessRetryDelays: readinessRetryDelays
        )
    }

    private func makeFlow(
        statuses: [LanguageAvailability.Status],
        detector: any LanguageDetectionService = IndonesianLanguageDetectionService(),
        readinessRetryDelays: [Duration] = []
    ) -> AppleInsightTranslationFlowService {
        let availability = LanguageAvailabilitySequence(statuses: statuses)
        let nativeTranslationService = AppleNativeTranslationService { _ in
            availability.next()
        }
        let coordinator = AnalyticsTranslationCoordinator(
            languageDetectionService: detector,
            nativeTranslationService: nativeTranslationService
        )
        return AppleInsightTranslationFlowService(
            translationCoordinator: coordinator,
            nativeTranslationService: nativeTranslationService,
            unsupportedReadinessRetryDelays: readinessRetryDelays
        )
    }

    private func makeContext(note: String) -> AnalyticsContext {
        AnalyticsContext(
            child: AnalyticsContext.Child(
                name: "Ari",
                age: 3,
                gender: ChildGender.boy.rawValue
            ),
            events: [
                AnalyticsContext.Event(
                    recordedAt: Date(timeIntervalSince1970: 100),
                    session: Sessions.morning.rawValue,
                    mood: Moods.happy.rawValue,
                    activity: Activity.BuiltInActivity.play.rawValue,
                    place: Place.BuiltInPlace.house.rawValue,
                    afterActivityNote: note
                ),
            ],
            reflections: []
        )
    }

    private func readyTranslation(
        from result: AppleInsightInputPreparationResult
    ) -> AnalyticsInputTranslation? {
        guard case let .ready(translation) = result else {
            return nil
        }
        return translation
    }

    private func blockingFailure(
        from result: AppleInsightInputPreparationResult
    ) -> AppleInsightTranslationFailure? {
        guard case let .blocked(failure) = result else {
            return nil
        }
        return failure
    }

    private func englishFallback(
        from result: AppleInsightOutputTranslationResult
    ) -> AppleInsightEnglishFallback? {
        guard case let .englishFallback(fallback) = result else {
            return nil
        }
        return fallback
    }

    private func localizedTexts(
        from result: AppleInsightOutputTranslationResult
    ) -> [IdentifiedTranslationText]? {
        guard case let .localized(texts) = result else {
            return nil
        }
        return texts
    }
}

@MainActor
private final class LanguageAvailabilitySequence {
    private let statuses: [LanguageAvailability.Status]
    private var index = 0

    init(statuses: [LanguageAvailability.Status]) {
        precondition(!statuses.isEmpty)
        self.statuses = statuses
    }

    func next() -> LanguageAvailability.Status {
        let status = statuses[min(index, statuses.count - 1)]
        if index < statuses.count - 1 {
            index += 1
        }
        return status
    }
}

nonisolated private struct IndonesianLanguageDetectionService: LanguageDetectionService {
    func detectLanguages(
        in requests: [LanguageDetectionRequest]
    ) throws -> LanguageDetectionResult {
        LanguageDetectionResult(
            responseLanguage: .indonesian,
            segments: requests.map {
                LanguageDetectionResult.Segment(
                    requestID: $0.id,
                    language: .indonesian
                )
            }
        )
    }
}

nonisolated private struct UndeterminedLanguageDetectionService: LanguageDetectionService {
    func detectLanguages(
        in requests: [LanguageDetectionRequest]
    ) throws -> LanguageDetectionResult {
        throw LanguageDetectionError.undeterminedLanguage
    }
}

@MainActor
private final class BatchExecutorFake {
    enum Behavior {
        case translate([String: String])
        case fail(NativeTranslationBatchExecutionError)
        case cancelTask
    }

    private(set) var batches: [NativeTranslationBatch] = []
    private(set) var modes: [NativeTranslationBatchExecutionMode] = []
    private var behaviors: [Behavior]

    init(behaviors: [Behavior]) {
        self.behaviors = behaviors
    }

    var handler: PreparedNativeTranslationBatchHandler {
        { [self] batch, mode in
            try execute(batch, mode: mode)
        }
    }

    private func execute(
        _ batch: NativeTranslationBatch,
        mode: NativeTranslationBatchExecutionMode
    ) throws -> [NativeTranslatedText] {
        batches.append(batch)
        modes.append(mode)

        guard !behaviors.isEmpty else {
            throw NativeTranslationBatchExecutionError.translationFailed
        }
        let behavior = behaviors.removeFirst()

        switch behavior {
        case let .translate(translationsBySourceText):
            return try batch.requests.map { request in
                guard let translatedText = translationsBySourceText[request.text] else {
                    throw NativeTranslationBatchExecutionError.translationFailed
                }
                return NativeTranslatedText(id: request.id, text: translatedText)
            }
        case let .fail(error):
            throw error
        case .cancelTask:
            throw CancellationError()
        }
    }
}

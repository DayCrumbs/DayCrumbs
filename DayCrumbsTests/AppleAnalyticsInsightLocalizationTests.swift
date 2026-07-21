import Foundation
import Testing
import Translation

@testable import DayCrumbs

@Suite("Apple analytics insight localization")
@MainActor
struct AppleAnalyticsInsightLocalizationTests {
    @Test("Mapper preserves insight shape and stable field ordering")
    func mapperRoundTrip() throws {
        let mapper = AnalyticsInsightTranslationMapper()
        let englishInsight = makeInsight()
        let englishTexts = mapper.identifiedTexts(from: englishInsight)

        #expect(englishTexts.map(\.id) == [
            "analytics.summary",
            "analytics.commonTriggers.0.title",
            "analytics.commonTriggers.0.explanation",
            "analytics.observedPatterns.0.title",
            "analytics.observedPatterns.0.evidence",
            "analytics.observedPatterns.0.linkedTrigger",
            "analytics.observedPatterns.0.contextTags.0",
            "analytics.observedPatterns.0.contextTags.1",
            "analytics.parentReflectionPrompt",
            "analytics.ethicalNote",
        ])

        let localizedTexts = englishTexts.map {
            IdentifiedTranslationText(id: $0.id, text: "ID: \($0.text)")
        }
        let localizedInsight = try mapper.reconstructedInsight(
            from: localizedTexts,
            matching: englishInsight
        )

        #expect(localizedInsight.summary == "ID: Limited English summary.")
        #expect(localizedInsight.commonTriggers[0].title == "ID: Morning transition")
        #expect(localizedInsight.observedPatterns[0].linkedTrigger == "ID: Morning transition")
        #expect(localizedInsight.observedPatterns[0].contextTags == [
            "ID: morning", "ID: house",
        ])
    }

    @Test("Mapper rejects missing localized fields")
    func mapperRejectsMissingIdentifier() throws {
        let mapper = AnalyticsInsightTranslationMapper()
        let englishInsight = makeInsight()
        var localizedTexts = mapper.identifiedTexts(from: englishInsight)
        localizedTexts.removeLast()

        #expect(throws: AnalyticsInsightTranslationMappingError.missingIdentifier(
            "analytics.ethicalNote"
        )) {
            try mapper.reconstructedInsight(
                from: localizedTexts,
                matching: englishInsight
            )
        }
    }

    @Test("Recommendation mapper translates catalog copy but preserves sources")
    func recommendationMapperRoundTrip() throws {
        let insightMapper = AnalyticsInsightTranslationMapper()
        let recommendationMapper = TriggerDetailTranslationMapper()
        let englishInsight = makeInsight()
        let englishDetails = makeTriggerDetails(for: englishInsight)
        let recommendationTexts = recommendationMapper.identifiedTexts(
            from: englishDetails
        )

        #expect(recommendationTexts.map(\.id) == [
            "recommendations.labels.evidence",
            "recommendations.labels.recommendedActivities",
            "recommendations.labels.whatMayHelp",
            "recommendations.labels.curatedSources",
            "recommendations.0.title",
            "recommendations.0.activities.0",
            "recommendations.0.activities.1",
            "recommendations.0.whatMayHelp.0",
            "recommendations.0.whatMayHelp.1",
        ])

        let localizedInsight = try insightMapper.reconstructedInsight(
            from: insightMapper.identifiedTexts(from: englishInsight).map {
                IdentifiedTranslationText(id: $0.id, text: "ID: \($0.text)")
            },
            matching: englishInsight
        )
        let localizedDetails =
            try recommendationMapper.reconstructedTriggerDetails(
                from: recommendationTexts.map {
                    IdentifiedTranslationText(
                        id: $0.id,
                        text: "ID: \($0.text)"
                    )
                },
                matching: englishDetails,
                englishInsight: englishInsight,
                localizedInsight: localizedInsight
            )

        #expect(localizedDetails[0].title == "ID: Morning transition")
        #expect(
            localizedDetails[0].recommendationTitle
                == "ID: A clear, predictable transition"
        )
        #expect(
            localizedDetails[0].sectionLabels.evidence
                == "ID: Evidence"
        )
        #expect(
            localizedDetails[0].sectionLabels.whatMayHelp
                == "ID: What may help"
        )
        #expect(localizedDetails[0].sourceLabels == [.cdc])
    }

    @Test("Successful output translation reconstructs localized insight")
    func localizesGeneratedInsight() async {
        let flow = TranslationFlowFake(localizeBehavior: .localized(prefix: "ID: "))
        let service = AppleAnalyticsInsightLocalizationService(
            translationFlow: flow
        )
        let englishInsight = makeInsight()

        let result = await service.localize(
            englishInsight,
            triggerDetails: makeTriggerDetails(for: englishInsight),
            to: .indonesian,
            using: unusedBatchHandler
        )

        #expect(result.responseLanguage == .indonesian)
        #expect(!result.isEnglishFallback)
        #expect(result.insight.summary == "ID: Limited English summary.")
        #expect(
            result.triggerDetails[0].sectionLabels.evidence
                == "ID: Evidence"
        )
        #expect(
            result.triggerDetails[0].recommendationTitle
                == "ID: A clear, predictable transition"
        )
        #expect(
            result.triggerDetails[0].sectionLabels.recommendedActivities
                == "ID: Recommended Activities"
        )
        #expect(result.triggerDetails[0].sourceLabels == [.cdc])
        #expect(flow.localizeCallCount == 1)
        #expect(flow.retryCallCount == 0)
    }

    @Test("Apple pipeline prepares input before generation and localizes output")
    func pipelineUsesExistingTranslationFlow() async throws {
        let flow = TranslationFlowFake(
            localizeBehavior: .localized(prefix: "ID: "),
            preparedResponseLanguage: .indonesian
        )
        let generator = AnalyticsInsightGeneratorFake()
        let pipeline = AppleLocalizedInsightGenerationService(
            generationService: generator,
            translationFlow: flow
        )

        let result = try await pipeline.generateInsight(
            from: [],
            for: .week,
            using: unusedBatchHandler
        )

        #expect(flow.prepareInputCallCount == 1)
        #expect(generator.generationCallCount == 1)
        #expect(generator.ranges == [.week])
        #expect(flow.localizeCallCount == 1)
        #expect(result.responseLanguage == .indonesian)
        #expect(result.insight.summary == "ID: Limited English summary.")
        #expect(
            result.triggerDetails[0].recommendedActivities[0]
                .hasPrefix("ID: ")
        )
    }

    @Test("Translation failure publishes the preserved English insight")
    func preservesEnglishFallback() async {
        let flow = TranslationFlowFake(localizeBehavior: .fallback(.translationFailed))
        let service = AppleAnalyticsInsightLocalizationService(
            translationFlow: flow
        )
        let englishInsight = makeInsight()

        let result = await service.localize(
            englishInsight,
            triggerDetails: makeTriggerDetails(for: englishInsight),
            to: .indonesian,
            using: unusedBatchHandler
        )

        #expect(result.insight == englishInsight)
        #expect(
            result.triggerDetails
                == makeTriggerDetails(for: englishInsight)
        )
        #expect(
            result.englishFallback?.englishTriggerDetails
                == makeTriggerDetails(for: englishInsight)
        )
        #expect(result.englishFallback?.displayLabel == "English fallback")
        #expect(result.englishFallback?.failure.reason == .translationFailed)
    }

    @Test("Unsafe reconstruction becomes an English fallback")
    func invalidLocalizedFieldsFallBackToEnglish() async {
        let flow = TranslationFlowFake(localizeBehavior: .missingLastIdentifier)
        let service = AppleAnalyticsInsightLocalizationService(
            translationFlow: flow
        )
        let englishInsight = makeInsight()

        let result = await service.localize(
            englishInsight,
            triggerDetails: makeTriggerDetails(for: englishInsight),
            to: .indonesian,
            using: unusedBatchHandler
        )

        #expect(result.insight == englishInsight)
        #expect(result.englishFallback?.failure.reason == .invalidTranslationData)
    }

    @Test("Translation retry reuses English fields without localization restart")
    func retryUsesOnlyPreservedOutput() async throws {
        let flow = TranslationFlowFake(
            localizeBehavior: .fallback(.translationFailed),
            retryBehavior: .localized(prefix: "Retry: ")
        )
        let service = AppleAnalyticsInsightLocalizationService(
            translationFlow: flow
        )
        let englishInsight = makeInsight()

        let initialResult = await service.localize(
            englishInsight,
            triggerDetails: makeTriggerDetails(for: englishInsight),
            to: .indonesian,
            using: unusedBatchHandler
        )
        let fallback = try #require(initialResult.englishFallback)
        let retriedResult = await service.retryOutputTranslation(
            fallback,
            using: unusedBatchHandler
        )

        #expect(!retriedResult.isEnglishFallback)
        #expect(retriedResult.insight.summary == "Retry: Limited English summary.")
        #expect(
            retriedResult.triggerDetails[0].whatMayHelp[0]
                .hasPrefix("Retry: ")
        )
        #expect(flow.localizeCallCount == 1)
        #expect(flow.retryCallCount == 1)
    }

    @Test("Stable host prepares and translates inside the supplied session")
    func hostExecutesPreparedBatch() async throws {
        let nativeService = NativeTranslationServiceFake()
        let host = AppleTranslationTaskHost(
            nativeTranslationService: nativeService
        )
        let batch = makeBatch()
        let staleSession = NativeTranslationSessionHostFake(
            pair: TranslationLanguagePair(
                source: .indonesian,
                target: .english
            )
        )
        let session = NativeTranslationSessionHostFake(pair: batch.pair)

        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .prepareThenTranslate)
        }
        await Task.yield()

        #expect(host.configuration != nil)
        await host.performPending(using: staleSession)
        #expect(nativeService.prepareCallCount == 0)
        #expect(nativeService.translateCallCount == 0)
        await host.performPending(using: session)
        let translations = try await execution.value

        #expect(nativeService.prepareCallCount == 1)
        #expect(nativeService.translateCallCount == 1)
        #expect(session.prepareCallCount == 1)
        #expect(translations == [
            NativeTranslatedText(id: "summary", text: "ID: Hello"),
        ])
    }

    @Test("Ready session skips preparation and translates immediately")
    func readyHostSessionSkipsPreparation() async throws {
        let nativeService = NativeTranslationServiceFake()
        let host = AppleTranslationTaskHost(
            nativeTranslationService: nativeService
        )
        let batch = makeBatch()
        let session = NativeTranslationSessionHostFake(
            pair: batch.pair,
            isReady: true
        )

        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .prepareThenTranslate)
        }
        await Task.yield()

        await host.performPending(using: session)
        let translations = try await execution.value

        #expect(nativeService.prepareCallCount == 0)
        #expect(session.prepareCallCount == 0)
        #expect(nativeService.translateCallCount == 1)
        #expect(translations == [
            NativeTranslatedText(id: "summary", text: "ID: Hello"),
        ])
    }

    @Test("Internal Translation errors are classified as transient")
    func internalTranslationErrorIsTransient() async {
        let nativeService = NativeTranslationServiceFake(
            preparationError: TranslationError.internalError
        )
        let host = AppleTranslationTaskHost(
            nativeTranslationService: nativeService
        )
        let batch = makeBatch()
        let session = NativeTranslationSessionHostFake(pair: batch.pair)

        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .prepareThenTranslate)
        }
        await Task.yield()

        await host.performPending(using: session)

        await #expect(
            throws: NativeTranslationBatchExecutionError.transientSessionFailure
        ) {
            try await execution.value
        }
        #expect(nativeService.translateCallCount == 0)
    }

    @Test("XPC invalidation errors are classified as transient")
    func xpcInvalidationIsTransient() async {
        let nativeService = NativeTranslationServiceFake(
            preparationError: NSError(
                domain: NSCocoaErrorDomain,
                code: NSXPCConnectionInvalid
            )
        )
        let host = AppleTranslationTaskHost(
            nativeTranslationService: nativeService
        )
        let batch = makeBatch()
        let session = NativeTranslationSessionHostFake(pair: batch.pair)

        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .prepareThenTranslate)
        }
        await Task.yield()

        await host.performPending(using: session)

        await #expect(
            throws: NativeTranslationBatchExecutionError.transientSessionFailure
        ) {
            try await execution.value
        }
        #expect(nativeService.translateCallCount == 0)
    }

    @Test("Cancelling a pending host operation resumes it as cancellation")
    func hostCancellation() async {
        let host = AppleTranslationTaskHost(
            nativeTranslationService: NativeTranslationServiceFake()
        )
        let batch = makeBatch()
        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .translateInstalled)
        }
        await Task.yield()

        host.cancelPendingBatch()

        await #expect(throws: NativeTranslationBatchExecutionError.cancelled) {
            try await execution.value
        }
        #expect(host.configuration == nil)
    }

    @Test("Host times out when Translation never supplies a session")
    func hostTimesOutBeforeSessionStarts() async {
        let timeoutGate = TranslationOperationTimeoutGate()
        let host = AppleTranslationTaskHost(
            nativeTranslationService: NativeTranslationServiceFake(),
            operationTimeoutSleeper: { duration in
                try await timeoutGate.sleep(for: duration)
            }
        )
        let batch = makeBatch()

        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .translateInstalled)
        }
        await timeoutGate.waitUntilArmed()
        timeoutGate.fire()

        await #expect(
            throws: NativeTranslationBatchExecutionError.transientSessionFailure
        ) {
            try await execution.value
        }
        #expect(host.configuration == nil)
    }

    @Test("Host cancels an active Translation session when it times out")
    func hostTimesOutDuringTranslation() async {
        let timeoutGate = TranslationOperationTimeoutGate()
        let host = AppleTranslationTaskHost(
            nativeTranslationService: NativeTranslationServiceFake(),
            operationTimeoutSleeper: { duration in
                try await timeoutGate.sleep(for: duration)
            }
        )
        let batch = makeBatch()
        let session = NativeTranslationSessionHostFake(
            pair: batch.pair,
            suspendsTranslationUntilCancelled: true
        )

        let execution = Task { @MainActor in
            try await host.execute(batch, executionMode: .translateInstalled)
        }
        await timeoutGate.waitUntilArmed()

        let sessionExecution = Task { @MainActor in
            await host.performPending(using: session)
        }
        await session.waitUntilTranslationStarts()
        timeoutGate.fire()

        await #expect(
            throws: NativeTranslationBatchExecutionError.transientSessionFailure
        ) {
            try await execution.value
        }
        await sessionExecution.value

        #expect(session.cancelCallCount == 1)
        #expect(host.configuration == nil)
    }
}

@MainActor
private final class TranslationFlowFake: AppleInsightTranslationFlow {
    enum Behavior {
        case localized(prefix: String)
        case fallback(AppleInsightTranslationFailure.Reason)
        case missingLastIdentifier
    }

    private let localizeBehavior: Behavior
    private let retryBehavior: Behavior
    private let preparedResponseLanguage: LanguageIdentifier
    private(set) var prepareInputCallCount = 0
    private(set) var localizeCallCount = 0
    private(set) var retryCallCount = 0

    init(
        localizeBehavior: Behavior,
        retryBehavior: Behavior? = nil,
        preparedResponseLanguage: LanguageIdentifier = .english
    ) {
        self.localizeBehavior = localizeBehavior
        self.retryBehavior = retryBehavior ?? localizeBehavior
        self.preparedResponseLanguage = preparedResponseLanguage
    }

    func prepareInputContext(
        _ context: AnalyticsContext,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightInputPreparationResult {
        prepareInputCallCount += 1
        return .ready(
            AnalyticsInputTranslation(
                englishContext: context,
                responseLanguage: preparedResponseLanguage,
                didTranslateParentText: false
            )
        )
    }

    func localizeGeneratedTexts(
        _ englishTexts: [IdentifiedTranslationText],
        to targetLanguage: LanguageIdentifier,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightOutputTranslationResult {
        localizeCallCount += 1
        return makeResult(
            behavior: localizeBehavior,
            englishTexts: englishTexts,
            targetLanguage: targetLanguage
        )
    }

    func retryOutputTranslation(
        _ fallback: AppleInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleInsightOutputTranslationResult {
        retryCallCount += 1
        return makeResult(
            behavior: retryBehavior,
            englishTexts: fallback.englishTexts,
            targetLanguage: fallback.targetLanguage
        )
    }

    private func makeResult(
        behavior: Behavior,
        englishTexts: [IdentifiedTranslationText],
        targetLanguage: LanguageIdentifier
    ) -> AppleInsightOutputTranslationResult {
        switch behavior {
        case .localized(let prefix):
            .localized(
                englishTexts.map {
                    IdentifiedTranslationText(
                        id: $0.id,
                        text: "\(prefix)\($0.text)"
                    )
                }
            )

        case .fallback(let reason):
            .englishFallback(
                AppleInsightEnglishFallback(
                    englishTexts: englishTexts,
                    targetLanguage: targetLanguage,
                    failure: AppleInsightTranslationFailure(
                        stage: .output,
                        reason: reason,
                        pair: TranslationLanguagePair(
                            source: .english,
                            target: targetLanguage
                        )
                    )
                )
            )

        case .missingLastIdentifier:
            .localized(Array(englishTexts.dropLast()))
        }
    }
}

@available(iOS 26.0, *)
@MainActor
private final class AnalyticsInsightGeneratorFake: AnalyticsInsightGenerating {
    private(set) var generationCallCount = 0
    private(set) var ranges: [TimeRange] = []
    private(set) var releaseCallCount = 0

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        preparingInputWith prepareInput: AppleAnalyticsInputPreparationHandler
    ) async throws -> AppleAnalyticsGenerationResult {
        generationCallCount += 1
        ranges.append(range)
        let preparation = await prepareInput(makeContext())
        guard case let .ready(inputTranslation) = preparation else {
            guard case let .blocked(failure) = preparation else {
                preconditionFailure("Unexpected input preparation state")
            }
            throw AppleAnalyticsGenerationError.inputTranslationBlocked(failure)
        }

        return AppleAnalyticsGenerationResult(
            englishInsight: makeInsight(),
            responseLanguage: inputTranslation.responseLanguage
        )
    }

    func releaseSession() {
        releaseCallCount += 1
    }
}

@MainActor
private final class NativeTranslationServiceFake: NativeTranslationService {
    private let preparationError: (any Error)?
    private(set) var prepareCallCount = 0
    private(set) var translateCallCount = 0

    init(preparationError: (any Error)? = nil) {
        self.preparationError = preparationError
    }

    func readiness(
        for pair: TranslationLanguagePair
    ) async -> NativeTranslationReadiness {
        NativeTranslationReadiness(
            pair: pair,
            availability: .installed,
            preparationState: .ready
        )
    }

    func makeBatches(
        from requests: [NativeTranslationRequest],
        targetLanguage: LanguageIdentifier
    ) throws -> [NativeTranslationBatch] {
        []
    }

    func configuration(
        for pair: TranslationLanguagePair
    ) -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: pair.source.rawValue),
            target: Locale.Language(identifier: pair.target.rawValue),
            preferredStrategy: .lowLatency
        )
    }

    func prepareTranslation(
        for pair: TranslationLanguagePair,
        using session: any NativeTranslationSession
    ) async throws -> NativeTranslationPreparationState {
        prepareCallCount += 1
        if let preparationError {
            throw preparationError
        }
        try await session.prepareTranslation()
        return .ready
    }

    func translate(
        _ batch: NativeTranslationBatch,
        using session: any NativeTranslationSession
    ) async throws -> [NativeTranslatedText] {
        translateCallCount += 1
        let responses = try await session.translations(
            from: batch.requests.map {
                NativeTranslationSessionRequest(
                    clientIdentifier: $0.id,
                    sourceText: $0.text
                )
            }
        )
        return responses.compactMap { response in
            response.clientIdentifier.map {
                NativeTranslatedText(id: $0, text: response.targetText)
            }
        }
    }
}

@MainActor
private final class NativeTranslationSessionHostFake: NativeTranslationSession {
    let sourceLanguage: LanguageIdentifier?
    let targetLanguage: LanguageIdentifier?
    let isReady: Bool
    private let suspendsTranslationUntilCancelled: Bool
    private(set) var prepareCallCount = 0
    private(set) var cancelCallCount = 0
    private var didStartTranslation = false
    private var translationStartContinuation: CheckedContinuation<Void, Never>?
    private var translationContinuation: CheckedContinuation<
        [NativeTranslationSessionResponse],
        any Error
    >?

    init(
        pair: TranslationLanguagePair,
        isReady: Bool = false,
        suspendsTranslationUntilCancelled: Bool = false
    ) {
        sourceLanguage = pair.source
        targetLanguage = pair.target
        self.isReady = isReady
        self.suspendsTranslationUntilCancelled = suspendsTranslationUntilCancelled
    }

    func prepareTranslation() async throws {
        prepareCallCount += 1
    }

    func translations(
        from requests: [NativeTranslationSessionRequest]
    ) async throws -> [NativeTranslationSessionResponse] {
        didStartTranslation = true
        translationStartContinuation?.resume()
        translationStartContinuation = nil

        if suspendsTranslationUntilCancelled {
            return try await withCheckedThrowingContinuation { continuation in
                translationContinuation = continuation
            }
        }

        return requests.map {
            NativeTranslationSessionResponse(
                clientIdentifier: $0.clientIdentifier,
                targetText: "ID: \($0.sourceText)"
            )
        }
    }

    func cancel() {
        cancelCallCount += 1
        translationContinuation?.resume(throwing: CancellationError())
        translationContinuation = nil
    }

    func waitUntilTranslationStarts() async {
        guard !didStartTranslation else {
            return
        }

        await withCheckedContinuation { continuation in
            if didStartTranslation {
                continuation.resume()
            } else {
                translationStartContinuation = continuation
            }
        }
    }
}

/// Replaces wall-clock sleeps so timeout tests control exactly when the
/// watchdog fires, independent of Xcode Cloud scheduling load.
@MainActor
private final class TranslationOperationTimeoutGate {
    private var isArmed = false
    private var armedContinuation: CheckedContinuation<Void, Never>?
    private var timeoutContinuation: CheckedContinuation<Void, any Error>?

    func sleep(for _: Duration) async throws {
        isArmed = true
        armedContinuation?.resume()
        armedContinuation = nil

        try await withCheckedThrowingContinuation { continuation in
            timeoutContinuation = continuation
        }
    }

    func waitUntilArmed() async {
        guard !isArmed else {
            return
        }

        await withCheckedContinuation { continuation in
            if isArmed {
                continuation.resume()
            } else {
                armedContinuation = continuation
            }
        }
    }

    func fire() {
        timeoutContinuation?.resume()
        timeoutContinuation = nil
    }
}

private let unusedBatchHandler: PreparedNativeTranslationBatchHandler = {
    _, _ in []
}

private func makeBatch() -> NativeTranslationBatch {
    NativeTranslationBatch(
        pair: TranslationLanguagePair(
            source: .english,
            target: .indonesian
        ),
        requests: [
            NativeTranslationRequest(
                id: "summary",
                text: "Hello",
                sourceLanguage: .english
            ),
        ]
    )
}

private func makeInsight() -> AnalyticsInsight {
    AnalyticsInsight(
        summary: "Limited English summary.",
        commonTriggers: [
            AnalyticsInsight.CommonTrigger(
                title: "Morning transition",
                explanation: "One morning event was recorded."
            ),
        ],
        observedPatterns: [
            AnalyticsInsight.ObservedPattern(
                title: "Morning observation",
                evidence: "One event happened in the morning at home.",
                linkedTrigger: "Morning transition",
                contextTags: ["morning", "house"]
            ),
        ],
        parentReflectionPrompt: "What felt different this morning?",
        ethicalNote: "This private observation is not a diagnosis."
    )
}

private func makeTriggerDetails(
    for insight: AnalyticsInsight
) -> [TriggerDetail] {
    ParentRecommendationCatalog().triggerDetails(for: insight)
}

private func makeContext() -> AnalyticsContext {
    AnalyticsContext(
        child: AnalyticsContext.Child(name: "Ari", age: 3, gender: "boy"),
        events: [
            AnalyticsContext.Event(
                recordedAt: Date(timeIntervalSince1970: 0),
                session: "morning",
                mood: "happy",
                activity: "play",
                place: "house",
                afterActivityNote: "Saya senang pagi ini."
            ),
        ],
        reflections: []
    )
}

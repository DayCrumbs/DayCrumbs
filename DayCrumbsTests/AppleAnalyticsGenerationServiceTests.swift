import Foundation
import Testing

@testable import DayCrumbs

#if canImport(FoundationModels)
@Suite("Apple typed analytics generation")
@MainActor
struct AppleAnalyticsGenerationServiceTests {
    @Test("Empty entries stop before availability and input preparation")
    func emptyEntriesStopImmediately() async throws {
        let runtime = RuntimeFake(behaviors: [])
        let preparation = InputPreparationFake()
        let service = makeService(runtime: runtime)

        await #expect(throws: AppleAnalyticsGenerationError.emptyEntries) {
            try await service.generateInsight(
                from: [],
                for: .day,
                preparingInputWith: preparation.handler
            )
        }

        #expect(runtime.availabilityReadCount == 0)
        #expect(runtime.contextEventCounts.isEmpty)
        #expect(preparation.contextEventCounts.isEmpty)
    }

    @Test("Unavailable Apple model stops before context preparation")
    func unavailableModelStopsBeforePreparation() async throws {
        let runtime = RuntimeFake(
            availabilities: [.modelNotReady],
            behaviors: []
        )
        let preparation = InputPreparationFake()
        let service = makeService(runtime: runtime)

        await #expect(
            throws: AppleAnalyticsGenerationError.modelUnavailable(.modelNotReady)
        ) {
            try await service.generateInsight(
                from: makeEntries(count: 1),
                for: .day,
                preparingInputWith: preparation.handler
            )
        }

        #expect(runtime.availabilityReadCount == 1)
        #expect(runtime.contextEventCounts.isEmpty)
        #expect(preparation.contextEventCounts.isEmpty)
    }

    @Test("Primary request uses 24 rows and returns validated typed insight")
    func primaryTypedGeneration() async throws {
        let runtime = RuntimeFake(behaviors: [.succeed(makeGeneratedInsight())])
        let preparation = InputPreparationFake(responseLanguage: .indonesian)
        let service = makeService(runtime: runtime)

        let result = try await service.generateInsight(
            from: makeEntries(count: 30),
            for: .month,
            preparingInputWith: preparation.handler
        )

        #expect(preparation.contextEventCounts == [24])
        #expect(runtime.contextEventCounts == [24])
        #expect(runtime.ranges == [.month])
        #expect(runtime.availabilityReadCount == 2)
        #expect(runtime.releaseCount == 1)
        #expect(result.responseLanguage == .indonesian)
        #expect(result.englishInsight.summary == "A possible pattern is visible.")
        #expect(result.englishInsight.observedPatterns[0].contextTags == [
            "morning", "house",
        ])
    }

    @Test("Retryable failure retries once with the 10-row context")
    func retryUsesSmallerContextOnce() async throws {
        let runtime = RuntimeFake(
            behaviors: [
                .fail(.exceededContextWindow),
                .succeed(makeGeneratedInsight()),
            ]
        )
        let preparation = InputPreparationFake()
        let service = makeService(runtime: runtime)

        _ = try await service.generateInsight(
            from: makeEntries(count: 30),
            for: .week,
            preparingInputWith: preparation.handler
        )

        #expect(preparation.contextEventCounts == [24, 10])
        #expect(runtime.contextEventCounts == [24, 10])
        #expect(runtime.ranges == [.week, .week])
        #expect(runtime.availabilityReadCount == 4)
        #expect(runtime.releaseCount == 1)
    }

    @Test("A second retryable failure is returned without a third attempt")
    func retriesAtMostOnce() async throws {
        let runtime = RuntimeFake(
            behaviors: [
                .fail(.decodingFailure),
                .fail(.exceededContextWindow),
            ]
        )
        let preparation = InputPreparationFake()
        let service = makeService(runtime: runtime)

        await #expect(
            throws: AppleAnalyticsGenerationError.generationFailed(
                .exceededContextWindow
            )
        ) {
            try await service.generateInsight(
                from: makeEntries(count: 30),
                for: .day,
                preparingInputWith: preparation.handler
            )
        }

        #expect(runtime.contextEventCounts == [24, 10])
        #expect(preparation.contextEventCounts == [24, 10])
    }

    @Test("Refusal is not retried or switched to another engine")
    func refusalDoesNotRetry() async throws {
        let runtime = RuntimeFake(behaviors: [.fail(.refusal)])
        let preparation = InputPreparationFake()
        let service = makeService(runtime: runtime)

        await #expect(
            throws: AppleAnalyticsGenerationError.generationFailed(.refusal)
        ) {
            try await service.generateInsight(
                from: makeEntries(count: 30),
                for: .day,
                preparingInputWith: preparation.handler
            )
        }

        #expect(runtime.contextEventCounts == [24])
        #expect(preparation.contextEventCounts == [24])
    }

    @Test("Blocked input translation prevents Apple generation")
    func blockedTranslationStopsGeneration() async throws {
        let failure = AppleInsightTranslationFailure(
            stage: .input,
            reason: .unsupportedLanguagePair,
            pair: nil
        )
        let runtime = RuntimeFake(behaviors: [])
        let preparation = InputPreparationFake(result: .blocked(failure))
        let service = makeService(runtime: runtime)

        await #expect(
            throws: AppleAnalyticsGenerationError.inputTranslationBlocked(failure)
        ) {
            try await service.generateInsight(
                from: makeEntries(count: 1),
                for: .day,
                preparingInputWith: preparation.handler
            )
        }

        #expect(preparation.contextEventCounts == [1])
        #expect(runtime.contextEventCounts.isEmpty)
        #expect(runtime.availabilityReadCount == 1)
    }

    @Test("Availability is rechecked after input preparation")
    func availabilityIsRechecked() async throws {
        let runtime = RuntimeFake(
            availabilities: [.available, .appleIntelligenceNotEnabled],
            behaviors: []
        )
        let preparation = InputPreparationFake()
        let service = makeService(runtime: runtime)

        await #expect(
            throws: AppleAnalyticsGenerationError.modelUnavailable(
                .appleIntelligenceNotEnabled
            )
        ) {
            try await service.generateInsight(
                from: makeEntries(count: 1),
                for: .day,
                preparingInputWith: preparation.handler
            )
        }

        #expect(runtime.availabilityReadCount == 2)
        #expect(preparation.contextEventCounts == [1])
        #expect(runtime.contextEventCounts.isEmpty)
    }

    @Test("Incomplete typed output is rejected before publication")
    func invalidTypedOutputIsRejected() async throws {
        let generated = makeGeneratedInsight(summary: " \n ")
        let runtime = RuntimeFake(behaviors: [.succeed(generated)])
        let service = makeService(runtime: runtime)

        await #expect(
            throws: AppleAnalyticsGenerationError.invalidGeneratedInsight(
                .emptySummary
            )
        ) {
            try await service.generateInsight(
                from: makeEntries(count: 1),
                for: .day,
                preparingInputWith: InputPreparationFake().handler
            )
        }

        #expect(runtime.contextEventCounts == [1])
    }

    private func makeService(
        runtime: RuntimeFake
    ) -> AppleAnalyticsGenerationService {
        AppleAnalyticsGenerationService(runtime: runtime)
    }
}

@available(iOS 26.0, *)
@MainActor
private final class RuntimeFake: AppleTypedInsightGeneratingRuntime {
    enum Behavior {
        case succeed(AppleGeneratedAnalyticsInsight)
        case fail(AppleFoundationModelsSessionError)
    }

    private var availabilities: [AppleFoundationModelAvailability]
    private var behaviors: [Behavior]
    private(set) var availabilityReadCount = 0
    private(set) var contextEventCounts: [Int] = []
    private(set) var ranges: [TimeRange] = []
    private(set) var releaseCount = 0

    init(
        availabilities: [AppleFoundationModelAvailability] = [.available],
        behaviors: [Behavior]
    ) {
        self.availabilities = availabilities
        self.behaviors = behaviors
    }

    var availability: AppleFoundationModelAvailability {
        availabilityReadCount += 1
        guard let first = availabilities.first else {
            return .unavailable
        }
        if availabilities.count > 1 {
            availabilities.removeFirst()
        }
        return first
    }

    func generateTypedInsight(
        from context: AnalyticsContext,
        for range: TimeRange,
        configuration: LocalLLMConfiguration
    ) async throws -> AppleGeneratedAnalyticsInsight {
        contextEventCounts.append(context.events.count)
        ranges.append(range)
        guard !behaviors.isEmpty else {
            throw AppleFoundationModelsSessionError.unavailableRuntime
        }

        switch behaviors.removeFirst() {
        case .succeed(let insight):
            return insight
        case .fail(let error):
            throw error
        }
    }

    func releaseSession() {
        releaseCount += 1
    }
}

@MainActor
private final class InputPreparationFake {
    private let responseLanguage: LanguageIdentifier
    private let fixedResult: AppleInsightInputPreparationResult?
    private(set) var contextEventCounts: [Int] = []

    init(
        responseLanguage: LanguageIdentifier = .english,
        result: AppleInsightInputPreparationResult? = nil
    ) {
        self.responseLanguage = responseLanguage
        fixedResult = result
    }

    var handler: AppleAnalyticsInputPreparationHandler {
        { [self] context in
            contextEventCounts.append(context.events.count)
            if let fixedResult {
                return fixedResult
            }
            return .ready(
                AnalyticsInputTranslation(
                    englishContext: context,
                    responseLanguage: responseLanguage,
                    didTranslateParentText: false
                )
            )
        }
    }
}

@available(iOS 26.0, *)
private func makeGeneratedInsight(
    summary: String = "  A possible   pattern is visible.  "
) -> AppleGeneratedAnalyticsInsight {
    AppleGeneratedAnalyticsInsight(
        summary: summary,
        commonTriggers: [
            AppleGeneratedCommonTrigger(
                title: "Morning transition",
                explanation: "One supplied morning row contained a sad mood."
            ),
        ],
        observedPatterns: [
            AppleGeneratedObservedPattern(
                title: "Morning observation",
                evidence: "One morning event was recorded at home.",
                linkedTrigger: "Morning transition",
                contextTags: [" morning ", "house", "  "]
            ),
        ],
        parentReflectionPrompt: "What felt different this morning?",
        ethicalNote: "This private observation is not a diagnosis."
    )
}

@MainActor
private func makeEntries(count: Int) -> [StoryEntry] {
    let profile = ChildProfile(name: "Ari", age: 3, gender: .boy)
    let session = DailySession(
        startedAt: Date(timeIntervalSince1970: 0),
        childProfile: profile
    )
    profile.dailySessions = [session]

    let entries = (0..<count).map { index in
        StoryEntry(
            session: .morning,
            mood: .happy,
            activity: .play,
            place: .house,
            recordedAt: Date(timeIntervalSince1970: TimeInterval(index)),
            dailySession: session
        )
    }
    session.entries = entries
    return entries
}
#endif

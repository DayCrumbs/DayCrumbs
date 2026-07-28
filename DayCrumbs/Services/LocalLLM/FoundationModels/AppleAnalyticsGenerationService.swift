import Foundation

#if canImport(FoundationModels)
/// Builds translated context and coordinates at most two fresh typed Apple sessions.
@available(iOS 26.0, *)
@MainActor
final class AppleAnalyticsGenerationService: AnalyticsInsightGenerating {
    private let runtime: any AppleTypedInsightGeneratingRuntime
    private let configuration: LocalLLMConfiguration
    private let contextBuilder: AnalyticsContextBuilder
    private let groundingService = AppleAnalyticsInsightGroundingService()
    private var isGenerating = false

    init() {
        let configuration = LocalLLMConfiguration.default
        runtime = AppleFoundationModelsTypedRuntime()
        self.configuration = configuration
        contextBuilder = AnalyticsContextBuilder(configuration: configuration)
    }

    init(
        runtime: any AppleTypedInsightGeneratingRuntime,
        configuration: LocalLLMConfiguration = .default
    ) {
        self.runtime = runtime
        self.configuration = configuration
        contextBuilder = AnalyticsContextBuilder(configuration: configuration)
    }

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        preparingInputWith prepareInput: AppleAnalyticsInputPreparationHandler
    ) async throws -> AppleAnalyticsGenerationResult {
        guard !isGenerating else {
            throw AppleAnalyticsGenerationError.concurrentRequest
        }
        guard !entries.isEmpty else {
            throw AppleAnalyticsGenerationError.emptyEntries
        }

        isGenerating = true
        defer {
            isGenerating = false
            runtime.releaseSession()
        }

        do {
            return try await generateAttempt(
                from: entries,
                for: range,
                eventLimit: .primary,
                preparingInputWith: prepareInput
            )
        } catch let error as AppleAnalyticsGenerationError {
            guard case let .generationFailed(sessionError) = error,
                  sessionError.allowsSmallerContextRetry else {
                throw error
            }

            return try await generateAttempt(
                from: entries,
                for: range,
                eventLimit: .retry,
                preparingInputWith: prepareInput
            )
        } catch is CancellationError {
            throw AppleAnalyticsGenerationError.cancelled
        }
    }

    func releaseSession() {
        runtime.releaseSession()
    }

    private func generateAttempt(
        from entries: [StoryEntry],
        for range: TimeRange,
        eventLimit: AnalyticsContextBuilder.EventLimit,
        preparingInputWith prepareInput: AppleAnalyticsInputPreparationHandler
    ) async throws -> AppleAnalyticsGenerationResult {
        try Task.checkCancellation()
        try requireAvailableModel()

        let context: AnalyticsContext
        do {
            context = try contextBuilder.build(
                from: entries,
                eventLimit: eventLimit
            )
        } catch let error as AnalyticsContextBuilder.BuildError {
            throw AppleAnalyticsGenerationError.invalidEntries(error)
        }

        let inputPreparation = await prepareInput(context)
        guard case let .ready(inputTranslation) = inputPreparation else {
            guard case let .blocked(failure) = inputPreparation else {
                preconditionFailure("Apple input preparation has an unknown state")
            }
            throw AppleAnalyticsGenerationError.inputTranslationBlocked(failure)
        }

        try Task.checkCancellation()
        try requireAvailableModel()

        do {
            let generated = try await runtime.generateTypedInsight(
                from: inputTranslation.englishContext,
                for: range,
                configuration: configuration
            )
            let validatedInsight = try generated.validatedAnalyticsInsight()
            let insight = groundingService.grounded(
                validatedInsight,
                in: inputTranslation.englishContext
            )
            return AppleAnalyticsGenerationResult(
                englishInsight: insight,
                responseLanguage: inputTranslation.responseLanguage
            )
        } catch is CancellationError {
            throw AppleAnalyticsGenerationError.cancelled
        } catch let error as AnalyticsInsight.ValidationError {
            throw AppleAnalyticsGenerationError.invalidGeneratedInsight(error)
        } catch let error as AppleFoundationModelsSessionError {
            throw AppleAnalyticsGenerationError.generationFailed(error)
        }
    }

    private func requireAvailableModel() throws {
        let availability = runtime.availability
        guard availability == .available else {
            throw AppleAnalyticsGenerationError.modelUnavailable(availability)
        }
    }
}
#endif

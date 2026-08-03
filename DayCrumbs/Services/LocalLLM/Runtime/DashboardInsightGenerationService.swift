import Foundation
import SwiftData

nonisolated struct DashboardGeneratedInsight: Equatable, Sendable {
    let insight: AnalyticsInsight
    let triggerDetails: [TriggerDetail]
    let englishFallback: AppleAnalyticsInsightEnglishFallback?
    let engine: AnalysisEngine

    init(
        insight: AnalyticsInsight,
        triggerDetails: [TriggerDetail] = [],
        englishFallback: AppleAnalyticsInsightEnglishFallback? = nil,
        engine: AnalysisEngine
    ) {
        self.insight = insight
        self.triggerDetails = triggerDetails
        self.englishFallback = englishFallback
        self.engine = engine
    }
}

nonisolated enum DashboardInsightGenerationError:
    Error,
    Equatable,
    Sendable
{
    case modelDownloadRequired
    case invalidGemmaInstallation
}

@MainActor
protocol DashboardInsightGenerating: AnyObject {
    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> DashboardGeneratedInsight

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> DashboardGeneratedInsight

    func releaseRuntime()
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@MainActor
final class DefaultDashboardInsightGenerationService:
    DashboardInsightGenerating
{
    private let resolver: any AnalysisEngineResolving
    private let appleService: any AppleLocalizedInsightGenerating
    private let gemmaService: any GemmaAnalyticsInsightGenerating
    private let recommendationCatalog: ParentRecommendationCatalog

    init(modelContext: ModelContext) {
        let storage = LocalModelStorage()
        let repository = LocalModelInstallationRepository(
            modelContext: modelContext
        )
        let installationService = LocalModelInstallationService(
            repository: repository,
            storage: storage
        )
        resolver = AnalysisEngineResolver(
            installationValidator: installationService
        )
        appleService = AppleLocalizedInsightGenerationService()
        gemmaService = GemmaAnalyticsGenerationService()
        recommendationCatalog = ParentRecommendationCatalog()
    }

    init(
        resolver: any AnalysisEngineResolving,
        appleService: any AppleLocalizedInsightGenerating,
        gemmaService: any GemmaAnalyticsInsightGenerating,
        recommendationCatalog: ParentRecommendationCatalog =
            ParentRecommendationCatalog()
    ) {
        self.resolver = resolver
        self.appleService = appleService
        self.gemmaService = gemmaService
        self.recommendationCatalog = recommendationCatalog
    }

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> DashboardGeneratedInsight {
        let resolution: AnalysisEngineResolution
        do {
            resolution = try await resolver.resolveEngine()
        } catch AnalysisEngineResolutionError.modelDownloadRequired {
            throw DashboardInsightGenerationError.modelDownloadRequired
        } catch {
            throw DashboardInsightGenerationError.invalidGemmaInstallation
        }

        switch resolution.engine {
        case .appleFoundationModels:
            let result = try await appleService.generateInsight(
                from: entries,
                for: range,
                using: executeBatch
            )
            return DashboardGeneratedInsight(
                insight: result.insight,
                triggerDetails: result.triggerDetails,
                englishFallback: result.englishFallback,
                engine: .appleFoundationModels
            )

        case .gemma4E2B:
            guard let modelURL = resolution.gemmaInstallation?.fileURL else {
                throw DashboardInsightGenerationError
                    .invalidGemmaInstallation
            }
            let insight = try await gemmaService.generateInsight(
                from: entries,
                for: range,
                modelURL: modelURL
            )
            let responseLanguage = GemmaResponseLanguageResolver().resolve(
                from: insight
            )
            return DashboardGeneratedInsight(
                insight: insight,
                triggerDetails: recommendationCatalog.triggerDetails(
                    for: insight,
                    responseLanguage: responseLanguage
                ),
                engine: .gemma4E2B
            )
        }
    }

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> DashboardGeneratedInsight {
        let result = await appleService.retryOutputTranslation(
            fallback,
            using: executeBatch
        )
        return DashboardGeneratedInsight(
            insight: result.insight,
            triggerDetails: result.triggerDetails,
            englishFallback: result.englishFallback,
            engine: .appleFoundationModels
        )
    }

    func releaseRuntime() {
        appleService.releaseSession()
        gemmaService.releaseRuntime()
    }
}
#endif

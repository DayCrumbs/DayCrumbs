import Foundation

nonisolated struct AnalysisEngineResolution: Equatable, Sendable {
    let engine: AnalysisEngine
    let gemmaInstallation: ValidatedLocalModelInstallation?

    static let appleFoundationModels = AnalysisEngineResolution(
        engine: .appleFoundationModels,
        gemmaInstallation: nil
    )

    static func gemma(
        _ installation: ValidatedLocalModelInstallation
    ) -> AnalysisEngineResolution {
        AnalysisEngineResolution(
            engine: .gemma4E2B,
            gemmaInstallation: installation
        )
    }
}

nonisolated enum AnalysisEngineResolutionError:
    Error,
    Equatable,
    Sendable
{
    case modelDownloadRequired
    case invalidGemmaInstallation
}

@MainActor
protocol AnalysisEngineResolving: AnyObject {
    func resolveEngine() async throws -> AnalysisEngineResolution
}

@MainActor
final class AnalysisEngineResolver: AnalysisEngineResolving {
    private let appleAvailability: () -> AppleFoundationModelAvailability
    private let installationValidator: any LocalModelInstallationValidating
    private let gemmaDescriptor: LocalModelDescriptor

    init(
        installationValidator: any LocalModelInstallationValidating,
        gemmaDescriptor: LocalModelDescriptor = LocalModelCatalog.gemma4E2B,
        appleAvailability: @escaping () -> AppleFoundationModelAvailability = {
            MainActor.assumeIsolated {
                AppleFoundationModelsRuntime.availability
            }
        }
    ) {
        self.installationValidator = installationValidator
        self.gemmaDescriptor = gemmaDescriptor
        self.appleAvailability = appleAvailability
    }

    func resolveEngine() async throws -> AnalysisEngineResolution {
        if appleAvailability() == .available {
            return .appleFoundationModels
        }

        do {
            guard let installation = try await installationValidator
                .validatedInstallation(for: gemmaDescriptor) else {
                throw AnalysisEngineResolutionError.modelDownloadRequired
            }
            return .gemma(installation)
        } catch let error as AnalysisEngineResolutionError {
            throw error
        } catch {
            throw AnalysisEngineResolutionError.invalidGemmaInstallation
        }
    }
}

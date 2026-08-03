import Foundation
import Observation
import SwiftData

nonisolated enum GemmaInstallationPresentationState: Equatable, Sendable {
    case checking
    case notInstalled
    case downloading(completed: Int64, expected: Int64)
    case ready
    case failed(message: String)
}

@MainActor
@Observable
final class ModelsViewModel {
    private(set) var availability: AppleFoundationModelAvailability = .unavailable
    private(set) var readinessMessage = "Checking Apple Intelligence readiness…"
    private(set) var gemmaState: GemmaInstallationPresentationState = .checking

    let gemmaDescriptor: LocalModelDescriptor

    private let installationService: LocalModelInstallationService
    private let downloadService: any LocalModelDownloading
    private let appleAvailabilityProvider:
        @MainActor () -> AppleFoundationModelAvailability
    private let appleReadinessMessageProvider: @MainActor () -> String
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var activeDownloadID: UUID?

    init(
        modelContext: ModelContext,
        storage: any LocalModelStoring = LocalModelStorage(),
        downloadService: (any LocalModelDownloading)? = nil,
        descriptor: LocalModelDescriptor = LocalModelCatalog.gemma4E2B,
        appleAvailability: @escaping @MainActor () ->
            AppleFoundationModelAvailability = {
                AppleFoundationModelsRuntime.availability
            },
        appleReadinessMessage: @escaping @MainActor () -> String = {
            AppleFoundationModelsRuntime.readinessMessage
        }
    ) {
        let repository = LocalModelInstallationRepository(
            modelContext: modelContext
        )
        installationService = LocalModelInstallationService(
            repository: repository,
            storage: storage
        )
        self.downloadService = downloadService
            ?? URLSessionLocalModelDownloadService(storage: storage)
        gemmaDescriptor = descriptor
        appleAvailabilityProvider = appleAvailability
        appleReadinessMessageProvider = appleReadinessMessage
    }

    var isAppleFoundationModelsAvailable: Bool {
        availability.isAvailable
    }

    var downloadProgress: Double? {
        guard case let .downloading(completed, expected) = gemmaState,
              expected > 0 else {
            return nil
        }
        return min(1, max(0, Double(completed) / Double(expected)))
    }

    var downloadProgressLabel: String? {
        guard case let .downloading(completed, expected) = gemmaState else {
            return nil
        }
        return "\(Self.fileSize(completed)) of \(Self.fileSize(expected))"
    }

    var canRequestDownload: Bool {
        switch gemmaState {
        case .notInstalled, .failed:
            true
        default:
            false
        }
    }

    var requiresPrivateInsightsSetup: Bool {
        guard !isAppleFoundationModelsAvailable else {
            return false
        }
        switch gemmaState {
        case .notInstalled, .failed:
            return true
        case .checking, .downloading, .ready:
            return false
        }
    }

    func refresh() async {
        refreshAppleAvailability()
        guard downloadTask == nil else {
            return
        }

        gemmaState = .checking
        do {
            let installation = try await installationService
                .validatedInstallation(for: gemmaDescriptor)
            gemmaState = installation == nil ? .notInstalled : .ready
        } catch {
            gemmaState = .failed(
                message: userMessage(for: error)
            )
        }
    }

    func refreshAppleAvailability() {
        availability = appleAvailabilityProvider()
        readinessMessage = appleReadinessMessageProvider()
    }

    func startDownload() {
        guard downloadTask == nil, canRequestDownload else {
            return
        }

        gemmaState = .downloading(
            completed: 0,
            expected: gemmaDescriptor.expectedByteCount
        )
        let downloadID = UUID()
        activeDownloadID = downloadID

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let validation = try await downloadService.download(
                    gemmaDescriptor
                ) { [weak self] completed, expected in
                    guard let self,
                          !Task.isCancelled,
                          activeDownloadID == downloadID else {
                        return
                    }
                    gemmaState = .downloading(
                        completed: completed,
                        expected: expected
                    )
                }
                try Task.checkCancellation()
                guard activeDownloadID == downloadID else {
                    return
                }
                try installationService.recordValidatedDownload(
                    validation,
                    descriptor: gemmaDescriptor
                )
                gemmaState = .ready
            } catch is CancellationError {
                if activeDownloadID == downloadID {
                    gemmaState = .notInstalled
                }
            } catch {
                if activeDownloadID == downloadID {
                    gemmaState = .failed(message: userMessage(for: error))
                }
            }

            if activeDownloadID == downloadID {
                downloadTask = nil
                activeDownloadID = nil
            }
        }

        downloadTask = task
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        activeDownloadID = nil
        if case .downloading = gemmaState {
            gemmaState = .notInstalled
        }
    }

    private func userMessage(for error: any Error) -> String {
        if let storageError = error as? LocalModelStorageError,
           case let .insufficientStorage(required, available) = storageError {
            let missing = max(0, required - available)
            return "There is not enough free space. Free up at least \(Self.fileSize(missing)) and try again."
        }
        if error is URLError {
            return "The download could not be completed. Check your internet connection and try again."
        }
        return "Private insights could not be set up. Please try again."
    }

    private nonisolated static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

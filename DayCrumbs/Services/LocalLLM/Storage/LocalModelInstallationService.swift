import Foundation

nonisolated struct ValidatedLocalModelInstallation: Equatable, Sendable {
    let descriptor: LocalModelDescriptor
    let fileURL: URL
}

@MainActor
protocol LocalModelInstallationValidating: AnyObject {
    func validatedInstallation(
        for descriptor: LocalModelDescriptor
    ) async throws -> ValidatedLocalModelInstallation?
}

@MainActor
final class LocalModelInstallationService: LocalModelInstallationValidating {
    private let repository: any LocalModelInstallationRepositoryProtocol
    private let storage: any LocalModelStoring

    init(
        repository: any LocalModelInstallationRepositoryProtocol,
        storage: any LocalModelStoring = LocalModelStorage()
    ) {
        self.repository = repository
        self.storage = storage
    }

    func validatedInstallation(
        for descriptor: LocalModelDescriptor
    ) async throws -> ValidatedLocalModelInstallation? {
        let metadata = try repository.installation(for: descriptor.id)

        do {
            let identity = try storage.finalFileIdentity(for: descriptor)
            if let metadata,
               metadata.status == .installed,
               metadata.relativeFilePath == identity.relativeFilePath,
               metadata.validatedByteCount == descriptor.expectedByteCount,
               metadata.validatedSHA256.caseInsensitiveCompare(
                   descriptor.expectedSHA256
               ) == .orderedSame,
               metadata.validatedFileModificationDate
                   == identity.modificationDate,
               identity.byteCount == descriptor.expectedByteCount {
                return ValidatedLocalModelInstallation(
                    descriptor: descriptor,
                    fileURL: identity.fileURL
                )
            }

            let validation = try await storage.validateFinalFile(for: descriptor)
            if metadata == nil
                || metadata?.status != .installed
                || metadata?.relativeFilePath != validation.relativeFilePath
                || metadata?.validatedByteCount != validation.byteCount
                || metadata?.validatedSHA256 != validation.sha256 {
                try repository.saveValidatedInstallation(
                    descriptor: descriptor,
                    relativeFilePath: validation.relativeFilePath,
                    validatedAt: .now,
                    fileModificationDate: validation.modificationDate
                )
            }
            return ValidatedLocalModelInstallation(
                descriptor: descriptor,
                fileURL: validation.fileURL
            )
        } catch LocalModelStorageError.missingFile {
            if metadata != nil {
                try repository.markInvalid(descriptorID: descriptor.id)
            }
            return nil
        } catch {
            if metadata != nil {
                try repository.markInvalid(descriptorID: descriptor.id)
            }
            throw error
        }
    }

    func recordValidatedDownload(
        _ validation: LocalModelFileValidation,
        descriptor: LocalModelDescriptor
    ) throws {
        try repository.saveValidatedInstallation(
            descriptor: descriptor,
            relativeFilePath: validation.relativeFilePath,
            validatedAt: .now,
            fileModificationDate: validation.modificationDate
        )
    }
}

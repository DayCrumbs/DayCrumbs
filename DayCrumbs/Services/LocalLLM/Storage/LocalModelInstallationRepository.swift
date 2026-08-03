import Foundation
import SwiftData

nonisolated enum LocalModelInstallationRepositoryError: LocalizedError, Equatable {
    case duplicateInstallations(String)

    var errorDescription: String? {
        switch self {
        case .duplicateInstallations:
            "More than one installation record exists for the local model."
        }
    }
}

@MainActor
protocol LocalModelInstallationRepositoryProtocol {
    func installation(for descriptorID: String) throws -> LocalModelInstallation?
    func saveValidatedInstallation(
        descriptor: LocalModelDescriptor,
        relativeFilePath: String,
        validatedAt: Date,
        fileModificationDate: Date
    ) throws
    func markInvalid(descriptorID: String) throws
    func removeInstallation(descriptorID: String) throws
}

@MainActor
final class LocalModelInstallationRepository:
    LocalModelInstallationRepositoryProtocol
{
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func installation(
        for descriptorID: String
    ) throws -> LocalModelInstallation? {
        let matches = try modelContext.fetch(
            FetchDescriptor<LocalModelInstallation>()
        ).filter {
            $0.descriptorID == descriptorID
        }

        guard matches.count <= 1 else {
            throw LocalModelInstallationRepositoryError
                .duplicateInstallations(descriptorID)
        }
        return matches.first
    }

    func saveValidatedInstallation(
        descriptor: LocalModelDescriptor,
        relativeFilePath: String,
        validatedAt: Date = .now,
        fileModificationDate: Date
    ) throws {
        if let installation = try installation(for: descriptor.id) {
            installation.relativeFilePath = relativeFilePath
            installation.validatedByteCount = descriptor.expectedByteCount
            installation.validatedSHA256 = descriptor.expectedSHA256
            installation.status = .installed
            installation.validatedAt = validatedAt
            installation.validatedFileModificationDate = fileModificationDate
        } else {
            modelContext.insert(
                LocalModelInstallation(
                    descriptorID: descriptor.id,
                    relativeFilePath: relativeFilePath,
                    validatedByteCount: descriptor.expectedByteCount,
                    validatedSHA256: descriptor.expectedSHA256,
                    status: .installed,
                    validatedAt: validatedAt,
                    validatedFileModificationDate: fileModificationDate
                )
            )
        }
        try modelContext.save()
    }

    func markInvalid(descriptorID: String) throws {
        guard let installation = try installation(for: descriptorID) else {
            return
        }
        installation.status = .invalid
        try modelContext.save()
    }

    func removeInstallation(descriptorID: String) throws {
        guard let installation = try installation(for: descriptorID) else {
            return
        }
        modelContext.delete(installation)
        try modelContext.save()
    }
}

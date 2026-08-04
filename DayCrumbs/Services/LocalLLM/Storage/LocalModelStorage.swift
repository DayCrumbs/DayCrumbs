import CryptoKit
import Foundation

nonisolated enum LocalModelStorageError: LocalizedError, Equatable, Sendable {
    case invalidRelativePath
    case missingFile
    case unexpectedByteCount(expected: Int64, actual: Int64)
    case checksumMismatch
    case insufficientStorage(required: Int64, available: Int64)

    var errorDescription: String? {
        switch self {
        case .invalidRelativePath:
            "The local model storage path is invalid."
        case .missingFile:
            "The downloaded model file could not be found."
        case .unexpectedByteCount:
            "The downloaded model has an unexpected file size."
        case .checksumMismatch:
            "The downloaded model did not pass its integrity check."
        case .insufficientStorage:
            "There is not enough free storage to download this model."
        }
    }
}

nonisolated struct LocalModelFileValidation: Equatable, Sendable {
    let fileURL: URL
    let relativeFilePath: String
    let byteCount: Int64
    let sha256: String
    let modificationDate: Date
}

nonisolated struct LocalModelFileIdentity: Equatable, Sendable {
    let fileURL: URL
    let relativeFilePath: String
    let byteCount: Int64
    let modificationDate: Date
}

nonisolated protocol LocalModelStoring: Sendable {
    func finalFileURL(for descriptor: LocalModelDescriptor) throws -> URL
    func partialFileURL(for descriptor: LocalModelDescriptor) throws -> URL
    func relativeFilePath(for descriptor: LocalModelDescriptor) -> String
    func prepareDirectory(for descriptor: LocalModelDescriptor) throws
    func partialByteCount(for descriptor: LocalModelDescriptor) throws -> Int64
    func resetPartialFile(for descriptor: LocalModelDescriptor) throws
    func finalFileIdentity(
        for descriptor: LocalModelDescriptor
    ) throws -> LocalModelFileIdentity
    func validateFinalFile(
        for descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation
    func validateFile(
        at url: URL,
        descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation
    func finalizePartialFile(
        for descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation
    func availableCapacity() throws -> Int64
}

nonisolated struct LocalModelStorage: LocalModelStoring {
    private let applicationSupportDirectory: URL

    init(
        applicationSupportDirectory: URL = .applicationSupportDirectory
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
            .standardizedFileURL
    }

    func finalFileURL(for descriptor: LocalModelDescriptor) throws -> URL {
        try validatedURL(
            applicationSupportDirectory
                .appending(path: relativeFilePath(for: descriptor))
        )
    }

    func partialFileURL(for descriptor: LocalModelDescriptor) throws -> URL {
        try validatedURL(
            applicationSupportDirectory
                .appending(path: "LocalModels")
                .appending(path: descriptor.id)
                .appending(path: "\(descriptor.filename).partial")
        )
    }

    func relativeFilePath(for descriptor: LocalModelDescriptor) -> String {
        "LocalModels/\(descriptor.id)/\(descriptor.filename)"
    }

    func prepareDirectory(for descriptor: LocalModelDescriptor) throws {
        let directory = try finalFileURL(for: descriptor)
            .deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func partialByteCount(for descriptor: LocalModelDescriptor) throws -> Int64 {
        let url = try partialFileURL(for: descriptor)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }
        return try Self.byteCount(at: url)
    }

    func resetPartialFile(for descriptor: LocalModelDescriptor) throws {
        try prepareDirectory(for: descriptor)
        let url = try partialFileURL(for: descriptor)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func finalFileIdentity(
        for descriptor: LocalModelDescriptor
    ) throws -> LocalModelFileIdentity {
        let url = try finalFileURL(for: descriptor)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalModelStorageError.missingFile
        }
        let attributes = try Self.fileAttributes(at: url)
        return LocalModelFileIdentity(
            fileURL: url,
            relativeFilePath: relativeFilePath(for: descriptor),
            byteCount: attributes.byteCount,
            modificationDate: attributes.modificationDate
        )
    }

    func validateFinalFile(
        for descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation {
        try await validateFile(
            at: finalFileURL(for: descriptor),
            descriptor: descriptor
        )
    }

    func validateFile(
        at url: URL,
        descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation {
        let expectedRoot = applicationSupportDirectory
        return try await Task.detached(priority: .utility) {
            let standardizedURL = url.standardizedFileURL
            let rootPath = expectedRoot.path.hasSuffix("/")
                ? expectedRoot.path
                : "\(expectedRoot.path)/"
            guard standardizedURL.path.hasPrefix(rootPath) else {
                throw LocalModelStorageError.invalidRelativePath
            }
            guard FileManager.default.fileExists(atPath: standardizedURL.path) else {
                throw LocalModelStorageError.missingFile
            }

            let attributes = try Self.fileAttributes(at: standardizedURL)
            let byteCount = attributes.byteCount
            guard byteCount == descriptor.expectedByteCount else {
                throw LocalModelStorageError.unexpectedByteCount(
                    expected: descriptor.expectedByteCount,
                    actual: byteCount
                )
            }

            let sha256 = try Self.sha256(at: standardizedURL)
            guard sha256.caseInsensitiveCompare(descriptor.expectedSHA256)
                    == .orderedSame else {
                throw LocalModelStorageError.checksumMismatch
            }

            return LocalModelFileValidation(
                fileURL: standardizedURL,
                relativeFilePath:
                    "LocalModels/\(descriptor.id)/\(descriptor.filename)",
                byteCount: byteCount,
                sha256: sha256,
                modificationDate: attributes.modificationDate
            )
        }.value
    }

    func finalizePartialFile(
        for descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation {
        let partialURL = try partialFileURL(for: descriptor)
        let validation = try await validateFile(
            at: partialURL,
            descriptor: descriptor
        )
        let finalURL = try finalFileURL(for: descriptor)

        if FileManager.default.fileExists(atPath: finalURL.path) {
            _ = try FileManager.default.replaceItemAt(
                finalURL,
                withItemAt: partialURL
            )
        } else {
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
        }

        // Moving a verified file within Application Support preserves its bytes
        // and file metadata, so avoid hashing the 2.58 GB payload a second time.
        return LocalModelFileValidation(
            fileURL: finalURL,
            relativeFilePath: validation.relativeFilePath,
            byteCount: validation.byteCount,
            sha256: validation.sha256,
            modificationDate: validation.modificationDate
        )
    }

    func availableCapacity() throws -> Int64 {
        let values = try applicationSupportDirectory
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    private func validatedURL(_ url: URL) throws -> URL {
        let standardized = url.standardizedFileURL
        let rootPath = applicationSupportDirectory.path.hasSuffix("/")
            ? applicationSupportDirectory.path
            : "\(applicationSupportDirectory.path)/"
        guard standardized.path.hasPrefix(rootPath) else {
            throw LocalModelStorageError.invalidRelativePath
        }
        return standardized
    }

    private static func byteCount(at url: URL) throws -> Int64 {
        try fileAttributes(at: url).byteCount
    }

    private static func fileAttributes(
        at url: URL
    ) throws -> (byteCount: Int64, modificationDate: Date) {
        let attributes = try FileManager.default
            .attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modificationDate = attributes[.modificationDate] as? Date ?? .distantPast
        return (byteCount, modificationDate)
    }

    private static func sha256(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        return hasher.finalize().map {
            String(format: "%02x", $0)
        }.joined()
    }
}

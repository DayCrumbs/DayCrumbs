import Foundation
import SwiftData

nonisolated enum LocalModelInstallationStatus: String, Codable, Sendable {
    case installed
    case invalid
}

/// SwiftData stores only small installation metadata, never model bytes.
@Model
final class LocalModelInstallation {
    var descriptorID: String
    var relativeFilePath: String
    var validatedByteCount: Int64
    var validatedSHA256: String
    private var statusRawValue: String
    var validatedAt: Date
    var validatedFileModificationDate: Date?

    var status: LocalModelInstallationStatus {
        get {
            LocalModelInstallationStatus(rawValue: statusRawValue) ?? .invalid
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    init(
        descriptorID: String,
        relativeFilePath: String,
        validatedByteCount: Int64,
        validatedSHA256: String,
        status: LocalModelInstallationStatus,
        validatedAt: Date = .now,
        validatedFileModificationDate: Date? = nil
    ) {
        self.descriptorID = descriptorID
        self.relativeFilePath = relativeFilePath
        self.validatedByteCount = validatedByteCount
        self.validatedSHA256 = validatedSHA256
        self.statusRawValue = status.rawValue
        self.validatedAt = validatedAt
        self.validatedFileModificationDate = validatedFileModificationDate
    }
}

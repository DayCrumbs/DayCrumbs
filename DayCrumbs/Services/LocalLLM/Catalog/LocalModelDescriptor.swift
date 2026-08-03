import Foundation

nonisolated enum LocalModelRuntime: String, Codable, Equatable, Sendable {
    case liteRTLM
}

/// Immutable catalog metadata used to validate a downloadable local model.
nonisolated struct LocalModelDescriptor: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let repository: String
    let downloadURL: URL
    let filename: String
    let expectedByteCount: Int64
    let expectedSHA256: String
    let runtime: LocalModelRuntime
    let licenseIdentifier: String
}

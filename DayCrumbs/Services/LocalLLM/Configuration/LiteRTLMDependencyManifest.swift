import Foundation

/// Pinned native dependency metadata verified against the GitHub release API.
nonisolated enum LiteRTLMDependencyManifest {
    static let version = "0.14.0"
    static let frameworkArchiveName = "CLiteRTLM.xcframework.zip"
    static let frameworkArchiveURL = URL(
        string: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.14.0/CLiteRTLM.xcframework.zip"
    )!

    /// The release asset was replaced on 10 July 2026 after the tag's
    /// Package.swift was created. This is the digest published by GitHub's
    /// immutable release-asset metadata for asset ID 472710399.
    static let frameworkArchiveSHA256 =
        "dddac2f6713ed65eaf01c18e115d9fec22184adf575cc7856a21387e8ba937e1"
    static let licenseIdentifier = "Apache-2.0"
}

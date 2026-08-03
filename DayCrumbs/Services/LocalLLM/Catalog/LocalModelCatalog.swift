import Foundation

/// Production catalog intentionally contains exactly one app-managed model.
nonisolated enum LocalModelCatalog {
    static let gemma4E2B = LocalModelDescriptor(
        id: "gemma-4-e2b-it-litertlm",
        displayName: "Gemma-4-E2B-it",
        repository: "litert-community/gemma-4-E2B-it-litert-lm",
        downloadURL: URL(
            string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
        )!,
        filename: "gemma-4-E2B-it.litertlm",
        expectedByteCount: 2_588_147_712,
        expectedSHA256:
            "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c",
        runtime: .liteRTLM,
        licenseIdentifier: "Apache-2.0"
    )

    static let productionModels = [gemma4E2B]
}

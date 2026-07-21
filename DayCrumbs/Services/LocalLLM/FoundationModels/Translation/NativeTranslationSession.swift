//
//  NativeTranslationSession.swift
//  DayCrumbs
//

/// Framework-neutral request passed to a view-bound session adapter.
nonisolated struct NativeTranslationSessionRequest: Equatable, Sendable {
    let clientIdentifier: String
    let sourceText: String
}

/// Framework-neutral response returned from a view-bound session adapter.
nonisolated struct NativeTranslationSessionResponse: Equatable, Sendable {
    let clientIdentifier: String?
    let targetText: String
}

/// Narrow session surface that allows service tests to avoid real translation assets.
@MainActor
protocol NativeTranslationSession: AnyObject {
    var sourceLanguage: LanguageIdentifier? { get }
    var targetLanguage: LanguageIdentifier? { get }
    var isReady: Bool { get async }

    func prepareTranslation() async throws

    func translations(
        from requests: [NativeTranslationSessionRequest]
    ) async throws -> [NativeTranslationSessionResponse]

    func cancel()
}

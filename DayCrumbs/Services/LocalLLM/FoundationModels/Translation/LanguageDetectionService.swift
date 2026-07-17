//
//  LanguageDetectionService.swift
//  DayCrumbs
//

import Foundation
import NaturalLanguage

/// A framework-neutral BCP-47 language identifier used across the translation layer.
nonisolated struct LanguageIdentifier: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let english = LanguageIdentifier(rawValue: NLLanguage.english.rawValue)
    static let indonesian = LanguageIdentifier(rawValue: NLLanguage.indonesian.rawValue)
}

/// Parent-authored text with a stable identifier supplied by its caller.
nonisolated struct LanguageDetectionRequest: Equatable, Sendable {
    let id: String
    let text: String
}

/// The resolved language for each nonempty request and for the eventual response.
nonisolated struct LanguageDetectionResult: Equatable, Sendable {
    struct Segment: Equatable, Sendable {
        let requestID: String
        let language: LanguageIdentifier
    }

    let responseLanguage: LanguageIdentifier
    let segments: [Segment]
}

nonisolated enum LanguageDetectionError: Error, Equatable, Sendable {
    case duplicateRequestIdentifier(String)
    case undeterminedLanguage
}

/// Detects parent-text languages without coupling callers to Natural Language.
nonisolated protocol LanguageDetectionService: Sendable {
    func detectLanguages(
        in requests: [LanguageDetectionRequest]
    ) throws -> LanguageDetectionResult
}

/// Apple Natural Language implementation used before Apple insight generation.
nonisolated struct NaturalLanguageDetectionService: LanguageDetectionService {
    typealias RecognizeLanguage = @Sendable (String) -> LanguageIdentifier?

    /// Very short notes do not provide enough context for dependable per-field detection.
    private static let minimumIndividualDetectionWordCount = 3

    private let recognizeLanguage: RecognizeLanguage

    init() {
        recognizeLanguage = { text in
            NLLanguageRecognizer.dominantLanguage(for: text).map {
                LanguageIdentifier(rawValue: $0.rawValue)
            }
        }
    }

    /// Internal injection keeps language-policy tests independent of OS model changes.
    init(recognizeLanguage: @escaping RecognizeLanguage) {
        self.recognizeLanguage = recognizeLanguage
    }

    func detectLanguages(
        in requests: [LanguageDetectionRequest]
    ) throws -> LanguageDetectionResult {
        try validateUniqueIdentifiers(in: requests)

        let nonemptyRequests = requests.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Structured analytics contains enough English context when no parent text exists.
        guard !nonemptyRequests.isEmpty else {
            return LanguageDetectionResult(
                responseLanguage: .english,
                segments: []
            )
        }

        let combinedText = nonemptyRequests
            .map(\.text)
            .joined(separator: "\n")
        guard let responseLanguage = recognizeLanguage(combinedText) else {
            throw LanguageDetectionError.undeterminedLanguage
        }

        let segments = nonemptyRequests.map { request in
            let language = individuallyDetectedLanguage(for: request.text)
                ?? responseLanguage
            return LanguageDetectionResult.Segment(
                requestID: request.id,
                language: language
            )
        }

        return LanguageDetectionResult(
            responseLanguage: responseLanguage,
            segments: segments
        )
    }

    private func individuallyDetectedLanguage(
        for text: String
    ) -> LanguageIdentifier? {
        guard wordCount(in: text) >= Self.minimumIndividualDetectionWordCount else {
            return nil
        }
        return recognizeLanguage(text)
    }

    private func wordCount(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.byWords, .substringNotRequired]
        ) { _, _, _, _ in
            count += 1
        }
        return count
    }

    private func validateUniqueIdentifiers(
        in requests: [LanguageDetectionRequest]
    ) throws {
        var identifiers: Set<String> = []
        for request in requests {
            guard identifiers.insert(request.id).inserted else {
                throw LanguageDetectionError.duplicateRequestIdentifier(request.id)
            }
        }
    }
}

import Foundation
import NaturalLanguage

/// The language Gemma must use for every user-visible value in its JSON output.
///
/// Gemma receives the original analytics context. This type controls generation
/// language only and does not invoke Apple's translation pipeline.
nonisolated struct GemmaResponseLanguage: Equatable, Sendable {
    let identifier: String
    let englishName: String

    static let english = GemmaResponseLanguage(
        identifier: NLLanguage.english.rawValue,
        englishName: "English"
    )

    static let indonesian = GemmaResponseLanguage(
        identifier: NLLanguage.indonesian.rawValue,
        englishName: "Indonesian"
    )

    var baseIdentifier: String {
        identifier
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init)?
            .lowercased()
            ?? identifier.lowercased()
    }

    init(identifier: String) {
        let normalizedIdentifier = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.identifier = normalizedIdentifier
        let baseIdentifier = normalizedIdentifier
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init)?
            .lowercased()
            ?? normalizedIdentifier.lowercased()
        englishName = Locale(identifier: "en_US_POSIX")
            .localizedString(forLanguageCode: baseIdentifier)?
            .capitalized
            ?? normalizedIdentifier
    }

    private init(identifier: String, englishName: String) {
        self.identifier = identifier
        self.englishName = englishName
    }
}

/// Resolves one explicit response language from parent-authored Gemma input.
nonisolated struct GemmaResponseLanguageResolver: Sendable {
    typealias RecognizeLanguage = @Sendable (String) -> String?

    private let recognizeLanguage: RecognizeLanguage

    init() {
        recognizeLanguage = {
            NLLanguageRecognizer.dominantLanguage(for: $0)?.rawValue
        }
    }

    init(recognizeLanguage: @escaping RecognizeLanguage) {
        self.recognizeLanguage = recognizeLanguage
    }

    func resolve(from context: AnalyticsContext) -> GemmaResponseLanguage {
        let parentTexts = context.events.compactMap(\.afterActivityNote)
            + context.reflections.map(\.content)
        return resolve(from: parentTexts)
    }

    func resolve(from insight: AnalyticsInsight) -> GemmaResponseLanguage {
        var generatedTexts = [
            insight.summary,
            insight.parentReflectionPrompt,
            insight.ethicalNote,
        ]
        generatedTexts += insight.commonTriggers.flatMap {
            [$0.title, $0.explanation]
        }
        generatedTexts += insight.observedPatterns.flatMap {
            // Context tags may intentionally preserve canonical structured labels
            // such as "sleep" and "house", so they are not language evidence.
            [$0.title, $0.evidence]
        }
        generatedTexts += insight.parentSuggestions.flatMap {
            [$0.title] + $0.recommendedActivities + $0.whatMayHelp
        }
        return resolve(from: generatedTexts)
    }

    private func resolve(from texts: [String]) -> GemmaResponseLanguage {
        let combinedText = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !combinedText.isEmpty,
              let identifier = recognizeLanguage(combinedText),
              identifier != "und" else {
            return .english
        }
        return GemmaResponseLanguage(identifier: identifier)
    }
}

nonisolated enum GemmaInsightLanguageValidationError:
    Error,
    Equatable,
    Sendable
{
    case mismatchedLanguage(expected: String, actual: String)
}

/// Rejects a decoded response that ignored Gemma's explicit language contract.
nonisolated struct GemmaInsightLanguageValidator: Sendable {
    typealias RecognizeLanguage = @Sendable (String) -> String?

    private let recognizeLanguage: RecognizeLanguage

    init() {
        recognizeLanguage = {
            NLLanguageRecognizer.dominantLanguage(for: $0)?.rawValue
        }
    }

    init(recognizeLanguage: @escaping RecognizeLanguage) {
        self.recognizeLanguage = recognizeLanguage
    }

    func validate(
        _ insight: AnalyticsInsight,
        expected: GemmaResponseLanguage
    ) throws {
        let detected = GemmaResponseLanguageResolver(
            recognizeLanguage: recognizeLanguage
        ).resolve(from: insight)

        guard detected.baseIdentifier == expected.baseIdentifier else {
            throw GemmaInsightLanguageValidationError.mismatchedLanguage(
                expected: expected.baseIdentifier,
                actual: detected.baseIdentifier
            )
        }
    }
}

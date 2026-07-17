import Foundation
import Testing
import Translation

@testable import DayCrumbs

@Suite("Analytics translation coordinator")
@MainActor
struct AnalyticsTranslationCoordinatorTests {
    @Test("Indonesian parent text becomes English without changing structured context")
    func translatesOnlyParentTextAndPreservesContext() async throws {
        let originalContext = makeContext(
            eventNotes: ["Anak bermain dengan tenang", nil],
            reflections: ["Rutinitas malam terasa lebih mudah"]
        )
        let detector = StubLanguageDetectionService(
            responseLanguage: .indonesian,
            languagesByText: [
                "Anak bermain dengan tenang": .indonesian,
                "Rutinitas malam terasa lebih mudah": .indonesian,
            ]
        )
        let translator = BatchTranslatorFake(
            translationsBySourceText: [
                "Anak bermain dengan tenang": "The child played calmly",
                "Rutinitas malam terasa lebih mudah": "The evening routine felt easier",
            ]
        )
        let coordinator = makeCoordinator(detector: detector)

        let result = try await coordinator.translateInputContext(
            originalContext,
            using: translator.handler
        )

        #expect(result.responseLanguage == .indonesian)
        #expect(result.didTranslateParentText)
        #expect(result.englishContext.child == originalContext.child)
        #expect(result.englishContext.events.map(\.recordedAt) == originalContext.events.map(\.recordedAt))
        #expect(result.englishContext.events.map(\.session) == originalContext.events.map(\.session))
        #expect(result.englishContext.events.map(\.mood) == originalContext.events.map(\.mood))
        #expect(result.englishContext.events.map(\.activity) == originalContext.events.map(\.activity))
        #expect(result.englishContext.events.map(\.place) == originalContext.events.map(\.place))
        #expect(result.englishContext.events.map(\.afterActivityNote) == [
            "The child played calmly", nil,
        ])
        #expect(result.englishContext.reflections.map(\.sessionStartedAt) == originalContext.reflections.map(\.sessionStartedAt))
        #expect(result.englishContext.reflections.map(\.content) == [
            "The evening routine felt easier",
        ])

        // AnalyticsContext has value semantics, so Apple preparation cannot mutate its input.
        #expect(originalContext == makeContext(
            eventNotes: ["Anak bermain dengan tenang", nil],
            reflections: ["Rutinitas malam terasa lebih mudah"]
        ))
        #expect(translator.batches.count == 1)
        #expect(translator.batches[0].pair == TranslationLanguagePair(
            source: .indonesian,
            target: .english
        ))
    }

    @Test("English parent text bypasses native translation")
    func englishInputBypassesTranslation() async throws {
        let context = makeContext(
            eventNotes: ["The child played calmly", nil],
            reflections: ["The evening routine felt easier"]
        )
        let detector = StubLanguageDetectionService(
            responseLanguage: .english,
            languagesByText: [
                "The child played calmly": .english,
                "The evening routine felt easier": .english,
            ]
        )
        let translator = BatchTranslatorFake(translationsBySourceText: [:])

        let result = try await makeCoordinator(detector: detector)
            .translateInputContext(context, using: translator.handler)

        #expect(result.englishContext == context)
        #expect(result.responseLanguage == .english)
        #expect(!result.didTranslateParentText)
        #expect(translator.batches.isEmpty)
    }

    @Test("Mixed source languages use separate ordered batches")
    func mixedLanguagesUseSeparateBatches() async throws {
        let spanish = LanguageIdentifier(rawValue: "es")
        let context = makeContext(
            eventNotes: [
                "Anak bermain dengan tenang",
                "Jugó tranquilamente afuera",
            ],
            reflections: ["The evening routine felt easier"]
        )
        let detector = StubLanguageDetectionService(
            responseLanguage: .indonesian,
            languagesByText: [
                "Anak bermain dengan tenang": .indonesian,
                "Jugó tranquilamente afuera": spanish,
                "The evening routine felt easier": .english,
            ]
        )
        let translator = BatchTranslatorFake(
            translationsBySourceText: [
                "Anak bermain dengan tenang": "The child played calmly",
                "Jugó tranquilamente afuera": "The child played calmly outside",
            ]
        )

        let result = try await makeCoordinator(detector: detector)
            .translateInputContext(context, using: translator.handler)

        #expect(translator.batches.map(\.pair.source) == [.indonesian, spanish])
        #expect(translator.batches.allSatisfy { batch in
            batch.requests.allSatisfy { request in
                request.sourceLanguage == batch.pair.source
            }
        })
        #expect(result.englishContext.events.map(\.afterActivityNote) == [
            "The child played calmly",
            "The child played calmly outside",
        ])
        #expect(result.englishContext.reflections.map(\.content) == [
            "The evening routine felt easier",
        ])
        #expect(result.responseLanguage == .indonesian)
    }

    @Test("Missing optional parent text needs no detection assets or translation")
    func emptyParentTextBypassesTranslation() async throws {
        let context = makeContext(eventNotes: [nil, nil], reflections: [])
        let detector = StubLanguageDetectionService(
            responseLanguage: .english,
            languagesByText: [:]
        )
        let translator = BatchTranslatorFake(translationsBySourceText: [:])

        let result = try await makeCoordinator(detector: detector)
            .translateInputContext(context, using: translator.handler)

        #expect(result == AnalyticsInputTranslation(
            englishContext: context,
            responseLanguage: .english,
            didTranslateParentText: false
        ))
        #expect(translator.batches.isEmpty)
    }

    @Test("Generic reverse translation restores identified-text ordering")
    func reverseTranslationRestoresOrdering() async throws {
        let texts = [
            IdentifiedTranslationText(id: "summary", text: "A possible pattern"),
            IdentifiedTranslationText(id: "reflection", text: "What changed today?"),
        ]
        let translator = BatchTranslatorFake(
            translationsBySourceText: [
                "A possible pattern": "Pola yang mungkin",
                "What changed today?": "Apa yang berubah hari ini?",
            ],
            reversesResponses: true
        )

        let translated = try await makeCoordinator(
            detector: StubLanguageDetectionService(
                responseLanguage: .english,
                languagesByText: [:]
            )
        ).translateIdentifiedTexts(
            texts,
            from: .english,
            to: .indonesian,
            using: translator.handler
        )

        #expect(translated == [
            IdentifiedTranslationText(id: "summary", text: "Pola yang mungkin"),
            IdentifiedTranslationText(id: "reflection", text: "Apa yang berubah hari ini?"),
        ])
        #expect(translator.batches.count == 1)
        #expect(translator.batches[0].pair == TranslationLanguagePair(
            source: .english,
            target: .indonesian
        ))
    }

    @Test("Reverse translation bypasses matching source and target languages")
    func reverseTranslationBypassesMatchingLanguage() async throws {
        let texts = [IdentifiedTranslationText(id: "summary", text: "Already English")]
        let translator = BatchTranslatorFake(translationsBySourceText: [:])

        let translated = try await makeCoordinator(
            detector: StubLanguageDetectionService(
                responseLanguage: .english,
                languagesByText: [:]
            )
        ).translateIdentifiedTexts(
            texts,
            from: .english,
            to: .english,
            using: translator.handler
        )

        #expect(translated == texts)
        #expect(translator.batches.isEmpty)
    }

    @Test("Missing translated fields return a typed reconstruction error")
    func missingTranslationIsRejected() async throws {
        let context = makeContext(
            eventNotes: ["Anak bermain dengan tenang", nil],
            reflections: []
        )
        let detector = StubLanguageDetectionService(
            responseLanguage: .indonesian,
            languagesByText: ["Anak bermain dengan tenang": .indonesian]
        )
        let translator = BatchTranslatorFake(
            translationsBySourceText: [:],
            omitsUnknownTranslations: true
        )

        await #expect(
            throws: AnalyticsTranslationError.missingTranslation("event-note-0")
        ) {
            try await makeCoordinator(detector: detector)
                .translateInputContext(context, using: translator.handler)
        }
    }

    @Test("Incomplete detection results return a typed reconstruction error")
    func missingDetectionIsRejected() async throws {
        let context = makeContext(
            eventNotes: ["Anak bermain dengan tenang", nil],
            reflections: []
        )
        let detector = FixedResultLanguageDetectionService(
            result: LanguageDetectionResult(
                responseLanguage: .indonesian,
                segments: []
            )
        )
        let translator = BatchTranslatorFake(translationsBySourceText: [:])

        await #expect(
            throws: AnalyticsTranslationError.missingDetectedLanguage("event-note-0")
        ) {
            try await makeCoordinator(detector: detector)
                .translateInputContext(context, using: translator.handler)
        }
    }

    private func makeCoordinator(
        detector: any LanguageDetectionService
    ) -> AnalyticsTranslationCoordinator {
        AnalyticsTranslationCoordinator(
            languageDetectionService: detector,
            nativeTranslationService: AppleNativeTranslationService { _ in .installed }
        )
    }

    private func makeContext(
        eventNotes: [String?],
        reflections: [String]
    ) -> AnalyticsContext {
        let eventDates = [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 200),
        ]
        let events = eventNotes.enumerated().map { index, note in
            AnalyticsContext.Event(
                recordedAt: eventDates[index],
                session: index == 0 ? Sessions.morning.rawValue : Sessions.evening.rawValue,
                mood: index == 0 ? Moods.happy.rawValue : Moods.surprise.rawValue,
                activity: index == 0
                    ? Activity.BuiltInActivity.play.rawValue
                    : "Finger painting",
                place: index == 0
                    ? Place.BuiltInPlace.outdoor.rawValue
                    : "Art room",
                afterActivityNote: note
            )
        }
        let contextReflections = reflections.enumerated().map { index, content in
            AnalyticsContext.Reflection(
                sessionStartedAt: Date(
                    timeIntervalSince1970: 300 + TimeInterval(index)
                ),
                content: content
            )
        }

        return AnalyticsContext(
            child: AnalyticsContext.Child(
                name: "Ari",
                age: 3,
                gender: ChildGender.boy.rawValue
            ),
            events: events,
            reflections: contextReflections
        )
    }
}

nonisolated private struct StubLanguageDetectionService: LanguageDetectionService {
    let responseLanguage: LanguageIdentifier
    let languagesByText: [String: LanguageIdentifier]

    func detectLanguages(
        in requests: [LanguageDetectionRequest]
    ) throws -> LanguageDetectionResult {
        let segments = try requests.map { request in
            guard let language = languagesByText[request.text] else {
                throw LanguageDetectionError.undeterminedLanguage
            }
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
}

nonisolated private struct FixedResultLanguageDetectionService: LanguageDetectionService {
    let result: LanguageDetectionResult

    func detectLanguages(
        in requests: [LanguageDetectionRequest]
    ) throws -> LanguageDetectionResult {
        result
    }
}

@MainActor
private final class BatchTranslatorFake {
    private(set) var batches: [NativeTranslationBatch] = []

    private let translationsBySourceText: [String: String]
    private let reversesResponses: Bool
    private let omitsUnknownTranslations: Bool

    init(
        translationsBySourceText: [String: String],
        reversesResponses: Bool = false,
        omitsUnknownTranslations: Bool = false
    ) {
        self.translationsBySourceText = translationsBySourceText
        self.reversesResponses = reversesResponses
        self.omitsUnknownTranslations = omitsUnknownTranslations
    }

    var handler: NativeTranslationBatchHandler {
        { [self] batch in
            try translate(batch)
        }
    }

    private func translate(
        _ batch: NativeTranslationBatch
    ) throws -> [NativeTranslatedText] {
        batches.append(batch)
        var responses: [NativeTranslatedText] = try batch.requests.compactMap { request in
            guard let translation = translationsBySourceText[request.text] else {
                if omitsUnknownTranslations {
                    return nil
                }
                throw LanguageDetectionError.undeterminedLanguage
            }
            return NativeTranslatedText(id: request.id, text: translation)
        }
        if reversesResponses {
            responses.reverse()
        }
        return responses
    }
}

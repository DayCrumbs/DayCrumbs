import Testing

@testable import DayCrumbs

@Suite("Language detection service")
struct LanguageDetectionServiceTests {
    @Test("No parent text defaults the response to English")
    func emptyParentTextDefaultsToEnglish() throws {
        let service = makeService { _ in .indonesian }

        let result = try service.detectLanguages(
            in: [
                LanguageDetectionRequest(id: "note-1", text: "  \n "),
                LanguageDetectionRequest(id: "reflection-1", text: ""),
            ]
        )

        #expect(result.responseLanguage == .english)
        #expect(result.segments.isEmpty)
    }

    @Test("Combined parent text controls the response language")
    func combinedTextControlsResponseLanguage() throws {
        let indonesianNote = "Anak bermain dengan tenang pagi ini"
        let englishReflection = "The bedtime routine felt much easier tonight"
        let service = makeService { text in
            switch text {
            case "\(indonesianNote)\n\(englishReflection)": .indonesian
            case indonesianNote: .indonesian
            case englishReflection: .english
            default: nil
            }
        }

        let result = try service.detectLanguages(
            in: [
                LanguageDetectionRequest(id: "note-1", text: indonesianNote),
                LanguageDetectionRequest(id: "reflection-1", text: englishReflection),
            ]
        )

        #expect(result.responseLanguage == .indonesian)
        #expect(
            result.segments == [
                .init(requestID: "note-1", language: .indonesian),
                .init(requestID: "reflection-1", language: .english),
            ]
        )
    }

    @Test("Short and undetermined segments inherit the combined language")
    func unresolvedSegmentsInheritCombinedLanguage() throws {
        let longText = "Hari ini anak bermain bersama dengan gembira"
        let undeterminedText = "Words long enough but intentionally unresolved"
        let service = makeService { text in
            switch text {
            case "\(longText)\nOK\n\(undeterminedText)": .indonesian
            case longText: .indonesian
            default: nil
            }
        }

        let result = try service.detectLanguages(
            in: [
                LanguageDetectionRequest(id: "note-1", text: longText),
                LanguageDetectionRequest(id: "note-2", text: "OK"),
                LanguageDetectionRequest(id: "reflection-1", text: undeterminedText),
            ]
        )

        #expect(result.segments.map(\.language) == [
            .indonesian,
            .indonesian,
            .indonesian,
        ])
    }

    @Test("Nonempty text without a detectable language returns a typed error")
    func undeterminedTextThrows() {
        let service = makeService { _ in nil }

        #expect(throws: LanguageDetectionError.undeterminedLanguage) {
            try service.detectLanguages(
                in: [LanguageDetectionRequest(id: "note-1", text: "12345")]
            )
        }
    }

    @Test("Duplicate identifiers are rejected before field reconstruction")
    func duplicateIdentifiersThrow() {
        let service = makeService { _ in .english }

        #expect(
            throws: LanguageDetectionError.duplicateRequestIdentifier("note-1")
        ) {
            try service.detectLanguages(
                in: [
                    LanguageDetectionRequest(id: "note-1", text: "First note"),
                    LanguageDetectionRequest(id: "note-1", text: "Second note"),
                ]
            )
        }
    }

    @Test("Natural Language recognizes clear English parent text")
    func recognizesEnglishWithNaturalLanguage() throws {
        let service = NaturalLanguageDetectionService()

        let result = try service.detectLanguages(
            in: [
                LanguageDetectionRequest(
                    id: "reflection-1",
                    text: "The child enjoyed playing outside with the family this morning."
                ),
            ]
        )

        #expect(result.responseLanguage == .english)
        #expect(result.segments.first?.language == .english)
    }

    private func makeService(
        recognition: @escaping NaturalLanguageDetectionService.RecognizeLanguage
    ) -> NaturalLanguageDetectionService {
        NaturalLanguageDetectionService(recognizeLanguage: recognition)
    }
}

import Foundation
import Testing
import Translation

@testable import DayCrumbs

@Suite("Native translation service")
@MainActor
struct NativeTranslationServiceTests {
    private let indonesianToEnglish = TranslationLanguagePair(
        source: .indonesian,
        target: .english
    )

    @Test("Apple availability statuses map to preparation states")
    func availabilityMapping() async {
        let cases: [(
            LanguageAvailability.Status,
            NativeTranslationAvailability,
            NativeTranslationPreparationState
        )] = [
            (.installed, .installed, .ready),
            (.supported, .supported, .downloadRequired),
            (.unsupported, .unsupported, .unsupported),
        ]

        for (appleStatus, expectedAvailability, expectedState) in cases {
            let service = makeService(status: appleStatus)

            let readiness = await service.readiness(for: indonesianToEnglish)

            #expect(readiness.availability == expectedAvailability)
            #expect(readiness.preparationState == expectedState)
            #expect(readiness.pair == indonesianToEnglish)
        }
    }

    @Test("Configuration uses the low-latency source-target pair")
    func lowLatencyConfiguration() {
        let service = makeService()

        let configuration = service.configuration(for: indonesianToEnglish)

        #expect(configuration.source?.minimalIdentifier == "id")
        #expect(configuration.target?.minimalIdentifier == "en")
        #expect(configuration.preferredStrategy == .lowLatency)
    }

    @Test("Mixed-language requests are split into ordered source batches")
    func groupsRequestsBySourceLanguage() throws {
        let spanish = LanguageIdentifier(rawValue: "es")
        let service = makeService()
        let requests = [
            NativeTranslationRequest(
                id: "note-1",
                text: "Anak bermain di luar",
                sourceLanguage: .indonesian
            ),
            NativeTranslationRequest(
                id: "note-2",
                text: "Jugó tranquilamente afuera",
                sourceLanguage: spanish
            ),
            NativeTranslationRequest(
                id: "reflection-1",
                text: "Rutinitas malam terasa lebih mudah",
                sourceLanguage: .indonesian
            ),
        ]

        let batches = try service.makeBatches(
            from: requests,
            targetLanguage: .english
        )

        #expect(batches.map(\.pair.source) == [.indonesian, spanish])
        #expect(batches.allSatisfy { batch in
            batch.requests.allSatisfy {
                $0.sourceLanguage == batch.pair.source
            }
        })
        #expect(batches[0].requests.map(\.id) == ["note-1", "reflection-1"])
        #expect(batches[1].requests.map(\.id) == ["note-2"])
    }

    @Test("Invalid request identifiers and same-language pairs are rejected")
    func invalidRequestsThrow() {
        let service = makeService()

        #expect(throws: NativeTranslationError.emptyRequestIdentifier) {
            try service.makeBatches(
                from: [
                    NativeTranslationRequest(
                        id: " ",
                        text: "Valid text",
                        sourceLanguage: .indonesian
                    ),
                ],
                targetLanguage: .english
            )
        }

        #expect(
            throws: NativeTranslationError.duplicateRequestIdentifier("note-1")
        ) {
            try service.makeBatches(
                from: [
                    NativeTranslationRequest(
                        id: "note-1",
                        text: "First text",
                        sourceLanguage: .indonesian
                    ),
                    NativeTranslationRequest(
                        id: "note-1",
                        text: "Second text",
                        sourceLanguage: .indonesian
                    ),
                ],
                targetLanguage: .english
            )
        }

        #expect(
            throws: NativeTranslationError.identicalSourceAndTarget(.english)
        ) {
            try service.makeBatches(
                from: [
                    NativeTranslationRequest(
                        id: "note-1",
                        text: "Already English",
                        sourceLanguage: .english
                    ),
                ],
                targetLanguage: .english
            )
        }
    }

    @Test("Response identifiers restore original request order")
    func responseIdentifiersRestoreOrder() async throws {
        let service = makeService()
        let batch = try #require(
            try service.makeBatches(
                from: [
                    NativeTranslationRequest(
                        id: "note-1",
                        text: "Catatan pertama",
                        sourceLanguage: .indonesian
                    ),
                    NativeTranslationRequest(
                        id: "reflection-1",
                        text: "Refleksi kedua",
                        sourceLanguage: .indonesian
                    ),
                ],
                targetLanguage: .english
            ).first
        )
        let session = NativeTranslationSessionFake(
            pair: indonesianToEnglish,
            responses: [
                .init(clientIdentifier: "reflection-1", targetText: "Second reflection"),
                .init(clientIdentifier: "note-1", targetText: "First note"),
            ]
        )

        let translations = try await service.translate(batch, using: session)

        #expect(translations == [
            NativeTranslatedText(id: "note-1", text: "First note"),
            NativeTranslatedText(id: "reflection-1", text: "Second reflection"),
        ])
        #expect(session.receivedRequests.map(\.clientIdentifier) == [
            "note-1",
            "reflection-1",
        ])
    }

    @Test("Missing response identifiers fail reconstruction")
    func missingResponseIdentifierThrows() async throws {
        let service = makeService()
        let batch = try #require(
            try service.makeBatches(
                from: [
                    NativeTranslationRequest(
                        id: "note-1",
                        text: "Catatan",
                        sourceLanguage: .indonesian
                    ),
                ],
                targetLanguage: .english
            ).first
        )
        let session = NativeTranslationSessionFake(
            pair: indonesianToEnglish,
            responses: [
                .init(clientIdentifier: nil, targetText: "Note"),
            ]
        )

        await #expect(throws: NativeTranslationError.missingResponseIdentifier) {
            try await service.translate(batch, using: session)
        }
    }

    @Test("Preparation delegates to the matching view-bound session")
    func preparesMatchingSession() async throws {
        let service = makeService()
        let session = NativeTranslationSessionFake(
            pair: indonesianToEnglish,
            responses: []
        )

        let state = try await service.prepareTranslation(
            for: indonesianToEnglish,
            using: session
        )

        #expect(state == .ready)
        #expect(session.prepareCallCount == 1)
    }

    @Test("A session for a different language pair is rejected")
    func mismatchedSessionThrows() async {
        let service = makeService()
        let spanishToEnglish = TranslationLanguagePair(
            source: LanguageIdentifier(rawValue: "es"),
            target: .english
        )
        let session = NativeTranslationSessionFake(
            pair: spanishToEnglish,
            responses: []
        )

        await #expect(
            throws: NativeTranslationError.sessionLanguageMismatch(
                expected: indonesianToEnglish,
                actualSource: spanishToEnglish.source,
                actualTarget: spanishToEnglish.target
            )
        ) {
            try await service.prepareTranslation(
                for: indonesianToEnglish,
                using: session
            )
        }
    }

    private func makeService(
        status: LanguageAvailability.Status = .installed
    ) -> AppleNativeTranslationService {
        AppleNativeTranslationService { _ in status }
    }
}

@MainActor
private final class NativeTranslationSessionFake: NativeTranslationSession {
    let sourceLanguage: LanguageIdentifier?
    let targetLanguage: LanguageIdentifier?
    let isReady = false

    private(set) var prepareCallCount = 0
    private(set) var receivedRequests: [NativeTranslationSessionRequest] = []
    private let responses: [NativeTranslationSessionResponse]

    init(
        pair: TranslationLanguagePair,
        responses: [NativeTranslationSessionResponse]
    ) {
        sourceLanguage = pair.source
        targetLanguage = pair.target
        self.responses = responses
    }

    func prepareTranslation() async throws {
        prepareCallCount += 1
    }

    func translations(
        from requests: [NativeTranslationSessionRequest]
    ) async throws -> [NativeTranslationSessionResponse] {
        receivedRequests = requests
        return responses
    }

    func cancel() {}
}

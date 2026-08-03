import Foundation
import SwiftData
import Testing

@testable import DayCrumbs

@Suite("Gemma-4-E2B production catalog")
struct Gemma4E2BCatalogTests {
    @Test("Production exposes exactly one downloadable model")
    func productionCatalog() throws {
        let models = LocalModelCatalog.productionModels
        let model = try #require(models.first)

        #expect(models.count == 1)
        #expect(model.id == "gemma-4-e2b-it-litertlm")
        #expect(model.displayName == "Gemma-4-E2B-it")
        #expect(
            model.repository
                == "litert-community/gemma-4-E2B-it-litert-lm"
        )
        #expect(model.filename == "gemma-4-E2B-it.litertlm")
        #expect(model.expectedByteCount == 2_588_147_712)
        #expect(
            model.expectedSHA256
                == "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"
        )
        #expect(model.runtime == .liteRTLM)
        #expect(model.licenseIdentifier == "Apache-2.0")
    }

    @Test("Vendored LiteRT-LM dependency remains pinned")
    func dependencyManifest() {
        #expect(LiteRTLMDependencyManifest.version == "0.14.0")
        #expect(
            LiteRTLMDependencyManifest.frameworkArchiveSHA256
                == "dddac2f6713ed65eaf01c18e115d9fec22184adf575cc7856a21387e8ba937e1"
        )
        #expect(LiteRTLMDependencyManifest.licenseIdentifier == "Apache-2.0")
    }
}

@Suite("Gemma analytics JSON parsing")
struct GemmaAnalyticsInsightParserTests {
    private let parser = GemmaAnalyticsInsightParser()

    @Test("Parses a complete compact insight")
    func validInsight() throws {
        let insight = try parser.parse(Self.validJSON)

        #expect(insight.summary == "A possible pattern is easier outdoor play.")
        #expect(insight.commonTriggers.first?.title == "Outdoor play")
        #expect(insight.observedPatterns.first?.linkedTrigger == "Outdoor play")
        #expect(
            insight.parentSuggestions.first?.title
                == "Make an outdoor discovery trail"
        )
        #expect(insight.parentReflectionPrompt == "What felt easiest today?")
    }

    @Test("Extracts JSON from a fenced response without exposing wrapper prose")
    func fencedInsight() throws {
        let insight = try parser.parse(
            "```json\n\(Self.validJSON)\n```"
        )

        #expect(insight.ethicalNote == "This is an observation, not a diagnosis.")
    }

    @Test("Rejects prose without a JSON object")
    func missingJSON() {
        #expect(
            throws: GemmaAnalyticsInsightParsingError.missingJSONObject
        ) {
            try parser.parse("I cannot provide structured output.")
        }
    }

    @Test("Structural repair cannot invent required fields")
    func incompleteJSON() {
        #expect(throws: GemmaAnalyticsInsightParsingError.malformedJSON) {
            try parser.parse(#"{"summary":"Only one field""#)
        }
    }

    @Test("Rejects an incomplete required field")
    func invalidInsight() {
        let invalid = Self.validJSON.replacingOccurrences(
            of: "A possible pattern is easier outdoor play.",
            with: "   "
        )
        #expect(
            throws: GemmaAnalyticsInsightParsingError.invalidInsight(
                .emptySummary
            )
        ) {
            try parser.parse(invalid)
        }
    }

    private static let validJSON = """
        {
          "summary": "A possible pattern is easier outdoor play.",
          "commonTriggers": [
            {
              "title": "Outdoor play",
              "explanation": "The supplied row links outdoor play with happy mood."
            }
          ],
          "observedPatterns": [
            {
              "title": "Happy outdoors",
              "evidence": "One outdoor play entry had happy mood.",
              "linkedTrigger": "Outdoor play",
              "contextTags": ["outdoor", "play", "happy"]
            }
          ],
          "parentSuggestions": [
            {
              "linkedTrigger": "Outdoor play",
              "title": "Make an outdoor discovery trail",
              "recommendedActivities": [
                "Choose three safe objects to spot outside.",
                "Let the child invent a movement for each object."
              ],
              "whatMayHelp": [
                "Keep the activity optional and short.",
                "Notice which part holds the child's interest."
              ]
            }
          ],
          "parentReflectionPrompt": "What felt easiest today?",
          "ethicalNote": "This is an observation, not a diagnosis."
        }
        """
}

@Suite("Gemma prompt transport")
struct GemmaAnalyticsPromptBuilderTests {
    @Test("Separates system policy from one engine-neutral context")
    func promptShape() {
        let context = AnalyticsContext(
            child: .init(name: "Mika", age: 4, gender: "girl"),
            events: [
                .init(
                    recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    session: "afternoon",
                    mood: "happy",
                    activity: "play",
                    place: "outdoor",
                    afterActivityNote: nil
                ),
            ],
            reflections: []
        )

        let prompt = GemmaAnalyticsPromptBuilder().prompt(
            from: context,
            for: .day
        )

        #expect(
            prompt.systemInstructions.contains(AnalyticsSystemPrompt.text)
        )
        #expect(
            prompt.systemInstructions.contains(
                "Required language: English"
            )
        )
        #expect(prompt.userPrompt.contains("ANALYTICS_CONTEXT"))
        #expect(prompt.userPrompt.contains("name: Mika"))
        #expect(prompt.userPrompt.contains("session: afternoon"))
        #expect(prompt.userPrompt.contains("under 512 tokens"))
        #expect(prompt.userPrompt.contains("OUTPUT_LANGUAGE"))
        #expect(prompt.userPrompt.contains("\"parentSuggestions\""))
        #expect(prompt.userPrompt.contains("safe, age-appropriate, low-cost"))
        #expect(
            prompt.userPrompt.contains(
                "Create varied but concise contextual suggestions."
            )
        )
        #expect(
            prompt.userPrompt.contains(
                "Write every user-visible JSON string in English"
            )
        )
        #expect(!prompt.userPrompt.contains(AnalyticsSystemPrompt.text))
    }

    @Test("Indonesian is an explicit system and JSON language contract")
    func indonesianPromptContract() {
        let context = AnalyticsContext(
            child: .init(name: "Rangga", age: 4, gender: "boy"),
            events: [
                .init(
                    recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    session: "night",
                    mood: "fear",
                    activity: "sleep",
                    place: "house",
                    afterActivityNote:
                        "Rangga takut setelah mendengar cerita hantu."
                ),
            ],
            reflections: []
        )

        let prompt = GemmaAnalyticsPromptBuilder().prompt(
            from: context,
            for: .day,
            responseLanguage: .indonesian
        )

        #expect(
            prompt.systemInstructions.contains(
                "Required language: Indonesian"
            )
        )
        #expect(prompt.userPrompt.contains("BCP-47 identifier: id"))
        #expect(
            prompt.userPrompt.contains(
                "Satu paragraf ringkas berdasarkan data yang diberikan."
            )
        )
        #expect(
            !prompt.userPrompt.contains(
                "predominant language used in the supplied parent-authored notes"
            )
        )
    }
}

@Suite("Gemma response language")
struct GemmaResponseLanguageTests {
    @Test("Production resolver recognizes representative Indonesian input")
    func productionResolverRecognizesIndonesian() {
        let context = AnalyticsContext(
            child: .init(name: "Rangga", age: 4, gender: "boy"),
            events: [
                .init(
                    recordedAt: .now,
                    session: "night",
                    mood: "fear",
                    activity: "sleep",
                    place: "house",
                    afterActivityNote:
                        "Rangga takut setelah mendengar cerita hantu sebelum tidur."
                ),
            ],
            reflections: [
                .init(
                    sessionStartedAt: .now,
                    content:
                        "Hari ini kami mencoba memahami perasaannya dengan tenang."
                ),
            ]
        )

        #expect(
            GemmaResponseLanguageResolver().resolve(from: context)
                == .indonesian
        )
    }

    @Test("Parent-authored Indonesian resolves to an explicit target")
    func resolvesIndonesianInput() {
        let resolver = GemmaResponseLanguageResolver { _ in "id" }
        let context = AnalyticsContext(
            child: .init(name: "Rangga", age: 4, gender: "boy"),
            events: [
                .init(
                    recordedAt: .now,
                    session: "night",
                    mood: "fear",
                    activity: "sleep",
                    place: "house",
                    afterActivityNote:
                        "Rangga takut setelah mendengar cerita hantu."
                ),
            ],
            reflections: []
        )

        #expect(resolver.resolve(from: context) == .indonesian)
    }

    @Test("Structured-only input keeps the existing English fallback")
    func structuredInputFallsBackToEnglish() {
        let resolver = GemmaResponseLanguageResolver { _ in nil }
        let context = AnalyticsContext(
            child: .init(name: "Rangga", age: 4, gender: "boy"),
            events: [
                .init(
                    recordedAt: .now,
                    session: "night",
                    mood: "fear",
                    activity: "sleep",
                    place: "house",
                    afterActivityNote: nil
                ),
            ],
            reflections: []
        )

        #expect(resolver.resolve(from: context) == .english)
    }
}

@Suite("Local Gemma file storage")
struct LocalModelStorageTests {
    @Test("Finalization checks byte count and SHA-256 before installation")
    func validatesAndFinalizes() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let storage = LocalModelStorage(applicationSupportDirectory: root)
        let descriptor = LocalModelDescriptor(
            id: "test-gemma",
            displayName: "Test Gemma",
            repository: "local/test",
            downloadURL: URL(string: "https://example.invalid/model")!,
            filename: "test.litertlm",
            expectedByteCount: 5,
            expectedSHA256:
                "3fb22a5597fb91ee4f9abbf30ea69d318be150e0fcf3ca1db8ca334b520d2894",
            runtime: .liteRTLM,
            licenseIdentifier: "Apache-2.0"
        )
        defer {
            try? fileManager.removeItem(at: root)
        }

        try storage.resetPartialFile(for: descriptor)
        try Data("gemma".utf8).write(
            to: storage.partialFileURL(for: descriptor)
        )
        let validation = try await storage.finalizePartialFile(
            for: descriptor
        )
        let identity = try storage.finalFileIdentity(for: descriptor)
        let finalURL = try storage.finalFileURL(for: descriptor)
        let partialURL = try storage.partialFileURL(for: descriptor)

        #expect(validation.byteCount == 5)
        #expect(validation.sha256 == descriptor.expectedSHA256)
        #expect(identity.byteCount == 5)
        #expect(identity.modificationDate == validation.modificationDate)
        #expect(
            fileManager.fileExists(
                atPath: finalURL.path
            )
        )
        #expect(
            !fileManager.fileExists(
                atPath: partialURL.path
            )
        )
    }

    @Test("A wrong final size is rejected before hashing")
    func rejectsWrongSize() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let storage = LocalModelStorage(applicationSupportDirectory: root)
        let descriptor = LocalModelDescriptor(
            id: "test-gemma",
            displayName: "Test Gemma",
            repository: "local/test",
            downloadURL: URL(string: "https://example.invalid/model")!,
            filename: "test.litertlm",
            expectedByteCount: 5,
            expectedSHA256: String(repeating: "0", count: 64),
            runtime: .liteRTLM,
            licenseIdentifier: "Apache-2.0"
        )
        defer {
            try? fileManager.removeItem(at: root)
        }

        try storage.prepareDirectory(for: descriptor)
        try Data("bad".utf8).write(
            to: storage.finalFileURL(for: descriptor)
        )

        await #expect(
            throws: LocalModelStorageError.unexpectedByteCount(
                expected: 5,
                actual: 3
            )
        ) {
            try await storage.validateFinalFile(for: descriptor)
        }
    }
}

@Suite("Gemma model download", .serialized)
@MainActor
struct LocalModelDownloadServiceTests {
    @Test("Streams, reports progress, verifies, and finalizes a download")
    func completeDownload() async throws {
        let fixture = try DownloadFixture()
        defer {
            fixture.cleanUp()
        }
        URLProtocolStub.handler = { request in
            let response = try #require(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Length": "5"]
                )
            )
            return (response, Data("gemma".utf8))
        }
        var progressValues: [Int64] = []

        let validation = try await fixture.service.download(
            fixture.descriptor
        ) { completed, _ in
            progressValues.append(completed)
        }

        #expect(validation.sha256 == fixture.descriptor.expectedSHA256)
        #expect(progressValues.first == 0)
        #expect(progressValues.last == 5)
        #expect(
            fixture.fileManager.fileExists(
                atPath: validation.fileURL.path
            )
        )
    }

    @Test("Resumes a partial file only from the validated byte boundary")
    func resumedDownload() async throws {
        let fixture = try DownloadFixture()
        defer {
            fixture.cleanUp()
        }
        try fixture.storage.resetPartialFile(for: fixture.descriptor)
        try Data("ge".utf8).write(
            to: fixture.storage.partialFileURL(for: fixture.descriptor)
        )
        URLProtocolStub.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Range") == "bytes=2-")
            let response = try #require(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 206,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Length": "3",
                        "Content-Range": "bytes 2-4/5",
                    ]
                )
            )
            return (response, Data("mma".utf8))
        }

        let validation = try await fixture.service.download(
            fixture.descriptor
        ) { _, _ in }

        #expect(validation.byteCount == 5)
        #expect(
            try Data(contentsOf: validation.fileURL)
                == Data("gemma".utf8)
        )
    }
}

private struct DownloadFixture {
    let fileManager = FileManager.default
    let root: URL
    let descriptor: LocalModelDescriptor
    let storage: LocalModelStorage
    let service: URLSessionLocalModelDownloadService

    init() throws {
        root = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        descriptor = LocalModelDescriptor(
            id: "download-test-gemma",
            displayName: "Test Gemma",
            repository: "local/test",
            downloadURL: URL(string: "https://example.test/model")!,
            filename: "test.litertlm",
            expectedByteCount: 5,
            expectedSHA256:
                "3fb22a5597fb91ee4f9abbf30ea69d318be150e0fcf3ca1db8ca334b520d2894",
            runtime: .liteRTLM,
            licenseIdentifier: "Apache-2.0"
        )
        storage = LocalModelStorage(applicationSupportDirectory: root)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        service = URLSessionLocalModelDownloadService(
            storage: storage,
            session: URLSession(configuration: configuration),
            progressUpdateByteInterval: 1
        )
    }

    func cleanUp() {
        URLProtocolStub.handler = nil
        try? fileManager.removeItem(at: root)
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler:
        ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.unknown)
            )
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("Analysis engine resolution")
@MainActor
struct AnalysisEngineResolverTests {
    @Test("Apple availability wins without touching Gemma storage")
    func appleFirst() async throws {
        let validator = InstallationValidatorFake(result: .success(nil))
        let resolver = AnalysisEngineResolver(
            installationValidator: validator,
            appleAvailability: { .available }
        )

        let resolution = try await resolver.resolveEngine()

        #expect(resolution == .appleFoundationModels)
        #expect(validator.callCount == 0)
    }

    @Test("Validated Gemma is selected only when Apple is unavailable")
    func gemmaFallback() async throws {
        let installation = ValidatedLocalModelInstallation(
            descriptor: LocalModelCatalog.gemma4E2B,
            fileURL: URL(filePath: "/tmp/gemma-4-E2B-it.litertlm")
        )
        let validator = InstallationValidatorFake(
            result: .success(installation)
        )
        let resolver = AnalysisEngineResolver(
            installationValidator: validator,
            appleAvailability: { .modelNotReady }
        )

        let resolution = try await resolver.resolveEngine()

        #expect(resolution == .gemma(installation))
        #expect(validator.callCount == 1)
    }

    @Test("Unavailable engines request the model download")
    func missingGemma() async {
        let validator = InstallationValidatorFake(result: .success(nil))
        let resolver = AnalysisEngineResolver(
            installationValidator: validator,
            appleAvailability: { .deviceNotEligible }
        )

        await #expect(
            throws: AnalysisEngineResolutionError.modelDownloadRequired
        ) {
            try await resolver.resolveEngine()
        }
    }
}

@Suite("Dashboard private insights setup")
@MainActor
struct DashboardPrivateInsightsSetupTests {
    @Test("Unavailable Apple intelligence and missing files require setup")
    func unavailableAppleRequiresSetup() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer {
            try? fileManager.removeItem(at: root)
        }
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let viewModel = ModelsViewModel(
            modelContext: container.mainContext,
            storage: LocalModelStorage(applicationSupportDirectory: root),
            appleAvailability: { .deviceNotEligible },
            appleReadinessMessage: { "Unavailable" }
        )

        await viewModel.refresh()

        #expect(viewModel.gemmaState == .notInstalled)
        #expect(viewModel.requiresPrivateInsightsSetup)
    }

    @Test("Available Apple intelligence never asks for fallback setup")
    func availableAppleSkipsSetup() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer {
            try? fileManager.removeItem(at: root)
        }
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let viewModel = ModelsViewModel(
            modelContext: container.mainContext,
            storage: LocalModelStorage(applicationSupportDirectory: root),
            appleAvailability: { .available },
            appleReadinessMessage: { "Ready" }
        )

        await viewModel.refresh()

        #expect(!viewModel.requiresPrivateInsightsSetup)
    }

    @Test("Gemma Dashboard path never calls Apple translation")
    func gemmaBypassesTranslation() async throws {
        let insight = try AnalyticsInsight(
            validatingSummary: "Observasi terbatas dari data hari ini.",
            commonTriggers: [
                .init(
                    title: "Cerita seram sebelum tidur",
                    explanation:
                        "Rasa takut terlihat setelah cerita seram."
                ),
            ],
            observedPatterns: [
                .init(
                    title: "Takut menjelang tidur",
                    evidence:
                        "Catatan menghubungkan cerita hantu dengan rasa takut.",
                    linkedTrigger: "Cerita seram sebelum tidur",
                    contextTags: ["sleep", "house"]
                ),
            ],
            parentReflectionPrompt: "Apa lagi yang Anda amati?",
            ethicalNote: "Ini adalah observasi, bukan diagnosis."
        )
        let installation = ValidatedLocalModelInstallation(
            descriptor: LocalModelCatalog.gemma4E2B,
            fileURL: URL(filePath: "/tmp/private-insights.litertlm")
        )
        let resolver = AnalysisEngineResolverFake(
            resolution: .gemma(installation)
        )
        let apple = AppleLocalizedInsightGeneratorFailingFake()
        let gemma = GemmaInsightGeneratorFake(insight: insight)
        let service = DefaultDashboardInsightGenerationService(
            resolver: resolver,
            appleService: apple,
            gemmaService: gemma
        )
        var translationCallCount = 0
        let entries = makeGemmaEntries(count: 1)

        let result = try await service.generateInsight(
            from: entries,
            for: .day
        ) { _, _ in
            translationCallCount += 1
            return []
        }

        #expect(result.engine == .gemma4E2B)
        #expect(result.insight == insight)
        #expect(gemma.generateCallCount == 1)
        #expect(apple.generateCallCount == 0)
        #expect(translationCallCount == 0)
        #expect(result.triggerDetails.first?.sectionLabels == .indonesian)
        #expect(
            result.triggerDetails.first?.recommendationTitle
                == "Amati dan bangun koneksi"
        )
    }
}

@MainActor
private final class AnalysisEngineResolverFake: AnalysisEngineResolving {
    let resolution: AnalysisEngineResolution

    init(resolution: AnalysisEngineResolution) {
        self.resolution = resolution
    }

    func resolveEngine() async throws -> AnalysisEngineResolution {
        resolution
    }
}

@MainActor
private final class AppleLocalizedInsightGeneratorFailingFake:
    AppleLocalizedInsightGenerating
{
    private(set) var generateCallCount = 0

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> AppleLocalizedAnalyticsInsight {
        generateCallCount += 1
        throw GemmaRuntimeError.runtimeUnavailable
    }

    func retryOutputTranslation(
        _ fallback: AppleAnalyticsInsightEnglishFallback,
        using executeBatch: PreparedNativeTranslationBatchHandler
    ) async -> AppleLocalizedAnalyticsInsight {
        preconditionFailure("Apple translation must not run for Gemma")
    }

    func releaseSession() {}
}

@MainActor
private final class GemmaInsightGeneratorFake:
    GemmaAnalyticsInsightGenerating
{
    let insight: AnalyticsInsight
    private(set) var generateCallCount = 0

    init(insight: AnalyticsInsight) {
        self.insight = insight
    }

    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        modelURL: URL
    ) async throws -> AnalyticsInsight {
        generateCallCount += 1
        return insight
    }

    func releaseRuntime() {}
}

@Suite("Gemma generation service")
@MainActor
struct GemmaAnalyticsGenerationServiceTests {
    @Test("An English response to Indonesian input retries in Indonesian")
    func wrongLanguageRetriesWithSameTarget() async throws {
        let runtime = GemmaRuntimeFake(
            outputs: [
                Self.validEmptyInsightJSON,
                Self.validIndonesianInsightJSON,
            ]
        )
        let service = GemmaAnalyticsGenerationService(
            runtime: runtime,
            responseLanguageResolver: GemmaResponseLanguageResolver {
                _ in "id"
            },
            responseLanguageValidator: GemmaInsightLanguageValidator {
                text in
                text.contains("Observasi terbatas") ? "id" : "en"
            }
        )

        let insight = try await service.generateInsight(
            from: makeGemmaEntries(count: 1, note: "Anakku senang bermain."),
            for: .day,
            modelURL: URL(filePath: "/tmp/test.litertlm")
        )
        let prompts = await runtime.recordedPrompts

        #expect(insight.summary == "Observasi terbatas dari data hari ini.")
        #expect(prompts.count == 2)
        #expect(prompts.allSatisfy {
            $0.systemInstructions.contains(
                "Required language: Indonesian"
            )
        })
        #expect(prompts.allSatisfy {
            $0.userPrompt.contains("BCP-47 identifier: id")
        })
    }

    @Test("Malformed primary output uses a deterministic eight-entry recovery")
    func parserRetryUsesSmallerContext() async throws {
        let runtime = GemmaRuntimeFake(
            outputs: [
                "not-json",
                Self.validEmptyInsightJSON,
            ]
        )
        let service = GemmaAnalyticsGenerationService(runtime: runtime)
        let entries = makeGemmaEntries(count: 25)

        let insight = try await service.generateInsight(
            from: entries,
            for: .month,
            modelURL: URL(filePath: "/tmp/test.litertlm")
        )
        let prompts = await runtime.recordedPrompts
        let configurations = await runtime.recordedConfigurations

        #expect(insight.summary == "A limited-data observation.")
        #expect(prompts.count == 2)
        #expect(prompts[0].userPrompt.contains("STORY_EVENTS: 24"))
        #expect(prompts[1].userPrompt.contains("STORY_EVENTS: 8"))
        #expect(prompts[0].userPrompt.contains("under 768 tokens"))
        #expect(prompts[1].userPrompt.contains("under 512 tokens"))
        #expect(
            prompts[1].userPrompt.contains(
                "Prioritize valid, complete JSON"
            )
        )
        #expect(configurations == [.gemmaCreative, .gemmaRecovery])
        #expect(await runtime.releaseCallCount == 2)
    }

    @Test("Recovery changes strategy even when the range has few entries")
    func parserRetryChangesStrategyForSmallRange() async throws {
        let runtime = GemmaRuntimeFake(
            outputs: [
                "not-json",
                Self.validEmptyInsightJSON,
            ]
        )
        let service = GemmaAnalyticsGenerationService(runtime: runtime)

        _ = try await service.generateInsight(
            from: makeGemmaEntries(count: 4),
            for: .week,
            modelURL: URL(filePath: "/tmp/test.litertlm")
        )

        let prompts = await runtime.recordedPrompts
        let configurations = await runtime.recordedConfigurations
        #expect(prompts.count == 2)
        #expect(prompts.allSatisfy {
            $0.userPrompt.contains("STORY_EVENTS: 4")
        })
        #expect(prompts[0] != prompts[1])
        #expect(configurations == [.gemmaCreative, .gemmaRecovery])
    }

    @Test("A second malformed response becomes a typed safe failure")
    func parserRetryStopsAfterOneAttempt() async {
        let runtime = GemmaRuntimeFake(outputs: ["bad", "still bad"])
        let service = GemmaAnalyticsGenerationService(runtime: runtime)

        await #expect(
            throws: GemmaAnalyticsGenerationError.invalidGeneratedInsight
        ) {
            try await service.generateInsight(
                from: makeGemmaEntries(count: 1),
                for: .day,
                modelURL: URL(filePath: "/tmp/test.litertlm")
            )
        }
        let prompts = await runtime.recordedPrompts
        #expect(prompts.count == 2)
        #expect(await runtime.releaseCallCount == 2)
    }

    private static let validEmptyInsightJSON = """
        {
          "summary": "A limited-data observation.",
          "commonTriggers": [],
          "observedPatterns": [],
          "parentReflectionPrompt": "What else did you notice?",
          "ethicalNote": "This is not a diagnosis."
        }
        """

    private static let validIndonesianInsightJSON = """
        {
          "summary": "Observasi terbatas dari data hari ini.",
          "commonTriggers": [],
          "observedPatterns": [],
          "parentReflectionPrompt": "Apa lagi yang Anda amati?",
          "ethicalNote": "Ini adalah observasi, bukan diagnosis."
        }
        """
}

@Suite("Gemma runtime policy")
struct GemmaRuntimePolicyTests {
    @Test("CPU and context limits remain suitable for mobile inference")
    func mobileLimits() {
        #expect(GemmaRuntimePolicy.cpuThreadCount == 2)
        #expect(GemmaRuntimePolicy.maximumContextTokens == 4_096)
    }
}

private actor GemmaRuntimeFake: GemmaTextGeneratingRuntime {
    private var outputs: [String]
    private(set) var recordedPrompts: [GemmaAnalyticsPrompt] = []
    private(set) var recordedConfigurations: [LocalLLMConfiguration] = []
    private(set) var releaseCallCount = 0

    init(outputs: [String]) {
        self.outputs = outputs
    }

    func generate(
        prompt: GemmaAnalyticsPrompt,
        modelURL: URL,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        recordedPrompts.append(prompt)
        recordedConfigurations.append(configuration)
        guard !outputs.isEmpty else {
            throw GemmaRuntimeError.generationFailed
        }
        return outputs.removeFirst()
    }

    nonisolated func cancel() {}

    func release() async {
        releaseCallCount += 1
    }
}

@MainActor
private func makeGemmaEntries(
    count: Int,
    note: String? = nil
) -> [StoryEntry] {
    let child = ChildProfile(name: "Mika", age: 4, gender: .girl)
    let session = DailySession(
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        childProfile: child
    )
    let entries = (0..<count).map { index in
        StoryEntry(
            session: .afternoon,
            mood: .happy,
            activity: .play,
            place: .outdoor,
            afterActivityNotes: note.map {
                AfterActivityNotes(text: $0)
            },
            recordedAt: session.startedAt.addingTimeInterval(
                Double(index)
            ),
            dailySession: session
        )
    }
    session.entries = entries
    child.dailySessions = [session]
    return entries
}

@MainActor
private final class InstallationValidatorFake:
    LocalModelInstallationValidating
{
    let result: Result<ValidatedLocalModelInstallation?, Error>
    private(set) var callCount = 0

    init(result: Result<ValidatedLocalModelInstallation?, Error>) {
        self.result = result
    }

    func validatedInstallation(
        for descriptor: LocalModelDescriptor
    ) async throws -> ValidatedLocalModelInstallation? {
        callCount += 1
        return try result.get()
    }
}

@Suite("Gemma installation metadata")
@MainActor
struct LocalModelInstallationPersistenceTests {
    @Test("SwiftData persists metadata without model binary content")
    func metadataRoundTrip() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = container.mainContext
        let repository = LocalModelInstallationRepository(
            modelContext: context
        )
        let modificationDate = Date(timeIntervalSince1970: 2_000)

        try repository.saveValidatedInstallation(
            descriptor: LocalModelCatalog.gemma4E2B,
            relativeFilePath:
                "LocalModels/gemma-4-e2b-it-litertlm/gemma-4-E2B-it.litertlm",
            validatedAt: Date(timeIntervalSince1970: 3_000),
            fileModificationDate: modificationDate
        )

        let installation = try #require(
            try repository.installation(
                for: LocalModelCatalog.gemma4E2B.id
            )
        )
        #expect(installation.status == .installed)
        #expect(
            installation.validatedByteCount
                == LocalModelCatalog.gemma4E2B.expectedByteCount
        )
        #expect(
            installation.validatedSHA256
                == LocalModelCatalog.gemma4E2B.expectedSHA256
        )
        #expect(installation.validatedFileModificationDate == modificationDate)
    }
}

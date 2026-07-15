import Foundation
import Testing

@testable import DayCrumbs

@Suite("Local LLM configuration")
struct LocalLLMConfigurationTests {
    @Test("Default configuration uses the shared product policy")
    func defaultValues() {
        let configuration = LocalLLMConfiguration.default

        #expect(configuration.primaryEventLimit == 24)
        #expect(configuration.retryEventLimit == 10)
        #expect(configuration.outputTokenLimit == 512)
        #expect(configuration.samplingPolicy == .greedy)
        #expect(configuration.temperature == nil)
        #expect(configuration.noteCharacterLimit == 500)
        #expect(configuration.reflectionCharacterLimit == 1_000)
    }

    @Test("Configuration survives a Codable round trip")
    func codableRoundTrip() throws {
        let original = try LocalLLMConfiguration(
            samplingPolicy: .probabilityThreshold(0.9),
            temperature: 0.7
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            LocalLLMConfiguration.self,
            from: encoded
        )

        #expect(decoded == original)
    }

    @Test(
        "Invalid numeric limits are rejected",
        arguments: [
            InvalidLimit(
                primary: 0,
                retry: 10,
                outputTokens: 512,
                noteCharacters: 500,
                reflectionCharacters: 1_000,
                expectedError: .primaryEventLimitMustBePositive
            ),
            InvalidLimit(
                primary: 24,
                retry: 0,
                outputTokens: 512,
                noteCharacters: 500,
                reflectionCharacters: 1_000,
                expectedError: .retryEventLimitMustBePositive
            ),
            InvalidLimit(
                primary: 10,
                retry: 11,
                outputTokens: 512,
                noteCharacters: 500,
                reflectionCharacters: 1_000,
                expectedError: .retryEventLimitExceedsPrimaryLimit
            ),
            InvalidLimit(
                primary: 24,
                retry: 10,
                outputTokens: 0,
                noteCharacters: 500,
                reflectionCharacters: 1_000,
                expectedError: .outputTokenLimitMustBePositive
            ),
            InvalidLimit(
                primary: 24,
                retry: 10,
                outputTokens: 512,
                noteCharacters: 0,
                reflectionCharacters: 1_000,
                expectedError: .noteCharacterLimitMustBePositive
            ),
            InvalidLimit(
                primary: 24,
                retry: 10,
                outputTokens: 512,
                noteCharacters: 500,
                reflectionCharacters: 0,
                expectedError: .reflectionCharacterLimitMustBePositive
            ),
        ]
    )
    func invalidLimits(_ invalid: InvalidLimit) {
        #expect(throws: invalid.expectedError) {
            try LocalLLMConfiguration(
                primaryEventLimit: invalid.primary,
                retryEventLimit: invalid.retry,
                outputTokenLimit: invalid.outputTokens,
                noteCharacterLimit: invalid.noteCharacters,
                reflectionCharacterLimit: invalid.reflectionCharacters
            )
        }
    }

    @Test("Supported sampling policies are accepted")
    func validSamplingPolicies() throws {
        _ = try LocalLLMConfiguration(samplingPolicy: .greedy)
        _ = try LocalLLMConfiguration(samplingPolicy: .topK(1))
        _ = try LocalLLMConfiguration(samplingPolicy: .topK(40))
        _ = try LocalLLMConfiguration(samplingPolicy: .probabilityThreshold(0.05))
        _ = try LocalLLMConfiguration(samplingPolicy: .probabilityThreshold(1.0))
    }

    @Test("Top-k must contain at least one candidate")
    func invalidTopK() {
        #expect(throws: LocalLLMConfiguration.ValidationError.topKMustBePositive) {
            try LocalLLMConfiguration(samplingPolicy: .topK(0))
        }
    }

    @Test(
        "Temperature must stay within the shared range",
        arguments: [-0.01, 2.01, .infinity, .nan]
    )
    func invalidTemperature(_ temperature: Double) {
        #expect(throws: LocalLLMConfiguration.ValidationError.temperatureOutOfRange) {
            try LocalLLMConfiguration(temperature: temperature)
        }
    }

    @Test(
        "Probability threshold must stay within the shared range",
        arguments: [0.0, 0.049, 1.01, .infinity, .nan]
    )
    func invalidProbabilityThreshold(_ threshold: Double) {
        #expect(
            throws: LocalLLMConfiguration.ValidationError.probabilityThresholdOutOfRange
        ) {
            try LocalLLMConfiguration(samplingPolicy: .probabilityThreshold(threshold))
        }
    }
}

struct InvalidLimit: CustomTestStringConvertible, Sendable {
    let primary: Int
    let retry: Int
    let outputTokens: Int
    let noteCharacters: Int
    let reflectionCharacters: Int
    let expectedError: LocalLLMConfiguration.ValidationError

    var testDescription: String {
        String(describing: expectedError)
    }
}

//
//  LocalLLMConfiguration.swift
//  DayCrumbs
//

import Foundation

/// Shared product policy for both on-device analytics engines.
///
/// Runtime adapters translate these values into engine-specific options. Keeping
/// the policy here prevents Apple Foundation Models and Gemma from drifting into
/// different prompt budgets or sampling behavior.
nonisolated struct LocalLLMConfiguration: Codable, Equatable, Sendable {
    // Preserve the original nested names for existing configuration call sites.
    typealias SamplingPolicy = LocalLLMSamplingPolicy
    typealias ValidationError = LocalLLMConfigurationValidationError

    // Product defaults balance enough recent evidence with a modest context and
    // output budget for memory-constrained devices.
    static let defaultPrimaryEventLimit = 24
    static let defaultRetryEventLimit = 10
    static let defaultOutputTokenLimit = 512
    static let defaultNoteCharacterLimit = 500
    static let defaultReflectionCharacterLimit = 1_000

    // These bounds are shared policy. Adapters should reject unsupported values
    // instead of silently applying different clamping rules per engine.
    static let probabilityThresholdRange = 0.05...1.0
    static let temperatureRange = 0.0...2.0

    // Construct the default through the validated initializer so a future edit
    // cannot introduce an invalid built-in configuration unnoticed.
    static let `default`: LocalLLMConfiguration = {
        do {
            return try LocalLLMConfiguration()
        } catch {
            preconditionFailure(
                "Default local LLM configuration must be valid: \(error)"
            )
        }
    }()

    /// Gemma can be moderately varied when proposing optional activities while
    /// remaining deterministic enough to preserve the compact JSON contract.
    static let gemmaCreative: LocalLLMConfiguration = {
        do {
            return try LocalLLMConfiguration(
                outputTokenLimit: 768,
                samplingPolicy: .probabilityThreshold(0.9),
                temperature: 0.65
            )
        } catch {
            preconditionFailure(
                "Creative Gemma configuration must be valid: \(error)"
            )
        }
    }()

    /// A deterministic, shorter fallback used only after Gemma returns output
    /// that cannot be decoded. This makes the retry materially different even
    /// when the selected range contains eight or fewer events.
    static let gemmaRecovery: LocalLLMConfiguration = {
        do {
            return try LocalLLMConfiguration(
                primaryEventLimit: 24,
                retryEventLimit: 8,
                outputTokenLimit: 512,
                samplingPolicy: .greedy,
                temperature: nil,
                noteCharacterLimit: 300,
                reflectionCharacterLimit: 600
            )
        } catch {
            preconditionFailure(
                "Recovery Gemma configuration must be valid: \(error)"
            )
        }
    }()

    /// Maximum number of story entries included in the initial request.
    let primaryEventLimit: Int
    /// Reduced story-entry count used for a smaller-context retry.
    let retryEventLimit: Int
    /// Maximum response-token budget exposed to either runtime adapter.
    let outputTokenLimit: Int
    /// Token-selection strategy shared by both engines.
    let samplingPolicy: SamplingPolicy
    /// Optional randomness control; `nil` leaves it unset in the adapter.
    let temperature: Double?
    /// Maximum number of characters retained from each after-activity note.
    let noteCharacterLimit: Int
    /// Maximum number of characters retained from each end-of-day reflection.
    let reflectionCharacterLimit: Int

    /// Creates a configuration after checking all cross-property invariants.
    init(
        primaryEventLimit: Int = Self.defaultPrimaryEventLimit,
        retryEventLimit: Int = Self.defaultRetryEventLimit,
        outputTokenLimit: Int = Self.defaultOutputTokenLimit,
        samplingPolicy: SamplingPolicy = .greedy,
        temperature: Double? = nil,
        noteCharacterLimit: Int = Self.defaultNoteCharacterLimit,
        reflectionCharacterLimit: Int = Self.defaultReflectionCharacterLimit
    ) throws {
        try Self.validate(
            primaryEventLimit: primaryEventLimit,
            retryEventLimit: retryEventLimit,
            outputTokenLimit: outputTokenLimit,
            samplingPolicy: samplingPolicy,
            temperature: temperature,
            noteCharacterLimit: noteCharacterLimit,
            reflectionCharacterLimit: reflectionCharacterLimit
        )

        self.primaryEventLimit = primaryEventLimit
        self.retryEventLimit = retryEventLimit
        self.outputTokenLimit = outputTokenLimit
        self.samplingPolicy = samplingPolicy
        self.temperature = temperature
        self.noteCharacterLimit = noteCharacterLimit
        self.reflectionCharacterLimit = reflectionCharacterLimit
    }

    // Decoding goes through the validated initializer so malformed or stale
    // persisted values cannot bypass the same invariants as new configurations.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            primaryEventLimit: container.decode(Int.self, forKey: .primaryEventLimit),
            retryEventLimit: container.decode(Int.self, forKey: .retryEventLimit),
            outputTokenLimit: container.decode(Int.self, forKey: .outputTokenLimit),
            samplingPolicy: container.decode(
                SamplingPolicy.self,
                forKey: .samplingPolicy
            ),
            temperature: container.decodeIfPresent(Double.self, forKey: .temperature),
            noteCharacterLimit: container.decode(Int.self, forKey: .noteCharacterLimit),
            reflectionCharacterLimit: container.decode(
                Int.self,
                forKey: .reflectionCharacterLimit
            )
        )
    }

    private static func validate(
        primaryEventLimit: Int,
        retryEventLimit: Int,
        outputTokenLimit: Int,
        samplingPolicy: SamplingPolicy,
        temperature: Double?,
        noteCharacterLimit: Int,
        reflectionCharacterLimit: Int
    ) throws {
        // A retry may reduce context, but it must never expand beyond the primary
        // request because that would undermine the retry's memory-saving purpose.
        guard primaryEventLimit > 0 else {
            throw ValidationError.primaryEventLimitMustBePositive
        }
        guard retryEventLimit > 0 else {
            throw ValidationError.retryEventLimitMustBePositive
        }
        guard retryEventLimit <= primaryEventLimit else {
            throw ValidationError.retryEventLimitExceedsPrimaryLimit
        }
        guard outputTokenLimit > 0 else {
            throw ValidationError.outputTokenLimitMustBePositive
        }

        switch samplingPolicy {
        case .greedy:
            break
        case .topK(let value):
            guard value > 0 else {
                throw ValidationError.topKMustBePositive
            }
        case .probabilityThreshold(let value):
            guard probabilityThresholdRange.contains(value) else {
                throw ValidationError.probabilityThresholdOutOfRange
            }
        }

        if let temperature {
            guard temperatureRange.contains(temperature) else {
                throw ValidationError.temperatureOutOfRange
            }
        }

        guard noteCharacterLimit > 0 else {
            throw ValidationError.noteCharacterLimitMustBePositive
        }
        guard reflectionCharacterLimit > 0 else {
            throw ValidationError.reflectionCharacterLimitMustBePositive
        }
    }
}

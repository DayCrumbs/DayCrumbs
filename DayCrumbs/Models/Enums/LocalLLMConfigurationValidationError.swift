//
//  LocalLLMConfigurationValidationError.swift
//  DayCrumbs
//

/// Validation failures produced while creating or decoding local LLM policy.
nonisolated enum LocalLLMConfigurationValidationError: Error, Equatable, Sendable {
    case primaryEventLimitMustBePositive
    case retryEventLimitMustBePositive
    case retryEventLimitExceedsPrimaryLimit
    case outputTokenLimitMustBePositive
    case topKMustBePositive
    case probabilityThresholdOutOfRange
    case temperatureOutOfRange
    case noteCharacterLimitMustBePositive
    case reflectionCharacterLimitMustBePositive
}

//
//  LocalLLMSamplingPolicy.swift
//  DayCrumbs
//

import Foundation

/// Engine-neutral strategies for choosing the next generated token.
nonisolated enum LocalLLMSamplingPolicy: Codable, Equatable, Sendable {
    /// Always selects the highest-probability token.
    case greedy
    /// Restricts selection to the given number of highest-probability tokens.
    case topK(Int)
    /// Restricts selection to tokens within the cumulative probability value.
    case probabilityThreshold(Double)

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    private enum Kind: String, Codable {
        case greedy
        case topK
        case probabilityThreshold
    }

    // Use an explicit representation so persisted configuration does not depend
    // on Swift's synthesized associated-value enum format.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(Kind.self, forKey: .kind) {
        case .greedy:
            self = .greedy
        case .topK:
            self = .topK(try container.decode(Int.self, forKey: .value))
        case .probabilityThreshold:
            self = .probabilityThreshold(
                try container.decode(Double.self, forKey: .value)
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .greedy:
            try container.encode(Kind.greedy, forKey: .kind)
        case .topK(let value):
            try container.encode(Kind.topK, forKey: .kind)
            try container.encode(value, forKey: .value)
        case .probabilityThreshold(let value):
            try container.encode(Kind.probabilityThreshold, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

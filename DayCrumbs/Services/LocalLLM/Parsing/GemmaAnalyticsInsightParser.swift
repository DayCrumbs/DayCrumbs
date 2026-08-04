import Foundation

nonisolated enum GemmaAnalyticsInsightParsingError:
    Error,
    Equatable,
    Sendable
{
    case outputTooLarge
    case missingJSONObject
    case malformedJSON
    case invalidInsight(AnalyticsInsight.ValidationError)
}

private nonisolated struct GemmaAnalyticsInsightDTO: Decodable {
    struct Trigger: Decodable {
        let title: String
        let explanation: String
    }

    struct Pattern: Decodable {
        let title: String
        let evidence: String
        let linkedTrigger: String?
        let contextTags: [String]
    }

    struct Suggestion: Decodable {
        let linkedTrigger: String
        let title: String
        let recommendedActivities: [String]
        let whatMayHelp: [String]
    }

    let summary: String
    let commonTriggers: [Trigger]
    let observedPatterns: [Pattern]
    let parentSuggestions: [Suggestion]?
    let parentReflectionPrompt: String
    let ethicalNote: String
}

/// Converts LiteRT text into the shared domain while never exposing raw output.
nonisolated struct GemmaAnalyticsInsightParser: Sendable {
    private static let maximumOutputCharacters = 262_144

    func parse(_ modelOutput: String) throws -> AnalyticsInsight {
        guard modelOutput.count <= Self.maximumOutputCharacters else {
            throw GemmaAnalyticsInsightParsingError.outputTooLarge
        }
        guard let json = extractedJSONObject(from: modelOutput),
              let data = json.data(using: .utf8) else {
            throw GemmaAnalyticsInsightParsingError.missingJSONObject
        }

        let dto: GemmaAnalyticsInsightDTO
        do {
            dto = try JSONDecoder().decode(
                GemmaAnalyticsInsightDTO.self,
                from: data
            )
        } catch {
            throw GemmaAnalyticsInsightParsingError.malformedJSON
        }

        do {
            return try AnalyticsInsight(
                validatingSummary: dto.summary,
                commonTriggers: dto.commonTriggers.map {
                    AnalyticsInsight.CommonTrigger(
                        title: $0.title,
                        explanation: $0.explanation
                    )
                },
                observedPatterns: dto.observedPatterns.map {
                    AnalyticsInsight.ObservedPattern(
                        title: $0.title,
                        evidence: $0.evidence,
                        linkedTrigger: $0.linkedTrigger,
                        contextTags: $0.contextTags
                    )
                },
                parentSuggestions: (dto.parentSuggestions ?? []).map {
                    AnalyticsInsight.ParentSuggestion(
                        linkedTrigger: $0.linkedTrigger,
                        title: $0.title,
                        recommendedActivities: $0.recommendedActivities,
                        whatMayHelp: $0.whatMayHelp
                    )
                },
                parentReflectionPrompt: dto.parentReflectionPrompt,
                ethicalNote: dto.ethicalNote
            )
        } catch let error as AnalyticsInsight.ValidationError {
            throw GemmaAnalyticsInsightParsingError.invalidInsight(error)
        }
    }

    private func extractedJSONObject(from output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = fencedBody(from: trimmed) ?? trimmed
        guard let startIndex = candidate.firstIndex(of: "{") else {
            return nil
        }

        var stack: [Character] = []
        var isInsideString = false
        var isEscaped = false

        for index in candidate.indices[startIndex...] {
            let character = candidate[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            switch character {
            case "\"":
                isInsideString = true
            case "{", "[":
                stack.append(character)
            case "}":
                guard stack.last == "{" else {
                    return nil
                }
                stack.removeLast()
            case "]":
                guard stack.last == "[" else {
                    return nil
                }
                stack.removeLast()
            default:
                break
            }

            if stack.isEmpty {
                return String(candidate[startIndex...index])
            }
        }

        // LiteRT-only structural repair: close balanced containers without
        // inventing values. Strict DTO decoding still rejects missing fields.
        guard !isInsideString, !stack.isEmpty else {
            return nil
        }
        let suffix = stack.reversed().map { $0 == "{" ? "}" : "]" }.joined()
        return String(candidate[startIndex...]) + suffix
    }

    private func fencedBody(from output: String) -> String? {
        guard output.hasPrefix("```"),
              let firstNewline = output.firstIndex(of: "\n") else {
            return nil
        }
        let bodyStart = output.index(after: firstNewline)
        guard let closingRange = output.range(
            of: "```",
            options: .backwards,
            range: bodyStart..<output.endIndex
        ) else {
            return nil
        }
        return String(output[bodyStart..<closingRange.lowerBound])
    }
}

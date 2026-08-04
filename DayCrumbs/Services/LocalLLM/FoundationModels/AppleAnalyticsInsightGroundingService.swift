import Foundation

/// Removes model trigger candidates that are not grounded in a specific
/// supplied circumstance-response relationship.
///
/// The selected engine remains responsible for wording and synthesis. This gate
/// prevents broad outcome-only summaries from being treated as causes and from
/// contaminating curated recommendation matching.
nonisolated struct AnalyticsInsightGroundingService: Sendable {
    func grounded(
        _ insight: AnalyticsInsight,
        in context: AnalyticsContext
    ) -> AnalyticsInsight {
        let eligibleTriggers = insight.commonTriggers.filter {
            isEligible($0, in: insight, context: context)
        }
        let eligibleTitles = Set(
            eligibleTriggers.map { normalizedPhrase($0.title) }
        )

        let patterns = insight.observedPatterns.map { pattern in
            guard let linkedTrigger = pattern.linkedTrigger,
                  eligibleTitles.contains(normalizedPhrase(linkedTrigger)) else {
                return AnalyticsInsight.ObservedPattern(
                    title: pattern.title,
                    evidence: pattern.evidence,
                    linkedTrigger: nil,
                    contextTags: pattern.contextTags
                )
            }
            return pattern
        }

        let suggestions = insight.parentSuggestions.filter {
            eligibleTitles.contains(normalizedPhrase($0.linkedTrigger))
        }

        return AnalyticsInsight(
            summary: insight.summary,
            commonTriggers: eligibleTriggers,
            observedPatterns: patterns,
            parentSuggestions: suggestions,
            parentReflectionPrompt: insight.parentReflectionPrompt,
            ethicalNote: insight.ethicalNote
        )
    }

    private func isEligible(
        _ trigger: AnalyticsInsight.CommonTrigger,
        in insight: AnalyticsInsight,
        context: AnalyticsContext
    ) -> Bool {
        let relatedPatterns = insight.observedPatterns.filter {
            guard let linkedTrigger = $0.linkedTrigger else {
                return false
            }
            return normalizedPhrase(linkedTrigger)
                == normalizedPhrase(trigger.title)
        }
        guard !relatedPatterns.isEmpty else {
            return false
        }

        let titleContext = contextTokens(in: trigger.title)
        guard !titleContext.isEmpty else {
            return false
        }

        let relationshipText = (
            [trigger.explanation]
                + relatedPatterns.flatMap {
                    [$0.title, $0.evidence] + $0.contextTags
                }
        ).joined(separator: " ")

        let supportedEvents = context.events.filter { event in
            let eventContext = contextTokens(
                in: [
                    event.activity,
                    event.place,
                    event.afterActivityNote,
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
            return !titleContext.isDisjoint(with: eventContext)
                && mentions(eventMood: event.mood, in: relationshipText)
        }

        let hasExplicitNoteSupport = supportedEvents.contains {
            $0.afterActivityNote?.isEmpty == false
        }
        if hasExplicitNoteSupport {
            return true
        }

        let reflectionContext = contextTokens(
            in: context.reflections.map(\.content).joined(separator: " ")
        )
        let hasReflectionSupport = !titleContext.isDisjoint(
            with: reflectionContext
        ) && context.events.contains {
            mentions(eventMood: $0.mood, in: relationshipText)
        }
        if hasReflectionSupport {
            return true
        }

        return supportedEvents.count >= 2
    }

    private func mentions(eventMood: String, in text: String) -> Bool {
        let expectedMood = canonicalMood(eventMood)
        return tokens(in: text).contains {
            canonicalMood($0) == expectedMood
        }
    }

    private func contextTokens(in text: String) -> Set<String> {
        Set(
            tokens(in: text).filter {
                $0.count > 2 && !Self.nonContextTokens.contains($0)
            }
        )
    }

    private func tokens(in text: String) -> [String] {
        splitCamelCase(text)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map(canonicalToken)
    }

    private func normalizedPhrase(_ text: String) -> String {
        tokens(in: text).joined(separator: " ")
    }

    private func splitCamelCase(_ text: String) -> String {
        text.reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
    }

    private func canonicalToken(_ token: String) -> String {
        switch token {
        case "emotions", "emotional":
            "emotion"
        case "feelings":
            "feeling"
        case "varied", "varying", "variety", "variation":
            "vary"
        case "playtime", "played", "playing":
            "play"
        case "mealtime", "ate", "eaten", "eating":
            "eat"
        case "wakes", "waking", "woke", "wakeup":
            "wake"
        case "studied", "studies", "studying":
            "study"
        case "disappointed", "disappointment":
            "sad"
        case "happiness", "joy", "joyful", "enjoyed", "enjoyment":
            "happy"
        case "sadness":
            "sad"
        case "anger", "frustrated", "frustration":
            "angry"
        case "fearful", "afraid", "scared":
            "fear"
        case "surprised", "startled":
            "surprise"
        case "disgusted":
            "disgust"
        default:
            token
        }
    }

    private func canonicalMood(_ value: String) -> String {
        canonicalToken(tokens(in: value).first ?? value.lowercased())
    }

    private static let nonContextTokens: Set<String> = [
        "a", "an", "and", "as", "at", "by", "during", "for", "from", "in",
        "into", "of", "on", "or", "the", "through", "throughout", "to", "with",
        "child", "children", "day", "event", "experience", "moment",
        "response", "time",
        "emotion", "feeling", "mood", "range", "vary", "mixed", "different",
        "happy", "sad", "angry", "fear", "surprise", "disgust",
    ]
}

/// Compatibility alias for existing Apple-focused tests and call sites.
typealias AppleAnalyticsInsightGroundingService =
    AnalyticsInsightGroundingService

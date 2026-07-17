import Foundation

/// Matches generated trigger text to local, reviewed parenting actions.
///
/// Generated text is used only for matching and evidence. Recommendation copy and
/// source labels always come from this catalog.
nonisolated struct ParentRecommendationCatalog: Sendable {
    private struct Entry: Sendable {
        let keywords: [String]
        let recommendation: ParentRecommendation
    }

    private let entries: [Entry]
    private let fallbackRecommendation: ParentRecommendation

    init() {
        entries = Self.defaultEntries
        fallbackRecommendation = Self.defaultFallbackRecommendation
    }

    /// Builds one detail per generated trigger without invoking either LLM runtime.
    func triggerDetails(for insight: AnalyticsInsight) -> [TriggerDetail] {
        insight.commonTriggers.map { triggerDetail(for: $0, in: insight) }
    }

    func triggerDetail(
        for trigger: AnalyticsInsight.CommonTrigger,
        in insight: AnalyticsInsight
    ) -> TriggerDetail {
        let relatedPatterns = insight.observedPatterns.filter {
            guard let linkedTrigger = $0.linkedTrigger else {
                return false
            }

            return Self.normalized(linkedTrigger) == Self.normalized(trigger.title)
        }
        let recommendation = recommendation(
            for: trigger,
            relatedPatterns: relatedPatterns,
            summary: insight.summary
        )

        return TriggerDetail(
            title: trigger.title,
            explanation: trigger.explanation,
            evidence: relatedPatterns.map {
                TriggerDetail.Evidence(
                    title: $0.title,
                    explanation: $0.evidence,
                    contextTags: $0.contextTags
                )
            },
            recommendationTitle: recommendation.title,
            recommendedActivities: recommendation.recommendedActivities,
            whatMayHelp: recommendation.whatMayHelp,
            sourceLabels: recommendation.sourceLabels
        )
    }

    func recommendation(
        for trigger: AnalyticsInsight.CommonTrigger,
        relatedPatterns: [AnalyticsInsight.ObservedPattern],
        summary: String = ""
    ) -> ParentRecommendation {
        var bestMatch: (score: Int, recommendation: ParentRecommendation)?

        for entry in entries {
            let score = matchScore(
                for: entry,
                trigger: trigger,
                relatedPatterns: relatedPatterns,
                summary: summary
            )

            // Keeping the first result on a tie makes catalog order deterministic.
            if score > 0, score > (bestMatch?.score ?? 0) {
                bestMatch = (score, entry.recommendation)
            }
        }

        return bestMatch?.recommendation ?? fallbackRecommendation
    }

    private func matchScore(
        for entry: Entry,
        trigger: AnalyticsInsight.CommonTrigger,
        relatedPatterns: [AnalyticsInsight.ObservedPattern],
        summary: String
    ) -> Int {
        var score = 0

        // Large gaps preserve the intended priority even when several lower-level
        // fields contain matching terms.
        if Self.containsKeyword(in: trigger.title, keywords: entry.keywords) {
            score += 1_000_000
        }
        if Self.containsKeyword(in: trigger.explanation, keywords: entry.keywords) {
            score += 10_000
        }

        for pattern in relatedPatterns {
            for tag in pattern.contextTags where Self.containsKeyword(
                in: tag,
                keywords: entry.keywords
            ) {
                score += 100
            }

            if Self.containsKeyword(
                in: "\(pattern.title) \(pattern.evidence)",
                keywords: entry.keywords
            ) {
                score += 10
            }
        }

        if Self.containsKeyword(in: summary, keywords: entry.keywords) {
            score += 1
        }

        return score
    }

    private static func containsKeyword(
        in text: String,
        keywords: [String]
    ) -> Bool {
        let normalizedText = " \(normalized(text)) "

        return keywords.contains { keyword in
            normalizedText.contains(" \(normalized(keyword)) ")
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension ParentRecommendationCatalog {
    private static let defaultEntries: [Entry] = [
        Entry(
            keywords: [
                "sleep", "bedtime", "nighttime", "night",
                "tidur", "waktu tidur", "malam",
            ],
            recommendation: ParentRecommendation(
                title: "Predictable bedtime steps",
                recommendedActivities: [
                    "Choose one short calming activity, such as reading together.",
                    "Follow the same simple wind-down steps in the same order.",
                ],
                whatMayHelp: [
                    "Keep bedtime and the sequence of steps predictable.",
                    "Offer a limited choice, such as which story to read.",
                ],
                sourceLabels: [.aap, .cdc]
            )
        ),
        Entry(
            keywords: [
                "transition", "routine", "get ready", "wake up", "morning",
                "change activity", "peralihan", "transisi", "rutinitas",
                "bersiap", "bangun", "pagi", "ganti aktivitas",
            ],
            recommendation: ParentRecommendation(
                title: "A clear, predictable transition",
                recommendedActivities: [
                    "Preview the next step with one short sentence.",
                    "Offer two simple, acceptable choices for the transition.",
                ],
                whatMayHelp: [
                    "Keep the sequence consistent so the next step is easier to expect.",
                    "Notice cooperation with specific, positive attention.",
                ],
                sourceLabels: [.cdc]
            )
        ),
        Entry(
            keywords: [
                "study", "homework", "school", "learning",
                "belajar", "tugas", "sekolah",
            ],
            recommendation: ParentRecommendation(
                title: "One manageable learning step",
                recommendedActivities: [
                    "Break the activity into one clear, age-appropriate direction.",
                    "Let the child choose which of two small steps to do first.",
                ],
                whatMayHelp: [
                    "Get close, gain attention, and state exactly what to do next.",
                    "Acknowledge effort with specific, positive feedback.",
                ],
                sourceLabels: [.cdc]
            )
        ),
        Entry(
            keywords: [
                "play", "sports", "outdoor", "public place",
                "bermain", "olahraga", "luar ruangan", "tempat umum",
            ],
            recommendation: ParentRecommendation(
                title: "Shared play and observation",
                recommendedActivities: [
                    "Join a short activity and follow what holds the child's attention.",
                    "Try a simple matching game, puzzle, or turn-taking activity.",
                ],
                whatMayHelp: [
                    "Allow time for the child to respond before taking the next turn.",
                    "Name what the child is seeing or doing in calm, concrete words.",
                ],
                sourceLabels: [.harvard, .cdc]
            )
        ),
        Entry(
            keywords: [
                "eat", "meal", "mealtime", "food",
                "makan", "waktu makan", "makanan",
            ],
            recommendation: ParentRecommendation(
                title: "A predictable mealtime step",
                recommendedActivities: [
                    "Invite the child to help with one simple mealtime task.",
                    "Use one clear direction for what happens next.",
                ],
                whatMayHelp: [
                    "Keep the routine and expectations consistent.",
                    "Offer specific positive attention for helpful participation.",
                ],
                sourceLabels: [.cdc]
            )
        ),
        Entry(
            keywords: [
                "angry", "sad", "fear", "disgust", "upset", "worry",
                "frustrated", "marah", "sedih", "takut", "jijik", "kesal",
                "cemas", "frustrasi",
            ],
            recommendation: ParentRecommendation(
                title: "Calm, responsive connection",
                recommendedActivities: [
                    "Pause for a short back-and-forth activity led by the child's focus.",
                    "Read, talk, or play together for a few quiet minutes.",
                ],
                whatMayHelp: [
                    "Respond calmly to the child's cue and allow time for a response.",
                    "Name what the child is doing or feeling without assigning a label.",
                ],
                sourceLabels: [.harvard, .cdc]
            )
        ),
    ]

    private static let defaultFallbackRecommendation = ParentRecommendation(
        title: "Observe and connect",
        recommendedActivities: [
            "Spend a few quiet minutes observing or joining the current activity.",
            "Ask one gentle question about what felt easy or difficult.",
        ],
        whatMayHelp: [
            "Use specific positive attention when you notice a helpful behavior.",
            "Keep the next direction short, clear, and age-appropriate.",
        ],
        sourceLabels: [.cdc, .harvard]
    )
}

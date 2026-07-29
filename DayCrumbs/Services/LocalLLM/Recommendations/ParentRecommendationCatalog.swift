import Foundation

/// Matches generated trigger text to local, reviewed parenting actions.
///
/// Generated text is used only for matching and evidence. Recommendation copy and
/// source labels always come from this catalog.
nonisolated struct ParentRecommendationCatalog: Sendable {
    private struct Entry: Sendable {
        let keywords: [String]
        let requiredKeywordGroups: [[String]]
        let excludedKeywords: [String]
        let recommendation: ParentRecommendation

        init(
            keywords: [String],
            requiredKeywordGroups: [[String]] = [],
            excludedKeywords: [String] = [],
            recommendation: ParentRecommendation
        ) {
            self.keywords = keywords
            self.requiredKeywordGroups = requiredKeywordGroups.isEmpty
                ? [keywords]
                : requiredKeywordGroups
            self.excludedKeywords = excludedKeywords
            self.recommendation = recommendation
        }
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
            sourceLabels: recommendation.sourceLabels,
            sectionLabels: .english
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
        let relatedTexts = [
            trigger.title,
            trigger.explanation,
        ] + relatedPatterns.flatMap { pattern in
            [pattern.title, pattern.evidence] + pattern.contextTags
        }
        let allTexts = relatedTexts + [summary]

        // Required groups prevent one broad word from selecting a recommendation.
        // Exclusions let a more specific entry handle materially different cases.
        guard entry.requiredKeywordGroups.allSatisfy({
            Self.containsKeyword(in: allTexts, keywords: $0)
        }) else {
            return 0
        }
        guard entry.excludedKeywords.isEmpty || !Self.containsKeyword(
            in: relatedTexts,
            keywords: entry.excludedKeywords
        ) else {
            return 0
        }

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

    private static func containsKeyword(
        in texts: [String],
        keywords: [String]
    ) -> Bool {
        texts.contains { containsKeyword(in: $0, keywords: keywords) }
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
            .map(canonicalToken)
            .joined(separator: " ")
    }

    /// Accepts ordinary model inflections while keeping recommendation copy local
    /// and reviewed.
    private static func canonicalToken(_ token: String) -> String {
        switch token {
        case "ate", "eaten", "eating":
            "eat"
        case "wakes", "waking", "woke", "awakened":
            "wake"
        case "played", "playing":
            "play"
        case "studied", "studies", "studying":
            "study"
        case "meals":
            "meal"
        case "foods":
            "food"
        case "vegetables":
            "vegetable"
        default:
            token
        }
    }
}

private extension ParentRecommendationCatalog {
    nonisolated private static let sleepContextKeywords = [
        "sleep", "nap", "bedtime", "night",
        "tidur", "tidur siang", "waktu tidur", "malam",
    ]

    nonisolated private static let sleepInterruptionKeywords = [
        "noise", "noisy", "loud", "interrupted", "disrupted", "disturbance",
        "woke", "awakened", "gangguan", "terganggu", "kebisingan",
        "berisik", "bising", "terbangun",
    ]

    nonisolated private static let natureKeywords = [
        "garden", "gardening", "plant", "watering plants", "nature",
        "leaves", "soil", "berkebun", "kebun", "tanaman",
        "menyiram tanaman", "alam", "daun", "tanah",
    ]

    nonisolated private static let outdoorMovementKeywords = [
        "outdoor", "outdoor play", "sports", "playground", "physical activity",
        "running", "luar ruangan", "bermain di luar", "olahraga",
        "taman bermain", "aktivitas fisik", "berlari",
    ]

    nonisolated private static let defaultEntries: [Entry] = [
        // AAP: "How Noise Affects Children" and "Healthy Sleep Habits".
        Entry(
            keywords: sleepContextKeywords + sleepInterruptionKeywords,
            requiredKeywordGroups: [
                sleepContextKeywords,
                sleepInterruptionKeywords,
            ],
            recommendation: ParentRecommendation(
                title: "Reduce avoidable sleep-area noise",
                recommendedActivities: [
                    "Before the next sleep period, move television, loud conversation, or noisy tasks away from the sleep area.",
                    "If a sound interrupts sleep, use one familiar quiet activity, such as reading together, before settling again.",
                ],
                whatMayHelp: [
                    "Observe whether the same sound, room, or time is linked to another interruption.",
                    "Keep the sleep space quiet, dim, and comfortably cool.",
                ],
                sourceLabels: [.aap]
            )
        ),

        // AAP "Brush, Book, Bed" guidance plus CDC predictable routines.
        Entry(
            keywords: [
                "bedtime", "nighttime", "bedtime routine", "wind down",
                "settling", "resists bedtime", "waktu tidur",
                "rutinitas tidur", "rutinitas malam", "sulit tidur",
                "menolak tidur", "malam",
            ],
            excludedKeywords: sleepInterruptionKeywords,
            recommendation: ParentRecommendation(
                title: "Predictable bedtime wind-down",
                recommendedActivities: [
                    "Use the same short sequence, such as brushing teeth, reading one book, and going to bed.",
                    "Let the child choose between two available books or other quiet wind-down options.",
                ],
                whatMayHelp: [
                    "Begin the sequence at a consistent time and keep the order predictable.",
                    "Keep the period before sleep calm, quiet, and screen-free.",
                ],
                sourceLabels: [.aap, .cdc]
            )
        ),

        // CDC: predictable structure, one clear direction, and limited choices.
        Entry(
            keywords: [
                "transition", "routine", "get ready", "wake", "wake up", "morning",
                "change activity", "peralihan", "transisi", "rutinitas",
                "bersiap", "bangun", "terbangun", "pagi", "ganti aktivitas",
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

        // CDC: age-appropriate directions, one step at a time, and specific praise.
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

        // AAP nature exploration, CDC child-led play, and Harvard serve-and-return.
        Entry(
            keywords: natureKeywords,
            recommendation: ParentRecommendation(
                title: "Child-led garden and nature exploration",
                recommendedActivities: [
                    "Continue one safe task already present in the observation, such as watering a plant, collecting fallen leaves, or drawing in soil.",
                    "Follow the child's focus by naming a color, texture, action, or change, then pause for a response.",
                ],
                whatMayHelp: [
                    "Keep the task short, supervised, and appropriate for the child's current skill.",
                    "Use specific praise for safe participation or helpful actions.",
                ],
                sourceLabels: [.aap, .cdc, .harvard]
            )
        ),

        // CDC child-led play and Harvard responsive back-and-forth interaction.
        Entry(
            keywords: outdoorMovementKeywords,
            excludedKeywords: natureKeywords,
            recommendation: ParentRecommendation(
                title: "Child-led outdoor movement",
                recommendedActivities: [
                    "Continue the safe outdoor movement already present in the observation, such as a ball activity, a short walk, or playground play.",
                    "Join briefly by imitating or describing what the child chooses to do.",
                ],
                whatMayHelp: [
                    "Let the child's attention guide the activity instead of introducing an unrelated game.",
                    "Use one short, specific direction when a safety boundary is needed.",
                ],
                sourceLabels: [.harvard, .cdc]
            )
        ),

        // AAP environmental-noise guidance plus CDC clear directions.
        Entry(
            keywords: [
                "public place", "crowd", "crowded", "public noise",
                "restaurant noise", "tempat umum", "keramaian",
                "ramai", "tempat berisik",
            ],
            recommendation: ParentRecommendation(
                title: "A manageable public-place pause",
                recommendedActivities: [
                    "Before the next step, move to a quieter nearby spot when one is available.",
                    "Give one short direction or offer two manageable choices for what happens next.",
                ],
                whatMayHelp: [
                    "Observe whether noise, waiting, or the transition into the place aligns with the response.",
                    "Use a calm voice and state the specific behavior you want to see.",
                ],
                sourceLabels: [.aap, .cdc]
            )
        ),

        // CDC special playtime and Harvard serve-and-return.
        Entry(
            keywords: [
                "play", "shared play", "turn taking", "toy",
                "bermain", "bermain bersama", "bergiliran", "mainan",
            ],
            excludedKeywords: natureKeywords,
            recommendation: ParentRecommendation(
                title: "Child-led shared play",
                recommendedActivities: [
                    "Join the activity already holding the child's attention and let the child lead for a few minutes.",
                    "Imitate or describe the child's action, then pause to allow a response or another turn.",
                ],
                whatMayHelp: [
                    "Keep questions and directions limited during this short shared-play period.",
                    "Use specific praise for a helpful, safe, or cooperative action.",
                ],
                sourceLabels: [.cdc, .harvard]
            )
        ),

        // AAP Committee on Nutrition guidance for low-pressure toddler meals.
        Entry(
            keywords: [
                "eat", "meal", "mealtime", "food", "vegetable",
                "food refusal",
                "picky eating", "refused meal", "makan", "waktu makan",
                "makanan", "sayur", "menolak makan",
                "pilih pilih makanan",
            ],
            recommendation: ParentRecommendation(
                title: "Low-pressure mealtime participation",
                recommendedActivities: [
                    "Offer a small amount of an available food alongside at least one familiar option.",
                    "Invite the child to help with one safe, age-appropriate food or table task.",
                ],
                whatMayHelp: [
                    "Avoid arguing, pressuring, or punishing when the child does not eat.",
                    "Keep family meals free from television and phone distractions when possible.",
                ],
                sourceLabels: [.aap]
            )
        ),

        // CDC active listening and Harvard responsive interaction.
        Entry(
            keywords: [
                "angry", "sad", "fear", "disgust", "upset", "worry",
                "frustrated", "marah", "sedih", "takut", "jijik", "kesal",
                "cemas", "frustrasi",
            ],
            recommendation: ParentRecommendation(
                title: "Calm listening and connection",
                recommendedActivities: [
                    "Get close to the child's level and reflect the words or cues you observed.",
                    "Pause for a short, quiet back-and-forth activity led by the child's focus.",
                ],
                whatMayHelp: [
                    "Allow time for a response before adding another question or direction.",
                    "Name a possible feeling tentatively instead of treating it as certain.",
                ],
                sourceLabels: [.harvard, .cdc]
            )
        ),
    ]

    nonisolated private static let defaultFallbackRecommendation = ParentRecommendation(
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

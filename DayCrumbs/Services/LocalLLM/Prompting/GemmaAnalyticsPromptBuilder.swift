import Foundation

nonisolated struct GemmaAnalyticsPrompt: Equatable, Sendable {
    let systemInstructions: String
    let userPrompt: String
}

nonisolated enum GemmaAnalyticsPromptMode: Equatable, Sendable {
    case creative
    case recovery
}

/// Serializes the existing engine-neutral context for LiteRT-LM text transport.
nonisolated struct GemmaAnalyticsPromptBuilder: Sendable {
    func prompt(
        from context: AnalyticsContext,
        for range: TimeRange,
        configuration: LocalLLMConfiguration = .default,
        mode: GemmaAnalyticsPromptMode = .creative,
        responseLanguage: GemmaResponseLanguage = .english
    ) -> GemmaAnalyticsPrompt {
        let copy = schemaCopy(for: responseLanguage)
        return GemmaAnalyticsPrompt(
            systemInstructions: """
            \(AnalyticsSystemPrompt.text)

            \(languageContract(for: responseLanguage))
            """,
            userPrompt: """
            \(AnalyticsSystemPrompt.scopeInstructions(for: range))

            ANALYTICS_CONTEXT
            \(context.text)

            \(languageContract(for: responseLanguage))
            Do not translate structured labels, names, activities, or places before analyzing them.

            \(modeInstructions(for: mode))

            RESPONSE_CONTRACT
            Return one JSON object only. Do not use markdown fences or add prose.
            Keep the complete response under \(configuration.outputTokenLimit) tokens.
            Use exactly this shape:
            {
              "summary": "\(copy.summary)",
              "commonTriggers": [
                {
                  "title": "\(copy.triggerTitle)",
                  "explanation": "\(copy.triggerExplanation)"
                }
              ],
              "observedPatterns": [
                {
                  "title": "\(copy.patternTitle)",
                  "evidence": "\(copy.patternEvidence)",
                  "linkedTrigger": "\(copy.linkedTrigger)",
                  "contextTags": ["\(copy.contextTag)"]
                }
              ],
              "parentSuggestions": [
                {
                  "linkedTrigger": "\(copy.linkedSuggestionTrigger)",
                  "title": "\(copy.suggestionTitle)",
                  "recommendedActivities": [
                    "\(copy.recommendedActivity)"
                  ],
                  "whatMayHelp": [
                    "\(copy.whatMayHelp)"
                  ]
                }
              ],
              "parentReflectionPrompt": "\(copy.reflectionPrompt)",
              "ethicalNote": "\(copy.ethicalNote)"
            }
            Write one parentSuggestions object for each common trigger and link it by
            the exact trigger title. You may invent safe, age-appropriate, low-cost
            activity ideas that fit the supplied context; do not invent observations
            or claim the ideas will solve the response. Prefer specific instructions
            a parent can try over generic advice. Return at most two activities and
            two whatMayHelp items per trigger. Use empty arrays when no eligible
            triggers or patterns are supported.
            """
        )
    }

    private func languageContract(
        for language: GemmaResponseLanguage
    ) -> String {
        """
        OUTPUT_LANGUAGE
        Required language: \(language.englishName)
        BCP-47 identifier: \(language.identifier)
        Write every user-visible JSON string in \(language.englishName).
        Keep JSON keys exactly as specified. Do not answer in English unless the
        required language is English. This requirement applies to the summary,
        trigger and pattern text, suggestions, reflection prompt, and ethical note.
        """
    }

    private func schemaCopy(
        for language: GemmaResponseLanguage
    ) -> SchemaCopy {
        guard language.baseIdentifier == "id" else {
            return .english
        }
        return .indonesian
    }

    private func modeInstructions(
        for mode: GemmaAnalyticsPromptMode
    ) -> String {
        switch mode {
        case .creative:
            """
            GENERATION_MODE
            Create varied but concise contextual suggestions.
            """

        case .recovery:
            """
            GENERATION_MODE
            The earlier response could not be decoded. Prioritize valid, complete JSON
            over variety. Use at most two common triggers, one observed pattern per
            trigger, one recommended activity per trigger, and one whatMayHelp item per
            trigger. Keep every string concise and close every JSON container.
            """
        }
    }
}

private nonisolated struct SchemaCopy: Sendable {
    let summary: String
    let triggerTitle: String
    let triggerExplanation: String
    let patternTitle: String
    let patternEvidence: String
    let linkedTrigger: String
    let contextTag: String
    let linkedSuggestionTrigger: String
    let suggestionTitle: String
    let recommendedActivity: String
    let whatMayHelp: String
    let reflectionPrompt: String
    let ethicalNote: String

    static let english = SchemaCopy(
        summary: "One concise grounded paragraph.",
        triggerTitle: "Short circumstance label.",
        triggerExplanation: "Tentative explanation grounded in supplied rows.",
        patternTitle: "Short evidence label.",
        patternEvidence: "Concrete observation from supplied rows.",
        linkedTrigger: "Exact trigger title or null.",
        contextTag: "Short supplied-row tag.",
        linkedSuggestionTrigger: "Exact commonTriggers title.",
        suggestionTitle: "Short contextual support idea.",
        recommendedActivity: "One playful, practical activity to try.",
        whatMayHelp: "One gentle routine adjustment or thing to observe.",
        reflectionPrompt: "One gentle observation question.",
        ethicalNote: "Short privacy and non-diagnosis reminder."
    )

    static let indonesian = SchemaCopy(
        summary: "Satu paragraf ringkas berdasarkan data yang diberikan.",
        triggerTitle: "Judul singkat untuk situasi yang diamati.",
        triggerExplanation: "Penjelasan tentatif berdasarkan catatan yang diberikan.",
        patternTitle: "Judul singkat untuk bukti pengamatan.",
        patternEvidence: "Pengamatan konkret dari data yang diberikan.",
        linkedTrigger: "Judul trigger yang sama persis atau null.",
        contextTag: "Tag singkat dari data yang diberikan.",
        linkedSuggestionTrigger: "Judul commonTriggers yang sama persis.",
        suggestionTitle: "Ide dukungan singkat yang sesuai konteks.",
        recommendedActivity: "Satu aktivitas praktis dan menyenangkan untuk dicoba.",
        whatMayHelp: "Satu penyesuaian lembut atau hal yang dapat diamati.",
        reflectionPrompt: "Satu pertanyaan pengamatan yang lembut.",
        ethicalNote: "Pengingat singkat tentang privasi dan bahwa ini bukan diagnosis."
    )
}

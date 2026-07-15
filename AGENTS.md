# .agents

Project: DayCrumbs
Purpose: Guide Codex / coding LLM agents to build an iOS/iPadOS app for guided storytelling analytics for first-time parents.

This file is the project instruction source for coding agents. Follow it when creating, editing, reviewing, or refactoring code in this repository.

## App Statement

Build an iOS/iPadOS app that helps first-time parents understand their child's behavior by turning daily reflections into structured story data, dashboard analytics, and on-device generated insight.

Primary user:

- First-time parents with young children.
- They need calm, practical, non-diagnostic observations.
- They should be able to inspect story data, understand behavior patterns, and generate local on-device insight.

Core assumption:

- After Activity Notes are optional and are not reliably available.
- End of Day Reflection is not optional but there is a chance it isn't given
- Analytics must work when `AfterActivityNotes` and/or End of Day Reflection is nil, empty, or rarely provided.
- The main analytics signal comes from structured data:
  - child profile
  - date
  - session
  - place
  - activity
  - mood
  - End of day reflection

## Current Domain Vocabulary

Use the existing project models and enum cases as the source of truth. Do not rename them or introduce replacement vocabulary unless the user explicitly requests a domain change.

- Analytics event entity: `StoryEntry`
- Session (`Sessions`): `morning`, `afternoon`, `evening`, `night`
- Mood (`Moods`): `angry`, `disgust`, `fear`, `happy`, `sad`, `surprise`
- Built-in activity (`Activity.BuiltInActivity`): `play`, `sleep`, `study`, `eat`, `getReady`, `wakeUp`
- Custom activity marker (`Activity.CustomActivity`): `customActivity`
- Built-in place (`Place.BuiltInPlace`): `house`, `outdoor`, `school`, `publicPlace`
- Custom place marker (`Place.CustomPlace`): `customPlace`
- Child gender (`ChildGender`): `boy`, `girl`

Prompts, dummy data, analytics grouping, tests, and UI labels must derive from or map explicitly to this vocabulary. Do not add cases such as `tired`, `excited`, `calm`, `confused`, `scared`, `breakfast`, `screenTime`, `park`, or `car` merely to satisfy an older example or guide.

The app must never diagnose the child. Insights must be phrased as observations or possibilities.

Use language such as:

- "This may suggest..."
- "A possible pattern is..."
- "You may want to observe..."

Avoid language such as:

- "Your child has..."
- "Your child is always..."
- "This means your child..."

## Technical Stack

Use Apple-native technology unless the task explicitly requires otherwise.

Required:

- Swift
- SwiftUI
- SwiftData
- Swift Charts
- Apple Foundation Models through `FoundationModels` and `SystemLanguageModel.default` when Apple Intelligence is available
- LiteRT-LM through vendored `CLiteRTLM.xcframework`
- Local-first data storage
- MVVM + Services + Repository architecture
- On-device analytics and local model inference
- Speech framework for voice notes

Do not add server/backend dependencies.
Do not require an internet connection for existing stored dashboard analytics.
Do not send child data to external APIs.
Do not put analytics logic directly inside SwiftUI Views.
Do not use Private Cloud Compute, server-backed language models, or external AI APIs for child data.

## Architecture Rule

Use MVVM + Services + Repository.

High-level flow:

```text
SwiftUI Views
-> ViewModels
-> Services / Repositories
-> SwiftData / Apple Foundation Models or LiteRT-LM runtime
```

Responsibilities:

Views:

- Render UI only.
- Hold minimal UI state.
- Trigger ViewModel actions.
- Do not fetch SwiftData directly except in simple preview-only code.
- Do not calculate analytics directly.
- Do not start model downloads or model inference directly.

ViewModels:

- Own screen state.
- Call repositories to load data.
- Call services to process data.
- Expose UI-ready values to Views.
- Keep async work structured and cancellable where appropriate.
- Convert technical errors into user-friendly UI messages.

Repositories:

- Encapsulate SwiftData access.
- Provide fetch, insert, update, delete methods.
- Keep persistence details out of ViewModels.
- Store local model metadata only, never model binary content.

Services:

- Contain business logic, analytics logic, downloads, parsing, and runtime orchestration.
- Must be protocol-based when there may be multiple implementations.
- Examples:
  - `RuleBasedAnalyticsService`
  - `BehaviorPatternDetector`
  - `LocalLLMService`
  - `LocalModelDownloadService`
  - `LocalModelStorage`

Models:

- Store domain entities and enums.
- Must not contain UI rendering logic.
- SwiftData models should remain simple and persistence-safe.

## Required Feature Tabs

Build exactly three main tabs:

1. Story
   - Purpose: Guide the parent through daily storytelling and structured activity logging.
   - If no child profile exists, the first step must be creating a child profile with name, age, and gender.
   - After profile setup, the parent chooses session, place, activity, mood, and optional after-activity notes.
   - The parent can add another activity in the same session or move to another session.
   - When moving on from the night session, end-of-day reflection is required.
   - This tab can also include a data explorer/history view, but guided storytelling is the primary flow.

2. Dashboard
   - Purpose: Show analytics cards, charts, pattern summaries, and generated insight.

3. Models
   - Purpose: Show Apple Intelligence readiness and let the user download the single app-managed fallback model, `Gemma-4-E2B-it`.
   - This is not a model picker.
   - Apple Foundation Models is status-only and is chosen automatically when available; it cannot be downloaded or selected by the user.
   - The only user-facing action here is downloading Gemma. Insight generation happens from Dashboard.
   - Loading, offloading, repair, deletion, diagnostics, and prompt/configuration are internal or development-only behaviors, not production user controls.


## On-Device Intelligence Rules

This is the most important implementation area.

The production app supports two on-device analytics engines, but only one app-managed downloadable model:

```text
Apple Foundation Models
Runtime: FoundationModels / SystemLanguageModel.default
Download: managed by iOS/iPadOS, not by this app
Use: preferred automatically when Apple Intelligence is available
```

```text
Gemma fallback

Name: Gemma-4-E2B-it
Runtime: LiteRT-LM
Format: .litertlm
Hugging Face repo: litert-community/gemma-4-E2B-it-litert-lm
File: gemma-4-E2B-it.litertlm
Approx size: 2.58 GB
Approx peak memory: 8.59 GB
```

Rules:

- Do not add a model picker in production.
- Do not expose E4B, Gemma-3, Qwen, MLC, Core ML model choices, or server model choices.
- The Models tab shows Apple Intelligence readiness as a status and provides Gemma-4-E2B-it download as the only action.
- Apple Foundation Models is not a model download and is not user-selectable. It is selected automatically only when `SystemLanguageModel.default.availability` is `.available`.
- The only production user-facing on-device intelligence actions are:
  - view Apple Intelligence readiness
  - download Gemma-4-E2B-it
  - generate insight from Dashboard
- The Dashboard must show a download-required alert only when Apple Foundation Models is unavailable and Gemma-4-E2B-it is not installed.
- If Apple Foundation Models is available, Generate Insight must work without requiring Gemma download.
- Do not auto-download the model without explicit user confirmation.
- Do not bundle the 2.58 GB `.litertlm` file in the app binary.
- `Resources/LocalModels/` may contain manifest/license files only.
- Store downloaded model files in Application Support or Documents.
- Store only metadata/path/checksum/status in SwiftData.
- Never store large binary model content in SwiftData.
- Do not send child data to external APIs.
- Do not use Private Cloud Compute or any server-backed Foundation Models configuration.

Download-required alert copy:

```text
Title:
Set Up On-Device Insights

Message:
Apple Intelligence is not ready on this device. Download Gemma-4-E2B-it to generate private, on-device insights. The download is about 2.58 GB and stays on this iPhone or iPad.

Primary button:
Download Model

Secondary button:
Cancel
```

Generate flow:

```text
Generate Insight tapped
-> Check Apple Foundation Models availability
-> If available, select Apple Foundation Models internally
-> Otherwise check validated Gemma-4-E2B-it installation
-> If Gemma is missing, show DownloadModelRequiredAlert and stop
-> If Gemma is installed, select LiteRT-LM internally
-> Select data scope: all, weekly, or date
-> Build analytics prompt
-> Generate a typed Apple insight or LiteRT compact JSON insight
-> Normalize output to AnalyticsInsight; parse/repair is LiteRT-only
-> Match parent recommendations from curated catalog
-> Save insight
-> Release Apple session or internally offload LiteRT model from memory
```

## LiteRT-LM Dependency Rules

Do not attach SwiftPM product `LiteRTLM` directly to the app target.

Even if the dependency URL is official, Xcode can reject the SwiftPM product because it uses unsafe linker/build flags.

Known error:

```text
The package product 'LiteRTLM' cannot be used as a dependency of this target because it uses unsafe build flags.
```

Required fix:

- Vendor official LiteRT-LM runtime pieces locally.
- Link and embed `CLiteRTLM.xcframework`.
- Copy Google's Swift wrapper sources into `Services/LocalLLM/Vendor/Swift`.
- Runtime code must import `CLiteRTLM`, not `LiteRTLM`.
- Remove stale `Package.resolved` after removing the Swift Package dependency.
- Run a clean Xcode build after vendoring the framework.

Xcode target requirements:

- `CLiteRTLM.xcframework` is in Link Binary With Libraries.
- `CLiteRTLM.xcframework` is in Embed Frameworks.
- Embed setting is `Embed & Sign`.
- Vendored Swift wrapper files are included in the app target.
- Simulator and device slices exist:
  - `ios-arm64`
  - `ios-arm64-simulator`

## Apple Foundation Models Rules

Apple Foundation Models is an on-device analytics engine. It is not a downloadable model card, a chat feature, or a fallback to a server.

Required implementation:

- Isolate Foundation Models code in `Services/LocalLLM/FoundationModels/`.
- Import with `#if canImport(FoundationModels)`.
- Use `SystemLanguageModel.default` only.
- Check `SystemLanguageModel.default.availability` immediately before generation. Never infer availability from the OS version or device name.
- Map `.available`, `.appleIntelligenceNotEnabled`, `.modelNotReady`, `.deviceNotEligible`, and unknown unavailable states to the app's `AppleFoundationModelAvailability` domain type.
- Create one fresh `LanguageModelSession` per Dashboard insight request; do not retain a chat transcript between requests.
- Use `@Generable` and `@Guide` to create a typed Apple transport schema. Map it into the shared `AnalyticsInsight` domain model.
- Use the same `AnalyticsSystemPrompt`, `AnalyticsContextBuilder`, data-scope rules, privacy constraints, and non-diagnostic wording as LiteRT-LM.
- Do not call `respond` while a session is already responding.
- On completion, cancellation, background, or memory warning, release the app's session, prompt, response, transcript, and task references.
- Do not claim to manually load or offload Apple's system model. The app only releases its own session; iOS/iPadOS manages the system model memory.
- Do not use Private Cloud Compute, external tools, or network-backed models for analytics.
- Treat model updates in iOS/iPadOS as a compatibility event: regression-test prompt behavior on each supported OS model version.

Engine selection:

```text
SystemLanguageModel.default.availability == .available
-> Apple Foundation Models runtime

otherwise, validated Gemma-4-E2B-it installation exists
-> LiteRT-LM runtime

otherwise
-> show Set Up On-Device Insights alert
```

`AnalysisEngine` must represent `.appleFoundationModels` and `.gemma4E2B`. It is an internal resolved state, not a user preference persisted as a model picker.

Do not automatically switch from a started Apple request to Gemma after a refusal or session/generation error. Discard the failed Apple session, retry once with smaller context only when appropriate, then show a user-friendly error. Use Gemma fallback only when Apple Foundation Models is unavailable before generation.

## LiteRT-LM Runtime Rules

The local LLM runtime is not a chatbot. It is an analytics engine for dashboard insight.

The runtime must:

- Load Gemma-4-E2B-it only when needed.
- Generate insight from structured story rows.
- Return compact JSON only.
- Release model references after generation.
- Offload on app background.
- Offload on memory warning.
- Cancel generation safely if needed.
- Avoid keeping raw LLM output in memory longer than necessary.

Memory lifecycle:

```text
load
-> generate
-> parse compact insight
-> save compact insight
-> cancel conversation if needed
-> nil conversation
-> nil engine
-> offloaded state
```

Do not keep the model loaded indefinitely in production. Do not expose manual load/offload controls to production users. The normal app flow should load just-in-time and offload after generation.

## Prompting Rules

System prompt must instruct the model to:

- Act as an on-device storytelling analytics engine.
- Analyze parent-logged child story events.
- Produce dashboard-ready insight only.
- Not chat with the parent.
- Not diagnose, label, or make medical claims.
- Prefer concrete patterns from supplied rows.
- Not invent research claims.
- Not generate free-form parenting science claims.
- Produce only the shared analytics fields and no chat response.

Required output schema:

```json
{
  "summary": "One concise paragraph with the overall insight. Do not repeat every pattern here.",
  "commonTriggers": [
    {
      "title": "One short trigger label.",
      "explanation": "Grounded explanation using only supplied rows."
    }
  ],
  "observedPatterns": [
    {
      "title": "Short evidence label, not a recommendation.",
      "evidence": "Concrete observation tied to count, session, place, mood, time, activity, reason, or note.",
      "linkedTrigger": "Optional title from commonTriggers.",
      "contextTags": ["Optional short tags from rows"]
    }
  ],
  "parentReflectionPrompt": "One gentle non-diagnostic question for the parent.",
  "ethicalNote": "A short privacy and non-diagnosis reminder."
}
```

Prompt budget:

- Limit events per generation.
- Prefer up to 24 events for primary prompt.
- Retry with smaller prompt, around 10 events, if generation fails.
- Keep output token budget modest.
- Do not request long prose from the model.
- LiteRT-LM must return compact JSON and use `AnalyticsInsightParser`.
- Apple Foundation Models must use `@Generable` typed output and must not be routed through the LiteRT JSON parser.

## Parent Recommendation Rules

The model must not freely invent science-based parenting recommendations.

Correct design:

- LLM identifies:
  - `summary`
  - `commonTriggers`
  - `observedPatterns`
  - `parentReflectionPrompt`
  - `ethicalNote`
- App selects `ParentRecommendation` from a curated in-app catalog.
- Recommendation matching is based primarily on common triggers, then observed patterns, then summary.

Allowed source labels:

- CDC
- AAP
- Harvard

Recommendation cards should show:

- title
- action
- source labels
- based-on trigger/evidence
- tap or long-press explanation popup

Recommendations are not diagnosis, therapy, or medical advice.

## SwiftData Rules

Use SwiftData for:

- ChildProfile
- StoryEntry
- AnalyticsInsight if persisted
- LocalModelInstallation metadata

Do not store large model binaries inside SwiftData.

Rules:

- Define persistent entities with `@Model`.
- Keep model relationships simple.
- Use repositories to isolate `ModelContext`.
- Seed dummy data only once unless user explicitly resets data.
- Provide reset seed action for development/debugging.

Minimum dummy data (if needed):

- At least 7 days.
- Each day should include 5-10 events.
- Each day should include `morning`, `afternoon`, `evening`, and `night` sessions.
- Include built-in places: `house`, `outdoor`, `school`, and `publicPlace`.
- Include built-in activities: `play`, `sleep`, `study`, `eat`, `getReady`, and `wakeUp`.
- Include moods: `angry`, `disgust`, `fear`, `happy`, `sad`, and `surprise`.
- Custom activity and place examples may be included through the existing `CustomActivity` and `CustomPlace` models.
- Parent notes should mostly be nil or empty.

## Analytics Rules

Dashboard must work from structured data only.

Parent note can improve insight if available, but must not be required.

Rule-based analytics must remain available as a deterministic fallback for charts and baseline summaries. Local LLM enhances generated insight, but base dashboard analytics should still render without downloading the model.

Analytics to implement (not concrete can and will be changed):

- Mood distribution.
- Mood by session.
- Mood by place.
- Mood by activity.
- Weekly mood trend.
- Repeated negative mood moments.
- Common trigger candidates based on repeated session/place/activity + mood patterns.
- Observed patterns with concrete evidence.
- Parent recommendations selected from curated catalog.

Mood scoring is not final. If implemented, it must cover only the current `Moods` cases (`angry`, `disgust`, `fear`, `happy`, `sad`, and `surprise`) unless the user explicitly approves a domain vocabulary change. Define and test the score mapping as a separate analytics policy rather than adding enum cases to fit a previous scoring example.

Do not present mood score as a clinical metric. Use it only internally for trend charts.

Good insight wording:

```text
Leo was often angry during the evening session when the activity was play and the place was outdoor. This may suggest that late-day transitions are worth observing more closely.
```

Bad insight wording:

```text
Leo has behavior problems in the evening.
```

#

## Output Style for Coding Agents

These rules apply to Codex and any other coding LLM agent working on this project.

When generating or editing code:

- Include complete files, not fragments, unless asked.
- Mention where each file should be placed.
- Keep names consistent with this `.agents` file.
- Prefer compiling code over theoretical code.
- When uncertain about a framework API, isolate it behind a service and mark the uncertain part clearly as TODO.
- Do not invent third-party APIs.
- Do not add package dependencies unless explicitly requested.
- For LiteRT-LM, use vendored `CLiteRTLM.xcframework` and local Swift wrapper sources.
- For Apple Foundation Models, use `FoundationModels`, `SystemLanguageModel.default.availability`, and `@Generable` typed output; do not invent its APIs or use a JSON-only path.
- Preserve privacy and non-diagnostic wording.

## Clean Code Rules

Code should be understandable, maintainable, and split by responsibility.

File structure and separation:

- Do not put many unrelated features into one large file.
- Split code by feature and responsibility: Views, ViewModels, Services, Repositories, Models, and Utilities.
- Keep SwiftUI Views focused on rendering and user interaction.
- Keep business logic in Services.
- Keep persistence logic in Repositories.
- Keep reusable UI in Shared Components.
- Extract subviews when a View becomes hard to scan.
- Extract service methods when a function is doing more than one job.

Naming:

- Use clear, descriptive names for types, functions, variables, and parameters.
- Prefer names that explain intent, not implementation detail.
- Avoid vague names such as `data`, `item`, `thing`, `manager`, `helper`, or `temp` unless the scope is truly generic and obvious.
- Boolean names should read naturally, such as `isGenerating`, `hasInstalledModel`, or `shouldShowDownloadAlert`.
- Function names should describe the action and result, such as `fetchEvents(for:)`, `buildAnalyticsPrompt(from:)`, or `saveCustomLocationImage(_:)`.

Comments:

- Add comments only where they clarify intent, constraints, or non-obvious behavior.
- Keep comments short and plain.
- Do not write comments that repeat the code line by line.
- Use comments to explain why something exists, not what every simple statement does.
- Mark temporary uncertainty with a specific TODO that names the missing decision or API.

Constants and magic values:

- Do not scatter magic numbers or hardcoded strings through implementation code.
- Put repeated numeric values, limits, filenames, UserDefaults keys, and storage paths in named constants.
- Give constants meaningful names, such as `maximumPrimaryPromptEvents`, `gemma4E2BFileName`, or `downloadProgressUpdateInterval`.
- Keep user-facing copy in a consistent location when it is reused.

Reuse and abstraction:

- Avoid single-use abstractions that make code harder to read.
- Avoid copy-pasting repeated logic.
- Extract helpers when the same logic is used more than once or when extraction makes a complex flow easier to understand.
- Prefer small, concrete services over large generic managers.
- Do not over-engineer protocols for code that has only one simple implementation unless tests or future swapping genuinely need it.

State and errors:

- Keep UI state in ViewModels, not deep inside Views.
- Keep async tasks cancellable where the user can navigate away or retry.
- Use typed errors for important domain failures.
- Convert technical errors into user-friendly messages at the ViewModel/UI boundary.
- Never hide errors silently unless there is a deliberate fallback.

Testing and verification:

- Add focused tests for parsing, matching, persistence, download state, and analytics logic.
- Prefer deterministic fixtures over random test data.
- Test edge cases: empty events, missing child profile, missing model, partial model download, malformed LLM JSON, and missing after-activity notes.
- Run the smallest useful test/build command after meaningful implementation changes when feasible.

# Apple Foundation Models iOS/iPadOS Implementation Guide

Panduan ini khusus untuk jalur utama Apple Foundation Models yang sudah ada di `PrototypeC3A02`. Foundation Models adalah default engine. `Gemma-4-E2B-it` hanya menjadi fallback kompatibilitas ketika Foundation Models tidak tersedia.

Dokumen ini tidak menambahkan implementasi baru. Semua fase mengacu pada kode project saat ini, termasuk keterbatasan bahwa response Apple saat ini masih berupa text yang dinormalisasi oleh parser analytics bersama.

Panduan fallback ada di [LiteRT-LM-Gemma4E2B-iOS-iPadOS-Implementation-Guide.md](LiteRT-LM-Gemma4E2B-iOS-iPadOS-Implementation-Guide.md).

## 1. Posisi Apple Foundation Models dalam Produk

Kebijakan produk:

- Apple Foundation Models adalah pilihan default.
- Device target Foundation Models adalah iPhone 15 Pro atau lebih baru dan iPad dengan M1 atau lebih baru.
- Hardware threshold tersebut bukan pengganti runtime check.
- Generation hanya boleh dimulai jika `SystemLanguageModel.default.availability == .available`.
- Apple Intelligence yang disabled, model belum ready, device tidak eligible, atau framework/OS tidak tersedia mengarahkan app ke fallback Gemma.

Foundation Models di project ini membutuhkan API `FoundationModels` pada iOS/iPadOS 26 atau lebih baru. Model dikelola oleh system: app tidak men-download, memasang, memilih file, atau meng-offload model Apple secara manual.

Catatan kondisi prototype: UI saat ini masih memiliki `AnalysisEngine` picker dan `selectedAnalysisEngine`. Ketika flow produk dibuat Apple-default, hilangkan keputusan manual dari user journey tanpa mengubah shared analytics contract.

## 2. Shared Contract: Satu Source of Truth

Apple dan Gemma tidak boleh memiliki salinan prompt, context, config, atau hasil domain yang terpisah.

| Contract | Source of truth project |
| --- | --- |
| System prompt | `LocalLLMConfiguration.defaultSystemPrompt` |
| Context notes | `LocalLLMConfiguration.defaultContextNotes` |
| Configuration object | `LocalLLMConfiguration.default` / `LocalModelLibrary.configuration` |
| Event sorting, row format, dan task | `LocalModelLibrary.analyticsUserPrompt(...)` |
| Hasil domain | `GeneratedLLMAnalyticsInsight` |
| Trigger dan pattern | `GeneratedLLMCommonTrigger`, `GeneratedLLMObservedPattern` |
| Recommendation | Curated matcher setelah normalization |
| Current text normalization | `LocalLLMAnalyticsParser` |

Aturannya:

- Jangan membuat `AppleSystemPrompt`, `AppleContext`, atau hard-coded Apple configuration.
- `LanguageModelSession.instructions` menerima `configuration.systemPrompt` yang sama dengan conversation Gemma.
- Prompt request dibuat oleh `LocalModelLibrary.analyticsUserPrompt(...)` dengan configuration yang sama.
- `configuration.contextNotes` dan event rows yang sama dipakai oleh kedua engine.
- UI dan persistence hanya menerima `GeneratedLLMAnalyticsInsight`.
- Config yang tidak memiliki padanan API Apple dipetakan di adapter tanpa menciptakan policy baru. Implementasi saat ini memetakan `temperature`, `topP`, dan `maxTokens`; config LiteRT-specific seperti accelerator tidak diterapkan ke system model.

Dengan pola ini, perubahan prompt/context hanya dilakukan sekali di `LocalLLMModels.swift` dan otomatis dipakai kedua engine.

## 3. File Implementasi yang Sudah Ada

```text
PrototypeC3A02/AppleFoundationModelsRuntime.swift
  Availability, readiness message, one-shot session, generation options,
  dan mapping error.

PrototypeC3A02/LocalLLMModels.swift
  Shared configuration, shared prompt builder, analytics domain,
  parser, repair, dan curated recommendation matcher.

PrototypeC3A02/DashboardView.swift
  Data scope, generation call, save insight, dan presentation.

PrototypeC3A02/ModelSelectionView.swift
  Foundation Models readiness dan prototype engine selection UI.

PrototypeC3A02Tests/LocalLLMModelTests.swift
  Shared prompt/parser/output safety tests.
```

## 4. Fase 0 — Siapkan UI dan Dummy Data

Foundation Models dapat diintegrasikan setelah UI dan dummy data tersedia; UI final tidak harus selesai.

Checklist:

- Gunakan `[StoryEntry]` sebagai input generation.
- Gunakan vocabulary domain project saat ini sebagai source of truth:
  - session: `morning`, `afternoon`, `evening`, `night`
  - mood: `angry`, `disgust`, `fear`, `happy`, `sad`, `surprise`
  - built-in activity: `play`, `sleep`, `study`, `eat`, `getReady`, `wakeUp`
  - built-in place: `house`, `outdoor`, `school`, `publicPlace`
  - child gender: `boy`, `girl`
- Gunakan `CustomActivity` dan `CustomPlace` untuk nilai custom; jangan menambahkan enum case baru hanya untuk menyesuaikan contoh lama.
- Pertahankan scope yang sudah ada: semua data, mingguan, atau tanggal tertentu.
- Biarkan `DashboardView` memilih event sebelum memanggil runtime.
- Jangan memasukkan SwiftUI view state atau rendered text ke prompt.
- Hentikan generation jika scope tidak memiliki event.

Gate fase: selected events dapat diberikan ke `AppleFoundationModelsRuntime.generateAnalytics(...)` tanpa dependency pada layout dashboard final.

## 5. Fase 1 — Pasang Foundation Models

Foundation Models adalah system framework, bukan package atau downloadable app model.

Checklist:

- Build dengan SDK yang menyediakan `FoundationModels`.
- Pertahankan conditional import:

```swift
#if canImport(FoundationModels)
import FoundationModels
#endif
```

- Pertahankan availability guard iOS/iPadOS 26 sebelum mengakses API.
- Jangan menambahkan Swift package, `.mlmodel`, `.litertlm`, atau network inference untuk jalur Apple.
- Jangan menampilkan tombol download model Apple.

Gate fase:

- Source tetap dapat dikompilasi ketika module tidak tersedia karena `#if canImport`.
- Device/OS yang tidak mendukung menerima `unsupportedOS`, bukan crash.

## 6. Fase 2 — Tes Koneksi dan Availability

Untuk Foundation Models, “tes koneksi” bukan network request. Tes ini memastikan system model siap menerima session.

Gunakan property yang sudah ada:

```swift
AppleFoundationModelsRuntime.isAvailable
AppleFoundationModelsRuntime.readinessMessage
```

Implementasi saat ini memeriksa `SystemLanguageModel.default.availability` dan memetakan state:

| State | Perilaku |
| --- | --- |
| `.available` | Izinkan Apple generation. |
| `.unavailable(.deviceNotEligible)` | Jelaskan device tidak eligible, gunakan Gemma fallback. |
| `.unavailable(.appleIntelligenceNotEnabled)` | Jelaskan Apple Intelligence belum aktif, tawarkan Gemma fallback. |
| `.unavailable(.modelNotReady)` | Jelaskan system model masih disiapkan, izinkan retry nanti atau Gemma fallback. |
| unknown / framework / OS unavailable | Jangan buat session; gunakan fallback policy. |

Acceptance check:

- `isAvailable` hanya `true` untuk `.available`.
- Readiness message aman untuk UI dan tidak menampilkan native dump.
- App tidak membuat `LanguageModelSession` saat unavailable.
- Hardware yang secara produk termasuk target tetap harus lolos runtime check.

## 7. Fase 3 — Generation

Call site yang sudah ada:

```swift
let insight = try await AppleFoundationModelsRuntime.generateAnalytics(
    events: selectedEvents,
    configuration: library.configuration
)
library.saveGeneratedInsight(insight)
```

Urutan internal saat ini:

1. Tolak event kosong.
2. Pastikan Foundation Models tersedia pada framework, OS, dan runtime.
3. Ambil `SystemLanguageModel.default`.
4. Buat `LanguageModelSession` baru dengan `configuration.systemPrompt`.
5. Bangun prompt melalui shared `LocalModelLibrary.analyticsUserPrompt(...)` dengan maksimal 16 event.
6. Map shared configuration ke `GenerationOptions`:
   - `maxTokens` di-clamp ke 128...512;
   - `temperature` di-clamp ke 0...2;
   - `topP` di-clamp ke 0.05...1;
   - temperature 0 memakai greedy, selain itu random probability threshold.
7. Panggil `session.respond(to:options:)`.
8. Normalisasi `response.content` menjadi `GeneratedLLMAnalyticsInsight`.
9. Simpan domain result, bukan transcript/session/raw response.

Setiap request memakai session baru. Jangan mempertahankan conversation lintas generation dan jangan mengirim dua request concurrent pada session yang sama.

## 8. Fase 4 — Normalisasi Output dan Larangan Raw JSON

Kondisi implementasi saat ini penting: Apple runtime masih memanggil text response API dan meneruskan `response.content` ke `LocalLLMAnalyticsParser`. Jadi, walaupun engine-nya Apple, response saat ini tetap mengikuti JSON transport contract dari shared system prompt.

Pipeline saat ini:

```text
Foundation Models response.content
-> LocalLLMAnalyticsParser.parse(...)
-> GeneratedLLMAnalyticsInsight
-> curated recommendations
-> save
-> dashboard cards
```

Raw JSON tidak boleh tampil. Proteksi yang sudah digunakan bersama Gemma:

- extract JSON dari markdown fence atau surrounding text;
- strict decode lalu salvage jika JSON terpotong;
- fallback summary tidak mengembalikan blob JSON;
- `repairFallbackInsight(...)` memperbaiki saved raw JSON lama;
- recommendation evidence menolak raw JSON;
- dashboard hanya membaca field domain insight.

Aturan wajib:

- Jangan bind `response.content` langsung ke UI.
- Jangan menyimpan `response.content` sebagai summary atau insight payload.
- Jangan menyimpan transcript `LanguageModelSession`.
- Jangan memakai raw response dalam telemetry/error report production.
- Jika parsing tidak menghasilkan payload aman, tampilkan fallback/failure state dan izinkan request baru dengan scope lebih kecil.

Jika project di masa depan mengganti Apple path ke guided/typed generation, hasil akhirnya tetap harus dimap ke `GeneratedLLMAnalyticsInsight`, dan shared context/system prompt/config tidak boleh diduplikasi. Perubahan itu belum ada dalam implementasi saat ini dan bukan bagian dari dokumen ini.

## 9. Fase 5 — Session dan Memory Lifecycle

Apple mengelola model system. App hanya mengelola object transient miliknya.

Lifecycle:

```text
availability check
-> create one-shot LanguageModelSession
-> generate
-> parse/map to GeneratedLLMAnalyticsInsight
-> save compact insight
-> release session, prompt, response, dan task references
```

Aturan:

- Jangan menawarkan load/offload model Apple.
- Jangan cache `LanguageModelSession` sebagai singleton permanen.
- Cancel task generation saat flow dibatalkan atau app masuk background bila task reference tersedia.
- Release session dan transient data setelah success maupun failure.
- Jangan menjanjikan app dapat mengosongkan memory system model; lifecycle model berada di bawah iOS/iPadOS.

## 10. Fase 6 — Swift Unit Test

Gunakan XCTest target `PrototypeC3A02Tests`.

Shared tests yang sudah ada dan relevan untuk Apple path:

- `LocalLLMConfiguration.default` Codable dan stabil;
- prompt berisi dashboard JSON contract;
- user prompt membatasi event rows, tidak memuat `System:`, dan tetap compact;
- Apple-labelled valid response diparse menjadi summary, triggers, patterns, dan curated recommendations;
- truncated/malformed response tidak menampilkan raw JSON;
- legacy saved schema dan raw JSON fallback dapat direpair.

Coverage yang perlu dipertahankan saat membawa implementasi ini ke app final:

```swift
func testBothEnginesUseTheSameConfigurationSource() {
    let configuration = LocalLLMConfiguration.default
    XCTAssertEqual(configuration.systemPrompt, LocalLLMConfiguration.defaultSystemPrompt)
    XCTAssertEqual(configuration.contextNotes, LocalLLMConfiguration.defaultContextNotes)
}

func testAppleTextOutputNeverBecomesRawJSONSummary() {
    let insight = LocalLLMAnalyticsParser.parse(
        modelOutput: #"{"summary":"partial","commonTriggers":["#,
        modelName: AppleFoundationModelsRuntime.displayName
    )
    XCTAssertFalse(insight.summary.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"))
}
```

Availability state mapping idealnya diuji dengan adapter/fake value ketika runtime dipindahkan ke app final. Implementasi prototype membaca singleton system model secara langsung, sehingga state riil tetap harus diuji pada physical device.

Physical-device matrix:

- iPhone 15 Pro atau lebih baru, Apple Intelligence aktif dan model ready;
- iPhone target dengan Apple Intelligence dimatikan;
- iPad M1 atau lebih baru, Apple Intelligence aktif dan model ready;
- state model not ready;
- device non-eligible untuk memastikan Gemma fallback muncul;
- background/cancel saat generation.

## 11. Fase 7 — Integrasi Default dan Fallback

Flow produk yang dituju berdasarkan dua runtime saat ini:

```text
User memilih data scope dan menekan Generate Insight
-> event kosong? stop
-> AppleFoundationModelsRuntime.isAvailable?
   -> yes: Apple generation -> normalize -> save -> render
   -> no: Gemma-4-E2B-it installed?
      -> yes: load -> generate -> normalize -> offload -> save -> render
      -> no: tampilkan setup/download Gemma
```

Fallback ke Gemma diputuskan sebelum generation dimulai. Error refusal/guardrail atau generation error dari request Apple yang sudah berjalan tidak otomatis mengirim data yang sama ke Gemma. Buat request baru setelah user retry dan gunakan scope lebih kecil bila perlu.

## 12. Checklist Selesai

- [ ] Foundation Models menjadi default engine.
- [ ] Product eligibility mengikuti iPhone 15 Pro ke atas dan iPad M1 ke atas.
- [ ] Runtime availability tetap diperiksa sebelum setiap generation.
- [ ] Tidak ada model file/download untuk jalur Apple.
- [ ] Session memakai shared `configuration.systemPrompt`.
- [ ] Prompt memakai shared `analyticsUserPrompt(...)` dan context yang sama dengan Gemma.
- [ ] Configuration berasal dari object yang sama dengan Gemma.
- [ ] Hasil selalu `GeneratedLLMAnalyticsInsight`.
- [ ] Raw response/raw JSON/transcript tidak dirender atau disimpan.
- [ ] Curated recommendations dipasang setelah normalization.
- [ ] Session dan transient references dilepas setelah request.
- [ ] XCTest shared prompt/parser/output-safety lulus.
- [ ] Availability dan generation diuji pada physical iPhone serta iPad yang eligible.
- [ ] Gemma hanya muncul sebagai fallback ketika Apple unavailable.

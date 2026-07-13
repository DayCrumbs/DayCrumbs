# LiteRT-LM Gemma-4-E2B-it iOS/iPadOS Implementation Guide

Panduan ini khusus untuk jalur kompatibilitas `Gemma-4-E2B-it` yang sudah ada di `PrototypeC3A02`. Gemma bukan engine utama. App memakainya hanya ketika Apple Foundation Models tidak tersedia pada device, belum aktif, atau belum siap.

Dokumen ini tidak menambahkan arsitektur atau model baru. Semua nama type, alur, prompt, parser, downloader, dan test mengacu pada implementasi project saat ini.

Panduan engine utama ada di [Apple-Foundation-Models-iOS-iPadOS-Implementation-Guide.md](Apple-Foundation-Models-iOS-iPadOS-Implementation-Guide.md).

## 1. Posisi Gemma dalam Produk

Kebijakan engine:

1. Cek `AppleFoundationModelsRuntime.isAvailable`.
2. Jika `true`, gunakan Apple Foundation Models.
3. Jika `false`, gunakan `Gemma-4-E2B-it` melalui LiteRT-LM bila model sudah terpasang.
4. Jika Gemma belum terpasang, minta user men-download model sebelum generation.

Gemma adalah fallback kompatibilitas untuk device yang tidak dapat memakai Foundation Models. Model tetap berjalan on-device dan data story event tidak dikirim ke layanan inference eksternal.

Catatan kondisi prototype: `DashboardView` saat ini masih mengikuti `selectedAnalysisEngine` yang dipilih melalui UI. Saat mengadopsi kebijakan Apple-default, keputusan otomatis di atas harus menjadi aturan produk; jangan membuat prompt, context, atau schema baru untuk resolver tersebut.

## 2. Shared Contract: Jangan Dibuat Ulang untuk Gemma

Gemma dan Apple Foundation Models wajib memakai input dan hasil domain yang sama. Source of truth saat ini adalah:

| Contract | Source of truth project |
| --- | --- |
| System prompt | `LocalLLMConfiguration.defaultSystemPrompt` |
| Context notes | `LocalLLMConfiguration.defaultContextNotes` |
| Sampling/config yang disimpan app | `LocalLLMConfiguration.default` |
| Event sorting, row format, dan task prompt | `LocalModelLibrary.analyticsUserPrompt(...)` |
| Hasil domain | `GeneratedLLMAnalyticsInsight` |
| Trigger dan pattern | `GeneratedLLMCommonTrigger`, `GeneratedLLMObservedPattern` |
| Recommendation | Curated matcher yang dipanggil oleh initializer insight |
| Output normalization | `LocalLLMAnalyticsParser` |

Aturannya:

- Jangan membuat `GemmaSystemPrompt`, `GemmaContext`, atau config analytics kedua.
- Jangan copy-paste isi prompt ke runtime Gemma.
- Teruskan object `LocalLLMConfiguration` yang sama dari `LocalModelLibrary` ke proses load dan generation.
- Gunakan `LocalModelLibrary.analyticsUserPrompt(...)` untuk membangun user prompt.
- UI dan persistence hanya menerima `GeneratedLLMAnalyticsInsight`, bukan string response model.
- Perbedaan engine hanya berada pada adapter inference: conversation LiteRT-LM untuk Gemma dan `LanguageModelSession` untuk Apple.

Low-level config yang tidak didukung salah satu engine boleh dipetakan oleh adapter masing-masing, tetapi nilai produk tetap berasal dari object configuration yang sama. Pada Gemma saat ini, `topK`, `topP`, `temperature`, accelerator, thinking, dan speculative decoding diterapkan oleh LiteRT-LM runtime.

## 3. File Implementasi yang Sudah Ada

```text
PrototypeC3A02/LocalLLMModels.swift
  Shared configuration, prompt builder, model catalog, downloader,
  installed metadata, analytics parser, dan insight domain model.

PrototypeC3A02/LiteRTLMAnalyticsRuntime.swift
  Load, connection/conversation setup, generation, retry, dan offload.

PrototypeC3A02/LiteRTLMVendor/
  Swift wrapper dan vendored CLiteRTLM.xcframework.

PrototypeC3A02/DashboardView.swift
  Data scope, generate action, save insight, dan presentation.

PrototypeC3A02/ModelSelectionView.swift
  Download, status, configuration, load/offload prototype controls.

PrototypeC3A02Tests/LocalLLMModelTests.swift
  Catalog, prompt, parser, repair, dan recommendation unit tests.
```

## 4. Fase 0 — Siapkan UI dan Dummy Data

Fase model tidak bergantung pada UI final. Jika dashboard dan dummy data sudah ada, pertahankan keduanya dan gunakan `StoryEvent` sebagai input.

Checklist:

- Pastikan generation menerima `[StoryEvent]`, bukan data yang sudah dirender menjadi view.
- Pertahankan scope yang sudah ada di `DashboardView`: semua data, mingguan, atau tanggal tertentu.
- Gunakan data hasil scope sebagai argument `events`.
- Jangan mengubah dummy data hanya untuk memenuhi output model.
- Pastikan empty scope menghentikan generation sebelum model dipanggil.

Gate fase: array event yang dipilih UI dapat diteruskan ke runtime tanpa perubahan schema UI.

## 5. Fase 1 — Pasang Runtime dan Model

### 5.1 Pasang LiteRT-LM

Project saat ini memakai vendored `CLiteRTLM.xcframework`, bukan product SwiftPM `LiteRTLM`.

Checklist target Xcode:

- Link `CLiteRTLM.xcframework` ke app target.
- Embed dan sign framework.
- Sertakan source wrapper dalam `LiteRTLMVendor/Swift/` ke target.
- Import native module dengan `import CLiteRTLM` di balik `#if canImport(CLiteRTLM)`.
- Pastikan framework memiliki slice physical device yang diperlukan.

Jika framework tidak terpasang, runtime saat ini menghasilkan error:

```text
CLiteRTLM is not linked. Rebuild after adding the LiteRT-LM framework to the app target.
```

### 5.2 Pasang Gemma-4-E2B-it

Entry catalog yang digunakan:

```text
ID: gemma-4-e2b-it-litertlm
Model: Gemma-4-E2B-it
Repository: litert-community/gemma-4-E2B-it-litert-lm
File: gemma-4-E2B-it.litertlm
Runtime: LiteRT-LM
Expected size: 2,583,085,056 bytes
```

Downloader saat ini:

- menyimpan model di `Documents/LocalLLMModels/<model.id>/`;
- memakai temporary file `*.download`;
- melanjutkan partial download dengan HTTP range;
- menghitung progress dari bytes bila size tersedia;
- memperbaiki completed partial download saat app start;
- menyimpan installed metadata melalui `LocalModelLibrary`.

Gate fase:

- File final `.litertlm` ditemukan oleh `liteRTLMModelFileURL(for:)`.
- `LocalModelLibrary.selectedInstalledModel` menunjuk ke model Gemma yang terpasang.
- App tidak menandai model installed sebelum file final tersedia.

## 6. Fase 2 — Tes Koneksi Runtime

Untuk model lokal, “tes koneksi” berarti memastikan app dapat membuka file model, menginisialisasi engine, dan membuat conversation. Ini bukan tes internet dan tidak mengirim event ke server.

Gunakan flow yang sudah ada:

```swift
await runtimeSession.load(
    model: installed,
    configuration: library.configuration
)
```

`LocalLLMRuntimeSession.load(...)` saat ini melakukan:

1. Release runtime lama.
2. Validasi runtime model adalah `.liteRTLM`.
3. Cari file `.litertlm`.
4. Buat `EngineConfig` dengan CPU/GPU dan context token budget.
5. Panggil `engine.initialize()`.
6. Buat `Conversation` memakai shared system prompt dan shared config.
7. Ubah state menjadi `.loaded` atau `.failed`.

Acceptance check:

- State berakhir pada `.loaded`.
- Pesan state menyebut model siap untuk analytics.
- Tidak ada data story event yang dibutuhkan untuk tes load ini.
- Bila gagal, UI membaca `state.message`; jangan lanjut ke generation.

## 7. Fase 3 — Generation

Gunakan flow yang sudah ada di `DashboardView` dan `LocalLLMRuntimeSession`:

```swift
let insight = try await runtimeSession.generateAnalytics(
    events: selectedEvents,
    configuration: library.configuration,
    model: installed
)
library.saveGeneratedInsight(insight)
```

Urutan internal saat ini:

1. Tolak input event kosong.
2. Pastikan model yang benar sudah loaded.
3. Bangun prompt melalui `LocalModelLibrary.analyticsUserPrompt(...)`.
4. Gunakan maksimal 24 event pada percobaan pertama.
5. Kirim message ke `Conversation`.
6. Jika gagal, reset conversation dan retry sekali dengan maksimal 10 event.
7. Release conversation dan engine.
8. Parse response menjadi `GeneratedLLMAnalyticsInsight`.
9. Simpan insight terstruktur dan render ke dashboard.

Jangan memasukkan ulang system prompt ke user prompt. System prompt sudah diberikan sebagai `Message(..., role: .system)` ketika conversation dibuat; `analyticsUserPrompt(...)` hanya membawa context, event rows, dan task.

## 8. Fase 4 — Normalisasi Output dan Larangan Raw JSON

Gemma saat ini diminta menghasilkan compact JSON karena LiteRT-LM mengembalikan text. JSON tersebut hanya transport internal dan tidak boleh dirender langsung.

Pipeline wajib:

```text
LiteRT-LM response string
-> LocalLLMAnalyticsParser.parse(...)
-> GeneratedLLMAnalyticsInsight
-> curated recommendations
-> save
-> dashboard cards
```

Proteksi yang sudah ada di parser:

- mengekstrak object dari markdown fence atau text tambahan;
- strict decode terlebih dahulu;
- salvage summary, triggers, dan patterns dari JSON terpotong;
- mengenali legacy `notablePatterns`;
- tidak memakai raw JSON sebagai recommendation evidence;
- mengganti raw/malformed JSON dengan pesan retry yang ramah;
- memperbaiki saved insight lama melalui `repairFallbackInsight(...)`.

Aturan presentation:

- Jangan pernah bind `response.toString` ke `Text`.
- Jangan menyimpan full raw response sebagai `summary`.
- Jangan memakai raw response untuk `basedOnEvidence`.
- Bila parser tidak mendapatkan payload aman, tampilkan fallback summary atau failure state, bukan JSON.
- Debug logging boleh mencatat kategori error, tetapi jangan memasukkan data anak atau full raw output ke telemetry production.

## 9. Fase 5 — Lifecycle dan Memory

Lifecycle saat ini:

- load just-in-time;
- generation;
- release `Conversation` dan `Engine` setelah success atau failure;
- offload saat app masuk background;
- offload saat memory warning;
- offload setelah idle timeout ketika hanya loaded.

`conversation?.cancel()` dipanggil sebelum reference dilepas. UI production tidak perlu menawarkan manual load/offload; kontrol tersebut saat ini berguna untuk prototype dan diagnosis.

Gate fase:

- Repeated generation tidak mempertahankan conversation lama.
- State kembali ke `.offloaded` setelah generation berhasil.
- Background dan memory warning tidak meninggalkan model loaded.

## 10. Fase 6 — Swift Unit Test

Gunakan XCTest target yang sudah ada: `PrototypeC3A02Tests`.

Test yang sudah tersedia dan harus tetap hijau:

- catalog menemukan `gemma-4-e2b-it-litertlm` dengan repo, filename, size, dan default config yang benar;
- `LocalLLMConfiguration.default` dapat encode/decode tanpa berubah;
- analytics prompt memuat contract dashboard;
- user prompt membatasi event rows dan tidak menduplikasi `System:`;
- valid JSON dipetakan ke summary, triggers, patterns, dan curated recommendations;
- markdown-fenced JSON dapat diparse;
- truncated JSON diselamatkan tanpa raw JSON menjadi summary;
- malformed JSON tidak menjadi recommendation evidence;
- legacy `notablePatterns` dimigrasikan;
- saved raw JSON fallback diperbaiki;
- partial download yang sudah lengkap direpair menjadi installed model.

Tambahan unit-test coverage yang perlu dipertahankan saat integrasi ke app final:

```swift
func testBothEnginesUseTheSameConfigurationSource() {
    let configuration = LocalLLMConfiguration.default
    XCTAssertEqual(configuration.systemPrompt, LocalLLMConfiguration.defaultSystemPrompt)
    XCTAssertEqual(configuration.contextNotes, LocalLLMConfiguration.defaultContextNotes)
}

func testMalformedGemmaOutputNeverBecomesRawJSONSummary() {
    let insight = LocalLLMAnalyticsParser.parse(
        modelOutput: #"{"summary":"partial","commonTriggers":["#,
        modelName: "Gemma-4-E2B-it"
    )
    XCTAssertFalse(insight.summary.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"))
}
```

Test runtime native tetap perlu dilakukan pada physical iPhone/iPad karena XCTest parser tidak membuktikan bahwa binary model dapat di-load atau memory cukup.

## 11. Fase 7 — Integrasi Apple-Default

Setelah masing-masing adapter lolos test:

```text
Generate Insight
-> AppleFoundationModelsRuntime.isAvailable?
   -> yes: Apple Foundation Models
   -> no: validated Gemma installation available?
      -> yes: load -> generate -> parse -> offload
      -> no: tampilkan setup/download Gemma
```

Jangan fallback dari Apple ke Gemma setelah Apple generation sudah dimulai hanya karena response ditolak atau generation error. Gemma dipilih ketika Apple diketahui unavailable sebelum request dimulai. Ini mencegah request yang sama diproses dua engine tanpa keputusan produk yang jelas.

## 12. Checklist Selesai

- [ ] Gemma hanya berfungsi sebagai compatibility/accessibility fallback.
- [ ] `CLiteRTLM.xcframework` linked, embedded, dan signed.
- [ ] `Gemma-4-E2B-it` ter-download dan tervalidasi.
- [ ] Load test berakhir pada state `.loaded`.
- [ ] Prompt dan context berasal dari shared `LocalLLMConfiguration`.
- [ ] User prompt berasal dari shared `analyticsUserPrompt(...)`.
- [ ] Generation menghasilkan `GeneratedLLMAnalyticsInsight`.
- [ ] Raw response atau raw JSON tidak pernah dirender atau disimpan sebagai insight.
- [ ] Retry memakai context lebih kecil.
- [ ] Runtime selalu offload setelah generation/background/memory warning.
- [ ] XCTest parser, prompt, catalog, dan repair lulus.
- [ ] Load/generate/offload diuji pada physical device fallback target.

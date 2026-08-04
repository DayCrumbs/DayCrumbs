# Workplan Gemma-4-E2B-it v2 untuk iOS/iPadOS

Status: implementasi kode selesai; verifikasi physical-device dan VoiceOver manual tertunda
Terakhir diperbarui: 3 Agustus 2026
Target project: `DayCrumbs`

Dokumen ini menggantikan workplan prototype lama. Nama type, urutan kerja,
acceptance gate, dan integrasi Dashboard di bawah mengikuti kondisi repository
DayCrumbs saat ini.

Gemma-4-E2B-it adalah fallback on-device. Apple Foundation Models tetap menjadi
engine yang dipilih otomatis ketika
`SystemLanguageModel.default.availability == .available`.

## 1. Keputusan Produk yang Tidak Boleh Berubah

- Gemma bukan model picker dan bukan engine yang dipilih manual oleh user.
- `AnalysisEngine` hanya memiliki `.appleFoundationModels` dan `.gemma4E2B`.
- Apple Foundation Models selalu dipilih ketika tersedia tepat sebelum generation.
- Gemma dipilih hanya ketika Apple Foundation Models sudah diketahui unavailable
  sebelum generation dimulai dan instalasi Gemma tervalidasi.
- Error atau refusal dari request Apple yang sudah berjalan tidak boleh otomatis
  mengirim data yang sama ke Gemma.
- Jika kedua engine tidak tersedia, Dashboard menampilkan setup/download alert
  dan berhenti.
- Gemma menerima `AnalyticsContext` asli. Gemma tidak boleh memakai Apple native
  translation coordinator.
- Semua inference berjalan lokal. Story data tidak boleh dikirim ke server,
  external AI API, atau Private Cloud Compute.
- Model tidak boleh di-download otomatis. Download harus dimulai dari tindakan
  eksplisit user.
- File `.litertlm` tidak boleh dibundel di app atau disimpan di SwiftData.
- UI production tidak menyediakan load, offload, delete, repair, prompt,
  configuration, atau diagnostics control.
- Dashboard tetap memakai range `Day`, `Week`, dan `Month`, dengan rolling
  boundaries yang sudah ditentukan project.
- Dashboard generation tetap otomatis saat entries selesai dimuat atau range
  berubah. Tidak ada production `Generate Insight` button.

## 2. Kondisi Repository Sebelum Implementasi

Implementasi harus berangkat dari kenyataan berikut:

- `DashboardViewModel` masih bergantung langsung pada
  `AppleLocalizedInsightGenerating`.
- `AnalyticsInsightGenerating` masih merupakan kontrak internal pipeline Apple
  karena menerima input-preparation handler untuk native translation.
- Belum ada `AnalysisEngine` dan engine resolver.
- Shell lama masih memakai tab Story, Dashboard, dan Models.
- Belum ada `LocalModelDescriptor`, `LocalModelInstallation`, repository model,
  downloader, storage validator, parser Gemma, atau LiteRT runtime adapter.
- Folder `Catalog`, `Download`, `Parsing`, `Runtime`, `Storage`,
  `Vendor/Frameworks`, dan `Vendor/Swift` masih placeholder.
- Belum ada `CLiteRTLM.xcframework` atau wrapper Swift vendored.
- Schema `DayCrumbsModelContainer` belum memuat metadata instalasi model.
- Shared input yang sudah ada adalah `AnalyticsContext` dari
  `AnalyticsContextBuilder`.
- Shared output yang sudah ada adalah `AnalyticsInsight`.
- Shared system policy yang sudah ada adalah `AnalyticsSystemPrompt` dan
  `LocalLLMConfiguration`.
- Recommendation source yang sudah ada adalah `ParentRecommendationCatalog`.

Workplan tidak boleh membuat ulang vocabulary, context, prompt policy, atau
hasil domain hanya untuk Gemma.

## 3. Dependency yang Dikunci

### 3.1 LiteRT-LM

Gunakan satu versi yang dipin untuk framework dan wrapper:

```text
Repository:
https://github.com/google-ai-edge/LiteRT-LM

Tag:
v0.14.0

iOS framework:
CLiteRTLM.xcframework.zip

Framework URL:
https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.14.0/CLiteRTLM.xcframework.zip

GitHub release asset SHA-256:
dddac2f6713ed65eaf01c18e115d9fec22184adf575cc7856a21387e8ba937e1

Swift wrapper source:
swift/ pada tag v0.14.0
```

Aturan integrasi:

- Jangan menambahkan product SwiftPM `LiteRTLM` ke app target.
- Vendor `CLiteRTLM.xcframework` ke
  `Services/LocalLLM/Vendor/Frameworks/`.
- Copy wrapper Swift resmi dari tag yang sama ke
  `Services/LocalLLM/Vendor/Swift/`.
- Runtime app mengimpor `CLiteRTLM`, bukan `LiteRTLM`.
- Jangan mencampur framework dari satu release dengan wrapper release lain.
- Verifikasi checksum archive sebelum mengekstrak.
- Verifikasi framework memuat slice `ios-arm64` dan
  `ios-arm64-simulator` sebelum konfigurasi target.
- Catat Apache-2.0 license/notice di resources metadata; jangan memasukkan
  binary model ke resources.

Package resmi v0.14.0 memakai linker flag `-all_load`. Kebutuhan flag tersebut
harus divalidasi bersama vendored wrapper sebelum konfigurasi target diubah.
Catatan supply-chain: release asset iOS diperbarui 10 Juli 2026 setelah
`Package.swift` pada tag dibuat. Karena itu checksum archive pada dokumen ini
mengikuti digest GitHub release asset ID `472710399`, bukan checksum lama yang
masih tertulis di manifest tag.

### 3.2 Gemma-4-E2B-it

Gunakan artifact berikut:

```text
Catalog ID:
gemma-4-e2b-it-litertlm

Display name:
Gemma-4-E2B-it

Repository:
litert-community/gemma-4-E2B-it-litert-lm

Filename:
gemma-4-E2B-it.litertlm

Download URL:
https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm

Expected byte count:
2,588,147,712

SHA-256:
181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c

License:
Apache-2.0
```

Ukuran dan checksum adalah bagian dari installation validation. Perubahan
artifact upstream adalah compatibility event dan harus dilakukan melalui update
catalog yang disengaja, bukan diterima diam-diam oleh downloader.

## 4. Arsitektur Target

```text
DashboardView
-> DashboardViewModel
-> DashboardInsightGenerating
-> AnalysisEngineResolver
   -> Apple adapter
      -> Apple input translation
      -> Apple typed generation
      -> Apple output localization
   -> Gemma adapter
      -> original AnalyticsContext
      -> LiteRT-LM text generation
      -> compact JSON parser
-> AnalyticsInsight
-> ParentRecommendationCatalog
-> Dashboard presentation
```

Boundary yang harus tersedia:

```swift
enum AnalysisEngine {
    case appleFoundationModels
    case gemma4E2B
}

protocol AnalysisEngineResolving {
    func resolveEngine() async throws -> AnalysisEngine
}

protocol DashboardInsightGenerating {
    func generateInsight(
        from entries: [StoryEntry],
        for range: TimeRange,
        using executeTranslationBatch: PreparedNativeTranslationBatchHandler
    ) async throws -> DashboardGeneratedInsight

    func releaseRuntime()
}
```

Nama final boleh disesuaikan dengan Swift conventions project, tetapi tanggung
jawab boundary tidak boleh digabung ke View.

`DashboardGeneratedInsight` adalah presentation result engine-neutral. Minimal:

- `AnalyticsInsight`
- trigger details yang sudah dicocokkan
- optional English fallback untuk jalur Apple
- engine yang benar-benar digunakan, untuk diagnostics internal

Engine bukan user preference dan tidak disimpan sebagai model picker.

## 5. Fase 0 — Bekukan Kontrak dan Fixture

### Pekerjaan

- Tambahkan dependency manifest kecil untuk LiteRT-LM dan Gemma metadata.
- Pastikan manifest menyimpan version, URLs, filename, byte count, checksum,
  dan license identifier.
- Gunakan `LocalLLMConfiguration.default` sebagai satu-satunya sumber event
  limits dan output budget.
- Pertahankan `AnalyticsContextBuilder` sebagai builder input kedua engine.
- Pertahankan `AnalyticsSystemPrompt` sebagai shared system policy.
- Dokumentasikan bahwa parser/repair hanya berlaku pada output text Gemma.
- Tambahkan fixture JSON valid, fenced, truncated, malformed, dan schema-incomplete
  untuk unit test parser. Fixture tidak boleh memuat data anak nyata.

### Gate

- Tidak ada type atau prompt prototype lama.
- Tidak ada vocabulary baru di luar enum domain project.
- Dependency version dan semua checksum tercatat satu kali.
- Test configuration yang sudah ada tetap hijau.

## 6. Fase 1 — Fondasi Model Lokal

### 6.1 Catalog

Buat `LocalModelDescriptor` yang immutable dan `Sendable`. Catalog production
hanya berisi Gemma-4-E2B-it.

Descriptor minimal:

- stable ID
- display name
- repository/download URL
- filename
- expected byte count
- expected SHA-256
- runtime kind
- license identifier

Jangan membuat array model pilihan di UI.

### 6.2 SwiftData Metadata

Buat `LocalModelInstallation` untuk metadata kecil saja:

- descriptor ID
- relative file path
- validated byte count
- validated SHA-256
- installation status
- installed/validated timestamp

Aturan:

- Jangan menyimpan absolute sandbox path jika relative path cukup.
- Jangan menyimpan binary atau raw model bytes.
- Jangan menandai `.installed` sebelum file final lolos validasi.
- Metadata tanpa file valid diperlakukan sebagai instalasi rusak/missing.
- File valid tanpa metadata boleh direkonsiliasi secara aman saat startup.

Tambahkan repository protocol agar ViewModel tidak mengakses SwiftData langsung.

### 6.3 Storage

Simpan file di Application Support, misalnya:

```text
Application Support/
  LocalModels/
    gemma-4-e2b-it-litertlm/
      gemma-4-E2B-it.litertlm
      gemma-4-E2B-it.litertlm.partial
```

Storage service harus:

- membangun URL dari stable descriptor ID;
- mencegah path traversal;
- membuat directory dengan aman;
- menghitung SHA-256 secara streaming, bukan membaca 2.58 GB ke satu `Data`;
- memindahkan partial file ke final secara atomic setelah validasi;
- menghapus atau mengarantina partial invalid secara recoverable;
- tidak menulis ke app bundle.

### Gate

- Catalog hanya menghasilkan satu descriptor production.
- SwiftData menyimpan metadata, bukan binary.
- Validator menolak wrong size dan wrong checksum.
- Repository dan storage mempunyai unit test berbasis temporary directory.
- Single-profile persistence tests tetap hijau.

## 7. Fase 2 — Downloader Produksi dan Models Tab

### 7.1 Download Service

Buat protocol-backed `LocalModelDownloadService`.

Required behavior:

- download hanya dimulai setelah explicit user action;
- preflight ruang penyimpanan sebelum request besar;
- progress berasal dari bytes written/expected;
- cancel aman;
- resume menggunakan mechanism yang didukung `URLSession`;
- partial download tidak dianggap installed;
- response HTTP, redirected final URL, dan expected content length divalidasi;
- final file selalu melalui byte-count dan SHA-256 validation;
- app relaunch dapat merekonsiliasi completed partial file;
- error dipetakan ke pesan ramah tanpa story data atau raw URL internals.

Downloader tidak boleh menerima atau membaca `StoryEntry`.

### 7.2 Private Insights Setup ViewModel

ViewModel menggabungkan:

- Apple Intelligence readiness internal;
- Gemma installation state;
- download state dan progress;
- user-facing failure;
- satu aksi setup/download.

Tidak ada:

- model picker;
- Apple download button;
- manual load/offload;
- delete/repair control production;
- prompt atau sampler settings.

### 7.3 Dashboard Setup Sheet

Production tidak memakai `TabView` atau Models screen. Setelah onboarding,
Dashboard adalah root dan Story dibuka dari aksi "Add story".

Saat Dashboard pertama kali tampil, setup sheet muncul jika Apple Foundation
Models unavailable dan Gemma belum valid. Sheet hanya menampilkan:

1. Penjelasan awam bahwa private insights memerlukan one-time download sekitar
   2.58 GB.
2. Satu tombol `Set Up Now`.
3. Progress/cancel UI selama download.
4. Ready state setelah checksum validation.

Nama Gemma, LiteRT-LM, model, engine, fallback, filename, repository, checksum,
dan istilah implementasi lain tidak boleh tampil di UI production.

Sheet boleh muncul otomatis, tetapi download hanya dimulai setelah user menekan
`Set Up Now`.

### Gate

- User harus menekan download sebelum transfer dimulai.
- Interrupted download dapat dilanjutkan atau dimulai ulang dengan aman.
- Wrong checksum tidak pernah menghasilkan Ready state.
- Tidak ada production Models screen atau model picker.
- UI tests hanya ditambah bila target UI test sudah tersedia; jangan mengubah
  `project.pbxproj` hanya untuk membuat target baru.

## 8. Fase 3 — Parser dan Transport Gemma

Kerjakan parser sebelum menghubungkan native runtime sehingga behavior output
dapat diuji tanpa file model 2.58 GB.

### 8.1 Prompt Serializer

Buat serializer khusus transport LiteRT yang menerima:

- `AnalyticsContext` asli;
- `TimeRange`;
- `AnalyticsSystemPrompt`;
- `LocalLLMConfiguration`.

Serializer:

- mempertahankan chronological ordering;
- memakai context yang sudah dibatasi `AnalyticsContextBuilder`;
- tidak melakukan Apple language detection atau native translation;
- meminta Gemma menjawab langsung dalam bahasa dominan parent notes/reflections,
  atau English ketika tidak ada parent-authored text;
- tidak menduplikasi system prompt ke user message;
- meminta compact JSON saja;
- tidak membuat `GemmaContext` atau vocabulary kedua.

### 8.2 Compact JSON DTO

DTO LiteRT mengikuti shape shared insight:

```json
{
  "summary": "One concise grounded paragraph.",
  "commonTriggers": [
    {
      "title": "Short trigger title.",
      "explanation": "Explanation grounded in supplied rows."
    }
  ],
  "observedPatterns": [
    {
      "title": "Short evidence label.",
      "evidence": "Concrete supplied observation.",
      "linkedTrigger": "Optional matching trigger title.",
      "contextTags": ["Optional supplied-row tags"]
    }
  ],
  "parentSuggestions": [
    {
      "linkedTrigger": "Exact commonTriggers title.",
      "title": "Short contextual support idea.",
      "recommendedActivities": ["Up to two practical, playful activities."],
      "whatMayHelp": ["Up to two gentle adjustments or observations."]
    }
  ],
  "parentReflectionPrompt": "One calm observation prompt.",
  "ethicalNote": "Non-diagnostic limitation."
}
```

### 8.3 Parser

Pipeline:

```text
LiteRT-LM text
-> bounded JSON extraction
-> strict DTO decode
-> LiteRT-only structural repair when safe
-> AnalyticsInsight(validating...)
-> grounding validation
-> grounded Gemma suggestion or ParentRecommendationCatalog fallback
-> DashboardGeneratedInsight
```

Rules:

- Jangan render atau persist raw response.
- Jangan memakai raw JSON sebagai summary, evidence, atau recommendation.
- Required field kosong adalah generation failure.
- `parentSuggestions` boleh absent/empty untuk compatibility, tetapi prompt meminta
  satu suggestion per eligible common trigger.
- Suggestion hanya dipakai bila `linkedTrigger` cocok dengan trigger yang lolos
  grounding; suggestion tidak mendapat curated source badge.
- Repair tidak boleh mengarang field yang hilang.
- Unknown keys boleh diabaikan hanya bila required schema tetap valid.
- Parsing error hanya menyimpan kategori error untuk logging.
- Story text dan full model output tidak masuk production log.

Grounding policy yang kini bernama Apple-specific harus diekstrak atau dibungkus
menjadi shared engine-neutral policy sebelum dipakai Gemma. Jangan copy-paste
grounding rule.

### Gate

- Valid compact JSON menghasilkan `AnalyticsInsight`.
- Markdown-fenced JSON dapat diekstrak secara bounded.
- Truncated/malformed/schema-incomplete output tidak pernah tampil sebagai text.
- Non-diagnostic validation tetap berlaku.
- Parser tests tidak membutuhkan framework atau physical device.

## 9. Fase 4 — Vendor dan Hubungkan LiteRT-LM

### 9.1 Source Preparation

- Download official v0.14.0 framework archive.
- Verifikasi archive checksum sebelum extract.
- Inspeksi slice dengan tooling Apple.
- Copy framework dan wrapper sources dari tag yang sama.
- Pertahankan license/notice.
- Jangan commit model `.litertlm`.

### 9.2 Xcode Approval Gate

`DayCrumbs.xcodeproj/project.pbxproj` adalah user-managed.

Sebelum perubahan target, jelaskan dan minta persetujuan eksplisit untuk edit
minimal berikut:

- link `CLiteRTLM.xcframework`;
- Embed & Sign framework;
- sertakan wrapper Swift di app target bila file-system-synchronized group belum
  cukup;
- tambahkan linker flag `-all_load` hanya jika hasil validasi v0.14.0
  membuktikannya diperlukan;
- jangan mengubah setting lain.

Tanpa persetujuan tersebut, source preparation boleh selesai tetapi konfigurasi
target harus berhenti.

### 9.3 Compile Gate

- `#if canImport(CLiteRTLM)` berhasil pada app target.
- Device dan simulator build menemukan module yang sama.
- Tidak ada SwiftPM product `LiteRTLM`.
- Tidak ada stale `Package.resolved` dari dependency LiteRT-LM.
- Clean build lulus sebelum runtime implementation dilanjutkan.

## 10. Fase 5 — Gemma Runtime Adapter

Buat protocol-backed runtime adapter di `Services/LocalLLM/Runtime/`.

Tanggung jawab:

- menerima validated local model URL;
- membuat writable compilation cache directory;
- memilih supported backend dengan policy yang eksplisit;
- membuat `EngineConfig`;
- initialize engine;
- membuat satu conversation untuk satu Dashboard request;
- menerapkan shared system instructions dan supported sampler policy;
- generate text;
- cancel conversation ketika task dibatalkan;
- melepas conversation dan engine pada semua exit path.

Lifecycle:

```text
validate installation
-> load engine just-in-time
-> create fresh conversation
-> generate compact JSON
-> release raw response after parsing
-> cancel conversation if needed
-> nil conversation
-> nil engine
-> offloaded
```

Retry:

- primary context memakai `configuration.primaryEventLimit`;
- retry maksimal sekali memakai deterministic `gemmaRecovery`;
- recovery memakai paling banyak 8 event, note 300 karakter, reflection 600
  karakter, greedy sampling, dan requested output maksimal 512 token;
- recovery prompt membatasi output menjadi maksimal dua trigger, satu observed
  pattern, satu activity, dan satu what-may-help per trigger;
- recovery harus berbeda dari primary walaupun range hanya memiliki delapan event
  atau kurang;
- retry hanya untuk context/resource atau parse/decode failure yang dinyatakan
  retryable;
- cancellation tidak retry;
- installation/runtime incompatibility tidak retry;
- setiap retry membuat conversation bersih;
- engine selalu offload setelah result atau failure.

Backend CPU/GPU dan experimental speculative decoding adalah internal policy.
Jangan expose ke production UI. Aktifkan hanya setelah physical-device evidence
menunjukkan memory, thermal, dan stability yang aman.

Current generation policy:

- runtime context `maxNumTokens` = 4.096 total input + output tokens;
- primary response budget = 768 tokens;
- nucleus sampling `topP = 0.9`, `topK = 40`, `temperature = 0.65`;
- recovery response budget = 512 tokens dengan greedy sampling;
- CPU backend memakai dua inference worker untuk membatasi sustained CPU sekitar
  dua core; auxiliary loader/callback thread masih dapat muncul sesaat;
- creative suggestions tetap dibatasi pada aktivitas low-risk dan tidak boleh
  berupa diagnosis, saran medis, hukuman, restraint, atau klaim hasil pasti.

### Gate

- Load test membuka file, initializes engine, dan membuat conversation.
- Empty entries berhenti sebelum model load.
- Successful generation menghasilkan shared `AnalyticsInsight`.
- Failure tidak meninggalkan engine atau raw output.
- Cancellation benar-benar membatalkan conversation.
- Repeated request tidak mempertahankan transcript lama.

## 11. Fase 6 — Engine Resolver dan Dashboard Orchestration

### 11.1 Resolver

Urutan wajib:

```text
selected range entries empty?
-> yes: publish empty state and stop

SystemLanguageModel.default.availability == .available?
-> yes: .appleFoundationModels
-> no: validated Gemma installation exists?
   -> yes: .gemma4E2B
   -> no: modelDownloadRequired
```

Resolver mengecek Apple availability tepat sebelum generation dan tidak
menyimpannya sebagai user preference.

### 11.2 Shared Orchestrator

`DashboardViewModel` berpindah dari Apple-only service ke
`DashboardInsightGenerating`.

Apple path:

- mempertahankan input translation;
- typed Foundation Models generation;
- output localization;
- English fallback dan translation-only retry.

Gemma path:

- memakai original `AnalyticsContext`;
- tidak memanggil translation coordinator/session;
- mendeteksi bahasa dominan gabungan parent-authored notes/reflections dengan
  `NLLanguageRecognizer` hanya untuk menetapkan target output di memori;
- mengirim nama bahasa dan BCP-47 identifier secara eksplisit pada system dan
  user prompt;
- memvalidasi bahasa seluruh field hasil setelah JSON parsing dan memakai satu
  recovery request yang sama jika bahasa output keliru;
- tidak melakukan translasi, language-pair availability checks, atau
  memunculkan download popup Translation framework;
- memakai label detail dan fallback katalog yang sesuai dengan bahasa output;
- compact JSON parse;
- tidak menawarkan translation-only retry.

Kedua path:

- menghasilkan `DashboardGeneratedInsight`;
- memakai `ParentRecommendationCatalog`;
- menghormati cancellation;
- mempublikasikan hanya jika captured range masih aktif;
- tidak mengubah chart/statistical aggregation.

### 11.3 Private Insights Setup Sheet

Sheet muncul pada Dashboard pertama kali ketika Apple unavailable dan Gemma
belum tervalidasi:

```text
Title:
Set Up Private Insights

Message:
To create insights privately on this device, DayCrumbs needs a one-time download of about 2.58 GB. The downloaded files stay on this iPhone or iPad.

Primary button:
Set Up Now

Secondary button:
Not Now
```

Primary action adalah konfirmasi jelas untuk memulai download. Tidak ada Models
flow terpisah dan tidak ada nama runtime/model teknis dalam copy.

### 11.4 Insight Persistence

Jika generated insights disimpan:

- gunakan repository shared;
- simpan normalized `AnalyticsInsight`, engine identifier, range, dan timestamp
  yang diperlukan;
- jangan simpan raw Gemma response, translated input, detected language, atau
  Apple session state;
- persistence failure dipetakan ke user-friendly state tanpa kehilangan
  runtime cleanup.

### Gate

- Apple available tidak membutuhkan Gemma.
- Apple unavailable + Gemma installed menggunakan Gemma.
- Kedua engine unavailable menghasilkan setup alert.
- Started Apple request tidak fallback ke Gemma setelah error.
- Selecting active range tetap no-op.
- Rapid range changes tidak mempublikasikan stale result.
- Translation-only retry tidak pernah menjalankan Gemma atau generation ulang.

## 12. Fase 7 — Lifecycle, Accessibility, dan Verification

### 12.1 Lifecycle

Release Gemma runtime pada:

- success;
- failure;
- cancellation/range change;
- Dashboard disappearance;
- app background;
- memory warning.

Memory warning handling harus berada pada app/service lifecycle boundary, bukan
di SwiftUI chart atau card.

### 12.2 Unit Tests

Tambahkan focused coverage:

- descriptor dan pinned metadata;
- streamed checksum validation;
- wrong size/wrong checksum;
- metadata/file reconciliation;
- partial download recovery;
- download cancellation;
- parser valid/fenced/truncated/malformed;
- raw JSON never published;
- context serializer chronological order;
- Apple: 24-event primary dan 10-event retry;
- Gemma: 24-event primary dan deterministic 8-event recovery;
- resolver matrix;
- empty range short-circuit;
- Apple failure does not fallback;
- Gemma bypasses Apple translation;
- stale-range publication guard;
- translation-only retry remains Apple-only;
- runtime cleanup on success/failure/cancellation.

Gunakan fakes untuk resolver, downloader, filesystem, checksum, dan runtime.
Unit tests tidak boleh men-download model asli.

### 12.3 Simulator Verification

- Jalankan full `DayCrumbs` scheme test suite.
- Build compact iPhone dan wide iPad simulator destinations.
- Verifikasi missing-model alert dan Models download states dengan fake services.
- Verifikasi Dashboard loaded, empty, failed, dan trigger detail accessibility.
- Catat bila tidak ada UI-test target; jangan membuat target lewat
  `project.pbxproj` tanpa approval.

Simulator build membuktikan compile/link dan UI orchestration, bukan runtime
memory/performance model.

### 12.4 Physical Device Verification

Gunakan minimal satu fallback-target iPhone dan satu iPad yang representatif.

Verifikasi:

- real 2.58 GB download;
- resume setelah interruption;
- checksum dan ready state;
- CPU/GPU backend yang dipilih;
- first load dan subsequent load;
- primary generation;
- smaller-context retry;
- cancellation saat range berubah;
- background cleanup;
- memory warning cleanup;
- peak memory, thermal behavior, dan app responsiveness;
- output tidak diagnostik dan hanya berdasar supplied rows;
- VoiceOver announcement, alert, focus, dan retry behavior.

Jangan menyatakan integrasi selesai hanya berdasarkan simulator atau parser
tests.

## 13. Urutan Implementasi

Kerjakan dalam urutan berikut:

1. Fase 0: manifest dan contract freeze.
2. Fase 1: catalog, metadata, repository, storage, validator.
3. Fase 2: downloader dan Models UI.
4. Fase 3: serializer, DTO, parser, normalization.
5. Fase 4: vendor source/framework dan approval konfigurasi Xcode.
6. Fase 5: native runtime adapter.
7. Fase 6: resolver dan Dashboard orchestration.
8. Fase 7: lifecycle serta full verification.

Jangan mulai integrasi Dashboard sebelum parser, installation validator, dan
runtime cleanup mempunyai focused tests.

## 14. Definition of Done

- [x] LiteRT-LM v0.14.0 dipin dan archive checksum tervalidasi.
- [x] Framework dan wrapper berasal dari tag yang sama.
- [x] `CLiteRTLM.xcframework` memiliki device dan simulator slices.
- [x] Tidak ada SwiftPM product `LiteRTLM`.
- [x] Model descriptor memakai exact current byte count dan SHA-256.
- [x] Download hanya dimulai setelah explicit confirmation.
- [x] Partial atau invalid file tidak pernah dianggap installed.
- [x] SwiftData hanya menyimpan metadata/path/checksum/status.
- [x] Production tidak memakai `TabView`, Models screen, atau model picker.
- [x] `AnalysisEngine` hanya memiliki Apple dan Gemma.
- [x] Resolver memilih Apple otomatis ketika available.
- [x] Gemma hanya dipakai ketika Apple unavailable sebelum generation.
- [x] Gemma menerima original `AnalyticsContext`.
- [x] Gemma tidak memanggil Apple translation flow.
- [x] Gemma mendeteksi bahasa parent, menetapkan target output eksplisit, dan
  merespons secara native tanpa translasi atau language-asset popup.
- [x] Compact JSON dinormalisasi menjadi `AnalyticsInsight`.
- [x] Gemma dapat membuat grounded parent suggestions dengan curated fallback.
- [x] Gemma memakai moderate sampling dan 768-token response budget.
- [x] Parse failure memakai deterministic 8-event recovery.
- [x] CPU inference dibatasi ke dua worker.
- [x] Raw model output tidak dirender, dipersist, atau dicatat.
- [x] Empty range berhenti sebelum model checks.
- [x] Stale range result tidak dapat dipublikasikan.
- [x] Runtime offload pada success, failure, cancellation, background, dan
      memory warning.
- [x] Unit tests catalog, storage, download, parser, resolver, dan lifecycle
      lulus.
- [x] Full `DayCrumbs` scheme tests lulus pada iOS Simulator.
- [ ] Load/generate/cancel/offload lulus pada physical iPhone dan iPad.
- [ ] Manual VoiceOver checks yang membutuhkan audio/focus sudah dicatat.
- [x] Tidak ada `.litertlm` di app bundle atau git repository.

## 15. Referensi yang Dipin

- [LiteRT-LM v0.14.0 release](https://github.com/google-ai-edge/LiteRT-LM/releases/tag/v0.14.0)
- [LiteRT-LM v0.14.0 Package.swift](https://raw.githubusercontent.com/google-ai-edge/LiteRT-LM/v0.14.0/Package.swift)
- [LiteRT-LM Swift API](https://developers.google.com/edge/litert-lm/swift)
- [Gemma-4-E2B-it LiteRT-LM model](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
- [Gemma model LFS metadata](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/raw/main/gemma-4-E2B-it.litertlm)

Jika dependency atau model artifact berubah, perbarui manifest, checksum,
compatibility tests, dan dokumen ini dalam satu perubahan yang dapat direview.

# 05 — AI Abstraction

AI **belum** dibuat di phase awal. Dokumen ini menetapkan kontraknya agar
phase 10–12 tidak mengubah arsitektur phase sebelumnya.

## 1. Prinsip

1. AI hanya menghasilkan **structured intent** (JSON).
2. AI tidak pernah mengakses database, file, shell, atau jaringan.
3. Business logic tetap di aplikasi (validator + repository).
4. Rule Parser bekerja lebih dulu; AI hanya untuk confidence rendah.
5. Aplikasi **tetap berfungsi penuh tanpa AI** (model tidak ada → fallback).
6. Tidak ada API key, tidak ada quota, tidak ada pengiriman data keluar.

## 2. Interface

```dart
// lib/shared/intents/ai_intent_result.dart

class AiIntentResult {
  const AiIntentResult({
    required this.intent,
    required this.confidence,
    this.entities = const {},
    this.needsConfirmation = true,
    this.rawJson,
  });

  /// salah satu dari IntentType yang didefinisikan aplikasi.
  final IntentType intent;

  /// 0.0 - 1.0
  final double confidence;

  /// kunci berbeda per intent (title, date, time, amount, items, dst).
  final Map<String, Object?> entities;

  final bool needsConfirmation;

  /// JSON mentah hasil model, hanya untuk log/debug lokal.
  final String? rawJson;
}
```

```dart
// lib/core/ai/local_ai_engine.dart

abstract class LocalAiEngine {
  Future<void> initialize();

  Future<AiIntentResult> understand(String text);

  Future<bool> isAvailable();

  Future<void> dispose();
}
```

```dart
// lib/core/ai/ai_config.dart
//
// SATU-SATUNYA tempat nama model, path file, dan parameter disimpan.
// Tidak ada hard-code nama model di tempat lain.
```

Catatan: kontrak di atas persis sesuai spesifikasi `PROJECT.md` bagian 7,
dengan tipe `AiIntentResult` yang didefinisikan aplikasi (bukan JSON mentah)
supaya aman secara tipe.

## 3. Interface pendukung

```dart
abstract class AiModelManager {
  Future<bool> downloadModel();      // opsional, dengan consent
  Future<bool> loadModel();
  Future<void> unloadModel();
  bool get isLoaded;
  String get modelName;
  int get sizeBytes;
}

abstract class IntentValidator {
  /// mengembalikan hasil valid, atau error yang bisa ditampilkan ke user.
  ValidatedIntent validate(AiIntentResult input);
}
```

`LocalAiEngine` hanya boleh dipanggil oleh `IntentProcessor`.
UI tidak boleh memanggil AI secara langsung.

## 4. Kontrak output JSON

Model wajib menghasilkan JSON valid berbentuk:

```json
{
  "intent": "create_reminder",
  "confidence": 0.96,
  "entities": {
    "title": "Bayar listrik",
    "date": "2026-10-06",
    "time": "08:00"
  },
  "needs_confirmation": false
}
```

Daftar `intent` yang sah (dari `PROJECT.md` bagian 10):

```
create_reminder, create_todo, create_shopping, create_expense,
create_note, create_journal, create_idea,
update_item, delete_item, complete_item, search,
unknown
```

Aturan validator:

1. Parse JSON gagal → tolak, fallback ke Rule Parser / tampilkan pilihan.
2. `intent` tidak ada di daftar → ubah ke `unknown`.
3. `confidence` di luar 0..1 → clamp, dan `needs_confirmation = true`.
4. Entity wajib per intent harus ada (mis. `create_expense` wajib `amount`);
   kurang → `needs_confirmation = true`, jangan pernah auto-save.
5. Tanggal/jam dinormalisasi oleh aplikasi, bukan dipercaya apa adanya.
6. Selalu simpan `rawJson` lokal (bukan untuk dikirim ke mana pun).

## 5. Larangan keras terhadap AI

AI TIDAK BOLEH memiliki kemampuan:

```
execute_shell
delete_database
send_network_request
file_write
send_notification
```

Implementasi yang diminta model untuk melakukan salah satu hal di atas wajib
ditolak oleh validator, dan dicatat sebagai error. Ini bukan fitur, ini
batas keamanan.

## 6. Threshold confidence (default, bisa disetel di config)

| Confidence | Perilaku |
|-----------|----------|
| ≥ 0.85 | langsung tampilkan kartu + tombol `Simpan` |
| 0.50 – 0.84 | tampilkan interpretasi + `Ya` / `Ubah` |
| < 0.50 | jangan menebak → teks dicatat ke Smart Inbox (PHASE 13) |
| `unknown` / gagal parse | jatuh ke Smart Inbox |

Threshold disimpan sebagai preferensi pengguna, bukan konstanta tersebar.

Implementasi (PHASE 11):

- Default ada di `AiConfig.acceptThreshold` (0.85) dan
  `AiConfig.uncertainThreshold` (0.50) — satu-satunya tempat konstanta.
- Nilai preferensi disimpan di tabel `user_preferences` dengan kunci
  `ai_confidence_accept` dan `ai_confidence_uncertain`, dibaca oleh
  `IntentProcessor` setiap pesan; nilai tidak valid atau tidak konsisten
  (`uncertain > accept`) otomatis jatuh ke default.
- Tabel di atas dipakai untuk **hasil jalur AI**. Hasil Rule Parser yang
  dikenal langsung dieksekusi tanpa kartu konfirmasi — Rule Parser punya
  confidence 0.7–0.95 dan dianggap aturan yang sudah teruji (bagian 7).
- Belum ada UI untuk mengubah threshold: nilainya sudah tersimpan sebagai
  preferensi dan bisa diubah lewat data; penyuntingan lewat layar
  Pengaturan bukan bagian DoD phase ini.

## 7. Integrasi dengan alur (ringkas)

Sebelum alur di bawah, `IntentProcessor` mengecek **perintah lanjutan**
(PHASE 12 — `FollowUpParser`): kalimat berawal `ubah` / `hapus` /
`selesaikan` / `tunda` menjadi intent kontekstual yang dirujukkan ke
`LastItemContext` (item terakhir, disimpan di preferensi). `hapus` selalu
minta konfirmasi; tanpa konteks atau tipe item belum didukung → balasan
penjelasan tanpa memanggil AI.

```
Normalizer → RuleParser → confidence tinggi? 
                              ├─ ya → ValidatedIntent
                              └─ tidak → LocalAiEngine.understand()
                                            ↓
                                      IntentValidator
                                            ↓
                                      Confirmation UI
                                            ↓
                                      Repository (aplikasi)
```

Ketika `LocalAiEngine.isAvailable() == false`:

- Aplikasi tetap jalan penuh untuk semua jalur Rule Parser.
- Input di luar Rule Parser → balasan penjelasan tanpa menyimpan data,
  tidak crash, tidak hang — dan teksnya dicatat ke Smart Inbox
  (PHASE 13, lihat bagian 10).

Implementasi PHASE 11:

- `core/intents/intent_processor.dart` — satu-satunya pemanggil
  `LocalAiEngine.understand()`; menghasilkan `IntentDisposition`
  (`execute` / `confirm` / `uncertain` / `rejected` / `unavailable`).
- `features/chat/.../intent_executor.dart` — menjalankan intent yang sudah
  dikonfirmasi ke repository (menyimpan `source` `rule`/`ai`).
- `features/chat/.../pending_confirmation.dart` — siklus konfirmasi
  (`confirm` / `reject` / `edit` / `abandon`) + draf input.
- `features/chat/.../widgets/confirmation_bar.dart` — kartu konfirmasi
  (`Simpan`/`Ya`+`Ubah`/`Batal`) di atas kolom chat.

Perilaku status pesan: pesan user yang menunggu keputusan disimpan dengan
`ChatStatus.needsConfirmation`; setelah konfirmasi/batal/ubah ia ditandai
`sent` + `resolvedAt`. Tidak ada data (todo, pengeluaran, dll.) yang
disimpan sebelum user menekan `Simpan`/`Ya`.

## 8. Kriteria pemilihan model (PHASE 10)

| Kriteria | Bobot |
|----------|-------|
| Lisensi komersial compatible | wajib |
| 100% offline on-device | wajib |
| Ukuran model | tinggi |
| RAM saat inference | tinggi |
| Dukungan Bahasa Indonesia | tinggi |
| Kualitas structured JSON output | tinggi |
| Latency di HP menengah | sedang |
| Kemudahan integrasi Flutter/Android | sedang |

Evaluasi dicatat di dokumen ini saat PHASE 10, termasuk alasannya dan hasil
benchmark sederhana.

### Hasil evaluasi (PHASE 10)

| Kandidat | Lisensi | Ukuran (q4) | Catatan | Keputusan |
|----------|---------|-------------|---------|-----------|
| **Qwen2.5-0.5B-Instruct-GGUF** | Apache-2.0 | ±469 MB | instruksi kuat di ukurannya, JSON rapi, Bahasa Indonesia lumayan | **DIPILIH** |
| Qwen2.5-1.5B-Instruct-GGUF | Apache-2.0 | ±1 GB | akurasi lebih tinggi, RAM/latensi 2–3× | cadangan bila 0.5B tidak cukup |
| Llama-3.2-1B-Instruct | Llama 3.2 Community | ±1,3 GB | lisensi komersial bersyarat, ID sedang | ditolak |
| SmolLM2-1.7B | Apache-2.0 | ±1,2 GB | dominan Inggris | ditolak |
| Gemma (kecil) | Google Gemma Terms | — | syarat lisensi + registrasi | ditolak |
| Phi-3.5-mini | MIT | ±2,3 GB | terlalu besar untuk perangkat menengah | ditolak |

Kriteria wajib (lisensi komersial, 100% offline) dipenuhi semua kandidat di
atas; pemilihan ditentukan oleh ukuran/RAM vs kualitas structured output.
Nama model, sumber, ukuran, dan parameter **hanya** ada di
`core/ai/ai_config.dart`.

## 9. Benchmark sederhana (DoD PHASE 10)

Uji setidaknya 20 kalimat campuran (rapi / informal / typo) dan catat:

- jumlah JSON valid
- jumlah intent benar
- rerata latency
- puncak pemakaian RAM
- perilaku saat model tidak dimuat (harus tetap jalan)

### Hasil (7 Oktober 2026)

Cara menjalankan (model diunduh sekali, lalu benchmark ±6 menit):

```powershell
$env:PA_AI_BENCHMARK='1'
flutter test test/core/ai/local_ai_real_test.dart
```

| Metrik | Hasil |
|--------|-------|
| Kalimat diuji | 20 (rapi, informal, typo) |
| JSON valid | **20/20** (grammar-constrained) |
| Intent benar | **17/20** (lantai DoD: ≥10) |
| Latency | rerata 13.967 ms, median 12.529 ms, min 5.796 ms, max 28.465 ms |
| RAM | sebelum inference 762 MB, puncak 833 MB (model ±469 MB + KV cache 4096 token) |
| Crash per kalimat | 0 (galat selalu berupa exception ter-tipe) |
| Tanpa model | aman: `initialize()` tidak melempar, `understand()` → `LocalAiUnavailableException`, Rule Parser tetap jalan |

Kasus yang masih salah (3): 2 soal nominal vs belanja ("Belanja mingguan …
empat ratus lima puluh ribu") dan 1 soal awalan "catet" — keduanya sudah
ditangani aturan eksplisit di prompt, tetapi model 0.5B tetap goyah di
batas ambigu. Ketidakakuratan ini aman karena output selalu melewati
`IntentValidator` (kurang entity → `needs_confirmation`, tidak pernah
auto-save).

Catatan pengukuran: `flutter test` (debug/`flutter_tester`) di Windows x64
CPU — bukan representasi HP menengah; angka di perangkat rilis akan berbeda.
Percobaan berulang bergerak di kisaran 16–18 benar dari 20 (greedy decoding
di CPU multithread tidak sepenuhnya deterministik).

## 10. Smart Inbox + pencarian (PHASE 13)

**Smart Inbox** mencatat input chat yang tidak bisa dipastikan maksudnya,
agar user bisa memprosesnya sendiri:

- **Kapan masuk**: disposition `uncertain` (confidence < 0.50),
  `unavailable` (AI belum dimuat dan Rule Parser tidak kenal), dan
  `rejected` (validator menolak output AI). Disposition `execute`,
  `confirm`, dan `noTarget` tidak dicatat.
- **Isi item**: `raw_text` (teks user apa adanya), `chat_message_id`
  (pesan asal), `suggestion` (storageValue intent bila AI sempat menebak,
  mis. `create_todo`; null bila tidak ada) — implementasi
  `ChatController._captureUnresolved`.
- **Auto-resolve**: saat teks yang sama akhirnya berhasil dieksekusi lewat
  chat (`ChatController._resolveInbox` pada disposition `execute`, atau
  `PendingConfirmationController._resolveInbox` setelah `confirm`),
  item terbuka dengan teks sama (normalisasi: trim + spasi rapat +
  lowercase) ditandai `converted` + `resolved_entity_type` dari
  `inboxEntityType(intent)`.
- **Ketahanan**: kegagalan menulis/menandai inbox dibungkus
  `on Object { // alasan }` — chat tidak pernah gagal gara-gara inbox.
- **Layar Inbox**: chip `Terbuka` / `Selesai` / `Semua`; aksi per item —
  `Simpan sebagai Catatan` (buat Note + tandai `converted`), `Buka di Chat`
  (isi `chatDraftProvider`, item tetap terbuka sampai teksnya dieksekusi),
  `Abaikan` (tandai `discarded`).

**Intent `search`** (jalur AI): hasil dicari lewat `SearchRepository`
(debounce 250 ms di UI, `limitPerType` per tipe); executor membalas tiga
hasil teratas di chat tanpa navigasi — daftar lengkap ada di layar
Pencarian (dari beranda, Kalender, dan Inbox).

## 11. Status

- [x] Interface dirancang
- [x] Kontrak output JSON
- [x] Aturan validator
- [x] Batasan keamanan AI
- [x] Kriteria pemilihan model
- [x] Implementasi → PHASE 10
- [x] Routing hybrid, fallback, konfirmasi → PHASE 11
- [x] Smart Inbox, auto-resolve, intent search → PHASE 13

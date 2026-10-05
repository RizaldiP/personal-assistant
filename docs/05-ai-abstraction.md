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
| < 0.50 | jangan menebak → tawarkan `Reminder` / `Todo` / `Catatan` (Smart Inbox) |
| `unknown` / gagal parse | jatuh ke Inbox |

Threshold disimpan sebagai preferensi pengguna, bukan konstanta tersebar.

## 7. Integrasi dengan alur (ringkas)

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
- Input di luar Rule Parser → masuk Smart Inbox, tidak crash, tidak hang.

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

## 9. Benchmark sederhana (DoD PHASE 10)

Uji setidaknya 20 kalimat campuran (rapi / informal / typo) dan catat:

- jumlah JSON valid
- jumlah intent benar
- rerata latency
- puncak pemakaian RAM
- perilaku saat model tidak dimuat (harus tetap jalan)

## 10. Status

- [x] Interface dirancang
- [x] Kontrak output JSON
- [x] Aturan validator
- [x] Batasan keamanan AI
- [x] Kriteria pemilihan model
- [ ] Implementasi → PHASE 10

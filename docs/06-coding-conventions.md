# 06 — Coding Conventions

Berlaku untuk seluruh codebase. `analysis_options.yaml` menegakkan sebagian
secara otomatis.

## 1. Dasar

- Bahasa source code dan komentar: **Inggris** (singkat).
- Bahasa UI dan pesan ke user: **Bahasa Indonesia**.
- Format: `dart format .`
- Lint: `package:flutter_lints/flutter.yaml` + tambahan di bawah.
- `dart analyze` wajib **0 error, 0 warning** sebelum sebuah phase dinyatakan
  selesai.

Tambahan `analysis_options.yaml`:

```yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    prefer_single_quotes: true
    always_declare_return_types: true
    avoid_print: true
    unawaited_futures: true
    directives_ordering: true
    prefer_final_locals: true
    omit_local_variable_types: false
```

`avoid_print` → gunakan logger internal (`core/utils/logger.dart`) yang
menulis ke memori/log lokal, bukan `print`.

## 2. Penamaan

| Item | Konvensi | Contoh |
|------|----------|--------|
| File | snake_case | `reminder_repository.dart` |
| Kelas, enum, mixin | PascalCase | `ReminderRepository` |
| Method, variabel, getter | lowerCamelCase | `scheduleReminder()` |
| Konstanta static final | lowerCamelCase | `defaultPriority` |
| Private | prefix `_` | `_parseAmount()` |
| Boolean | diawali kata benda `is/has/can/should` | `isActive`, `hasDueDate` |
| Future-returning | verb | `fetchTodos()` |
| Factory constructor | `fromX` / `toX` | `fromMap`, `toJson` |
| Riverpod provider | suffix `Provider` | `reminderListProvider` |
| Test file | `<target>_test.dart` | `amount_parser_test.dart` |

## 3. Struktur file Dart

```dart
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../../../core/...';
import '../entities/...';
part 'table.g.dart';

/// Single responsibility, urutan: konstanta → class → helpers private.
```

Urutan import: `dart:` → `package:` → relatif, dipisah 1 baris kosong,
diurutkan alfabetis (`directives_ordering`).

## 4. Aturan layer

1. File di `domain/` **tidak boleh** import `package:flutter/**`.
2. File di `presentation/` tidak boleh query Drift langsung — selalu lewat
   repository.
3. Tidak ada `BuildContext` di domain/data.
4. Waktu selalu disuntik: pakai `Clock` dari `core/utils/clock.dart`,
   jangan `DateTime.now()` langsung di luar UI. Ini wajib agar test tanggal
   (hari ini/besok/3 hari lagi) bisa deterministik.
5. Semua plugin platform dipanggil lewat interface abstract.
6. Jangan pakai `dynamic` jika tipe bisa ditentukan.

## 5. Error handling

- Gunakan `sealed class Failure` di `core/error/`, bukan melempar string.
- Return type aksi bisnis: `Result<T>` (`Success<T>` / `Failure`).
- Jangan `catch` lalu diam. Selalu: catat ke logger + kembalikan Failure
  yang bisa dipahami user.
- UI menampilkan error state yang bisa dicoba ulang, bukan crash.

```dart
sealed class Result<T> { const Result(); }
class Success<T> extends Result<T> { const Success(this.value); final T value; }
class Err<T> extends Result<T> { const Err(this.failure); final Failure failure; }
```

## 6. State (Riverpod)

- `StateNotifier`/`AsyncNotifier` untuk aksi; `Provider` untuk dependensi.
- Jangan mutasi list state dari UI langsung.
- Provider yang tidak dipakai lintas layar → `autoDispose`.
- Sumber kebenaran data = database. Provider hanya cache hasil query.

## 7. UI & theme

- Warna, radius, spacing, font → `core/theme/` (token), jangan hex literal
  di widget.
- Semua ukuran spacing pakai konstanta `AppSpacing.xs..xl`.
- Wajib punya: empty state, loading state, error state.
- Tidak ada `Container` tanpa child/padding yang tidak disengaja.
- Ukuran teks maksimal mengikuti `AppTypography` scale.
- Harus aman dari overflow pada layar kecil (test dengan width 320).
- Dukung dark & light mode tanpa hard-code warna gelap/terang di widget.
- Pesan empty state Bahasa Indonesia dan menjelaskan langkah berikutnya.

## 8. Komentar

- Jangan komentari kode yang sudah jelas.
- Komentar hanya untuk: alasan non-obvious, batasan platform, TODO +
  phase yang memilikinya.
  Contoh: `// TODO(phase 14): tampilkan preview attachment`

## 9. Test

| Jenis | Lokasi | Kapan wajib |
|-------|--------|-------------|
| Unit | `test/**` | setiap logic parser, repository, usecase |
| Widget | `test/**/presentation` | layar dengan state penting |
| Integration | `integration_test/` | alur utama per phase |

Aturan:

1. Satu behavior satu test, nama test menjelaskan behavior
   (`parses 'besok jam 8' into tomorrow 08:00`).
2. Test tidak saling bergantung; DB in-memory per test.
3. Test tidak menyentuh jaringan.
4. `flutter test` wajib hijau sebelum `REPORT`.
5. Coverage minimal untuk domain: parser, validator, manager. Target
   bukan angka, tapi semua intent dan semua jalur error tertutup.

Framework test: `flutter_test` + `mocktail`.

## 10. Performa & keamanan

- Tidak ada I/O berat di UI thread; gunakan `Isolate` untuk berat
  (mis. parse backup besar, inference AI).
- ListView/wave widget pakai builder, jangan `Column`+`ListView` bersarang.
- Tidak ada log berisi isi journal/expense ke output publik.
- Tidak ada secret/key di repo.
- Path file selalu di dalam app sandbox.

## 11. Git / commit (jika repo diinisialisasi)

- Commit message Inggris, imperative: `add reminder repository`.
- Satu commit = satu perubahan koheren.
- Jangan commit file build (`build/`, `.dart_tool/`, `*.iml`).
- Jangan commit database produksi atau data pengguna.

## 12. Definition of Done per perubahan kode

- [ ] `dart format .` bersih
- [ ] `dart analyze` 0 issue
- [ ] `flutter test` PASS
- [ ] punya test untuk logic baru (atau alasan tertulis bila tidak perlu)
- [ ] empty/loading/error state bila menyentuh UI
- [ ] tidak menambah dependency di luar `03-dependencies.md`
- [ ] tidak melanggar phase aktif

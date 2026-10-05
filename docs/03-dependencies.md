# 03 — Dependencies

Versi dicek dari pub.dev pada saat PHASE 0 (Flutter 3.44.1 / Dart 3.12.1).
Saat implementasi phase, jalankan `flutter pub add <pkg>` agar resolusi
mengikuti constraint terbaru yang kompatibel. Jangan menambah package di luar
daftar ini tanpa mencatat alasannya di bagian "Catatan".

## 1. Ringkasan sikap

- Dependensi sesuai phase (jangan dipasang lebih awal).
- Tidak ada package networking/cloud untuk fitur utama.
- Tidak ada package analytics/crash-report.
- Tidak ada package AI cloud.
- Setiap plugin platform dibungkus interface milik aplikasi.

## 2. Core (PHASE 1)

| Package | Versi | Keperluan |
|---------|-------|-----------|
| `flutter` (SDK) | 3.44.1 | framework |
| `dart` (SDK) | 3.12.1 | bahasa |
| `flutter_riverpod` | 3.4.3 | state management |
| `flutter_lints` | 6.0.0 | lint rules |
| `intl` | 0.20.3 | format tanggal/jam/IDR |

`analysis_options.yaml` memakai `package:flutter_lints/flutter.yaml`.

## 3. Database (PHASE 2)

| Package | Versi terpasang | Keperluan |
|---------|-----------------|-----------|
| `drift` | 2.35.1 | SQLite ORM, query, migration |
| `drift_flutter` | 0.3.1 | helper inisialisasi drift (`driftDatabase`) |
| `path_provider` | 2.1.6 | lokasi file database (application support dir) |

Dev:

| Package | Versi terpasang | Keperluan |
|---------|-----------------|-----------|
| `drift_dev` | 2.35.1 | generator tabel/DAO/database (`build_runner`) |
| `build_runner` | 2.15.1 | codegen: `dart run build_runner build` |
| `mocktail` | 1.0.5 | double untuk repository/usecase test |
| `sqlite3` | 3.5.2 | test migrasi: menulis file database skema v1 secara mentah |

### Keputusan: `sqlite3_flutter_libs` TIDAK dipasang

Riset dilakukan saat PHASE 2 (dicek di pub.dev):

- `sqlite3_flutter_libs 0.6.0+eol` berbunyi: *"Starting from version 0.6.0,
  this package no longer does anything"* dan *"obsolete after upgrading to
  version 3.x of package:sqlite3"*.
- drift 2.35.1 memakai `sqlite3 ^3.4.0` (resolusi terpasang: 3.5.2), yang
  sejak 3.x menyediakan library native lewat build hook miliknya sendiri.

Kesimpulan: cukup `drift` + `drift_flutter` + `path_provider`. Menambahkan
`sqlite3_flutter_libs` justru tidak menambah apa pun.

Catatan lain PHASE 2:

- Kolom bertipe boolean di drift 2.35 dideklarasikan sebagai `Column<bool>`
  (bukan `BooleanColumn`); perbandingan angka memakai
  `col.isSmallerOrEqualValue(x)`.
- Anotasi DAO memakai `@DriftAccessor(tables: [...])`, bukan `@DriftDao`.

## 4. Notification (PHASE 6)

| Package | Versi | Keperluan |
|---------|-------|-----------|
| `flutter_local_notifications` | 22.3.1 | schedule/cancel/snooze lokal |
| `permission_handler` | 13.0.2 | izin Android (post notification, alarm) |
| `timezone` | 0.11.1 | zonedSchedule |
| `flutter_timezone` | 5.1.1 | tz lokal perangkat |

Wajib tetap bekerja tanpa internet dan saat app ditutup.

## 5. File, backup, PDF (PHASE 14)

| Package | Versi | Keperluan |
|---------|-------|-----------|
| `file_picker` | 13.1.0 | pilih file backup |
| `share_plus` | 13.3.1 | export/share backup |
| `archive` | 4.3.0 | ZIP attachment |
| `pdf` | 3.13.1 | PDF export |
| `open_filex` | 4.7.0 | buka hasil export |

## 6. Security (PHASE 15)

| Package | Versi | Keperluan |
|---------|-------|-----------|
| `flutter_secure_storage` | 11.2.0 | simpan PIN/secret via Keystore |
| `local_auth` | 3.0.2 | biometric |

PIN tidak pernah disimpan plaintext. Hash + salt (mis. argon2/bcrypt tidak
tersedia di pub secara resmi → gunakan pendekatan yang didokumentasikan di
phase 15).

## 7. Diagnostik (opsional, phase dev tooling)

| Package | Versi | Keperluan |
|---------|-------|-----------|
| `device_info_plus` | 13.3.0 | info device untuk log lokal |

Tidak dipakai untuk telemetry.

## 8. AI runtime — BELUM DIPUTUSKAN (PHASE 10)

Sengaja tidak dipilih sekarang. Kandidat akan dinilai pada PHASE 10
berdasarkan kriteria di `05-ai-abstraction.md`:

- offline / on-device
- lisensi komersial compatible
- performa RAM & latency di perangkat Android menengah
- dukungan Bahasa Indonesia
- menghasilkan structured JSON
- ukuran model wajar (bukan ratusan MB kalau bisa dihindari)

Interface tetap sama (`LocalAiEngine`), implementasi menyusul.
Jangan hard-code nama model di seluruh codebase — hanya di satu tempat:
`core/config/ai_config.dart`.

## 9. Package yang DILARANG

| Kategori | Alasan |
|----------|--------|
| HTTP client untuk API produk (`dio`, `http` untuk backend) | offline-first |
| Firebase / Supabase / cloud SDK | tidak ada cloud |
| Analytics (`firebase_analytics`, dsb.) | privacy-first |
| Crash report online | privacy-first |
| Auth online | tidak ada akun |
| AI cloud / API key based | wajib offline |
| In-app review / ads | tidak relevan |

Pengecualian: `http` boleh dipakai **hanya** untuk download asset model AI
opsional dengan consent pengguna, dan tidak menyimpan data pengguna.

## 10. Strategi upgrade

- Tidak ada auto-upgrade dependency di tengah phase.
- Upgrade hanya saat phase membutuhkan, dicatat di `07-roadmap.md`.
- Sebelum upgrade besar: jalankan seluruh test.

# CATATAN LANJUTAN — PHASE 16 (UI/UX Polish)

> Catatan tangan untuk sesi lanjutan. Dibuat: 2026-10-08.

## Status saat ini
- **PHASE 14 (Backup/Restore/PDF): DONE** — `flutter analyze` 0 issue, `flutter test` **525 PASS** (+3 skip).
- **PHASE 15 (Security): dilewati** atas instruksi user -> catat `SKIPPED` di roadmap, DoD di PROJECT.md tetap `[ ]`.
- **PHASE 16: belum dimulai.** Plan lengkap sudah disetujui user.

## Keputusan user (sudah terkunci)
1. Skip PHASE 15 -> dicatat `SKIPPED` di `docs/07-roadmap.md`.
2. Saat mulai implementasi, *saya* yang set penanda `PHASE 16 / IN PROGRESS` di PROJECT.md §4/§39 + roadmap.
3. Animasi **minimal**: `PageTransitionsTheme` global saja (tanpa AnimatedSwitcher tambahan).
4. Hapus dead code `AppColors.success/warning/danger`.

## Langkah eksekusi (urutan)
1. **Dokumen awal**: PROJECT.md §4/§39 + `docs/07-roadmap.md` -> `PHASE 16 / IN PROGRESS`, catat skip PHASE 15.
2. **Shared `ErrorState`** (`lib/shared/widgets/error_state.dart`) — gantikan 7 `_ErrorState` duplikat (chat, todo, notes, finance, shopping, journal, ideas); konversi error-path `lib/features/inbox/.../inbox_screen.dart:37`, `lib/features/search/.../search_screen.dart:103`, `lib/features/calendar/.../calendar_screen.dart:456` dari `EmptyState` -> `ErrorState` + tombol "Coba lagi". **Retensi teks yang di-assert test**: `'Belum ada tugas hari ini'`, `'Coba lagi'`, `'Coba lagi sebentar lagi.'`.
3. **`PageTransitionsTheme`** di `AppTheme` (light+dark); pilih `FadeForwardsPageTransitionsBuilder` jika SDK mendukung, fallback `ZoomPageTransitionsBuilder`.
4. **Aksesibilitas**: `Tooltip` pada `IconButton` tanpa label; target sentuh >=48px (ChoiceChip, sel hari kalender); layout aman textScaler di 3 bar pencarian `PreferredSize(72)`, `lib/core/theme/app_theme.dart:54`, `lib/features/calendar/.../calendar_screen.dart:294`.
5. **Overflow**: 5 `Row` tak-ter-constrain -> `Flexible`/`Expanded` (daftar file persis dari re-run audit).
6. **Light/dark**: naikkan kontras alpha `lib/features/chat/.../message_bubble.dart:66-67`; hapus `AppColors.success/warning/danger`; audit kontras akhir kedua mode.
7. **Typography/spacing**: ganti angka literal -> token `AppSpacing` (xs4/sm8/md12/lg16/xl24/xxl32; radiusSm10/Md16/Lg24).
8. **Verifikasi tiap langkah**: `dart format .` -> `flutter analyze` 0 issue -> `flutter test` >=525 PASS; smoke manual light/dark + text scale besar.
9. **Dokumen akhir**: PROJECT.md §39 -> `PHASE 16 / STATUS: DONE`, DoD `[x]`, log `### PHASE 16` di `docs/07-roadmap.md`. **JANGAN mulai PHASE 17.**

## Fakta teknis penting
- Spek PHASE 16: PROJECT.md ~baris 1494-1520 — **"Jangan menambahkan fitur baru."**
- File kunci: `lib/app.dart` (MaterialApp dengan theme/darkTheme/themeMode, tanpa pageTransitionsTheme), `lib/core/navigation/app_shell.dart` (IndexedStack + NavigationBar), `lib/core/theme/*`.
- Error path saat ini: 7 `_ErrorState` private duplikat; inbox/search/calendar malah memakai `EmptyState` tanpa retry.
- Pola test: widget-test default 800x600; ListView lazy -> `scrollUntilVisible` (pola `test/features/settings/presentation/settings_screen_test.dart`); Drift hang di FakeAsync -> fake subclass (`test/helpers/fake_backup_service.dart`, `fake_backup_storage.dart`). Test peng-assert error: `test/app_test.dart:77`, `test/features/chat/presentation/chat_screen_test.dart:158,172`, `test/features/settings/presentation/backup_section_test.dart:94,105`.
- Dependensi PHASE 14 (jangan diubah): `file_picker ^13.1.0`, `share_plus ^13.3.1`, `archive ^4.3.0`, `pdf ^3.13.1`, `open_filex ^4.7.0`.
- Konvensi: UI/pesan Bahasa Indonesia, kode Inggris; file test `<target>_test.dart`; commit hanya jika diminta user.

## Open issue saat implementasi
- Master audit aksesibilitas sub-agent ke-3 tak tercatat utuh di transkrip -> re-run audit untuk daftar persis IconButton tanpa tooltip + 5 file `Row` tak-ter-constrain.
- Konfirmasi ketersediaan `FadeForwardsPageTransitionsBuilder` pada Flutter SDK terpasang sebelum memakai `PageTransitionsTheme`.

## Perintah lanjut sesi berikutnya
> "Lanjutkan PHASE 16 sesuai plan yang disetujui: set penanda IN PROGRESS dulu, lalu step 2-9 berurutan, verifikasi tiap langkah."
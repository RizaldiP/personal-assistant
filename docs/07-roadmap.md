# 07 — Roadmap & Status

Sumber kebenaran urutan kerja tetap `PROJECT.md`. Dokumen ini hanya ringkasan
status.

## 1. Status saat ini

```
CURRENT ACTIVE PHASE: PHASE 2
STATUS: DONE
```

Diubah oleh OpenCode setelah DoD phase terpenuhi; diubah oleh **pengguna**
saat ingin memulai phase berikutnya (lihat `PROJECT.md` bagian 4 dan 39).

## 2. Tabel phase

| Phase | Nama | Status |
|-------|------|--------|
| 0 | Project Planning | DONE |
| 1 | Flutter Foundation | DONE |
| 2 | Local Database | DONE |
| 3 | Chat UI | NOT STARTED |
| 4 | Rule-Based NLP | NOT STARTED |
| 5 | Todo | NOT STARTED |
| 6 | Reminder + Notification | NOT STARTED |
| 7 | Shopping List | NOT STARTED |
| 8 | Finance | NOT STARTED |
| 9 | Note / Journal / Idea | NOT STARTED |
| 10 | Local AI | NOT STARTED |
| 11 | Hybrid Intelligence | NOT STARTED |
| 12 | Contextual Chat | NOT STARTED |
| 13 | Search + Calendar + Smart Inbox | NOT STARTED |
| 14 | Backup / Restore / PDF | NOT STARTED |
| 15 | Security | NOT STARTED |
| 16 | UI/UX Polish | NOT STARTED |
| 17 | Testing & Release | NOT STARTED |

Status hanya boleh diubah oleh phase yang sedang dikerjakan.
Jangan menandai phase berikutnya DONE di sesi yang sama.

## 3. Dependency antar phase

```
0 ─→ 1 ─→ 2 ─→ 3 ─→ 4 ─→ 5 ─→ 6 ─→ 7 ─→ 8 ─→ 9
                                                    └─→ 10 ─→ 11 ─→ 12 ─→ 13
                                                                          └─→ 14 ─→ 15 ─→ 16 ─→ 17
```

- Phase 4 butuh phase 3 (ada tempat input) dan phase 2 (bisa simpan hasil).
- Phase 10 **tidak menggantikan** phase 4; keduanya hidup berdampingan.
- Phase 16 dilarang menambah fitur baru.

## 4. Artefak per phase

Setiap phase menghasilkan:

1. Rencana singkat (disebut sebelum coding).
2. Kode + test.
3. Laporan `PHASE n RESULT` berisi: Completed / Tests / Status.
4. Pembaruan tabel status di dokumen ini.
5. **STOP.**

## 5. Log progres

### PHASE 0 — Project Planning (selesai)

Completed:

- `docs/00-index.md` — indeks dokumen
- `docs/01-architecture.md` — arsitektur 4 layer + alur intent
- `docs/02-folder-structure.md` — struktur folder + konvensi penamaan file
- `docs/03-dependencies.md` — daftar dependency + versi + phase pemakaian
- `docs/04-database-planning.md` — 14 entity minimal + 1 tambahan + migrasi
- `docs/05-ai-abstraction.md` — `LocalAiEngine` + kontrak JSON + batasan AI
- `docs/06-coding-conventions.md` — lint, naming, error handling, test
- `docs/07-roadmap.md` — dokumen ini

Notes:

- Versi dependency dicek dari pub.dev: drift 2.35.1, flutter_riverpod 3.4.3,
  flutter_local_notifications 22.3.1, dll.
- `sqlite3_flutter_libs` terbit dengan tag `+eol` → wajib dicek saat PHASE 2.
- Belum ada file kode Dart; belum ada dependency yang dipasang.

Tests: N/A (phase dokumentasi)

Status: DONE

---

### PHASE 1 — Flutter Foundation (selesai)

Completed:

- Project Flutter dibuat: `personal_offline`, org `com.personaloffline`,
  platform Android saja, label aplikasi `Personal Offline`
- Dependency phase 1: `flutter_riverpod 3.4.3`, `intl 0.20.3`,
  `shared_preferences 2.5.5` (flutter_lints 6.0.0 sudah default)
- `analysis_options.yaml` disesuaikan dengan `docs/06-coding-conventions.md`
  (strict-casts, strict-inference, prefer_single_quotes, dst.)
- `core/theme/` — `AppColors`, `AppSpacing`, `AppTypography`, `AppTheme`
  (Material 3, satu seed color, light + dark)
- `core/navigation/app_shell.dart` — bottom nav 5 layar (Beranda, Kalender,
  Inbox, Insight, Pengaturan) dengan `IndexedStack`
- `core/settings/theme_controller.dart` — Riverpod `Notifier` untuk
  System/Terang/Gelap, dipersist ke SharedPreferences
- `core/config/app_info.dart`, `shared/widgets/empty_state.dart`
- Home: sapaan jam, tanggal Bahasa Indonesia, section HARI INI (empty state),
  input placeholder
- 3 placeholder: Kalender, Inbox, Insight (empty state)
- Pengaturan: pilih tema, catatan privasi, info aplikasi
- Test: 11 widget/unit test

Catatan:

- Build Android gagal pertama kali karena Kotlin incremental compilation
  (`different roots`, project di `F:`, Pub cache di `C:`) → diperbaiki dengan
  `kotlin.incremental=false` + `kotlin.caching.enabled=false` di
  `android/gradle.properties`. Build ulang: SUKSES
  (`build\app\outputs\flutter-apk\app-debug.apk`).
- Build APK final untuk instalasi ditunda sampai pengerjaan selesai
  (permintaan pengguna). Emulator tidak dipakai.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 11 PASS

Status: DONE

---

### PHASE 2 — Local Database (selesai)

Completed:

- Dependency: `drift 2.35.1`, `drift_flutter 0.3.1`, `path_provider 2.1.6`;
  dev `drift_dev 2.35.1`, `build_runner 2.15.1`, `mocktail 1.0.5`,
  `sqlite3 3.5.2` (khusus test migrasi). `sqlite3_flutter_libs` tidak dipasang
  (keputusan terdokumentasi di `03-dependencies.md` bagian 3).
- `core/database/tables/` — 4 tabel: `Tasks`, `Reminders`, `ChatMessages`,
  `UserPreferences` sesuai `04-database-planning.md`
- `core/database/daos/` — `TaskDao`, `ReminderDao`, `ChatMessageDao`,
  `UserPreferencesDao`: CRUD, watch stream, search, query due/watch
- `core/database/app_database.dart` — `schemaVersion` 2:
  - v1 baseline empat tabel
  - v2 menambah kolom jejak NLP (`source`, `raw_input`, `confidence` pada
    task/reminder; `intent`, `payload`, `status`, `resolved_at` pada chat)
    + 6 indeks (termasuk unique index pada `user_preferences.key`)
- `core/database/database_provider.dart` — `appDatabaseProvider` + `clockProvider`
- `core/utils/clock.dart` — `Clock`, `SystemClock`, `FixedClock` (waktu bisa
  disuntikkan untuk test deterministik)
- Lapisan domain + data:
  - `features/todo/domain/*` + `features/todo/data/repositories/task_repository_impl.dart`
  - `features/reminder/domain/*` + `features/reminder/data/repositories/reminder_repository_impl.dart`
  - `features/chat/domain/*` + `features/chat/data/repositories/chat_repository_impl.dart`
  - `core/settings/preferences_repository.dart`
- Provider Riverpod di setiap repository (`taskRepositoryProvider`, dst.)

Catatan:

- Bug lama ditemukan dan diperbaiki lewat test: escaping pencarian `LIKE`
  (`_escapeLike` memakai sintaks replacement Java/JS `\$&` dan tanpa klause
  `ESCAPE`) → diganti `replaceAllMapped` + `like(pattern, escapeChar: '\\')`.
- `ChatStatus.storageValue` menghasilkan `needsConfirmation` sedangkan
  `parse` membaca `needs_confirmation` → diseragamkan (snake_case).
- Test migrasi menulis file skema v1 secara mentah (`PRAGMA user_version = 1`)
  dengan `package:sqlite3`, lalu membukanya lewat `AppDatabase`.
- Domain `Task`/`ChatMessage` memakai `DateTime`, `Reminder` memakai epoch
  ms UTC (sesuai kolom database).

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 54 PASS

Status: DONE

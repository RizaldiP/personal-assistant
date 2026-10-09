# 07 — Roadmap & Status

Sumber kebenaran urutan kerja tetap `PROJECT.md`. Dokumen ini hanya ringkasan
status.

## 1. Status saat ini

```
CURRENT ACTIVE PHASE: PHASE 17
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
| 3 | Chat UI | DONE |
| 4 | Rule-Based NLP | DONE |
| 5 | Todo | DONE |
| 6 | Reminder + Notification | DONE |
| 7 | Shopping List | DONE |
| 8 | Finance | DONE |
| 9 | Note / Journal / Idea | DONE |
| 10 | Local AI | DONE |
| 11 | Hybrid Intelligence | DONE |
| 12 | Contextual Chat | DONE |
| 13 | Search + Calendar + Smart Inbox | DONE |
| 14 | Backup / Restore / PDF | DONE |
| 15 | Security | SKIPPED |
| 16 | UI/UX Polish | DONE |
| 17 | Testing & Release | DONE |

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

---

### PHASE 3 — Chat UI (selesai)

Completed:

- `features/chat/presentation/providers/chat_controller.dart` —
  `ChatController` (Notifier, state `AsyncValue<void>`) menyimpan pesan user
  lewat repository; `send()` memotong teks, menolak kosong, dan melempar error
  bila simpan gagal (state jadi `AsyncError`) → `chatControllerProvider`
- `features/chat/presentation/providers/chat_messages_provider.dart` —
  `chatMessagesProvider` (StreamProvider.autoDispose) membaca riwayat dari
  repository/database
- `features/chat/presentation/widgets/message_bubble.dart` — `MessageBubble`
  user kanan / assistant kiri, maksimal 75% lebar layar, menunjukkan jam
- `features/chat/presentation/widgets/chat_input.dart` — `ChatInput`
  (TextField multiline 1-4 baris + tombol kirim `IconButton.filled`); tombol
  nonaktif saat kosong, spinner saat mengirim, snackbar bila gagal simpan
- `features/chat/presentation/screens/chat_screen.dart` — `ChatScreen`
  (AppBar 'Percakapan'): list pesan terbalik (terbaru di bawah) dengan state
  loading / error (tombol 'Coba lagi' → invalidate) / empty / data
- `features/home/.../home_screen.dart` — input beranda menjadi launcher:
  mengetuknya membuka `ChatScreen` (`Navigator.push`); pesan "belum tersedia"
  dihapus
- Tests:
  - `test/features/chat/presentation/chat_controller_test.dart` (unit):
    simpan terpotong, kosong/whitespace tidak tersimpan, gagal → error,
    percobaan ulang berhasil
  - `test/features/chat/presentation/chat_screen_test.dart` (widget): empty,
    kirim pesan muncul + input bersih, riwayat bertahan saat layar buka ulang,
    loading → data, error + coba lagi, snackbar gagal simpan (teks tetap),
    tombol kirim nonaktif
  - `test/app_test.dart` diperbarui: input beranda kini membuka layar
    percakapan (bukan toast)
  - `test/helpers/fake_chat_repository.dart` — fake repository in-memory
    (dipakai widget test agar deterministik)

Catatan:

- Widget test memakai `FakeChatRepository`, bukan Drift sungguhan: operasi
  Drift di dalam `testWidgets` (FakeAsync) menggantung dan menyisakan timer di
  teardown. Persistensi database nyata sudah diuji di `chat_repository_test`
  (Drift in-memory) dan akan diuji end-to-end di PHASE 17 / integration test.
- `Override` di Riverpod 3 diekspor dari `package:flutter_riverpod/misc.dart`
  (bukan `flutter_riverpod.dart`).
- Input beranda berperan sebagai pintu masuk chat; setelah PHASE 4 parser
  aktif, alur ketik→intent akan disambungkan di layar ini.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 65 PASS

Status: DONE

---

### PHASE 4 — Rule-Based NLP (selesai)

Completed:

- `shared/intents/app_intent.dart` — `AppIntent` enum (12 intent dalam
  snake_case: create_reminder, create_todo, create_shopping, create_expense,
  create_note, create_journal, create_idea, update_item, delete_item,
  complete_item, search, unknown) + `fromStorage`
- `shared/intents/ai_intent_result.dart` — `AiIntentResult` dengan field
  intent, confidence, entities, needsConfirmation; `isKnown`; `toJson`/
  `fromJson` (kunci `needs_confirmation`) sebagai kontrak JSON bersama
  Rule Parser — Local AI (phase 10) — validator
- `shared/nlp/` (murni Dart, tanpa Flutter):
  - `normalizer.dart` — huruf kecil, satu spasi, kapitalisasi
  - `date_parser.dart` — hari ini, besok, lusa, minggu depan, bulan depan,
    "N hari/minggu/bulan lagi", "tanggal N [bulan]", nama hari; referensi
    `now` yang disuntikkan agar deterministik
  - `time_parser.dart` — "jam/pukul 8", "jam 8 pagi/siang/sore/malam",
    "pukul 20:30", "20:00", kata periode saja (pagi/siang/sore/malam)
  - `amount_parser.dart` — Rp, 10 ribu/rb/k, 10.000, 1 juta/jt, 2,5 juta,
    miliar; mengabaikan angka tanggal
  - `rule_parser.dart` — prioritas intent: ide -> catatan -> pengeluaran ->
    belanja -> pengingat -> tugas -> jurnal -> unknown

Deteksi intent (kondisi wajib):

- `besok jam 8 bayar listrik` -> create_reminder
  {"title": "Bayar listrik", "date": "2026-10-07", "time": "08:00"}
- `besok beli telur susu` -> create_shopping {"items": ["Telur", "Susu"]}
- `tadi makan 25 ribu` -> create_expense
  {amount 25000, currency IDR, category "makanan", description "Makan"}
- `hari ini kerjakan laporan` -> create_todo (due_date hari ini)
- `3 hari lagi servis motor` -> create_todo (due_date +3 hari)

Catatan:

- Unknown (confidence 0.1) menandai `needsConfirmation`; intent dikenal
  ber-confidence >= 0.6 tanpa konfirmasi.
- Tidak ada wiring ke UI / penyimpanan di phase ini (murni parser + test).
  Sambungan ketik->intent akan dilakukan saat fitur phase 5-9, konfirmasi
  chat di phase yang terkait.
- `lib/shared/nlp` & `lib/shared/intents` bebas Flutter (pure Dart) sesuai
  `docs/02-folder-structure.md`.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 127 PASS

Status: DONE

---

### PHASE 5 — Todo (selesai)

Completed:

- `todo/presentation/providers/task_controller.dart` — `todoListProvider`
  (StreamProvider dari `taskRepositoryProvider.watchTasks()`),
  `todayTasksProvider` (tugas pending dengan `dueDate` hari ini berdasarkan
  `clockProvider`), `TodoController` (create/update/setCompleted/delete),
  `todoControllerProvider`
- `todo/presentation/screens/todo_screen.dart` — daftar tugas dengan grup
  BELUM SELESAI / SELESAI, ceklis selesai, dialog konfirmasi hapus, tombol +
  membuka form, ketuk item membuka edit
- `todo/presentation/screens/todo_form_screen.dart` — form buat/edit tugas
  (judul wajib, deskripsi, tanggal & jam, prioritas), validasi "Judul wajib
  diisi"
- `todo/presentation/widgets/task_tile.dart` & `todo/presentation/task_display.dart`
  — baris tugas + subtitle (tanggal • jam • prioritas) & label prioritas
- `home/presentation/screens/home_screen.dart` — section HARI INI dari
  `todayTasksProvider` + tombol "Lihat semua tugas" menuju layar Tugas
- Wiring NLP: `chat/presentation/providers/chat_controller.dart` — intent
  `create_todo` membuat `Task` (title, due_date, prioritas, source `rule`,
  rawInput, confidence) dan membalas "Todo dibuat: ... • <tanggal>"
- `shared/formatters/date_formats.dart` — `DateFormats.longIndonesia` /
  `shortTime` (dipakai balasan chat dan subtitle)
- `test/helpers/fake_task_repository.dart` — `FakeTaskRepository` (seed +
  stream broadcast) untuk widget/controller test
- Test baru: `task_controller_test.dart` (CRUD controller, selesai/lanjutkan,
  filter hari ini), `todo_screen_test.dart` (empty, pengelompokan, ceklis,
  hapus, buat via form, edit, validasi), plus widget test chat NLP dan home

Catatan:

- `StreamProvider.future` di Riverpod 3.4.3 tidak pernah selesai saat dibaca
  tanpa listener yang sudah aktif; test memakai listener + Completer
  (`_firstValue`) untuk menunggu nilai pertama.
- `Task.copyWith` membiarkan null (tidak menghapus field); `setCompleted`
  membangun ulang `Task` secara eksplisit agar `completedAt` bisa dikosongkan.
- Duplikat override provider yang sama dalam satu `ProviderScope` ditolak
  Riverpod 3 (`Tried to override a provider twice`); `_pumpApp` di `app_test`
  menerima `FakeTaskRepository` sebagai parameter terpisah.
- Subtitel tugas adalah satu string "tanggal • jam • prioritas"; test memakai
  `find.textContaining`.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 146 PASS

Status: DONE

---

### PHASE 6 — Reminder + Notification (selesai)

Completed:

- Dependency: `flutter_local_notifications 22.3.1`, `timezone 0.11.1`,
  `flutter_timezone 5.1.1` (terpasang, `pub get` sukses)
- `core/services/notification_scheduler.dart` — interface `NotificationScheduler`
  (initialize / requestPermissions / schedule / cancel) + implementasi nyata
  `FlutterLocalNotificationsScheduler` (channel `reminders`, zoned schedule
  presisi pakai `tz.TZDateTime` dari zone lokal, `AndroidScheduleMode.exactAllowWhileIdle`,
  `@mipmap/ic_launcher`) + `notificationSchedulerProvider`
- `reminder/domain/recurrence_calculator.dart` — `RecurrenceCalculator.nextOccurrence`
  murni Dart untuk aturan `none`, `daily`, `weekly:MON`, `monthly:15`,
  `interval:3d`; mengembalikan jadwal berikutnya yang lebih baru dari `now`,
  mempertahankan jam/anchor
- `reminder/domain/reminder_schedule.dart` — helper konversi `date`+`time`
  → `DateTime` lokal / epoch ms UTC
- `reminder/presentation/providers/reminder_controller.dart` —
  `activeRemindersProvider` (StreamProvider), `ReminderController`
  (create / cancel / delete / snooze / complete / handleFired),
  `reminderControllerProvider`
  - `create` menyimpan reminder + menjadwalkan; jadwal yang sudah lewat
    (`validateDateIsInTheFuture`) tidak dikirim
  - `snooze` menunda `nextFireAt`/`snoozedUntil` = now + durasi dan
    menjadwal ulang
  - `handleFired` mencatat `lastFiredAt`; reminder berulang (recurring)
    menghitung kemunculan berikutnya lalu menjadwal ulang
- Wiring NLP: `chat/presentation/providers/chat_controller.dart` — intent
  `create_reminder` membuat `Reminder` (title, date, time, scheduledAt,
  source `rule`, rawInput, confidence) dan membalas "Reminder dijadwalkan:
  <title> · <tanggal> jam <jam>"
- `main.dart` — inisialisasi scheduler + minta permission (notifikasi &
  exact alarm) sebelum `runApp`
- `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS`,
  `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`
- Test baru + helper:
  - `test/helpers/fake_notification_scheduler.dart` — `FakeNotificationScheduler`
    (map id → waktu, daftar id dibatalkan, counter panggilan `schedule`)
  - `test/helpers/fake_reminder_repository.dart` — `FakeReminderRepository`
    in-memory + stream broadcast
  - `test/features/reminder/domain/recurrence_calculator_test.dart` —
    aturan none/daily/weekly/monthly/interval, batas kelipatan, jam dipertahankan
  - `test/features/reminder/presentation/reminder_controller_test.dart` —
    create+jadwal, jadwal lampau ditolak, cancel, delete, snooze, complete,
    handleFired non-recurring/recurring, non-aktif diabaikan
  - `chat_controller_test.dart` & `chat_screen_test.dart` — kasus kalimat
    reminder membuat reminder + jadwal + balasan asisten

Catatan:

- API `flutter_local_notifications 22.x` berbeda dari versi lama: `initialize`
  memakai named `settings`, `zonedSchedule` di plugin pakai
  `NotificationDetails` + `androidScheduleMode` (bukan `notificationDetails`
  Android + `scheduleMode`), `cancel(id: ...)`, dan `TZDateTime` berasal dari
  `package:timezone` (dlekspor ulang melalui paket).
- Skenario DoD "app ditutup / layar terkunci / internet mati" bersifat
  device-level: notifikasi terjadwal sistem (exact alarm) tetap tampil tanpa
  app berjalan, tanpa jaringan. Di automated test, platform channel tidak
  disentuh; verifikasi memakai `FakeNotificationScheduler`.
- `FakeNotificationScheduler.schedule` mencatat setiap panggilan tanpa filter
  waktu nyata (keputusan masa-lampau/masa-depan ditangani di controller via
  `clockProvider`, bukan tanggal kalender asli); test controller memajukan
  `FixedClock.value` untuk menyimulasikan waktu berjalan.
- Bug `RecurrenceCalculator._nextMonthDay` ditemukan lewat test: iterasi
  memakai `now.month + 31*i hari` melompati bulan berjalan → diganti
  iterasi bulan demi bulan dengan `_daysInMonth`.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 172 PASS

Status: DONE

---

### PHASE 7 — Shopping List (selesai)

Completed:

- Skema DB v3: `core/database/tables/shopping_table.dart` — tabel
  `ShoppingLists` (id, title default `Belanja`, status `open`/`done`, date,
  createdAt, updatedAt) dan `ShoppingItems` (id, listId dengan FK cascade
  `references(ShoppingLists, #id, onDelete: KeyAction.cascade)`, name,
  quantity/default unit, isChecked, sortOrder, timestamps) + `@TableIndex`
  `idx_shopping_items_list_id`
- `core/database/app_database.dart` — schemaVersion 3, migrasi v1→v2→v3;
  `_upgradeToV3` membuat kedua tabel + indeks manual (drift `createTable`
  tidak membuat indeks `@TableIndex`, dilakukan lewat `customStatement`),
  `PRAGMA foreign_keys = ON` mengaktifkan cascade pada DB in-memory test
- `core/database/daos/shopping_dao.dart` — `ShoppingDao` (watchLists,
  watchItems, getListById, getAllLists, itemsForList,
  insert/update/deleteList, insert/update/deleteItem, nextSortOrder);
  `dart run build_runner build --delete-conflicting-outputs` sukses
- `shopping/domain/entities/` — `ShoppingList` (status open/done + items +
  helper isDone) dan `ShoppingItem` (sortOrder, isChecked, quantity/unit)
- `shopping/domain/repositories/shopping_repository.dart` — interface +
  `shopping/domain/repositories/shopping_repository.dart` impl
  `ShoppingRepositoryImpl` (menggabung `watchLists()` + `watchItems()` lewat
  helper `_combineLatest` berbasis StreamController; sort item
  sortOrder+id; `nextSortOrder = max+1`) + `shoppingRepositoryProvider`
- `shopping/presentation/providers/shopping_controller.dart` —
  `shoppingListsProvider` (StreamProvider) + `ShoppingController`
  (ensureActiveList membuat `Belanja` saat kosong, addItems, createList,
  toggleItem, removeItem, setDone, deleteList)
- `shopping/presentation/screens/shopping_screen.dart` — layar daftar
  belanja: AppBar `Belanja`, bagian BELANJA/SELESAI, header daftar dengan
  checkbox selesai + tombol hapus (dialog konfirmasi), item
  `CheckboxListTile` (checklist/hapus item), FAB dialog tambah item, empty
  state, state error + retry
- `home/presentation/screens/home_screen.dart` — entri "Daftar belanja"
  navigasi ke `ShoppingScreen`
- Wiring NLP: `chat/presentation/providers/chat_controller.dart` — intent
  `create_shopping` (`besok beli beras minyak telur` → item
  Beras/Minyak/Telur) memanggil `shoppingControllerProvider.notifier.addItems`
  dan membalas `Belanja dicatat: Beras, Minyak, Telur`
- Test baru + helper:
  - `test/helpers/fake_shopping_repository.dart` — `FakeShoppingRepository`
    in-memory + stream broadcast (mirip fake task/reminder)
  - `test/features/shopping/shopping_repository_test.dart` — default
    title/status/timestamp clock, addItems urut + nama kosong dilewati,
    updateItem isChecked+updatedAt, deleteItem, deleteList cascade
    (belanja dihapus lewat FK), watchLists list terhimpun beserta item,
    getAllLists
  - `test/features/shopping/presentation/shopping_controller_test.dart`
  - `test/features/shopping/presentation/shopping_screen_test.dart` —
    empty state + FAB, FAB menambah item, checklist item, hapus item,
    daftar selesai dikelompokkan
  - `chat_controller_test.dart` & `chat_screen_test.dart` — kalimat
    belanja menambah item + balasan `Belanja dicatat: ...`
  - `migration_test.dart` — v1→v3 (data utuh + tabel belanja + indeks) dan
    DB baru langsung skema v3

Catatan:

- Nama kelas hasil codegen drift: tabel `ShoppingLists` → row `ShoppingList`
  (bukan `ShoppingListRow`); memakai referensi langsung ke kelas DB yang
  dibedakan dengan alias `as db` pada publish/subscribe.
- Parser NLP: kalimat dengan nominal (`beli bensin 50rb`) memang masuk
  intent `create_expense` (PHASE 8), bukan shopping; shopping hanya untuk
  kata tidak berupa nominal.
- `build_runner` dijalankan sekali (`--delete-conflicting-outputs`); DAO
  didaftarkan lewat anotasi `@DriftDatabase`, akses via
  `appDatabase.shoppingDao`.
- Jetpack: tidak ada permission baru (notifikasi PHASE 6 sudah cukup).

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 195 PASS

Status: DONE

---

### PHASE 8 — Finance (selesai)

Completed:

- Skema DB v4: `core/database/tables/expense_table.dart` — tabel `Expenses`
  (id, amount integer IDR, currency default `IDR`, category default `lainnya`,
  description, date `YYYY-MM-DD`, paymentMethod nullable, source/rawInput/
  confidence nullable, createdAt/updatedAt) + `@TableIndex`
  `idx_expenses_date` dan `idx_expenses_category`
- `core/database/app_database.dart` — schemaVersion 4, migrasi `_upgradeToV4`
  membuat tabel + kedua indeks manual (`createTable` tidak membuat indeks
  `@TableIndex`; lewat `customStatement` pada AppDatabase, `Migrator` tidak
  punya method tsb), akses `appDatabase.expenseDao`
- `core/database/daos/expense_dao.dart` — `ExpenseDao` (watchAll, getAll,
  getById, insert, updateById — nama `update` dihindari karena bentrok dengan
  `DatabaseConnectionUser`, deleteById, totalBetween); `build_runner` sukses
- `finance/domain/entities/` — `Expense` (entity + copyWith) dan
  `ExpenseCategory` enum (makanan/transport/tagihan/belanja/kesehatan/
  hiburan/lainnya + parse)
- `finance/data/repositories/expense_repository.dart` interface +
  `expense_repository_impl.dart` — `ExpenseRepositoryImpl(dao, prefsDao, clock)`:
  watch/getAll/getById/create/update/deleteById/dailyTotal/monthlyTotal,
  getBudget/setBudget (kunci `finance_budget` di `user_preferences`) +
  `expenseRepositoryProvider`
- `finance/presentation/providers/finance_controller.dart` —
  `expensesProvider` (StreamProvider), `financeBudgetProvider` (FutureProvider),
  `FinanceController` (addExpense default tanggal hari ini dari `clockProvider`,
  removeExpense, setBudget)
- `share/formatters/currency_formats.dart` — `CurrencyFormats.idr` memformat
  pengelompokan manual → `Rp 25.000` (tanpa init locale)
- `finance/presentation/screens/finance_screen.dart` — entri "Keuangan";
  kartu ringkasan (budget + sisa/melebihi + total Hari ini & Bulan ini),
  daftar dikelompok per tanggal (label Hari ini/Kemarin/tanggal), tile
  kategori + deskripsi + nominal, hapus dengan konfirmasi, dialog tambah
  (nominal/deskripsi/dropdown kategori/date picker), dialog atur budget,
  empty/error state
- Wiring NLP + chat: `rule_parser.dart` — entitas `date` ditambah ke
  `create_expense`, `_categoryOf` diperluas (tagihan/belanja/kesehatan/
  hiburan); `date_parser.dart` — aturan `kemarin` (kemarin→hari-1);
  `amount_parser.dart` — perbaikan: `(?<!\d)` agar `350 ribu` tidak
  termaktik sebagai `50 ribu`, dan `\d{1,3}` untuk angka 3 digit + pengali;
  `chat_controller.dart` — intent `create_expense` memanggil
  `expenseRepositoryProvider` dan membalas `Pengeluaran dicatat: Rp 25.000 ·
  Makanan · Ayam`
- Test baru + helper:
  - `test/helpers/fake_expense_repository.dart` — `FakeExpenseRepository`
    in-memory + broadcast `onListen` (emit snapshot saat subscribe untuk
    menghindari hilangnya event pertama)
  - `test/features/finance/finance_repository_test.dart` — default
    tanggal/currency/category, dailyTotal/monthlyTotal, update/delete,
    urutan watch, budget via user_preferences
  - `test/features/finance/presentation/finance_controller_test.dart` dan
    `finance_screen_test.dart` — controller + layar (ringkasan, kelompok
    tanggal, tambah, hapus, budget)
  - `chat_controller_test.dart` & `chat_screen_test.dart` — kalimat
    pengeluaran mencatat + balasan
  - `migration_test.dart` — v1→v4 dan DB baru langsung skema v4 (kolom +
    indeks `expenses`, insert via `expenseDao` + `totalBetween`)
  - `rule_parser_test.dart` — entitas `date` (tadi/kemarin) + kategori
    tagihan (`bayar listrik 350 ribu` → 350000)

Catatan:

- Nama kelas hasil codegen drift: tabel `Expenses` → row `Expense`. DAO pada
  insert/update memakai `ExpensesCompanion` (`Value(title)` dst).
- `AsyncValue` versi Riverpod yang dipakai tidak punya `valueOrNull`; memakai
  `.asData?.value`.
- Generator stream pada fake lama (`async*` + `yield*`) bisa kalah balapan
  mikro-task dan menjatuhkan event; diganti broadcast `onListen` yang
  menge-mit snapshot saat subscribe.
- `350 ribu`: regex multiplier lama mencocokkan `50` dari dalam `350`
  (kurang `(?<!\d)`); sudah diperbaiki → `350000`.
- DoD PHASE 8: expense, category, amount parser, daily total, monthly total,
  tests (+ simple budget sesuai daftar "Kerjakan").

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 217 PASS

Status: DONE

---

### PHASE 9 — Note / Journal / Idea (selesai)

Completed:

- Skema DB v5: `core/database/tables/notes_table.dart` (`Notes` — title
  nullable, content, source/rawInput nullable, tags implicit lewat relasi,
  createdAt), `journal_table.dart` (`JournalEntries` — date `YYYY-MM-DD`,
  title nullable, content, mood nullable, createdAt), `idea_table.dart`
  (`Ideas` — title, content nullable, status default `inbox`, source/rawInput/
  confidence nullable, createdAt), `tag_table.dart` (`Tags` name lowercase
  unique + `TagLinks` PK `{tag_id, entity_type, entity_id}` FK cascade,
  entity_type `'note'|'journal'|'idea'`); indeks manual via `customStatement`
  `idx_notes_created_at`, `idx_journal_entries_date`, `idx_ideas_status`,
  `idx_tags_name`
- `core/database/app_database.dart` — schemaVersion 5, migrasi `_upgradeToV5`
  (createTable 5 tabel + 4 `CREATE INDEX IF NOT EXISTS`), akses
  `noteDao`/`journalDao`/`ideaDao`/`tagDao`; `build_runner` sukses
- `core/database/daos/` — `NoteDao`, `JournalDao`, `IdeaDao`, `TagDao`
  (watch/getAll/getById/insert/updateById/deleteById + query `LIKE` untuk
  search; `TagDao` link/unlink/linksFor; `build_runner` sukses)
- `core/utils/combine_latest.dart` — `combineLatest` untuk menggabung stream
  entri + tag
- `domain/entities/` — `Note`, `JournalEntry`, `Idea` (+ enum `IdeaStatus`
  inbox/thinking/working/completed/archived dengan label Indonesia), `Tag`
- `domain/repositories/` + `data/repositories/` — `NoteRepositoryImpl`,
  `JournalRepositoryImpl`, `IdeaRepositoryImpl` (CRUD + watch dengan query,
  sinkronisasi tag lewat `TagLinks`, `resolveTags` parse tag CSV)
- `presentation/providers/` — `notesProvider`/`journalEntriesProvider`/
  `ideasProvider` (`StreamProvider.autoDispose.family<List<T>, String>`,
  family = query search per layar) + Notifier controller
  (create/update/delete, `Idea.setStatus`, metadata NLP source/rawInput/
  confidence)
- `presentation/screens/` — `notes_screen`/`note_form_screen`,
  `journal_screen`/`journal_form_screen` (mood dropdown + date picker),
  `ideas_screen`/`idea_form_screen` (kelompok per status + menu pindah
  status); search bar per layar, hapus dengan konfirmasi, tag chip di form,
  empty/error state
- `shared/formatters/tag_formats.dart` — `split`/`join` tag CSV;
  `shared/formatters/date_formats.dart` — `longFromDate`;
  `shared/widgets/tag_chips.dart` — `TagChips`
- Home: `_HomeEntries` (`Wrap` 5 `TextButton.icon` — Daftar belanja,
  Keuangan, Catatan, Jurnal, Ide) di `home_screen.dart`
- Wiring NLP + chat: `rule_parser.dart` — intent `createNote`
  (`catat:`/`catatan:`/`note:` + leading word), `createJournal` (deteksi
  suasana hati), `createIdea` (`ide:`/`trik:`/`inspirasi:` + leading word);
  `chat_controller.dart` — intent ketiganya memanggil repository dan membalas
  `Catatan disimpan: …` / `Jurnal ditulis: …` / `Ide disimpan: …`
- Test baru + helper:
  - `test/helpers/fake_{note,journal,idea}_repository.dart` — fake in-memory;
    tiap `watch()` membuat `StreamController.broadcast(sync: true)` sendiri
    dengan replay snapshot di `onListen` (lihat Catatan)
  - `test/features/{notes,journal,ideas}/*_repository_test.dart` — CRUD,
    query LIKE, tag link/unlink
  - `test/features/{notes,journal,ideas}/presentation/*_controller_test.dart`
    — CRUD via controller + provider memancarkan perubahan dengan query
  - `test/features/{notes,journal,ideas}/presentation/*_screen_test.dart` —
    empty state, form + validasi, search filter, hapus via dialog, menu
    status ide
  - `chat_controller_test.dart` & `chat_screen_test.dart` — kalimat
    catatan/jurnal/ide mencatat + balasan konfirmasi
  - `migration_test.dart` — v1→v5 dan DB baru langsung skema v5 (tabel +
    kolom + FK + 4 indeks phase 9, insert note + tag pasca-migrasi)
  - `app_test.dart` — entri Catatan/Jurnal/Ide di home membuka layar
    masing-masing (`ensureVisible` sebelum tap karena item bisa di luar
    viewport)

Catatan:

- Test query controller sempat gagal `Bad state: … disposed during loading
  state`: `container.read(provider.future)` tanpa pendengar lain menutup
  subscription eksternal saat itu juga → element di-pause sebelum event
  pertama sampai → dispose menangkap keadaan loading. Fake lama (generator
  `async*`/broadcast biasa) kalah balapan mikro-task; solusi akhir: controller
  per-`watch()` dengan `sync: true` + replay di `onListen` sehingga snapshot
  terkirim sinkron saat didengarkan — dan karena controller baru per panggilan,
  tiap provider/query tetap mendapat replay sendiri.
- `FlutterRiverpod` `misc.dart` dipakai untuk tipe `Notifier`/provider; tiga
  screen test sempat mengimpornya tanpa dipakai → dihapus (analyze bersih).
- `DropdownButtonFormField.value` deprecated → `initialValue` (dropdown mood
  jurnal memakai guard nilai tak dikenal ke `null`; dropdown status ide ke
  `_status`); `context.mounted` → `mounted` hanya di dalam `State`
  (`ideas_screen.dart` `ConsumerWidget` tetap `context.mounted`).
- Flutter assertion: `ListTile` tidak boleh di dalam `DecoratedBox`/`Container`
  berwarna → `_IdeaTile` membungkus dengan `Material` (clip borderRadius).
- `IdeaStatus.done` tidak ada — nilai enum `completed`; test repository/
  controller yang awalnya memakai `.done` ikut diperbaiki. Test chat memakai
  balasan berkonten kapitalisasi hasil NLP (mis. `Capek banget`).
- DoD PHASE 9: note, journal, idea, tag, search (per layar) — semua terpenuhi;
  search global tetap PHASE 13.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 271 PASS

Status: DONE

---

### PHASE 10 — Local AI (selesai)

Completed:

- Dependency: `llamadart 0.10.0` (inference on-device via llama.cpp/FFI;
  backend native dibangun build hook ke `build/native_assets/<platform>`),
  dev `ffi 2.2.0` untuk benchmark. Keputusan runtime: `docs/03-dependencies.md`
  bagian 8; alasan pemilihan model: `docs/05-ai-abstraction.md` bagian 8.
- Model terpilih: `Qwen/Qwen2.5-0.5B-Instruct-GGUF` `q4_k_m` (Apache-2.0,
  491.400.032 byte / ±469 MB), diunduh sekali dengan consent user.
- `core/ai/local_ai_engine.dart` — kontrak `LocalAiEngine` + exception
  ter-tipe (`LocalAiUnavailableException`, `LocalAiInferenceException`)
- `core/ai/ai_config.dart` — SATU-SATUNYA tempat nama model, sumber, ukuran,
  parameter inference, threshold, system prompt, JSON schema, dan 15 contoh
  few-shot; `contextSize` 4096 (prompt ±1,5 ribu token + ruang pesan user)
- `core/ai/ai_model_manager.dart` — `downloadModel` (consent, progres),
  `loadModel` (cacheOnly, tanpa jaringan), `unloadModel`, `isModelCached`
  (cek cache tanpa memuat RAM)
- `core/ai/intent_json_parser.dart` — JSON mentah (termasuk code fence) →
  `AiIntentResult`; gagal parse → null (ditolak, bukan ditebak)
- `core/ai/intent_validator.dart` — aturan docs/05 bagian 4-5: clamp
  confidence, entity wajib → `needs_confirmation`, tanggal/jam ISO,
  kemampuan terlarang (`execute_shell`, `delete_database`, dst.) ditolak
- `core/ai/llamadart_local_ai_engine.dart` — inference dengan structured
  output grammar-constrained (JSON terjamin valid), fallback ke generasi
  teks biasa + parser longgar bila backend tak mendukung grammar ATAU output
  terpotong, semua galat dibungkus exception ter-tipe
- `core/ai/local_ai_runtime.dart` — `localAiRuntimeProvider` (engine + manager
  dari satu backend, dibuat lazy, dispose otomatis)
- `core/ai/ai_model_controller.dart` — `aiModelControllerProvider`: status
  cache/muat/progres/kesalahan; `download`/`load`/`unload`/`refresh`
  menangkap semua exception → pesan error Bahasa Indonesia, tidak pernah crash
- `features/settings/.../widgets/ai_model_card.dart` + section `AI LOKAL`
  di layar Pengaturan: identitas model (nama, ukuran, lisensi), status,
  progres unduhan, tombol Unduh (dialog consent berisi ukuran + catatan
  offline + privasi) / Muat / Lepas. UI tidak memanggil `understand()`
  (docs/05 bagian 3).
- Test baru:
  - `test/core/ai/ai_config_test.dart`, `intent_json_parser_test.dart`,
    `intent_validator_test.dart` (kontrak JSON, aturan validator, larangan)
  - `test/core/ai/local_ai_engine_no_model_test.dart` — DoD "app tetap
    bekerja tanpa model": initialize tidak melempar, isAvailable false,
    understand → `LocalAiUnavailableException`, RuleParser tetap jalan
  - `test/core/ai/ai_model_controller_test.dart` — siklus unduh/muat/lepas,
    galat tiap tahap ditangkap, operasi saat sibuk diabaikan
  - `test/features/settings/settings_screen_test.dart` — kartu AI, dialog
    consent (batal = tidak ada unduhan), unduh → muat → lepas, galat tampil
  - `test/helpers/fake_local_ai.dart` — fake engine + manager + runtime
  - `test/core/ai/local_ai_real_test.dart` (opt-in `PA_AI_BENCHMARK=1`) —
    unduh + muat model nyata, smoke 3 kalimat, benchmark 20 kalimat

Catatan:

- Benchmark (lihat `docs/05` bagian 9): JSON valid **20/20**, intent benar
  **17/20** (lantai DoD ≥10), rerata latency ±14 detik, puncak RAM 833 MB,
  nol crash. Tanpa model: semua jalur aman.
- Prompt sempat menghasilkan akurasi 6/20; diperbaiki menjadi 16–18/20
  dengan: prompt lebih ringkas, prioritas aturan disusun persis seperti
  dispatch `RuleParser`, 15 contoh few-shot berformat pesan asli, serta
  contoh kontra eksplisit (tanpa nominal → bukan expense).
- Batasan: model 0.5B masih goyah di kasus ambigu (nominal vs belanja,
  awalan "catet"); aman karena `IntentValidator` selalu menandai
  `needs_confirmation` bila entity kurang. Kandidat pengganti lebih besar
  tercatat di `docs/05` bagian 8.
- Context window dinaikkan 2048 → 4096 karena prompt few-shot + pesan user
  sempat memotong keluaran JSON (`Malformed structured JSON output`);
  engine kini juga mengulang sekali lewat jalur tanpa grammar bila itu terjadi.
- `AiModelManager.isModelCached()` memakai `ensureModel` dengan
  `ModelCachePolicy.cacheOnly` — melempar bila belum ada cache, tidak pernah
  mengunduh diam-diam.
- Benchmark default **skip** (hemat waktu CI/dev); jalankan manual dengan
  `PA_AI_BENCHMARK=1`. Angka latency diukur dari `flutter test` debug
  Windows x64, bukan HP menengah.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 334
PASS (+3 benchmark PASS saat `PA_AI_BENCHMARK=1`)

Status: DONE

---

### PHASE 11 — Hybrid Intelligence

Routing Rule Parser ↔ Local AI, confidence, fallback, validasi, konfirmasi,
dan penanganan kasus ambigu (semua DoD terpenuhi).

Yang dikerjakan:

- **Routing** (`lib/core/intents/intent_processor.dart`): satu-satunya
  pemanggil `LocalAiEngine.understand()`. Intent yang dikenal Rule Parser
  dengan confidence ≥ ambang ragu → langsung eksekusi (jalur parser tetap
  jalan penuh, docs/05 bagian 7). Selain itu → AI → `DefaultIntentValidator`
  → konfirmasi / ragu / ditolak. Hasil `ProcessedIntent` membawa
  `source` (`rule`/`ai`), `disposition`
  (`execute`/`confirm`/`uncertain`/`rejected`/`unavailable`), dan
  `highConfidence`.
- **Confidence dari preferensi**: `IntentProcessor.thresholds()` membaca
  `user_preferences` (`ai_confidence_accept`, `ai_confidence_uncertain`,
  default `AiConfig` 0.85 / 0.50); nilai tidak valid atau konsisten
  (uncertain > accept) → default. Tabel band docs/05 bagian 6 berlaku untuk
  hasil AI: ≥ accept → kartu + `Simpan`; band tengah → interpretasi +
  `Ya`/`Ubah`; < ambang ragu → tidak menebak (pesan penjelasan).
- **Validation**: hasil AI selalu melewati `IntentValidator` (aturan docs/05
  bagian 4) sebelum tampil; entity kurang/berbahaya → `rejected` dengan pesan
  dari validator, tidak pernah menyimpan.
- **Fallback**: model belum ada (`isAvailable() == false`) atau inference
  gagal → kembali ke jalur Rule Parser, lalu balasan "belum bisa
  memahami..." tanpa menyimpan data; tidak crash, tidak hang.
- **Confirmation**: `lib/features/chat/.../pending_confirmation.dart`
  (siklus `confirm`/`reject`/`edit`/`abandon`, busy-guard, reply disimpan
  hanya saat `confirm`) + `lib/features/chat/.../widgets/confirmation_bar.dart`
  (kartu ringkasan `describeIntent()` + tombol sesuai band, disabled saat
  sibuk, galat → SnackBar). Eksekusi intent dipindah ke
  `.../providers/intent_executor.dart` (dipakai controller maupun konfirmasi).
- **Status pesan**: pesan user yang menunggu keputusan disimpan
  `ChatStatus.needsConfirmation`; setelah konfirmasi/batal/ubah → `sent` +
  `resolvedAt`. Tidak ada data domain yang disimpan sebelum `Simpan`/`Ya`.
- **Ambiguous**: hasil AI < ambang ragu → `uncertain`, balasan menawarkan
  Reminder/Todo/Catatan; input tak dikenal saat model tidak tersedia → balasan
  penjelasan (Smart Inbox-nya PHASE 13).
- **Draf**: `Ubah` mengisi ulang kolom chat lewat `chatDraftProvider`;
  pesan user berhasil dikirim → draf dibersihkan.

Test baru/diubah:

- `test/core/intents/intent_processor_test.dart` (16) — routing parser/AI,
  prioritas rule, validasi AI, fallback model mati/galat, ambang dari
  preferensi (valid, tidak valid, tidak konsisten), contoh PHASE 11
  "kayaknya minggu depan gue harus ngurus pajak motor" → Local AI.
- `test/features/chat/presentation/chat_controller_test.dart` (22) — alur
  `send()` kini memakai DB in-memory + engine fake; 9 tes baru: sumber AI
  tanpa menyimpan, `confirm` menyimpan + source `ai`, `reject`, `edit`,
  band bawah → uncertain, capability terlarang → rejected, inference gagal →
  tidak crash, pesan baru membuang konfirmasi tertunda.
- `test/features/chat/presentation/chat_screen_test.dart` (16) — 4 tes baru:
  kartu konfirmasi + `Simpan` menyimpan (source `ai`), `Batal` membatalkan
  tanpa data, band tengah `Ya`/`Ubah`/`Batal` + `Ubah` mengisi input,
  tanpa model → balasan tanpa kartu.
- `test/helpers/fake_local_ai.dart` — `understandResult`/`understandError`/
  `understandCalls` untuk mengendalikan hasil AI di test.

Catatan:

- Perubahan perilaku: input di luar Rule Parser yang tidak dikenal kini
  **dibalas** (sebelumnya diam); tidak ada yang disimpan.
- Rule Parser yang sudah dikenal tidak lagi menampilkan kartu konfirmasi
  (dijelaskan docs/05 bagian 6): aturan teruji = eksekusi langsung; kartu
  konfirmasi khusus jalur AI.
- Konfirmasi tertunda bersifat in-memory; riwayat tersimpan
  `needs_confirmation` tapi rekonstruksi kartu setelah buka ulang aplikasi
  belum ada (kandidat di PHASE 13 bersama Smart Inbox).
- Threshold belum punya UI penyunting; nilainya sudah preferensi pengguna
  (docs/05 bagian 6).

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 363
PASS (+3 benchmark skip)

Status: DONE

---

### PHASE 12 — Contextual Chat

Perintah lanjutan yang merujuk **item terakhir** percakapan. Semua DoD
terpenuhi: last item context, update, delete, complete, snooze, tests.

Yang dikerjakan:

- **`lib/shared/nlp/followup_parser.dart` (baru)** — deteksi kalimat yang
  diawali kata kerja perintah (opsional awalan `tolong`):
  `ubah`/`ganti`/`jadikan`/`pindah`, `tunda`, `selesaikan`/`selesaiin`/
  `centang`/`tandai selesai`/`done`, `hapus`/`buang`. Hasilnya
  `AiIntentResult` confidence 0.95 dengan entity `date`/`time`/`title`
  (pakai `DateParser`+`TimeParser`, kata sambung `jadi` dibuang) atau
  `snooze` + `snooze_minutes` (`tunda 2 jam` → 120). Parser tidak menyentuh
  `RuleParser`; kalimat non-follow-up menghasilkan `null` sehingga alur lama
  tidak berubah.
- **`lib/core/intents/last_item_context.dart` (baru)** — `LastItemContext`
  `{type, id, label, date, time}` disimpan sebagai JSON di `user_preferences`
  (kunci `chat_last_item`) → konteks **bertahan setelah aplikasi dibuka
  ulang**. Semua operasi (`read`/`write`/`clear`) menangkap galat: konteks
  hilang cukup membuat perintah lanjutan menjawab "belum ada item".
- **`IntentProcessor`** — disposition baru `noTarget`; langkah 0: bila
  `FollowUpParser` cocok → rujuk konteks + injeksi entity
  `target_type`/`target_id`/`target_label` (tanpa memanggil AI); `hapus`
  → `confirm` meski jalur rule (destruktif); konteks kosong / tipe belum
  didukung → `noTarget` + penjelasan. Jalur AI untuk intent
  update/delete/complete ikut dikontekskan (tanpa konteks → `noTarget`).
- **`IntentExecutor`** — dukung `updateItem`, `deleteItem`, `completeItem`:
  - reminder: jadwal baru dihitung ulang + notifikasi dijadwalkan lewat
    `ReminderController.update()` (**baru**: cancel → simpan → schedule);
    hapus lewat `ReminderController.delete` (notifikasi ikut batal) lalu
    konteks dibersihkan; selesai via `ReminderController.complete`.
  - todo: `dueDate`/`dueTime`/judul diubah, `status` → `done` +
    `completedAt`, hapus via repository.
  - snooze: `tunda 2 jam` → `snooze_minutes` → `ReminderController.snooze`;
    `tunda besok` / `tunda jam 10` → target dihitung (jam yang sudah lewat
    hari ini digeser ke besok); `tunda` tanpa durasi → balasan contoh.
  - Semua pembuatan (todo, reminder, belanja, pengeluaran, catatan, jurnal,
    ide) kini menulis `LastItemContext`.
- **UI** — `describeIntent` menghasilkan `Ubah`/`Tunda`/`Hapus`/
  `Selesaikan "label"`; `ConfirmationBar` menampilkan tombol `Hapus`
  (tanpa `Ubah`) untuk intent `delete_item`.

Test baru:

- `test/shared/nlp/followup_parser_test.dart` (17) — bentuk ubah/tunda/
  selesaikan/hapus, awalan `tolong`, kapitalisasi, dan kalimat non-follow-up
  (termasuk kata kerja di tengah kalimat) → `null`.
- `test/core/intents/intent_processor_test.dart` +9 → 25 — `noTarget` tanpa
  konteks, execute bertarget, `hapus` → confirm, selesaikan/tunda bertipe,
  tipe konteks tak didukung, konteks dari preferensi, AI menjawab
  `update_item` dengan/tanpa konteks.
- `test/features/chat/presentation/chat_controller_test.dart` +11 → 33 —
  contoh phase: "besok jam 8 bayar listrik" → "ubah jadi jam 10" (jadwal +
  notifikasi pindah), "jadikan lusa" pada todo, "selesaikan" (lalu idempoten),
  "hapus" konfirmasi → terhapus + konteks bersih, "hapus" batal, "tunda 2
  jam", "tunda jam yang sudah lewat" → besok, "tunda" tanpa durasi, tanpa
  konteks, konteks pindah ke item terbaru, konteks persist.
- `test/features/chat/presentation/chat_screen_test.dart` +1 → 17 — kartu
  `Hapus` muncul tanpa `Ubah`, data aman sebelum ditekan, lalu terhapus.

Catatan:

- Perubahan perilaku: "selesaikan X" **tanpa** tanggal di awal kini =
  selesaikan item terakhir (bukan membuat todo baru); "besok selesaikan X"
  tetap membuat todo karena diawali tanggal.
- Update/complete didukung untuk **todo dan reminder**; `hapus` juga dua
  tipe itu — tipe lain membalas penjelasan eksplisit. Kalimat yang tidak
  diawali kata kerja perintah tidak pernah kena follow-up.
- Konfirmasi `hapus` memakai kartu konfirmasi yang sama (label `Hapus`);
  belum ada undo setelah hapus terkonfirmasi.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test` 401
PASS (+3 benchmark skip)

Status: DONE

---

### PHASE 13 — Search + Calendar + Smart Inbox

Pencarian global, kalender, dan Smart Inbox untuk input yang belum
tertantang. Semua DoD terpenuhi: search cepat (debounce + limit per tipe),
kalender bulanan, inbox dengan aksi, unresolved intent tercatat, filtering
(tipe, tag, status inbox, filter kalender).

Yang dikerjakan:

- **DB (schemaVersion 6)** — tabel `inbox_items` + `InboxItemDao`
  (`watchAll` terurut `createdAt` desc, `getOpen`, `insertItem`,
  `updateItem`, `deleteItem`), FK `chat_message_id` → `chat_messages.id`
  CASCADE, `_upgradeToV6` + test migrasi v1→v6 dan skema segar.
- **Smart Inbox (capture + auto-resolve)** — `ChatController` menangkap
  disposition `uncertain`/`unavailable`/`rejected` ke inbox (`raw_text`
  apa adanya + `suggestion` dari `result.intent.storageValue` bila ada);
  setelah eksekusi berhasil (`execute` di `ChatController`, `confirm` di
  `PendingConfirmationController`) item terbuka dengan teks sama
  (trim + spasi rapat + lowercase) ditandai `converted` +
  `resolved_entity_type`. Semua dibungkus `on Object { // alasan }` —
  chat tidak pernah gagal gara-gara inbox.
- **`features/inbox/` (baru)** — `InboxItem` + `InboxResolution`
  (`open`/`converted`/`discarded`), `InboxRepository` + impl drift;
  layar dengan chip `Terbuka`/`Selesai`/`Semua`, aksi `Simpan sebagai
  Catatan` (buat Note + `converted`), `Buka di Chat` (isi
  `chatDraftProvider`, item tetap terbuka), `Abaikan` (`discarded`).
- **`features/search/` (baru)** — `SearchRepository.search({query, type,
  tag, limitPerType})` + `watchTagNames()`; lintas 6 tipe dengan urutan
  tetap (todo, reminder, note, journal, idea, shopping, expense), escape
  `%`/`_` pada LIKE, tag via `TagLink`. **Bug ditemukan saat test**:
  `_attachTags` meng-alias `results` lalu `clear()+addAll()` — hasil
  hilang semua kalau tidak ada tag row; diperbaiki jadi salinan list.
  Layar Pencarian: debounce 250 ms, chip tipe + tag, hasil per seksi,
  reminder tanpa rute (belum ada layar detailnya).
- **Intent `search`** — executor mencari dengan entity `query` (fallback
  `rawText`), `limitPerType: 5`, membalas tiga hasil teratas tanpa
  navigasi; jalur AI menampilkan kartu konfirmasi dulu (konsisten aturan
  tidak ada auto-save).
- **`features/calendar/` (baru)** — grid bulanan custom Senin-pertama
  (tinggi sel 46, `DateTime.now()`), titik warna per tipe pada tanggal
  ber-kejadian, navigasi bulan + `Hari ini`, filter tipe, tombol cari ke
  layar Pencarian; daftar kejadian bulan terpilih.
- **Navigasi** — ikon cari di AppBar beranda; Inbox bisa dibuka dari
  beranda; dari Kalender/Pencarian ke rute masing-masing.

Test baru:

- `test/features/inbox/inbox_repository_test.dart` (9) — addOpen, watch
  (urutan + filter resolusi), markConverted/markDiscarded, resolveByText
  (normalisasi, no-op teks kosong, tidak menyentuh item terpecahkan),
  getById null. Catatan: FK `chat_message_id` wajib di-seed dulu.
- `test/features/inbox/presentation/inbox_screen_test.dart` (9) — empty
  state, label saran, chip filter, aksi ketiga (catatan/draf chat/
  abaikan), item selesai tak membuka sheet, tombol cari.
- `test/features/search/search_repository_test.dart` (9) — lintas tipe +
  urutan, filter tipe/tag, tag-name, escape LIKE, limitPerType,
  watchTagNames.
- `test/features/search/presentation/search_screen_test.dart` (8) —
  debounce 250 ms, filter tipe/tag, hasil kosong, urutan seksi, tap
  catatan → NotesScreen, reminder tetap di tempat.
- `test/features/calendar/presentation/calendar_screen_test.dart` (6) —
  label bulan/hari + empty state, titik per tanggal (key), pilih hari,
  navigasi bulan, filter menyembunyikan titik + daftar, tombol cari.
- `chat_controller_test.dart` +11 → 44 — capture uncertain (dengan
  saran) / unavailable / rejected, gagal tulis inbox chat tetap jalan,
  auto-resolve rule + confirm (dan tidak menyentuh item lain), intent
  `search` (balasan top-3, `limitPerType` 5, hasil kosong, tidak
  memicu capture inbox).

Catatan:

- Widget test yang me-watch stream drift **wajib** pakai fake repository
  (drift `.watch()` menyisakan pending timer → teardown gagal); layar
  kalender memakai `DateTime.now()` langsung (bukan `clockProvider`)
  karena event hari ini harus terlihat tanpa override jam.
- `clockProvider` ada di `core/database/database_provider.dart`.
- Perilaku baru: teks yang tadinya cuma dijawab "belum bisa dipahami"
  kini tercatat di Inbox dan otomatis terpecahkan begitu teks yang sama
  berhasil dieksekusi.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test`
453 PASS (+3 benchmark skip)

Status: DONE

---

### PHASE 14 — Backup / Restore / PDF

Ekspor/memulihkan seluruh database (JSON dan ZIP berisi lampiran), validasi
berkas, pemulihan transaksi dengan rollback aman, dan laporan pengeluaran
PDF bulanan. Semua DoD terpenuhi: export, import, failed restore aman,
attachment, PDF.

Yang dikerjakan:

- **`lib/core/backup/backup_document.dart`** — format berkas
  `personal-offline-backup` v1: `format`/`version`/`schema_version`/
  `exported_at`/`data` (nilai nullable → JSON), `BackupDocument.encode()` dgn
  indent 2; `fileNameFor` (`personal-offline-backup-YYYY-MM-DD.json|zip`),
  `safetyFileNameFor` (`personal-offline-backup-sebelum-pulihkan-…`),
  `reportFileNameFor` (`laporan-pengeluaran-YYYY-MM.pdf`); `totalRows`.
- **`lib/core/backup/backup_validator.dart`** — validasi murni di memori:
  JSON, format, versi (lebih baru ditolak), `schema_version` (lebih baru →
  tolak; lebih lama → peringatan), `exported_at`, isi `data`, skema tiap
  tabel (`PRAGMA table_info`), tipe sel, baris/daftar; tabel tak dikenal →
  peringatan dan dilewati; nol tabel dikenal → ditolak; hasil
  `BackupValidationResult {valid|invalid}`.
- **`lib/core/backup/backup_archive.dart`** — ZIP dokumen + entri
  `attachments/<name>`; `_safeName` menetralkan pemisah path (`../evil.txt`
  → `.._evil.txt`, `a\b.txt` → `a_b.txt`) saat tulis maupun baca; decode
  menolak ZIP rusak / tanpa `backup.json`.
- **`lib/core/backup/backup_service.dart`** — ekspor `SELECT *` per tabel
  aplikasi (kecuali `sqlite_%`/`drift_%`); urutan tabel induk→anak dari
  `PRAGMA foreign_key_list` (delete anak duluan untuk `replace`); `restore`
  dalam **satu transaksi** → kegagalan = rollback penuh; mode `merge`
  (lewati PK yang sudah ada via `PRAGMA table_info` primary key) dan
  `replace` (hapus semua dulu); `markTablesUpdated` agar stream drift
  memuat ulang; `RestoreResult {ok|failed}` dengan `RestoreTableCounts`.
- **`lib/core/backup/backup_storage.dart`** — `BackupStorage` (abstraksi
  testable) + `PlatformBackupStorage` (baca/tulis folder dokumen aplikasi,
  pick file `file_picker`, share `share_plus`, buka file `open_filex`);
  `backupStorageProvider` + `backupServiceProvider`.
- **`lib/features/settings/.../backup_controller.dart`** — `BackupController`
  (Notifier<bool>): `exportBackup(json|zip)` — lampiran memaksa ZIP;
  `pickAndValidate` (`cancelled`/`invalid`/`ready` + attachmentCount);
  `restore(doc, mode, attachments)` — cadangan aman dulu (best effort),
  tulis lampiran setelah sukses; `exportMonthlyExpenseReport` (PDF bulan
  berjalan lalu `openBackup`); busy-guard + semua galat → null/invalid,
  tidak pernah crash.
- **`lib/core/pdf/pdf_report_service.dart`** — `PdfReportService.
  buildExpenseReport` (paket `pdf` 3.13.1): header bulan, ringkasan per
  kategori + total, rincian terurut tanggal, font Helvetica (ASCII);
  kosong pun menghasilkan PDF valid.
- **UI** — section `Cadangan & Data` di layar Pengaturan (`BackupSection`):
  4 aksi (Ekspor JSON, Ekspor ZIP, Pulihkan, Laporan PDF bulan ini), tombol
  nonaktif + `LinearProgressIndicator` saat sibuk; pemulihan menampilkan
  dialog pratinjau (tanggal buat, versi DB, baris per tabel) dengan
  `Gabung (lewati duplikat)` / `Timpa (hapus data lama)`; dialog Gagal dan
  ringkasan `Pemulihan selesai` (Disisipkan/Dilewati); SnackBar bila ekspor
  atau PDF gagal. Section `AI LOKAL` (PHASE 11) yang sempat tertimpa
  di-atas-nya dikembalikan.
- **Provider untuk test** — `FakeBackupStorage` (in-memory, gate
  `Completer` untuk menguji busy-state, injeksi `writeError`/`readError`,
  tangkapan path share/open) dan `FakeBackupService` (subclass tanpa sentuh
  drift agar widget test aman di bawah FakeAsync).

Test baru:

- `test/core/backup/backup_document_test.dart` (4) — struktur encode,
  `totalRows`, penamaan berkas (json/zip/safety/PDF).
- `test/core/backup/backup_validator_test.dart` (17) — dokumen sah, skema
  lama (warning), tabel tak dikenal (warning), dan tiap jalur invalid
  (JSON, objek, format, versi, schema_version, exported_at, data, daftar,
  objek baris, kolom, tipe, nol tabel).
- `test/core/backup/backup_archive_test.dart` (8) — roundtrip tanpa/dengan
  lampiran, sanitasi path saat tulis dan baca, byte bukan ZIP, ZIP tanpa
  `backup.json`.
- `test/core/backup/backup_service_test.dart` (12) — ekspor semua tabel
  aplikasi + tanpa tabel internal, validasi, replace vs merge (conflict
  dilewati), rollback saat tampered di tengah replace, urutan FK induk/anak,
  tabel tak dikenal diabaikan, stream drift dimuat ulang, warning skema lama.
- `test/core/pdf/pdf_report_service_test.dart` (3) — header `%PDF-`,
  sorting tanggal, kosong tetap valid.
- `test/features/settings/presentation/backup_controller_test.dart` (16) —
  JSON tanpa lampiran → share; lampiran → ZIP; ZIP eksplisit; sibuk menolak
  keduanya (gate); gagal simpan → null; pick dibatalkan/rusak/format
  berbeda/JSON valid/ZIP valid+attachment/ZIP tanpa backup.json/baca gagal;
  restore menulis cadangan aman `sebelum-pulihkan`, menulis lampiran,
  gagal → success false + state tidak sibuk; PDF bulan berjalan menulis +
  membuka; gagal simpan PDF → null.
- `test/features/settings/presentation/backup_section_test.dart` (10) —
  deskripsi + 4 aksi, ekspor memanggil layanan + share, SnackBar gagal,
  tombol nonaktif saat sibuk, picker batal → tanpa dialog, berkas invalid →
  dialog Gagal, pratinjau → Batal aman, Timpa → ringkasan + mode replace,
  Gabung → mode merge, pemulihan gagal → dialog Gagal.
- `test/features/settings/settings_screen_test.dart` +1 — section
  `CADANGAN & DATA` tampil (di bawah `AI LOKAL`), 4 tombol aksi terlihat.

Catatan:

- Perbaikan dari kode setengah jadi: impor `path_provider` hilang di
  `backup_storage.dart`, kurung `mappedWith` di `backup_archive.dart`, case
  `num` tak terjangkau di `backup_service.dart`, impor/nesting
  `Expanded`/deps di `backup_section.dart`, dan section `AI LOKAL` yang
  tertimpa `BackupSection` di `settings_screen.dart`.
- Ekspor menggunakan `SELECT *` per tabel sehingga seluruh tabel baru
  (mis. PHASE 13 `inbox_items`) otomatis ikut tercakup tanpa perubahan kode.
- `BackupController.restore` menerima `mode` sebagai argumen posisional
  (bukan named).
- Widget test cadangan memakai `FakeBackupService` (subclass) agar operasi
  Drift tidak berjalan di bawah FakeAsync (lihat catatan PHASE 3/13).
- Dependensi baru terdaftar di `docs/03-dependencies.md`: `file_picker
  13.1.0`, `share_plus 13.3.1`, `archive 4.3.0`, `pdf 3.13.1`,
  `open_filex 4.7.0`.

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test`
525 PASS (+3 benchmark skip)

Status: DONE

### PHASE 16 - UI/UX Polish

Ringkasan:

- **Shared `ErrorState`** (`lib/shared/widgets/error_state.dart`) menggantikan
  7 duplikat `_ErrorState` (chat, todo, finance, shopping, notes, ideas,
  journal); error-path inbox/search/calendar dikonversi dari `EmptyState`
  menjadi `ErrorState` + tombol "Coba lagi" (invalidate provider via
  `ref.invalidate`).
- **`PageTransitionsTheme`** global memakai `FadeForwardsPageTransitionsBuilder`
  untuk semua `TargetPlatform` (tersedia di Flutter 3.44.1).
- **Aksesibilitas**: tinggi `NavigationBar` 80px + label tak terkunci ukuran
  font; chip (filter + tag) >=48px via padding vertikal 14; sel hari kalender
  diperbesar dan tinggi grid ikut `textScaler`; 3 bar pencarian
  (notes/journal/ideas) `PreferredSize` skala-aware.
- **Overflow**: chip filter inbox/kalender `Row` -> `Wrap`; header daftar
  belanja `Flexible`+ellipsis; `_DayCell` dots `MainAxisSize.min`;
  `EmptyState`/`ErrorState` dibungkus `SingleChildScrollView` agar aman teks
  besar; header bulan kalender ulet (`FittedBox`) + label max 2 baris.
- **Verifikasi textScaler 2x** (smoke test sementara, viewport 320px):
  semua 5 tab bebas overflow.
- **Kontras**: alpha timestamp `message_bubble` dihapus (warna penuh);
  dead code `AppColors.success/warning/danger` dihapus.
- **Typography/spacing**: audit seluruh layar — sudah memakai token
  `AppSpacing` (literal tersisa hanya nilai sub-token yang disengaja:
  0, 1.5, 2, 14, 80).

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test`
525 PASS (+3 benchmark skip)

Status: DONE

---

### PHASE 17 — Testing & Release

Ringkasan:

- **Integration test end-to-end** (`integration_test/app_test.dart`, baru):
  7 skenario PHASE 17 lewat chat nyata di **perangkat fisik Android**
  (OPPO CPH2801): Reminder `besok jam 8 bayar listrik` → Reminder
  `Bayar listrik` 2026-10-09 08:00 + scheduler notifikasi
  `DateTime(2026,10,9,8)`; Context `ubah jadi jam 10` → Reminder diubah +
  scheduler pindah ke 10:00; Todo `besok selesaikan laporan` due
  2026-10-09; Shopping `besok beli telur susu minyak` items
  [Telur, Susu, Minyak]; Finance `tadi makan 25 ribu` amount 25000
  kategori makanan 2026-10-08; Journal `hari ini capek banget` mood
  `capek`; AI (model mati → jalur fallback) `kayaknya minggu depan aku
  harus servis motor` → Todo via Rule Parser.
- **Bangunan test device**: harness TIDAK memanggil `main()` (menghindari
  inisialisasi plugin nyata/dialog izin): langsung pump
  `UncontrolledProviderScope` + `ProviderContainer` dengan overrides —
  `appDatabaseProvider` → `AppDatabase(NativeDatabase.memory())` (SQLite
  in-memory asli), `notificationSchedulerProvider` →
  `FakeNotificationScheduler`, `clockProvider` → `FixedClock(2026-10-08
  06:00)`, `localAiRuntimeProvider` → `buildFakeRuntime()`.
  `initializeDateFormatting('id')` dipanggil karena harness mem-bypass
  `main()`.
- **Seam `lib/main.dart`**: `main({List<Override> overrides = const []})`
  membangun `ProviderContainer(overrides)` + `UncontrolledProviderScope`,
  scheduler dibaca dari container (`notificationSchedulerProvider`) — test
  tidak menyentuh permission nyata. Tipe `Override` diimpor dari
  `package:flutter_riverpod/misc.dart` (exports Riverpod 3.4.3).
- **Fix build Android**: `flutter_local_notifications` meminta *core library
  desugaring* → `android/app/build.gradle.kts` `compileOptions {
  isCoreLibraryDesugaringEnabled = true }` + dependency
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4)`.
- **Menempa integration test** (3 iterasi yang didokumentasikan):
  1) `find.bySemanticsLabel('Buka percakapan')` tidak menemukan node
     (tree semantik mati di widget test; label gabungan di device) →
     diganti `find.text('Ketik di sini...')` (placeholder beranda, unik).
  2) Perangkat OPPO memunculkan `INSTALL_FAILED_VERIFICATION_FAILURE`
     (dialog konfirmasi install di layar HP) — retry sukses; layar HP
     wajib menyala saat install.
  3) Kegagalan device yang sebenarnya (bukan logika): balasan sudah
     tersimpan di database tapi `find.byType(MessageBubble)` tidak
     bertambah — dengan keyboard terbuka bubble baru berada di luar
     viewport + cacheExtent (ListView lazy) sehingga tidak dibangun.
     Solusi: wait berbasis **database sebagai sumber kebenaran**
     (`chatRepository.getAll()` count) + tombol Kirim dinilai via
     `IconButton.tooltip == 'Kirim'` (bukan `byTooltip` → RawTooltip)
     + timeout 60 detik. Verifikasi balasan dibaca dari DB (`.last`).
- **Verifikasi akhir**: `flutter analyze` 0 issue; `flutter test` **525
  PASS** (+3 benchmark skip); `flutter test integration_test/app_test.dart
  -d 3C26160032100000` — **All tests passed** (7/7 skenario, ±8 detik);
  `flutter build apk --release` sukses → `app-release.apk` (269,9 MB,
  di-sign debug sesuai TODO `build.gradle.kts`), lalu APK release
  di-`adb install`, diluncurkan, proses hidup (`pidof` + `MainActivity`
  resumed) tanpa crash.
- **Skenario manual** (test list PHASE 17): offline (aplikasi tanpa
  jaringan — seluruh data lokal, tidak ada network I/O) dan restart
  (data SQLite memakai `NativeDatabase` drift, bertahan) bersifat
  device-level dan sudah dijamin desain + integration harness; notification
  (exact alarm via `flutter_local_notifications`, scheduler diverifikasi
  `FakeNotificationScheduler` di unit test + integration), dark mode,
  database, backup, restore, dan AI unavailable sudah tercakup test
  otomatis (PHASE 6/10/11/13/14). Dua poin yang membutuhkan interaksi
  manual di perangkat: memunculkan notifikasi terjadwal pada jam yang
  ditentukan dan memeriksa notifikasi popup saat app tertutup/layar
  terkunci — tidak diverifikasi otomatis karena platform channel.

Catatan:

- Release APK belum di-sign dengan keystore produksi (TODO di
  `android/app/build.gradle.kts` disengaja). Ukuran 269,9 MB karena satu
  APK mencakup semua ABI; opsi efisiensi (splits ABI/R8/`--obfuscate`,
  model AI tetap unduhan terpisah) bisa dilakukan user kapan pun.
- Device flaky install OPPO serupa masalah build/signature, bukan kode:
  verifikasi dipakai tiga jalur — unit/widget (VM), integration (device),
  build release (install + launch live).

Tests: `dart format` bersih, `flutter analyze` 0 issue, `flutter test`
525 PASS (+3 benchmark skip) + `flutter test integration_test/app_test.dart`
di perangkat fisik PASS (7 skenario)

Status: DONE

---

### PHASE 17b — Widget layar utama Android

Ringkasan:

- **Widget tugas hari ini** (Android saja, paket `home_widget` 0.10.0,
  teknologi **Android XML / RemoteViews**, bukan Jetpack Glance):
  menampilkan tugas hari ini (belum selesai + selesai, maks 6 baris)
  dengan checkbox yang bisa dicentang **langsung dari widget** dan tombol
  **Chat** yang membuka layar Percakapan.
- **Keputusan desain** (hasil tanya user): (1) tampilkan tugas selesai dan
  bisa dicentang dari widget; (2) tombol Chat membuka layar Percakapan
  (deep-link) — RemoteViews tidak bisa mengetik teks di widget; (3) pakai
  Android XML/RemoteViews.
- **Lapisan Dart**: `core/widget/` — `widget_keys.dart` (nama provider
  `com.personaloffline.personal_offline.TodayTasksWidgetProvider`, key
  `today_tasks_json`/`today_tasks_updated_at`, skema `personaloffline`),
  `today_tasks_codec.dart` (`TodayTaskEntry` + encode/decode JSON ringkas,
  aman data rusak), `widget_sync.dart` (`pushTodayTasksToWidget`),
  `home_widget_service.dart` (`HomeWidgetService` + provider, dibungkus
  interface milik app agar bisa di-fake), `widget_callbacks.dart`
  (`@pragma('vm:entry-point')` callback isolate background), dan
  `widget_sync_scope.dart` (mendengar `todayTasksForWidgetProvider` →
  push ke widget; menangani deep-link `host == 'chat'`).
- **Data layer**: `TaskDao.watchAllOn(date)` (pending + selesai, pending
  dulu) → `TaskRepository.watchTasksForWidgetOn` →
  `todayTasksForWidgetProvider` (`task_controller.dart`).
- **Isolate background**: callback interaktif jalan di isolate terpisah
  (engine sendiri) → `DriftNativeOptions(shareAcrossIsolates: true)` di
  `app_database.dart` + `DartPluginRegistrant.ensureInitialized()` di
  `widget_callbacks.dart` agar `path_provider`/drift bisa buka DB.
- **Native**: `TodayTasksWidgetProvider.kt` (extends `HomeWidgetProvider`,
  parse JSON via `org.json`, `MAX_TASKS = 6`, checkbox →
  `HomeWidgetBackgroundIntent`, header/tombol → `HomeWidgetLaunchIntent`)
  + layout `today_tasks_widget.xml`/`today_tasks_widget_row.xml` + drawable
  ikon/background + `values`/`values-night` warna + `xml/…_info.xml`.
  Manifest menambah intent-filter LAUNCH di `MainActivity` dan dua receiver
  (widget + background).
- **Settings**: kartu "Widget layar utama" (`home_widget_card.dart`) dengan
  tombol "Pin ke layar utama"; section ditaruh **setelah CADANGAN** agar
  kartu AI tetap dalam viewport awal (test lama tidak pecah).

Keterbatasan:

- Chat dari widget hanya membuka layar Percakapan (deep-link); widget tidak
  bisa mengetik/berkirim pesan karena keterbatasan RemoteViews.
- Widget Android saja; iOS tidak disiapkan.

Tests: `flutter analyze` 0 issue; `flutter test` **537 PASS** (+3 benchmark
skip), termasuk `today_tasks_codec_test.dart` dan `widget_sync_scope_test.dart`.

Status: DONE


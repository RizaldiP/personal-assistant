# 07 — Roadmap & Status

Sumber kebenaran urutan kerja tetap `PROJECT.md`. Dokumen ini hanya ringkasan
status.

## 1. Status saat ini

```
CURRENT ACTIVE PHASE: PHASE 8
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

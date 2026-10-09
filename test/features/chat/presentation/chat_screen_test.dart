import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/services/notification_scheduler.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/calendar/domain/calendar_event.dart';
import 'package:personal_offline/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/domain/entities/chat_message.dart';
import 'package:personal_offline/features/chat/presentation/providers/chat_messages_provider.dart';
import 'package:personal_offline/features/chat/presentation/screens/chat_screen.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/notes/presentation/screens/notes_screen.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/presentation/screens/todo_screen.dart';
import 'package:personal_offline/shared/intents/ai_intent_result.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

import '../../../helpers/fake_chat_repository.dart';
import '../../../helpers/fake_expense_repository.dart';
import '../../../helpers/fake_journal_repository.dart';
import '../../../helpers/fake_local_ai.dart';
import '../../../helpers/fake_note_repository.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_reminder_repository.dart';
import '../../../helpers/fake_shopping_repository.dart';
import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeChatRepository repository;
  late FakeLocalAiEngine engine;
  late db.AppDatabase database;

  setUp(() {
    repository = FakeChatRepository();
    engine = FakeLocalAiEngine();
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  /// Override dasar: database in-memory + engine AI fake (PHASE 11).
  List<Override> baseOverrides() => [
    appDatabaseProvider.overrideWithValue(database),
    localAiRuntimeProvider.overrideWithValue(buildFakeRuntime(engine: engine)),
  ];

  Future<void> pumpChat(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repository),
          ...baseOverrides(),
          ...overrides,
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder sendButton() => find.ancestor(
    of: find.byIcon(Icons.arrow_upward_rounded),
    matching: find.byType(IconButton),
  );

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(sendButton());
    await tester.pumpAndSettle();
  }

  testWidgets('chat kosong menampilkan empty state dan input', (tester) async {
    await pumpChat(tester);

    expect(find.text('Belum ada percakapan'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ketik di sini...'), findsOneWidget);
    expect(sendButton(), findsOneWidget);
  });

  testWidgets('quick action selalu menampilkan tiga chip daftar', (
    tester,
  ) async {
    await pumpChat(tester);

    expect(find.byType(ActionChip), findsNWidgets(3));
    expect(find.text('Daftar Tugas'), findsOneWidget);
    expect(find.text('Daftar Catatan'), findsOneWidget);
    expect(find.text('Daftar Reminder'), findsOneWidget);
  });

  testWidgets('quick action "Daftar Tugas" membuka TodoScreen', (tester) async {
    await pumpChat(
      tester,
      overrides: [
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
      ],
    );

    await tester.tap(find.text('Daftar Tugas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(TodoScreen), findsOneWidget);
  });

  testWidgets('quick action "Daftar Catatan" membuka NotesScreen', (
    tester,
  ) async {
    await pumpChat(
      tester,
      overrides: [
        noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
      ],
    );

    await tester.tap(find.text('Daftar Catatan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(NotesScreen), findsOneWidget);
  });

  testWidgets(
    'quick action "Daftar Reminder" membuka kalender dengan filter reminder',
    (tester) async {
      await pumpChat(
        tester,
        overrides: [
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          reminderRepositoryProvider.overrideWithValue(
            FakeReminderRepository(),
          ),
          journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
        ],
      );

      await tester.tap(find.text('Daftar Reminder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final calendar = tester.widget<CalendarScreen>(
        find.byType(CalendarScreen),
      );
      expect(calendar.initialFilter, CalendarEventTypes.reminder);
    },
  );

  testWidgets('user bisa mengetik dan mengirim pesan', (tester) async {
    await pumpChat(tester);

    await typeAndSend(tester, 'besok bayar listrik');

    expect(find.text('besok bayar listrik'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('riwayat pesan bertahan setelah layar dibuka ulang', (
    tester,
  ) async {
    await pumpChat(tester);
    await typeAndSend(tester, 'besok bayar listrik');
    expect(find.text('besok bayar listrik'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await pumpChat(tester);

    expect(find.text('besok bayar listrik'), findsOneWidget);
  });

  testWidgets('menampilkan loading sebelum riwayat siap lalu data', (
    tester,
  ) async {
    final streamController = StreamController<List<ChatMessage>>();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repository),
          chatMessagesProvider.overrideWith((ref) => streamController.stream),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    streamController.add(const []);
    await tester.pumpAndSettle();

    expect(find.text('Belum ada percakapan'), findsOneWidget);
  });

  testWidgets('riwayat gagal dimuat menampilkan error state dengan coba lagi', (
    tester,
  ) async {
    await pumpChat(
      tester,
      overrides: [
        chatMessagesProvider.overrideWith(
          (ref) => Stream<List<ChatMessage>>.error(StateError('rusak')),
        ),
      ],
    );

    expect(find.text('Riwayat gagal dimuat'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Riwayat gagal dimuat'), findsOneWidget);
  });

  testWidgets('gagal menyimpan pesan menampilkan snackbar dan teks tetap', (
    tester,
  ) async {
    repository.failSave = true;
    await pumpChat(tester);

    await typeAndSend(tester, 'besok bayar listrik');

    expect(find.text('Pesan gagal disimpan. Coba lagi.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'besok bayar listrik',
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('tombol kirim nonaktif saat input kosong', (tester) async {
    await pumpChat(tester);

    expect(tester.widget<IconButton>(sendButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(sendButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'halo');
    await tester.pump();
    expect(tester.widget<IconButton>(sendButton()).onPressed, isNotNull);
  });

  testWidgets('kalimat todo membuat balasan asisten konfirmasi', (
    tester,
  ) async {
    final taskRepository = FakeTaskRepository();
    await pumpChat(
      tester,
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 9))),
        taskRepositoryProvider.overrideWithValue(taskRepository),
      ],
    );

    await typeAndSend(tester, 'besok selesaikan laporan kapal');

    expect(taskRepository.tasks, hasLength(1));
    expect(taskRepository.tasks.single.title, 'Selesaikan laporan kapal');
    expect(
      find.text('Todo dibuat: Selesaikan laporan kapal · 6 Oktober 2026'),
      findsOneWidget,
    );
    expect(find.text('besok selesaikan laporan kapal'), findsOneWidget);
  });

  testWidgets('kalimat reminder membuat balasan asisten konfirmasi', (
    tester,
  ) async {
    final reminderRepository = FakeReminderRepository();
    await pumpChat(
      tester,
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 9))),
        reminderRepositoryProvider.overrideWithValue(reminderRepository),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
      ],
    );

    await typeAndSend(tester, 'besok jam 8 bayar listrik');

    expect(reminderRepository.reminders, hasLength(1));
    expect(reminderRepository.reminders.single.title, 'Bayar listrik');
    expect(
      find.text(
        'Reminder dijadwalkan: Bayar listrik · 6 Oktober 2026 jam 08:00',
      ),
      findsOneWidget,
    );
    expect(find.text('besok jam 8 bayar listrik'), findsOneWidget);
  });

  testWidgets('kalimat belanja membuat balasan asisten konfirmasi', (
    tester,
  ) async {
    final shoppingRepository = FakeShoppingRepository();
    await pumpChat(
      tester,
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 9))),
        shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
      ],
    );

    await typeAndSend(tester, 'besok beli beras minyak telur');

    final list = shoppingRepository.lists.single;
    expect(list.items.map((i) => i.name), ['Beras', 'Minyak', 'Telur']);
    expect(find.text('Belanja dicatat: Beras, Minyak, Telur'), findsOneWidget);
    expect(find.text('besok beli beras minyak telur'), findsOneWidget);
  });

  testWidgets('kalimat pengeluaran membuat balasan asisten konfirmasi', (
    tester,
  ) async {
    final expenseRepository = FakeExpenseRepository();
    await pumpChat(
      tester,
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 9))),
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
      ],
    );

    await typeAndSend(tester, 'tadi makan ayam 25 ribu');

    final expense = expenseRepository.expenses.single;
    expect(expense.amount, 25000);
    expect(expense.category, ExpenseCategory.makanan);
    expect(
      find.text('Pengeluaran dicatat: Rp 25.000 · Makanan · Ayam'),
      findsOneWidget,
    );
    expect(find.text('tadi makan ayam 25 ribu'), findsOneWidget);
  });

  testWidgets('kalimat catatan membuat balasan asisten konfirmasi', (
    tester,
  ) async {
    final noteRepository = FakeNoteRepository();
    await pumpChat(
      tester,
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 9))),
        noteRepositoryProvider.overrideWithValue(noteRepository),
      ],
    );

    await typeAndSend(tester, 'catatan: nomor sparepart 12345');

    expect(noteRepository.notes, hasLength(1));
    expect(noteRepository.notes.single.content, 'Nomor sparepart 12345');
    expect(
      find.text('Catatan disimpan: Nomor sparepart 12345'),
      findsOneWidget,
    );
    expect(find.text('catatan: nomor sparepart 12345'), findsOneWidget);
  });

  group('kartu konfirmasi AI (PHASE 11)', () {
    const aiText = 'laporan kapal harus selesai minggu depan';

    void engineYakin({double confidence = 0.9}) {
      engine.ready = true;
      engine.understandResult = AiIntentResult(
        intent: AppIntent.createTodo,
        confidence: confidence,
        entities: const {'title': 'Kirim laporan', 'due_date': '2026-10-10'},
      );
    }

    testWidgets('hasil AI memunculkan kartu konfirmasi sebelum menyimpan', (
      tester,
    ) async {
      engineYakin();
      final taskRepository = FakeTaskRepository();
      await pumpChat(
        tester,
        overrides: [taskRepositoryProvider.overrideWithValue(taskRepository)],
      );

      await typeAndSend(tester, aiText);

      expect(
        find.textContaining('Konfirmasi: Tugas "Kirim laporan"'),
        findsOneWidget,
      );
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
      expect(taskRepository.tasks, isEmpty);

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(taskRepository.tasks, hasLength(1));
      expect(taskRepository.tasks.single.source, 'ai');
      expect(
        find.text('Todo dibuat: Kirim laporan · 10 Oktober 2026'),
        findsOneWidget,
      );
      expect(find.text('Simpan'), findsNothing);
    });

    testWidgets('Batal membatalkan konfirmasi tanpa menyimpan data', (
      tester,
    ) async {
      engineYakin();
      final taskRepository = FakeTaskRepository();
      await pumpChat(
        tester,
        overrides: [taskRepositoryProvider.overrideWithValue(taskRepository)],
      );

      await typeAndSend(tester, aiText);
      expect(find.text('Simpan'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(taskRepository.tasks, isEmpty);
      expect(find.text('Oke, tidak jadi disimpan.'), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);
    });

    testWidgets('confidence menengah menampilkan Ya/Ubah/Batal', (
      tester,
    ) async {
      engineYakin(confidence: 0.6);
      final taskRepository = FakeTaskRepository();
      await pumpChat(
        tester,
        overrides: [taskRepositoryProvider.overrideWithValue(taskRepository)],
      );

      await typeAndSend(tester, aiText);

      expect(find.text('Ya'), findsOneWidget);
      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(taskRepository.tasks, isEmpty);

      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      expect(taskRepository.tasks, isEmpty);
      expect(find.text('Ubah'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        aiText,
      );
    });

    testWidgets('tanpa model AI, kalimat tak dikenal dibalas tanpa kartu', (
      tester,
    ) async {
      await pumpChat(tester);

      await typeAndSend(tester, 'qwerty asdf');

      expect(find.textContaining('belum bisa memahami'), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);
    });

    testWidgets('perintah hapus menampilkan kartu Hapus, lalu menghapus', (
      tester,
    ) async {
      final taskRepository = FakeTaskRepository();
      await pumpChat(
        tester,
        overrides: [taskRepositoryProvider.overrideWithValue(taskRepository)],
      );

      await typeAndSend(tester, 'besok selesaikan laporan kapal');
      expect(taskRepository.tasks, hasLength(1));

      await typeAndSend(tester, 'hapus');

      expect(taskRepository.tasks, hasLength(1), reason: 'belum dikonfirmasi');
      expect(find.text('Hapus'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
      expect(find.text('Simpan'), findsNothing);

      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(taskRepository.tasks, isEmpty);
      expect(
        find.text('Todo dihapus: Selesaikan laporan kapal'),
        findsOneWidget,
      );
      expect(find.text('Hapus'), findsNothing);
    });
  });
}

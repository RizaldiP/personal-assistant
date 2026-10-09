// PHASE 17 — integration test: skenario "Full test" lewat chat end-to-end.
//
// Berjalan di perangkat nyata/emulator (`flutter test integration_test -d ...`).
// Database nyata (SQLite in-memory via drift), jam tetap, scheduler notifikasi
// palsu, dan AI lokal dimatikan (jalur fallback) — minimal satu kalimat tetap
// bisa dieksekusi lewat Rule Parser sehingga seluruh tujuh skenario diuji.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_offline/app.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/core/database/app_database.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/services/notification_scheduler.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/presentation/screens/chat_screen.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';

import '../test/helpers/fake_local_ai.dart';
import '../test/helpers/fake_notification_scheduler.dart';

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 60),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    condition(),
    isTrue,
    reason: reason ?? 'kondisi tidak tercapai sebelum timeout',
  );
}

Future<String> _sendAndGetLatestReply(
  WidgetTester tester,
  String text,
  ProviderContainer container,
) async {
  final chatRepo = container.read(chatRepositoryProvider);
  final msgsBefore = (await chatRepo.getAll()).length;
  final kirimButton = find.byWidgetPredicate(
    (w) => w is IconButton && w.tooltip == 'Kirim',
  );
  await tester.enterText(find.byType(TextField), text);
  await _waitUntil(tester, () {
    final matches = kirimButton.evaluate();
    if (matches.isEmpty) return false;
    final button = matches.first.widget as IconButton;
    return button.onPressed != null;
  }, reason: 'tombol Kirim belum aktif');
  await tester.tap(kirimButton);
  await _waitForMessages(
    tester,
    container,
    msgsBefore + 2,
    reason: 'balasan asisten untuk "$text" belum muncul',
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  final msgs = await chatRepo.getAll();
  return msgs.last.content;
}

Future<void> _waitForMessages(
  WidgetTester tester,
  ProviderContainer container,
  int requiredCount, {
  Duration timeout = const Duration(seconds: 60),
  String? reason,
}) async {
  final chatRepo = container.read(chatRepositoryProvider);
  final deadline = DateTime.now().add(timeout);
  var count = 0;
  while (count < requiredCount) {
    if (DateTime.now().isAfter(deadline)) break;
    await tester.pump(const Duration(milliseconds: 100));
    count = (await chatRepo.getAll()).length;
  }
  expect(count, greaterThanOrEqualTo(requiredCount), reason: reason);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Full test: Reminder, Todo, Shopping, Finance, Journal, AI, Context',
    (tester) async {
      await initializeDateFormatting('id');
      final now = DateTime(2026, 10, 8, 6, 0);
      final scheduler = FakeNotificationScheduler();
      final overrides = <Override>[
        appDatabaseProvider.overrideWithValue(
          AppDatabase(NativeDatabase.memory()),
        ),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(FixedClock(now)),
        localAiRuntimeProvider.overrideWithValue(buildFakeRuntime()),
      ];
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PersonalOfflineApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Buka layar percakapan dari beranda.
      await tester.tap(find.text('Ketik di sini...'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);

      // 1. Reminder.
      var reply = await _sendAndGetLatestReply(
        tester,
        'besok jam 8 bayar listrik',
        container,
      );
      expect(reply, contains('Reminder dijadwalkan'));
      expect(reply, contains('Bayar listrik'));
      var reminders = await container.read(reminderRepositoryProvider).getAll();
      expect(reminders, hasLength(1));
      expect(reminders.first.title, 'Bayar listrik');
      expect(reminders.first.date, '2026-10-09');
      expect(reminders.first.time, '08:00');
      expect(scheduler.scheduled.values, contains(DateTime(2026, 10, 9, 8)));

      // 2. Context: "ubah jadi jam 10" merujuk reminder terakhir.
      reply = await _sendAndGetLatestReply(
        tester,
        'ubah jadi jam 10',
        container,
      );
      expect(reply, contains('Reminder diubah'));
      expect(reply, contains('jam 10:00'));
      reminders = await container.read(reminderRepositoryProvider).getAll();
      expect(reminders.first.time, '10:00');
      expect(scheduler.scheduled.values, contains(DateTime(2026, 10, 9, 10)));

      // 3. Todo.
      reply = await _sendAndGetLatestReply(
        tester,
        'besok selesaikan laporan',
        container,
      );
      expect(reply, contains('Todo dibuat'));
      final tasks = await container.read(taskRepositoryProvider).getAll();
      expect(tasks.any((t) => t.title == 'Selesaikan laporan'), isTrue);
      expect(tasks.first.dueDate, '2026-10-09');

      // 4. Shopping.
      reply = await _sendAndGetLatestReply(
        tester,
        'besok beli telur susu minyak',
        container,
      );
      expect(reply, contains('Belanja dicatat'));
      final lists = await container.read(shoppingRepositoryProvider).getAll();
      final names = lists
          .expand((list) => list.items)
          .map((item) => item.name)
          .toList();
      expect(names, containsAll(['Telur', 'Susu', 'Minyak']));

      // 5. Finance.
      reply = await _sendAndGetLatestReply(
        tester,
        'tadi makan 25 ribu',
        container,
      );
      expect(reply, contains('Pengeluaran dicatat'));
      final expenses = await container.read(expenseRepositoryProvider).getAll();
      expect(expenses, hasLength(1));
      expect(expenses.first.amount, 25000);
      expect(expenses.first.category, ExpenseCategory.makanan);
      expect(expenses.first.date, '2026-10-08');

      // 6. Journal.
      reply = await _sendAndGetLatestReply(
        tester,
        'hari ini capek banget',
        container,
      );
      expect(reply, contains('Jurnal ditulis'));
      final journals = await container.read(journalRepositoryProvider).getAll();
      expect(journals, hasLength(1));
      expect(journals.first.mood, 'capek');
      expect(journals.first.date, '2026-10-08');

      // 7. AI (dengan model mati, Rule Parser tetap mengeksekusi todo).
      reply = await _sendAndGetLatestReply(
        tester,
        'kayaknya minggu depan aku harus servis motor',
        container,
      );
      expect(reply, contains('Todo dibuat'));
      final allTasks = await container.read(taskRepositoryProvider).getAll();
      expect(allTasks.any((t) => t.title.contains('servis motor')), isTrue);

      // Aplikasi tetap di layar chat tanpa exception.
      await _waitUntil(
        tester,
        () => find.byType(ChatScreen).evaluate().isNotEmpty,
        reason: 'layar chat harus tetap hidup',
      );
    },
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/services/notification_scheduler.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/domain/entities/chat_message.dart';
import 'package:personal_offline/features/chat/presentation/providers/chat_controller.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/reminder/domain/reminder_schedule.dart';
import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';

import '../../../helpers/fake_chat_repository.dart';
import '../../../helpers/fake_expense_repository.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_reminder_repository.dart';
import '../../../helpers/fake_shopping_repository.dart';
import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeChatRepository repository;
  late FakeTaskRepository taskRepository;
  late FakeReminderRepository reminderRepository;
  late FakeShoppingRepository shoppingRepository;
  late FakeExpenseRepository expenseRepository;
  late FakeNotificationScheduler scheduler;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeChatRepository();
    taskRepository = FakeTaskRepository();
    reminderRepository = FakeReminderRepository();
    shoppingRepository = FakeShoppingRepository();
    expenseRepository = FakeExpenseRepository();
    scheduler = FakeNotificationScheduler();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repository),
        taskRepositoryProvider.overrideWithValue(taskRepository),
        reminderRepositoryProvider.overrideWithValue(reminderRepository),
        shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  ChatController controller() =>
      container.read(chatControllerProvider.notifier);

  test('send menyimpan pesan user dengan teks yang sudah dipotong', () async {
    await controller().send('  besok jam 8 bayar listrik  ');

    expect(repository.saved, hasLength(2));
    final saved = repository.saved.first;
    expect(saved.role, ChatRole.user);
    expect(saved.content, 'besok jam 8 bayar listrik');
    expect(saved.intent, 'create_reminder');
    expect(saved.payload, isNotNull);
    expect(container.read(chatControllerProvider).isLoading, isFalse);
    expect(container.read(chatControllerProvider).hasError, isFalse);
  });

  test('send teks kosong atau hanya spasi tidak menyimpan apa pun', () async {
    await controller().send('');
    await controller().send('   ');

    expect(repository.saved, isEmpty);
  });

  test(
    'send saat penyimpanan gagal melempar error dan state menjadi error',
    () async {
      repository.failSave = true;

      await expectLater(
        controller().send('besok bayar listrik'),
        throwsA(isA<StateError>()),
      );

      expect(container.read(chatControllerProvider).hasError, isTrue);
    },
  );

  test('setelah gagal, percobaan berikutnya bisa berhasil', () async {
    repository.failSave = true;
    await expectLater(
      controller().send('percobaan pertama'),
      throwsA(isA<StateError>()),
    );

    repository.failSave = false;
    await controller().send('percobaan kedua');

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.content, 'percobaan kedua');
    expect(container.read(chatControllerProvider).hasError, isFalse);
  });

  test('send kalimat todo membuat tugas dan balasan asisten', () async {
    await controller().send('besok selesaikan laporan kapal');

    expect(taskRepository.tasks, hasLength(1));
    final task = taskRepository.tasks.single;
    expect(task.title, 'Selesaikan laporan kapal');
    expect(task.dueDate, '2026-10-06');
    expect(task.priority, TaskPriority.normal);
    expect(task.source, 'rule');
    expect(task.rawInput, 'besok selesaikan laporan kapal');
    expect(task.confidence, 0.9);

    expect(repository.saved, hasLength(2));
    final reply = repository.saved.last;
    expect(reply.role, ChatRole.assistant);
    expect(
      reply.content,
      'Todo dibuat: Selesaikan laporan kapal · 6 Oktober 2026',
    );
  });

  test('send kalimat reminder membuat reminder, jadwal, dan balasan', () async {
    await controller().send('besok jam 8 bayar listrik');

    expect(reminderRepository.reminders, hasLength(1));
    final reminder = reminderRepository.reminders.single;
    expect(reminder.title, 'Bayar listrik');
    expect(reminder.date, '2026-10-06');
    expect(reminder.time, '08:00');
    expect(
      reminder.scheduledAt,
      reminderToEpochUtc(reminderLocalDateTime('2026-10-06', '08:00')),
    );
    expect(reminder.source, 'rule');
    expect(reminder.rawInput, 'besok jam 8 bayar listrik');
    expect(scheduler.scheduled[reminder.id], DateTime(2026, 10, 6, 8));

    expect(repository.saved, hasLength(2));
    final reply = repository.saved.last;
    expect(reply.role, ChatRole.assistant);
    expect(
      reply.content,
      'Reminder dijadwalkan: Bayar listrik · 6 Oktober 2026 jam 08:00',
    );
  });

  test('send pesan reminder tidak membuat tugas', () async {
    await controller().send('besok bayar listrik');

    expect(taskRepository.tasks, isEmpty);
    expect(reminderRepository.reminders, isEmpty);
    expect(shoppingRepository.lists, isEmpty);
    expect(expenseRepository.expenses, isEmpty);
    expect(repository.saved, hasLength(1));
  });

  test('send kalimat belanja menambah item dan balasan', () async {
    await controller().send('besok beli beras minyak telur');

    final list = shoppingRepository.lists.single;
    expect(list.title, 'Belanja');
    expect(list.items.map((i) => i.name), ['Beras', 'Minyak', 'Telur']);

    expect(repository.saved, hasLength(2));
    final reply = repository.saved.last;
    expect(reply.role, ChatRole.assistant);
    expect(reply.content, 'Belanja dicatat: Beras, Minyak, Telur');
  });

  test('send kalimat pengeluaran menambah expense dan balasan', () async {
    await controller().send('tadi makan ayam 25 ribu');

    final expense = expenseRepository.expenses.single;
    expect(expense.amount, 25000);
    expect(expense.category, ExpenseCategory.makanan);
    expect(expense.description, 'Ayam');
    expect(expense.date, '2026-10-05', reason: 'tadi = hari ini');
    expect(expense.source, 'rule');
    expect(expense.rawInput, 'tadi makan ayam 25 ribu');
    expect(expense.confidence, 0.95);

    expect(repository.saved, hasLength(2));
    final reply = repository.saved.last;
    expect(reply.role, ChatRole.assistant);
    expect(reply.content, 'Pengeluaran dicatat: Rp 25.000 · Makanan · Ayam');
  });

  test('send teks tidak dikenal tidak membuat tugas', () async {
    await controller().send('qwerty asdf');

    expect(taskRepository.tasks, isEmpty);
    final saved = repository.saved.single;
    expect(saved.intent, 'unknown');
  });
}

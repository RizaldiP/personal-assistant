import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/ai/local_ai_engine.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/intents/last_item_context.dart';
import 'package:personal_offline/core/services/notification_scheduler.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/domain/entities/chat_message.dart';
import 'package:personal_offline/features/chat/presentation/providers/chat_controller.dart';
import 'package:personal_offline/features/chat/presentation/providers/pending_confirmation.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/ideas/data/repositories/idea_repository_impl.dart';
import 'package:personal_offline/features/ideas/domain/entities/idea.dart';
import 'package:personal_offline/features/inbox/data/repositories/inbox_repository_impl.dart';
import 'package:personal_offline/features/inbox/domain/entities/inbox_item.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/reminder/domain/reminder_schedule.dart';
import 'package:personal_offline/features/search/data/repositories/search_repository_impl.dart';
import 'package:personal_offline/features/search/domain/search_result.dart';
import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';
import 'package:personal_offline/shared/intents/ai_intent_result.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

import '../../../helpers/fake_chat_repository.dart';
import '../../../helpers/fake_expense_repository.dart';
import '../../../helpers/fake_idea_repository.dart';
import '../../../helpers/fake_inbox_repository.dart';
import '../../../helpers/fake_journal_repository.dart';
import '../../../helpers/fake_local_ai.dart';
import '../../../helpers/fake_note_repository.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_reminder_repository.dart';
import '../../../helpers/fake_search_repository.dart';
import '../../../helpers/fake_shopping_repository.dart';
import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeChatRepository repository;
  late FakeTaskRepository taskRepository;
  late FakeReminderRepository reminderRepository;
  late FakeShoppingRepository shoppingRepository;
  late FakeExpenseRepository expenseRepository;
  late FakeNoteRepository noteRepository;
  late FakeJournalRepository journalRepository;
  late FakeIdeaRepository ideaRepository;
  late FakeInboxRepository inboxRepository;
  late FakeSearchRepository searchRepository;
  late FakeNotificationScheduler scheduler;
  late FixedClock clock;
  late FakeLocalAiEngine engine;
  late db.AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    repository = FakeChatRepository();
    taskRepository = FakeTaskRepository();
    reminderRepository = FakeReminderRepository();
    shoppingRepository = FakeShoppingRepository();
    expenseRepository = FakeExpenseRepository();
    noteRepository = FakeNoteRepository();
    journalRepository = FakeJournalRepository();
    ideaRepository = FakeIdeaRepository();
    inboxRepository = FakeInboxRepository();
    searchRepository = FakeSearchRepository();
    scheduler = FakeNotificationScheduler();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    engine = FakeLocalAiEngine();
    database = db.AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        chatRepositoryProvider.overrideWithValue(repository),
        localAiRuntimeProvider.overrideWithValue(
          buildFakeRuntime(engine: engine),
        ),
        taskRepositoryProvider.overrideWithValue(taskRepository),
        reminderRepositoryProvider.overrideWithValue(reminderRepository),
        shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
        noteRepositoryProvider.overrideWithValue(noteRepository),
        journalRepositoryProvider.overrideWithValue(journalRepository),
        ideaRepositoryProvider.overrideWithValue(ideaRepository),
        inboxRepositoryProvider.overrideWithValue(inboxRepository),
        searchRepositoryProvider.overrideWithValue(searchRepository),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
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

    expect(repository.saved, hasLength(2));
    expect(repository.saved.first.content, 'percobaan kedua');
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
    expect(repository.saved, hasLength(2));
    expect(repository.saved.first.role, ChatRole.user);
    expect(repository.saved.last.role, ChatRole.assistant);
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

  test('send teks tidak dikenal membalas tanpa menyimpan data', () async {
    await controller().send('qwerty asdf');

    expect(taskRepository.tasks, isEmpty);
    expect(noteRepository.notes, isEmpty);
    expect(repository.saved, hasLength(2));

    final userMessage = repository.saved.first;
    expect(userMessage.role, ChatRole.user);
    expect(userMessage.intent, 'unknown');
    expect(userMessage.status, ChatStatus.sent);

    final reply = repository.saved.last;
    expect(reply.role, ChatRole.assistant);
    expect(reply.content, contains('belum bisa memahami'));
  });

  test('send kalimat catatan membuat note dan balasan', () async {
    await controller().send('catatan: nomor sparepart 12345');

    final note = noteRepository.notes.single;
    expect(note.content, 'Nomor sparepart 12345');
    expect(note.source, 'rule');
    expect(note.rawInput, 'catatan: nomor sparepart 12345');
    expect(note.confidence, 0.8);

    expect(repository.saved, hasLength(2));
    final reply = repository.saved.last;
    expect(reply.role, ChatRole.assistant);
    expect(reply.content, 'Catatan disimpan: Nomor sparepart 12345');
    expect(repository.saved.first.intent, 'create_note');
  });

  test('send kalimat jurnal membuat entri hari ini dan balasan', () async {
    await controller().send('hari ini capek banget');

    final entry = journalRepository.entries.single;
    expect(entry.content, 'Capek banget');
    expect(entry.mood, 'capek');
    expect(entry.date, '2026-10-05');
    expect(entry.source, 'rule');
    expect(entry.rawInput, 'hari ini capek banget');

    expect(repository.saved, hasLength(2));
    expect(repository.saved.last.content, 'Jurnal ditulis: Capek banget');
    expect(repository.saved.first.intent, 'create_journal');
  });

  test('send kalimat ide membuat idea dan balasan', () async {
    await controller().send('ide: aplikasi inventory kapal');

    final idea = ideaRepository.ideas.single;
    expect(idea.title, 'Aplikasi inventory kapal');
    expect(idea.status, IdeaStatus.inbox);
    expect(idea.source, 'rule');
    expect(idea.rawInput, 'ide: aplikasi inventory kapal');

    expect(repository.saved, hasLength(2));
    expect(
      repository.saved.last.content,
      'Ide disimpan: Aplikasi inventory kapal',
    );
    expect(repository.saved.first.intent, 'create_idea');
  });

  group('routing AI + konfirmasi (PHASE 11)', () {
    const aiText = 'laporan kapal harus selesai minggu depan';

    PendingConfirmation? pending() =>
        container.read(pendingConfirmationProvider);

    AiIntentResult aiTodo({double confidence = 0.9}) => AiIntentResult(
      intent: AppIntent.createTodo,
      confidence: confidence,
      entities: const {'title': 'Kirim laporan', 'due_date': '2026-10-10'},
    );

    test('Rule Parser dikenal tetap dieksekusi tanpa memanggil AI', () async {
      engine.ready = true;
      engine.understandResult = aiTodo();

      await controller().send('besok jam 8 bayar listrik');

      expect(engine.understandCalls, 0);
      expect(reminderRepository.reminders, hasLength(1));
    });

    test(
      'AI yakin → pesan ditandai butuh konfirmasi, data belum tersimpan',
      () async {
        engine.ready = true;
        engine.understandResult = aiTodo();

        await controller().send(aiText);

        expect(engine.understandCalls, 1);
        expect(taskRepository.tasks, isEmpty);
        expect(repository.saved, hasLength(2));

        final userMessage = repository.saved.first;
        expect(userMessage.intent, 'create_todo');
        expect(userMessage.status, ChatStatus.needsConfirmation);

        final reply = repository.saved.last;
        expect(reply.role, ChatRole.assistant);
        expect(
          reply.content,
          startsWith('Aku menangkap: Tugas "Kirim laporan"'),
        );

        expect(pending(), isNotNull);
        expect(pending()!.highConfidence, isTrue);
        expect(pending()!.source, 'ai');
        expect(pending()!.rawText, aiText);
      },
    );

    test(
      'confirm menyimpan entri dengan source ai lalu menyelesaikan pesan',
      () async {
        engine.ready = true;
        engine.understandResult = aiTodo();
        await controller().send(aiText);

        await container.read(pendingConfirmationProvider.notifier).confirm();

        final task = taskRepository.tasks.single;
        expect(task.title, 'Kirim laporan');
        expect(task.source, 'ai');
        expect(task.rawInput, aiText);

        expect(pending(), isNull);
        expect(
          repository.saved.last.content,
          'Todo dibuat: Kirim laporan · 10 Oktober 2026',
        );

        final userMessage = repository.saved.first;
        expect(userMessage.status, ChatStatus.sent);
        expect(userMessage.resolvedAt, isNotNull);
      },
    );

    test('reject tidak menyimpan data apa pun', () async {
      engine.ready = true;
      engine.understandResult = aiTodo();
      await controller().send(aiText);

      await container.read(pendingConfirmationProvider.notifier).reject();

      expect(taskRepository.tasks, isEmpty);
      expect(pending(), isNull);
      expect(repository.saved.last.content, 'Oke, tidak jadi disimpan.');

      final userMessage = repository.saved.first;
      expect(userMessage.status, ChatStatus.sent);
      expect(userMessage.resolvedAt, isNotNull);
    });

    test('edit mengembalikan kalimat user ke draf input', () async {
      engine.ready = true;
      engine.understandResult = aiTodo();
      await controller().send(aiText);

      await container.read(pendingConfirmationProvider.notifier).edit();

      expect(taskRepository.tasks, isEmpty);
      expect(pending(), isNull);
      expect(container.read(chatDraftProvider), aiText);
    });

    test('AI tidak yakin → balasan penjelasan tanpa konfirmasi', () async {
      engine.ready = true;
      engine.understandResult = aiTodo(confidence: 0.4);

      await controller().send(aiText);

      expect(taskRepository.tasks, isEmpty);
      expect(pending(), isNull);
      expect(repository.saved, hasLength(2));
      expect(repository.saved.last.content, contains('belum yakin'));
      expect(repository.saved.first.status, ChatStatus.sent);
    });

    test('AI menolak output berisi kemampuan terlarang', () async {
      engine.ready = true;
      engine.understandResult = const AiIntentResult(
        intent: AppIntent.unknown,
        confidence: 0.9,
        rawJson:
            '{"intent":"execute_shell","confidence":0.9,'
            '"entities":{},"needs_confirmation":false}',
      );

      await controller().send(aiText);

      expect(pending(), isNull);
      expect(repository.saved.last.content, contains('terlarang'));
      expect(taskRepository.tasks, isEmpty);
    });

    test('inference AI gagal → tetap membalas tanpa crash', () async {
      engine.ready = true;
      engine.understandError = const LocalAiInferenceException('rusak');

      await controller().send(aiText);

      expect(pending(), isNull);
      expect(repository.saved, hasLength(2));
      expect(repository.saved.last.content, contains('belum bisa memahami'));
      expect(container.read(chatControllerProvider).hasError, isFalse);
    });

    test('pesan baru menyelesaikan konfirmasi yang masih tertunda', () async {
      engine.ready = true;
      engine.understandResult = aiTodo();
      await controller().send(aiText);
      expect(pending(), isNotNull);

      await controller().send('besok jam 8 bayar listrik');

      expect(pending(), isNull);
      expect(taskRepository.tasks, isEmpty);

      final oldUserMessage = repository.saved.first;
      expect(oldUserMessage.status, ChatStatus.sent);
      expect(oldUserMessage.resolvedAt, isNotNull);
      expect(reminderRepository.reminders, hasLength(1));
    });
  });

  group('perintah lanjutan (PHASE 12)', () {
    test('buat reminder lalu "ubah jadi jam 10" memperbarui jadwal', () async {
      await controller().send('besok jam 8 bayar listrik');
      await controller().send('ubah jadi jam 10');

      final reminder = reminderRepository.reminders.single;
      expect(reminder.time, '10:00');
      expect(reminder.date, '2026-10-06');
      expect(
        reminder.scheduledAt,
        reminderToEpochUtc(reminderLocalDateTime('2026-10-06', '10:00')),
      );
      expect(scheduler.scheduled[reminder.id], DateTime(2026, 10, 6, 10));

      expect(repository.saved, hasLength(4));
      final followUp = repository.saved[2];
      expect(followUp.role, ChatRole.user);
      expect(followUp.content, 'ubah jadi jam 10');
      expect(followUp.intent, 'update_item');
      expect(followUp.status, ChatStatus.sent);
      expect(
        repository.saved.last.content,
        'Reminder diubah: Bayar listrik · 6 Oktober 2026 jam 10:00',
      );
    });

    test('buat todo lalu "jadikan lusa" mengubah tenggat', () async {
      await controller().send('besok selesaikan laporan kapal');
      await controller().send('jadikan lusa');

      final task = taskRepository.tasks.single;
      expect(task.dueDate, '2026-10-07');
      expect(
        repository.saved.last.content,
        'Todo diubah: Selesaikan laporan kapal · 7 Oktober 2026',
      );
    });

    test('"selesaikan" menandai todo terakhir selesai', () async {
      await controller().send('besok selesaikan laporan kapal');
      await controller().send('selesaikan');

      final task = taskRepository.tasks.single;
      expect(task.status, TaskStatus.done);
      expect(task.completedAt, isNotNull);
      expect(
        repository.saved.last.content,
        'Todo diselesaikan: Selesaikan laporan kapal',
      );

      await controller().send('selesaikan');
      expect(repository.saved.last.content, contains('sudah selesai'));
    });

    test('"hapus" minta konfirmasi lalu menghapus reminder', () async {
      await controller().send('besok jam 8 bayar listrik');
      final reminderId = reminderRepository.reminders.single.id;
      await controller().send('hapus');

      expect(reminderRepository.reminders, hasLength(1), reason: 'belum hapus');
      expect(repository.saved.last.content, 'Hapus Bayar listrik?');
      expect(repository.saved[2].intent, 'delete_item');
      expect(repository.saved[2].status, ChatStatus.needsConfirmation);

      final pending = container.read(pendingConfirmationProvider);
      expect(pending, isNotNull);
      expect(pending!.result.intent, AppIntent.deleteItem);
      expect(pending.source, 'rule');

      await container.read(pendingConfirmationProvider.notifier).confirm();

      expect(reminderRepository.reminders, isEmpty);
      expect(scheduler.cancelled, contains(reminderId));
      expect(scheduler.scheduled.containsKey(reminderId), isFalse);
      expect(repository.saved.last.content, 'Reminder dihapus: Bayar listrik');
      expect(
        await container.read(lastItemContextProvider).read(),
        isNull,
        reason: 'konteks dibersihkan setelah hapus',
      );
    });

    test('"hapus" lalu batal tidak menghapus apa pun', () async {
      await controller().send('besok jam 8 bayar listrik');
      await controller().send('hapus');

      await container.read(pendingConfirmationProvider.notifier).reject();

      expect(reminderRepository.reminders, hasLength(1));
      expect(repository.saved.last.content, 'Oke, tidak jadi disimpan.');
      expect(container.read(pendingConfirmationProvider), isNull);
    });

    test('"tunda 2 jam" menunda reminder dari sekarang', () async {
      await controller().send('besok jam 8 bayar listrik');
      await controller().send('tunda 2 jam');

      final reminder = reminderRepository.reminders.single;
      expect(
        reminder.snoozedUntil,
        reminderToEpochUtc(reminderLocalDateTime('2026-10-05', '11:00')),
      );
      expect(
        reminder.nextFireAt,
        reminderToEpochUtc(reminderLocalDateTime('2026-10-05', '11:00')),
      );
      expect(scheduler.scheduled[reminder.id], DateTime(2026, 10, 5, 11));
      expect(
        repository.saved.last.content,
        'Reminder ditunda: Bayar listrik · 5 Oktober 2026 jam 11:00',
      );
    });

    test('"tunda jam 8" yang sudah lewat bergeser ke besok', () async {
      await controller().send('hari ini jam 8 bayar listrik');
      await controller().send('tunda jam 8');

      final reminder = reminderRepository.reminders.single;
      expect(reminder.snoozedUntil, isNotNull);
      expect(
        repository.saved.last.content,
        'Reminder ditunda: Bayar listrik · 6 Oktober 2026 jam 08:00',
      );
    });

    test(
      '"tunda" tanpa durasi menawarkan contoh, tanpa mengubah data',
      () async {
        await controller().send('besok jam 8 bayar listrik');
        await controller().send('tunda');

        final reminder = reminderRepository.reminders.single;
        expect(reminder.snoozedUntil, isNull);
        expect(reminder.time, '08:00');
        expect(repository.saved.last.content, contains('tunda 1 jam'));
      },
    );

    test('perintah lanjutan sebelum ada item → penjelasan, tanpa AI', () async {
      engine.ready = true;

      await controller().send('hapus');

      expect(engine.understandCalls, 0);
      expect(repository.saved, hasLength(2));
      expect(repository.saved.first.role, ChatRole.user);
      expect(repository.saved.first.intent, 'delete_item');
      expect(repository.saved.first.status, ChatStatus.sent);
      expect(repository.saved.last.content, contains('Belum ada item'));
      expect(container.read(pendingConfirmationProvider), isNull);
      expect(taskRepository.tasks, isEmpty);
      expect(reminderRepository.reminders, isEmpty);
    });

    test('konteks pindah ke item terbaru yang dibuat', () async {
      await controller().send('besok jam 8 bayar listrik');
      await controller().send('catatan: nomor sparepart 12345');
      await controller().send('hapus');

      expect(noteRepository.notes, hasLength(1), reason: 'tidak dihapus');
      expect(
        reminderRepository.reminders,
        hasLength(1),
        reason: 'tidak dihapus',
      );
      expect(repository.saved.last.content, contains('todo dan reminder'));
      expect(repository.saved.last.content, contains('Nomor sparepart 12345'));
      expect(container.read(pendingConfirmationProvider), isNull);
    });

    test('konteks item terakhir bertahan lewat preferensi', () async {
      await controller().send('besok jam 8 bayar listrik');

      final context = await container.read(lastItemContextProvider).read();

      expect(context, isNotNull);
      expect(context!.type, 'reminder');
      expect(context.id, reminderRepository.reminders.single.id);
      expect(context.label, 'Bayar listrik');
      expect(context.date, '2026-10-06');
      expect(context.time, '08:00');
    });
  });

  group('Smart Inbox (PHASE 13)', () {
    const aiText = 'laporan kapal harus selesai minggu depan';

    AiIntentResult aiTodo({double confidence = 0.9}) => AiIntentResult(
      intent: AppIntent.createTodo,
      confidence: confidence,
      entities: const {'title': 'Kirim laporan', 'due_date': '2026-10-10'},
    );

    test('AI tidak yakin → masuk inbox dengan saran intent', () async {
      engine.ready = true;
      engine.understandResult = aiTodo(confidence: 0.4);

      await controller().send(aiText);

      expect(inboxRepository.items, hasLength(1));
      final item = inboxRepository.items.single;
      expect(item.rawText, aiText);
      expect(item.suggestion, 'create_todo');
      expect(item.resolution, InboxResolution.open);
      expect(item.chatMessageId, isNotNull);
      expect(taskRepository.tasks, isEmpty, reason: 'tidak ada data tersimpan');
    });

    test('AI tidak tersedia → masuk inbox tanpa saran', () async {
      engine.ready = false;

      await controller().send('hm kayaknya begini deh');

      final item = inboxRepository.items.single;
      expect(item.suggestion, isNull);
      expect(item.resolution, InboxResolution.open);
      expect(repository.saved.last.content, contains('belum bisa memahami'));
    });

    test('output AI ditolak validator → masuk inbox tanpa saran', () async {
      engine.ready = true;
      engine.understandResult = const AiIntentResult(
        intent: AppIntent.unknown,
        confidence: 0.9,
        rawJson:
            '{"intent":"execute_shell","confidence":0.9,'
            '"entities":{},"needs_confirmation":false}',
      );

      await controller().send(aiText);

      final item = inboxRepository.items.single;
      expect(item.suggestion, isNull);
      expect(item.resolution, InboxResolution.open);
      expect(repository.saved.last.content, contains('terlarang'));
    });

    test('kegagalan menulis inbox tidak menggagalkan balasan chat', () async {
      inboxRepository.failAdd = true;
      engine.ready = true;
      engine.understandResult = aiTodo(confidence: 0.4);

      await controller().send(aiText);

      expect(inboxRepository.items, isEmpty);
      expect(repository.saved, hasLength(2));
      expect(container.read(chatControllerProvider).hasError, isFalse);
    });

    test('perintah rule yang dieksekusi menandai teks sama di inbox', () async {
      final id = await inboxRepository.addOpen(
        rawText: 'besok jam 8 bayar listrik',
      );

      await controller().send('besok jam 8 bayar listrik');

      final item = (await inboxRepository.getById(id))!;
      expect(item.resolution, InboxResolution.converted);
      expect(item.resolvedEntityType, 'reminder');
      expect(reminderRepository.reminders, hasLength(1));
    });

    test('teks yang beda tidak ikut ditandai selesai', () async {
      final id = await inboxRepository.addOpen(rawText: 'hal lain sama sekali');

      await controller().send('besok jam 8 bayar listrik');

      final item = (await inboxRepository.getById(id))!;
      expect(item.resolution, InboxResolution.open);
    });

    test('konfirmasi AI menyelesaikan item inbox dengan teks sama', () async {
      final id = await inboxRepository.addOpen(rawText: aiText);
      engine.ready = true;
      engine.understandResult = aiTodo();

      await controller().send(aiText);
      expect(
        (await inboxRepository.getById(id))!.resolution,
        InboxResolution.open,
        reason: 'belum dikonfirmasi',
      );

      await container.read(pendingConfirmationProvider.notifier).confirm();

      final item = (await inboxRepository.getById(id))!;
      expect(item.resolution, InboxResolution.converted);
      expect(item.resolvedEntityType, 'todo');
      expect(taskRepository.tasks, hasLength(1));
    });

    test('konfirmasi intent tanpa entitas tidak menyentuh inbox', () async {
      final id = await inboxRepository.addOpen(rawText: aiText);
      engine.ready = true;
      engine.understandResult = const AiIntentResult(
        intent: AppIntent.search,
        confidence: 0.9,
        entities: {'query': 'laporan'},
      );

      await controller().send(aiText);
      await container.read(pendingConfirmationProvider.notifier).confirm();

      final item = (await inboxRepository.getById(id))!;
      expect(item.resolution, InboxResolution.open);
    });
  });

  group('Intent cari (PHASE 13)', () {
    AiIntentResult aiSearch(String query) => AiIntentResult(
      intent: AppIntent.search,
      confidence: 0.9,
      entities: {'query': query},
    );

    test('konfirmasi search membalas cuplikan hasil teratas', () async {
      searchRepository.results = [
        const SearchResult(
          type: SearchTypes.note,
          id: 1,
          title: 'Catatan liburan Bali',
        ),
        const SearchResult(
          type: SearchTypes.journal,
          id: 2,
          title: 'Jurnal liburan Bali',
        ),
        const SearchResult(
          type: SearchTypes.idea,
          id: 3,
          title: 'Ide perjalanan Bali',
        ),
        const SearchResult(
          type: SearchTypes.note,
          id: 4,
          title: 'Catatan pantai Sanur',
        ),
      ];
      engine.ready = true;
      engine.understandResult = aiSearch('bali');

      await controller().send('cari bali');
      await container.read(pendingConfirmationProvider.notifier).confirm();

      expect(searchRepository.searchCalls, 1);
      expect(searchRepository.lastQuery, 'bali');
      expect(searchRepository.lastLimitPerType, 5);
      final reply = repository.saved.last.content;
      expect(reply, contains('Menemukan 4 hasil untuk "bali"'));
      expect(reply, contains('Catatan liburan Bali'));
      expect(reply, contains('Ide perjalanan Bali'));
      expect(
        reply,
        isNot(contains('Catatan pantai Sanur')),
        reason: 'hanya tiga teratas',
      );
    });

    test('search tanpa hasil menawarkan contoh kata kunci', () async {
      searchRepository.results = [];
      engine.ready = true;
      engine.understandResult = aiSearch('zzz');

      await controller().send('cari zzz');
      await container.read(pendingConfirmationProvider.notifier).confirm();

      expect(
        repository.saved.last.content,
        contains('Tidak ada hasil untuk "zzz"'),
      );
    });

    test('search tidak mengubah data dan tidak masuk inbox', () async {
      engine.ready = true;
      engine.understandResult = aiSearch('laporan');

      await controller().send('cari laporan');

      expect(inboxRepository.items, isEmpty);
      expect(taskRepository.tasks, isEmpty);
      expect(reminderRepository.reminders, isEmpty);
      expect(noteRepository.notes, isEmpty);
      expect(container.read(pendingConfirmationProvider), isNotNull);
    });
  });
}

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('TaskDao', () {
    test('create lalu getById mengembalikan data yang sama', () async {
      final id = await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Beli beras',
          description: const Value('2 kg'),
          dueDate: const Value('2026-10-05'),
          dueTime: const Value('18:00'),
          priority: const Value('high'),
          category: const Value('belanja'),
          createdAt: 1728000000000,
          updatedAt: 1728000000000,
        ),
      );

      final row = await db.taskDao.getById(id);

      expect(row, isNotNull);
      expect(row!.title, 'Beli beras');
      expect(row.description, '2 kg');
      expect(row.dueDate, '2026-10-05');
      expect(row.dueTime, '18:00');
      expect(row.priority, 'high');
      expect(row.category, 'belanja');
      expect(row.status, 'pending');
      expect(row.source, isNull);
      expect(row.confidence, isNull);
      expect(row.createdAt, 1728000000000);
    });

    test('update hanya mengubah kolom yang diberikan', () async {
      final id = await db.taskDao.insertTask(
        TasksCompanion.insert(title: 'Lama', createdAt: 1, updatedAt: 1),
      );

      final changed = await db.taskDao.updateTask(
        id,
        TasksCompanion(
          status: const Value('done'),
          completedAt: const Value(2000),
          updatedAt: const Value(3000),
        ),
      );

      expect(changed, isTrue);
      final row = await db.taskDao.getById(id);
      expect(row!.status, 'done');
      expect(row.completedAt, 2000);
      expect(row.updatedAt, 3000);
      expect(row.title, 'Lama');
      expect(row.createdAt, 1);
    });

    test(
      'delete menghapus baris dan id yang sama mengembalikan false',
      () async {
        final id = await db.taskDao.insertTask(
          TasksCompanion.insert(title: 'Hapus', createdAt: 1, updatedAt: 1),
        );

        expect(await db.taskDao.deleteTask(id), isTrue);
        expect(await db.taskDao.getById(id), isNull);
        expect(await db.taskDao.deleteTask(id), isFalse);
      },
    );

    test('search cocok pada title maupun description', () async {
      await db.taskDao.insertTask(
        TasksCompanion.insert(title: 'Beli beras', createdAt: 1, updatedAt: 1),
      );
      await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Buat kue',
          description: const Value('beli santan'),
          createdAt: 2,
          updatedAt: 2,
        ),
      );
      await db.taskDao.insertTask(
        TasksCompanion.insert(title: 'Diskon 100%', createdAt: 3, updatedAt: 3),
      );

      expect((await db.taskDao.search('beras')).single.title, 'Beli beras');
      expect((await db.taskDao.search('santan')).single.title, 'Buat kue');
      expect((await db.taskDao.search('100%')).single.title, 'Diskon 100%');
      expect(await db.taskDao.search('tidak-ada'), isEmpty);
    });

    test('watchPendingOn hanya tugas pending pada tanggal tersebut', () async {
      await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Sore',
          dueDate: const Value('2026-10-05'),
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Selesai',
          dueDate: const Value('2026-10-05'),
          status: const Value('done'),
          createdAt: 2,
          updatedAt: 2,
        ),
      );
      await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Besok',
          dueDate: const Value('2026-10-06'),
          createdAt: 3,
          updatedAt: 3,
        ),
      );

      final rows = await db.taskDao.watchPendingOn('2026-10-05').first;

      expect(rows, hasLength(1));
      expect(rows.single.title, 'Sore');
    });
  });

  group('ReminderDao', () {
    test('create lalu getById memakai nilai default', () async {
      final id = await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Minum obat',
          date: '2026-10-05',
          time: '18:00',
          scheduledAt: 1728000000000,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      final row = await db.reminderDao.getById(id);

      expect(row, isNotNull);
      expect(row!.title, 'Minum obat');
      expect(row.priority, 'normal');
      expect(row.status, 'active');
      expect(row.isRecurring, isFalse);
      expect(row.recurrenceRule, 'none');
      expect(row.source, isNull);
    });

    test('update, delete', () async {
      final id = await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Rapat',
          date: '2026-10-05',
          time: '09:00',
          scheduledAt: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      expect(
        await db.reminderDao.updateReminder(
          id,
          RemindersCompanion(
            status: const Value('completed'),
            completedAt: const Value(400),
            updatedAt: const Value(500),
          ),
        ),
        isTrue,
      );
      final row = await db.reminderDao.getById(id);
      expect(row!.status, 'completed');
      expect(row.completedAt, 400);
      expect(row.updatedAt, 500);
      expect(row.title, 'Rapat');

      expect(await db.reminderDao.deleteReminder(id), isTrue);
      expect(await db.reminderDao.getById(id), isNull);
    });

    test(
      'watchActive mengabaikan status selain active dan urut scheduledAt',
      () async {
        await db.reminderDao.insertReminder(
          RemindersCompanion.insert(
            title: 'Nanti',
            date: '2026-10-05',
            time: '20:00',
            scheduledAt: 300,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        await db.reminderDao.insertReminder(
          RemindersCompanion.insert(
            title: 'Tadi',
            date: '2026-10-05',
            time: '08:00',
            scheduledAt: 100,
            createdAt: 2,
            updatedAt: 2,
          ),
        );
        await db.reminderDao.insertReminder(
          RemindersCompanion.insert(
            title: 'Sudah selesai',
            date: '2026-10-05',
            time: '07:00',
            scheduledAt: 50,
            status: const Value('completed'),
            createdAt: 3,
            updatedAt: 3,
          ),
        );

        final active = await db.reminderDao.watchActive().first;

        expect(active.map((r) => r.title), ['Tadi', 'Nanti']);
      },
    );

    test('dueAt mengembalikan reminder aktif yang jatuh tempo', () async {
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Lewat',
          date: '2026-10-01',
          time: '08:00',
          scheduledAt: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Belum',
          date: '2026-10-05',
          time: '20:00',
          scheduledAt: 900,
          createdAt: 2,
          updatedAt: 2,
        ),
      );
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Lewat tapi selesai',
          date: '2026-10-01',
          time: '08:00',
          scheduledAt: 100,
          status: const Value('completed'),
          createdAt: 3,
          updatedAt: 3,
        ),
      );
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Dijadwalkan ulang',
          date: '2026-10-05',
          time: '18:00',
          scheduledAt: 900,
          nextFireAt: const Value(200),
          createdAt: 4,
          updatedAt: 4,
        ),
      );
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Ditunda',
          date: '2026-10-01',
          time: '09:00',
          scheduledAt: 100,
          nextFireAt: const Value(800),
          createdAt: 5,
          updatedAt: 5,
        ),
      );

      final due = await db.reminderDao.dueAt(500);

      expect(
        due.map((r) => r.title),
        ['Lewat', 'Dijadwalkan ulang'],
        reason: 'pakai next_fire_at bila ada, selain itu scheduled_at',
      );
    });

    test('search cocok pada title maupun notes', () async {
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Beli obat',
          notes: const Value('di apotek'),
          date: '2026-10-05',
          time: '18:00',
          scheduledAt: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await db.reminderDao.insertReminder(
        RemindersCompanion.insert(
          title: 'Rapat',
          notes: const Value('ruang obat'),
          date: '2026-10-06',
          time: '09:00',
          scheduledAt: 2,
          createdAt: 2,
          updatedAt: 2,
        ),
      );

      expect(
        (await db.reminderDao.search('obat')).map((r) => r.title),
        containsAll(['Beli obat', 'Rapat']),
      );
      expect(await db.reminderDao.search('kantor'), isEmpty);
    });
  });

  group('ChatMessageDao', () {
    test('create lalu getById memakai status default sent', () async {
      final id = await db.chatMessageDao.insertMessage(
        ChatMessagesCompanion.insert(
          role: 'user',
          content: 'buat tugas besok',
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      final row = await db.chatMessageDao.getById(id);

      expect(row, isNotNull);
      expect(row!.role, 'user');
      expect(row.content, 'buat tugas besok');
      expect(row.status, 'sent');
      expect(row.intent, isNull);
      expect(row.resolvedAt, isNull);
    });

    test('getLatest mengembalikan pesan dengan createdAt terbesar', () async {
      await db.chatMessageDao.insertMessage(
        ChatMessagesCompanion.insert(
          role: 'assistant',
          content: 'lama',
          createdAt: 10,
          updatedAt: 10,
        ),
      );
      await db.chatMessageDao.insertMessage(
        ChatMessagesCompanion.insert(
          role: 'user',
          content: 'baru',
          createdAt: 20,
          updatedAt: 20,
        ),
      );

      final latest = await db.chatMessageDao.getLatest();

      expect(latest!.content, 'baru');
      expect(await db.chatMessageDao.watchAll().first, hasLength(2));
    });

    test('update dan delete', () async {
      final id = await db.chatMessageDao.insertMessage(
        ChatMessagesCompanion.insert(
          role: 'user',
          content: 'awal',
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      expect(
        await db.chatMessageDao.updateMessage(
          id,
          ChatMessagesCompanion(
            status: const Value('failed'),
            updatedAt: const Value(5),
          ),
        ),
        isTrue,
      );
      final row = await db.chatMessageDao.getById(id);
      expect(row!.status, 'failed');
      expect(row.content, 'awal');

      expect(await db.chatMessageDao.deleteMessage(id), isTrue);
      expect(await db.chatMessageDao.getById(id), isNull);
      expect(await db.chatMessageDao.deleteMessage(id), isFalse);
    });

    test('getLatest pada database kosong mengembalikan null', () async {
      expect(await db.chatMessageDao.getLatest(), isNull);
    });
  });

  group('UserPreferencesDao', () {
    test('set lalu get, nilai kedua menimpa nilai pertama', () async {
      await db.userPreferencesDao.set('theme', 'dark', nowEpochMs: 1);
      expect(await db.userPreferencesDao.get('theme'), 'dark');

      await db.userPreferencesDao.set('theme', 'light', nowEpochMs: 2);
      expect(await db.userPreferencesDao.get('theme'), 'light');

      final rows = await db.userPreferencesDao.watchAll().first;
      expect(rows, hasLength(1), reason: 'unique index mencegah duplikat');
      expect(rows.single.updatedAt, 2);

      expect(await db.userPreferencesDao.get('missing'), isNull);
    });

    test('remove mengembalikan true hanya ketika key ada', () async {
      await db.userPreferencesDao.set('locale', 'id', nowEpochMs: 1);

      expect(await db.userPreferencesDao.remove('locale'), isTrue);
      expect(await db.userPreferencesDao.remove('locale'), isFalse);
      expect(await db.userPreferencesDao.get('locale'), isNull);
    });

    test('watchAll terurut berdasarkan key', () async {
      await db.userPreferencesDao.set('z', '1', nowEpochMs: 1);
      await db.userPreferencesDao.set('a', '2', nowEpochMs: 2);

      final rows = await db.userPreferencesDao.watchAll().first;

      expect(rows.map((r) => r.key), ['a', 'z']);
    });
  });
}

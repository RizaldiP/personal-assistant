import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/reminder/domain/entities/reminder.dart';
import 'package:personal_offline/features/reminder/domain/repositories/reminder_repository.dart';

void main() {
  late db.AppDatabase database;
  late ReminderRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = ReminderRepositoryImpl(database.reminderDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('create memakai nilai default dan timestamp clock', () async {
    final id = await repository.create(
      Reminder(
        title: 'Minum obat',
        date: '2026-10-05',
        time: '18:00',
        scheduledAt: 1791000000000,
      ),
    );

    final reminder = await repository.getById(id);

    expect(reminder, isNotNull);
    expect(reminder!.status, ReminderStatus.active);
    expect(reminder.priority, 'normal');
    expect(reminder.isRecurring, isFalse);
    expect(reminder.recurrenceRule, 'none');
    expect(reminder.createdAt, start.toUtc().millisecondsSinceEpoch);
  });

  test('update mengubah status dan updatedAt', () async {
    final id = await repository.create(
      Reminder(
        title: 'Rapat',
        date: '2026-10-05',
        time: '09:00',
        scheduledAt: 100,
      ),
    );
    final created = await repository.getById(id);

    clock.value = start.add(const Duration(minutes: 5));
    await repository.update(
      created!.copyWith(status: ReminderStatus.completed, completedAt: 900),
    );

    final updated = await repository.getById(id);
    expect(updated!.status, ReminderStatus.completed);
    expect(updated.completedAt, 900);
    expect(updated.createdAt, created.createdAt);
    expect(
      updated.updatedAt,
      start.add(const Duration(minutes: 5)).toUtc().millisecondsSinceEpoch,
    );
  });

  test('update tanpa id mengembalikan false', () async {
    expect(
      await repository.update(
        Reminder(
          title: 'tanpa id',
          date: '2026-10-05',
          time: '09:00',
          scheduledAt: 1,
        ),
      ),
      isFalse,
    );
  });

  test('delete mengembalikan true dan menghapus data', () async {
    final id = await repository.create(
      Reminder(
        title: 'Hapus',
        date: '2026-10-05',
        time: '09:00',
        scheduledAt: 1,
      ),
    );

    expect(await repository.delete(id), isTrue);
    expect(await repository.getById(id), isNull);
    expect(await repository.delete(id), isFalse);
  });

  test('watchActive dan dueAt', () async {
    await repository.create(
      Reminder(
        title: 'Lewat',
        date: '2026-10-01',
        time: '08:00',
        scheduledAt: 100,
      ),
    );
    await repository.create(
      Reminder(
        title: 'Belum',
        date: '2026-10-05',
        time: '20:00',
        scheduledAt: 900,
      ),
    );
    await repository.create(
      Reminder(
        title: 'Selesai',
        date: '2026-10-01',
        time: '07:00',
        scheduledAt: 50,
        status: ReminderStatus.completed,
      ),
    );

    expect((await repository.watchActive().first).map((r) => r.title), [
      'Lewat',
      'Belum',
    ]);

    final due = await repository.dueAt(
      DateTime.fromMillisecondsSinceEpoch(500, isUtc: true),
    );
    expect(due.single.title, 'Lewat');
  });

  test('getAll dan search', () async {
    await repository.create(
      Reminder(
        title: 'Beli obat',
        notes: 'di apotek',
        date: '2026-10-05',
        time: '18:00',
        scheduledAt: 1,
      ),
    );
    await repository.create(
      Reminder(
        title: 'Rapat',
        date: '2026-10-06',
        time: '09:00',
        scheduledAt: 2,
      ),
    );

    expect(await repository.getAll(), hasLength(2));
    expect((await repository.search('apotek')).single.title, 'Beli obat');
  });
}

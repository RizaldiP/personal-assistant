import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';
import 'package:personal_offline/features/todo/domain/repositories/task_repository.dart';

void main() {
  late db.AppDatabase database;
  late TaskRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = TaskRepositoryImpl(database.taskDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('create mengisi createdAt dan updatedAt dari clock', () async {
    final id = await repository.create(
      const Task(title: 'Belajar Flutter', dueDate: '2026-10-05'),
    );

    final task = await repository.getById(id);

    expect(task, isNotNull);
    expect(task!.title, 'Belajar Flutter');
    expect(task.status, TaskStatus.pending);
    expect(task.priority, TaskPriority.normal);
    expect(task.createdAt, start.toUtc());
    expect(task.updatedAt, start.toUtc());
  });

  test('update mengubah updatedAt tetapi mempertahankan createdAt', () async {
    final id = await repository.create(const Task(title: 'Awal'));
    final created = await repository.getById(id);

    clock.value = start.add(const Duration(hours: 2));
    await repository.update(created!.copyWith(title: 'Baru'));

    final updated = await repository.getById(id);
    expect(updated!.title, 'Baru');
    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt, start.add(const Duration(hours: 2)));
  });

  test('update pada entitas tanpa id mengembalikan false', () async {
    expect(await repository.update(const Task(title: 'tanpa id')), isFalse);
  });

  test('delete mengembalikan true dan menghapus data', () async {
    final id = await repository.create(const Task(title: 'Hapus'));

    expect(await repository.delete(id), isTrue);
    expect(await repository.getById(id), isNull);
    expect(await repository.delete(id), isFalse);
  });

  test('getAll dan search', () async {
    await repository.create(const Task(title: 'Beli beras'));
    await repository.create(
      const Task(title: 'Buat kue', description: 'beli santan'),
    );

    expect(await repository.getAll(), hasLength(2));
    expect((await repository.search('santan')).single.title, 'Buat kue');
  });

  test(
    'watchTasksOn hanya menampilkan tugas pending pada tanggal itu',
    () async {
      await repository.create(const Task(title: 'Sore', dueDate: '2026-10-05'));
      await repository.create(
        const Task(
          title: 'Besok',
          dueDate: '2026-10-06',
          status: TaskStatus.done,
        ),
      );

      final rows = await repository.watchTasksOn('2026-10-05').first;

      expect(rows.single.title, 'Sore');
    },
  );

  test('watchTasksForWidgetOn mengembalikan pending lalu selesai hari itu', () async {
    await repository.create(
      const Task(
        id: null,
        title: 'Selesai pagi',
        dueDate: '2026-10-05',
        dueTime: '07:00',
        status: TaskStatus.done,
      ),
    );
    await repository.create(
      const Task(title: 'Pending siang', dueDate: '2026-10-05', dueTime: '12:00'),
    );
    await repository.create(
      const Task(title: 'Besok', dueDate: '2026-10-06'),
    );

    final rows = await repository.watchTasksForWidgetOn('2026-10-05').first;

    expect(rows.map((task) => task.title), ['Pending siang', 'Selesai pagi']);
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';
import 'package:personal_offline/features/todo/presentation/providers/task_controller.dart';

import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repository;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeTaskRepository();
    clock = FixedClock(DateTime(2026, 10, 5, 8));
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  group('TodoController', () {
    test('create menambahkan tugas dan memberikan id', () async {
      final id = await container
          .read(todoControllerProvider.notifier)
          .create(const Task(title: 'Kerjakan laporan'));

      expect(id, 1);
      final task = repository.tasks.single;
      expect(task.id, 1);
      expect(task.title, 'Kerjakan laporan');
    });

    test('update mengubah field yang sama', () async {
      final id = await container
          .read(todoControllerProvider.notifier)
          .create(const Task(title: 'Lama'));
      final created = repository.tasks.single;

      final updated = await container
          .read(todoControllerProvider.notifier)
          .update(created.copyWith(title: 'Baru', priority: TaskPriority.high));

      expect(updated, isTrue);
      expect(repository.tasks, hasLength(1));
      expect(repository.tasks.single.id, id);
      expect(repository.tasks.single.title, 'Baru');
      expect(repository.tasks.single.priority, TaskPriority.high);
    });

    test(
      'setCompleted(true) menandai done dengan completedAt jam sekarang',
      () async {
        final id = await container
            .read(todoControllerProvider.notifier)
            .create(const Task(title: 'Kirim email'));
        final created = repository.tasks.single;

        await container
            .read(todoControllerProvider.notifier)
            .setCompleted(created, true);

        final task = repository.tasks.single;
        expect(task.status, TaskStatus.done);
        expect(task.completedAt, DateTime(2026, 10, 5, 8).toUtc());
        expect(task.id, id);
      },
    );

    test(
      'setCompleted(false) mengembalikan ke pending dan membersihkan waktu',
      () async {
        await container
            .read(todoControllerProvider.notifier)
            .create(const Task(title: 'Kirim email'));
        final created = repository.tasks.single;
        await container
            .read(todoControllerProvider.notifier)
            .setCompleted(created, true);

        await container
            .read(todoControllerProvider.notifier)
            .setCompleted(repository.tasks.single, false);

        final task = repository.tasks.single;
        expect(task.status, TaskStatus.pending);
        expect(task.completedAt, isNull);
      },
    );

    test('delete menghapus tugas yang diminta', () async {
      final id = await container
          .read(todoControllerProvider.notifier)
          .create(const Task(title: 'Buang sampah'));

      final deleted = await container
          .read(todoControllerProvider.notifier)
          .delete(id);

      expect(deleted, isTrue);
      expect(repository.tasks, isEmpty);
      expect(
        await container.read(todoControllerProvider.notifier).delete(id),
        isFalse,
      );
    });
  });

  group('todayTasksProvider', () {
    test('hanya memunculkan tugas pending hari ini', () async {
      await repository.create(
        const Task(title: 'Hari ini', dueDate: '2026-10-05'),
      );
      await repository.create(
        const Task(title: 'Besok', dueDate: '2026-10-06'),
      );
      await repository.create(
        const Task(
          title: 'Selesai',
          dueDate: '2026-10-05',
          status: TaskStatus.done,
        ),
      );

      final tasks = await _firstValue(container, todayTasksProvider);

      expect(tasks.map((t) => t.title).toList(), ['Hari ini']);
    });
  });
}

Future<List<Task>> _firstValue(
  ProviderContainer container,
  StreamProvider<List<Task>> provider,
) async {
  final completer = Completer<List<Task>>();
  container.listen<AsyncValue<List<Task>>>(provider, (previous, next) {
    final value = next.value;
    if (value != null && !completer.isCompleted) completer.complete(value);
  });
  return completer.future;
}

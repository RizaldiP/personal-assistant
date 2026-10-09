import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';

/// Daftar seluruh tugas (sumber kebenaran database).
final todoListProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

/// Tugas yang masih pending untuk tanggal hari ini (dipakai Beranda).
final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  final now = ref.watch(clockProvider).now();
  return ref.watch(taskRepositoryProvider).watchTasksOn(_isoDate(now));
});

/// Semua tugas hari ini (pending + selesai) untuk widget layar utama.
final todayTasksForWidgetProvider = StreamProvider<List<Task>>((ref) {
  final now = ref.watch(clockProvider).now();
  return ref
      .watch(taskRepositoryProvider)
      .watchTasksForWidgetOn(_isoDate(now));
});

class TodoController extends Notifier<void> {
  @override
  void build() {}

  Future<int> create(Task task) =>
      ref.read(taskRepositoryProvider).create(task);

  Future<bool> update(Task task) =>
      ref.read(taskRepositoryProvider).update(task);

  Future<bool> setCompleted(Task task, bool done) {
    final repository = ref.read(taskRepositoryProvider);
    if (!done) {
      return repository.update(
        Task(
          id: task.id,
          title: task.title,
          description: task.description,
          dueDate: task.dueDate,
          dueTime: task.dueTime,
          priority: task.priority,
          category: task.category,
          status: TaskStatus.pending,
          source: task.source,
          rawInput: task.rawInput,
          confidence: task.confidence,
          createdAt: task.createdAt,
          updatedAt: task.updatedAt,
        ),
      );
    }
    final now = ref.read(clockProvider).now();
    return repository.update(
      task.copyWith(status: TaskStatus.done, completedAt: now.toUtc()),
    );
  }

  Future<bool> delete(int id) => ref.read(taskRepositoryProvider).delete(id);
}

final todoControllerProvider = NotifierProvider<TodoController, void>(
  TodoController.new,
);

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

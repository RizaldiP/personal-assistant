import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';
import 'daily_task_reminder.dart';

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

  Future<int> create(Task task) async {
    final id = await ref.read(taskRepositoryProvider).create(task);
    await _reconcileDailyReminder();
    return id;
  }

  Future<bool> update(Task task) async {
    final saved = await ref.read(taskRepositoryProvider).update(task);
    if (saved) await _reconcileDailyReminder();
    return saved;
  }

  Future<bool> setCompleted(Task task, bool done) async {
    final repository = ref.read(taskRepositoryProvider);
    final bool saved;
    if (!done) {
      saved = await repository.update(
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
    } else {
      final now = ref.read(clockProvider).now();
      saved = await repository.update(
        task.copyWith(status: TaskStatus.done, completedAt: now.toUtc()),
      );
    }
    if (saved) await _reconcileDailyReminder();
    return saved;
  }

  Future<bool> delete(int id) async {
    final saved = await ref.read(taskRepositoryProvider).delete(id);
    if (saved) await _reconcileDailyReminder();
    return saved;
  }

  /// Menyinkronkan notifikasi digest tugas harian (08.00) setelah perubahan.
  Future<void> _reconcileDailyReminder() =>
      ref.read(dailyTaskReminderProvider.notifier).reconcile();
}

final todoControllerProvider = NotifierProvider<TodoController, void>(
  TodoController.new,
);

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

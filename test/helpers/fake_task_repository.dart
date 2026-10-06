import 'dart:async';

import 'package:personal_offline/features/todo/domain/entities/task.dart';
import 'package:personal_offline/features/todo/domain/repositories/task_repository.dart';

/// Fake [TaskRepository] untuk test controller, layar, dan alur chat.
///
/// Data disimpan dalam memori; setiap perubahan memancarkan daftar terbaru
/// melalui stream agar UI yang menonton ikut terbarui.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({List<Task> seed = const []}) : _tasks = List.of(seed);

  final List<Task> _tasks;
  final StreamController<List<Task>> _changes =
      StreamController<List<Task>>.broadcast();

  int _nextId = 1;

  List<Task> get tasks => List.unmodifiable(_tasks);

  @override
  Stream<List<Task>> watchTasks() async* {
    yield List.of(_tasks);
    yield* _changes.stream;
  }

  @override
  Stream<List<Task>> watchTasksOn(String date) async* {
    yield _pendingOn(date);
    yield* _changes.stream.map((_) => _pendingOn(date));
  }

  List<Task> _pendingOn(String date) => _tasks
      .where((t) => t.status == TaskStatus.pending && t.dueDate == date)
      .toList();

  @override
  Future<Task?> getById(int id) async {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<List<Task>> getAll() async => List.of(_tasks);

  @override
  Future<List<Task>> search(String query) async {
    final lower = query.toLowerCase();
    return _tasks
        .where(
          (t) =>
              t.title.toLowerCase().contains(lower) ||
              (t.description?.toLowerCase().contains(lower) ?? false),
        )
        .toList();
  }

  @override
  Future<int> create(Task task) async {
    final id = _nextId++;
    _tasks.add(task.copyWith(id: id));
    _changes.add(List.of(_tasks));
    return id;
  }

  @override
  Future<bool> update(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return false;
    _tasks[index] = task;
    _changes.add(List.of(_tasks));
    return true;
  }

  @override
  Future<bool> delete(int id) async {
    final length = _tasks.length;
    _tasks.removeWhere((t) => t.id == id);
    _changes.add(List.of(_tasks));
    return _tasks.length != length;
  }
}

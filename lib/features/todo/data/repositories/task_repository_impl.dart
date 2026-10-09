import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/task_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._dao, this._clock);

  final TaskDao _dao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Task>> watchTasks() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Stream<List<Task>> watchTasksOn(String date) =>
      _dao.watchPendingOn(date).map((rows) => rows.map(_toDomain).toList());

  @override
  Stream<List<Task>> watchTasksForWidgetOn(String date) =>
      _dao.watchAllOn(date).map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Task?> getById(int id) async => _mapOrNull(await _dao.getById(id));

  @override
  Future<List<Task>> getAll() async =>
      (await _dao.getAll()).map(_toDomain).toList();

  @override
  Future<List<Task>> search(String query) async =>
      (await _dao.search(query)).map(_toDomain).toList();

  @override
  Future<int> create(Task task) =>
      _dao.insertTask(_insertCompanion(task, _now));

  @override
  Future<bool> update(Task task) async {
    final id = task.id;
    if (id == null) return false;
    return _dao.updateTask(id, _updateCompanion(task, _now));
  }

  @override
  Future<bool> delete(int id) => _dao.deleteTask(id);

  static Task? _mapOrNull(db.Task? row) => row == null ? null : _toDomain(row);

  static Task _toDomain(db.Task row) => Task(
    id: row.id,
    title: row.title,
    description: row.description,
    dueDate: row.dueDate,
    dueTime: row.dueTime,
    priority: TaskPriority.parse(row.priority),
    category: row.category,
    status: TaskStatus.parse(row.status),
    completedAt: _fromEpoch(row.completedAt),
    source: row.source,
    rawInput: row.rawInput,
    confidence: row.confidence,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static db.TasksCompanion _insertCompanion(Task task, int now) =>
      db.TasksCompanion.insert(
        title: task.title,
        description: Value(task.description),
        dueDate: Value(task.dueDate),
        dueTime: Value(task.dueTime),
        priority: Value(task.priority.storageValue),
        category: Value(task.category),
        status: Value(task.status.storageValue),
        completedAt: Value(_toEpoch(task.completedAt)),
        source: Value(task.source),
        rawInput: Value(task.rawInput),
        confidence: Value(task.confidence),
        createdAt: now,
        updatedAt: now,
      );

  static db.TasksCompanion _updateCompanion(Task task, int now) =>
      db.TasksCompanion(
        title: Value(task.title),
        description: Value(task.description),
        dueDate: Value(task.dueDate),
        dueTime: Value(task.dueTime),
        priority: Value(task.priority.storageValue),
        category: Value(task.category),
        status: Value(task.status.storageValue),
        completedAt: Value(_toEpoch(task.completedAt)),
        source: Value(task.source),
        rawInput: Value(task.rawInput),
        confidence: Value(task.confidence),
        updatedAt: Value(now),
      );

  static int? _toEpoch(DateTime? value) =>
      value?.toUtc().millisecondsSinceEpoch;

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return TaskRepositoryImpl(database.taskDao, ref.watch(clockProvider));
});

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/task_table.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  Stream<List<Task>> watchAll() =>
      (select(tasks)..orderBy([
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.asc(t.dueTime),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  Stream<List<Task>> watchPendingOn(String date) =>
      (select(tasks)
            ..where((t) => t.status.equals('pending') & t.dueDate.equals(date))
            ..orderBy([
              (t) => OrderingTerm.asc(t.dueTime),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  Future<Task?> getById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Task>> getAll() => select(tasks).get();

  Future<List<Task>> search(String query) {
    final like = '%${_escapeLike(query)}%';
    return (select(tasks)
          ..where(
            (t) =>
                t.title.like(like, escapeChar: '\\') |
                t.description.like(like, escapeChar: '\\'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(int id, TasksCompanion entry) async {
    final updated = await (update(
      tasks,
    )..where((t) => t.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteTask(int id) async {
    final deleted = await (delete(tasks)..where((t) => t.id.equals(id))).go();
    return deleted > 0;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

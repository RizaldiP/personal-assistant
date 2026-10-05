import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reminder_table.dart';

part 'reminder_dao.g.dart';

@DriftAccessor(tables: [Reminders])
class ReminderDao extends DatabaseAccessor<AppDatabase>
    with _$ReminderDaoMixin {
  ReminderDao(super.db);

  Stream<List<Reminder>> watchActive() =>
      (select(reminders)
            ..where((r) => r.status.equals('active'))
            ..orderBy([
              (r) => OrderingTerm.asc(r.scheduledAt),
              (r) => OrderingTerm.asc(r.id),
            ]))
          .watch();

  Future<Reminder?> getById(int id) =>
      (select(reminders)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<List<Reminder>> getAll() => select(reminders).get();

  /// Reminder aktif yang jatuh tempo pada `now` (epoch ms UTC).
  ///
  /// Memakai `next_fire_at` bila ada (hasil penjadwalan ulang/snooze), jika
  /// kosong jatuh tempo dihitung dari `scheduled_at`.
  Future<List<Reminder>> dueAt(int nowEpochMs) =>
      (select(reminders)
            ..where(
              (r) =>
                  r.status.equals('active') &
                  ifNull(
                    r.nextFireAt,
                    r.scheduledAt,
                  ).isSmallerOrEqualValue(nowEpochMs),
            )
            ..orderBy([
              (r) => OrderingTerm.asc(ifNull(r.nextFireAt, r.scheduledAt)),
              (r) => OrderingTerm.asc(r.id),
            ]))
          .get();

  Future<List<Reminder>> search(String query) {
    final like = '%${_escapeLike(query)}%';
    return (select(reminders)
          ..where(
            (r) =>
                r.title.like(like, escapeChar: '\\') |
                r.notes.like(like, escapeChar: '\\'),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
        .get();
  }

  Future<int> insertReminder(RemindersCompanion entry) =>
      into(reminders).insert(entry);

  Future<bool> updateReminder(int id, RemindersCompanion entry) async {
    final updated = await (update(
      reminders,
    )..where((r) => r.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteReminder(int id) async {
    final deleted = await (delete(
      reminders,
    )..where((r) => r.id.equals(id))).go();
    return deleted > 0;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

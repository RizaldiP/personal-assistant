import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/journal_table.dart';

part 'journal_dao.g.dart';

@DriftAccessor(tables: [JournalEntries])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  Stream<List<JournalEntry>> watchAll({String? query}) => _query(query).watch();

  Future<List<JournalEntry>> getAll({String? query}) => _query(query).get();

  Future<JournalEntry?> getById(int id) =>
      (select(journalEntries)..where((j) => j.id.equals(id))).getSingleOrNull();

  Future<int> insert(JournalEntriesCompanion entry) =>
      into(journalEntries).insert(entry);

  Future<bool> updateById(int id, JournalEntriesCompanion entry) async {
    final updated = await (update(
      journalEntries,
    )..where((j) => j.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteById(int id) async {
    final deleted = await (delete(
      journalEntries,
    )..where((j) => j.id.equals(id))).go();
    return deleted > 0;
  }

  /// Query entri jurnal: urut tanggal terbaru, difilter [query] bila terisi.
  SimpleSelectStatement<$JournalEntriesTable, JournalEntry> _query(
    String? query,
  ) {
    final statement = select(journalEntries)
      ..orderBy([
        (j) => OrderingTerm.desc(j.date),
        (j) => OrderingTerm.desc(j.id),
      ]);
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final pattern = '%${_escapeLike(trimmed)}%';
      statement.where(
        (j) =>
            j.content.like(pattern, escapeChar: '\\') |
            j.title.like(pattern, escapeChar: '\\') |
            j.mood.like(pattern, escapeChar: '\\'),
      );
    }
    return statement;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

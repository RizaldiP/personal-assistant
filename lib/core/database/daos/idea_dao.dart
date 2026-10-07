import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/idea_table.dart';

part 'idea_dao.g.dart';

@DriftAccessor(tables: [Ideas])
class IdeaDao extends DatabaseAccessor<AppDatabase> with _$IdeaDaoMixin {
  IdeaDao(super.db);

  Stream<List<Idea>> watchAll({String? query}) => _query(query).watch();

  Future<List<Idea>> getAll({String? query}) => _query(query).get();

  Future<Idea?> getById(int id) =>
      (select(ideas)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<int> insert(IdeasCompanion entry) => into(ideas).insert(entry);

  Future<bool> updateById(int id, IdeasCompanion entry) async {
    final updated = await (update(
      ideas,
    )..where((i) => i.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteById(int id) async {
    final deleted = await (delete(ideas)..where((i) => i.id.equals(id))).go();
    return deleted > 0;
  }

  /// Query daftar ide: urut terbaru, difilter [query] bila terisi.
  SimpleSelectStatement<$IdeasTable, Idea> _query(String? query) {
    final statement = select(ideas)
      ..orderBy([
        (i) => OrderingTerm.desc(i.createdAt),
        (i) => OrderingTerm.desc(i.id),
      ]);
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final pattern = '%${_escapeLike(trimmed)}%';
      statement.where(
        (i) =>
            i.title.like(pattern, escapeChar: '\\') |
            i.content.like(pattern, escapeChar: '\\'),
      );
    }
    return statement;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

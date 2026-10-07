import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/notes_table.dart';

part 'note_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Stream<List<Note>> watchAll({String? query}) => _query(query).watch();

  Future<List<Note>> getAll({String? query}) => _query(query).get();

  Future<Note?> getById(int id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> insert(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateById(int id, NotesCompanion entry) async {
    final updated = await (update(
      notes,
    )..where((n) => n.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteById(int id) async {
    final deleted = await (delete(notes)..where((n) => n.id.equals(id))).go();
    return deleted > 0;
  }

  /// Query daftar catatan: urut terbaru, difilter [query] bila terisi.
  SimpleSelectStatement<$NotesTable, Note> _query(String? query) {
    final statement = select(notes)
      ..orderBy([
        (n) => OrderingTerm.desc(n.createdAt),
        (n) => OrderingTerm.desc(n.id),
      ]);
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final pattern = '%${_escapeLike(trimmed)}%';
      statement.where(
        (n) =>
            n.content.like(pattern, escapeChar: '\\') |
            n.title.like(pattern, escapeChar: '\\'),
      );
    }
    return statement;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

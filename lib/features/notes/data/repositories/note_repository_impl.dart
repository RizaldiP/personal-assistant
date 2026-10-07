import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/note_dao.dart';
import 'package:personal_offline/core/database/daos/tag_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/core/utils/combine_latest.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';

/// Implementasi [NoteRepository] berbasis drift.
///
/// Tag ditautkan lewat tabel `tag_links` dengan entity type [entityType];
/// nama tag disimpan lowercase.
class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl(this._dao, this._tagDao, this._clock);

  static const String entityType = 'note';

  final NoteDao _dao;
  final TagDao _tagDao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Note>> watchNotes({String? query}) {
    return combineLatest(
      _dao.watchAll(query: query),
      _tagDao.watchNames(entityType),
      (rows, tagNames) {
        final grouped = <int, List<String>>{};
        for (final item in tagNames) {
          grouped.putIfAbsent(item.entityId, () => []).add(item.name);
        }
        return rows
            .map((row) => _toNote(row, grouped[row.id] ?? const []))
            .toList();
      },
    );
  }

  @override
  Future<List<Note>> getAll({String? query}) async {
    final rows = await _dao.getAll(query: query);
    return Future.wait(rows.map(_withTags));
  }

  @override
  Future<Note?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _withTags(row);
  }

  @override
  Future<int> create(Note note) async {
    final id = await _dao.insert(_insertCompanion(note, _now));
    await _saveTags(id, note.tags);
    return id;
  }

  @override
  Future<bool> update(Note note) async {
    final id = note.id;
    if (id == null) return false;
    final updated = await _dao.updateById(id, _updateCompanion(note, _now));
    if (updated) await _saveTags(id, note.tags);
    return updated;
  }

  @override
  Future<bool> deleteById(int id) async {
    final deleted = await _dao.deleteById(id);
    if (deleted) await _tagDao.deleteLinks(entityType, id);
    return deleted;
  }

  Future<Note> _withTags(db.Note row) async {
    final names = (await _tagDao.tagsForEntity(
      entityType,
      row.id,
    )).map((tag) => tag.name).toList();
    return _toNote(row, names);
  }

  Future<void> _saveTags(int entityId, List<String> names) async {
    await _tagDao.deleteLinks(entityType, entityId);
    final now = _now;
    for (final raw in names) {
      final name = raw.trim().toLowerCase();
      if (name.isEmpty) continue;
      final existing = await _tagDao.getByName(name);
      final tagId =
          existing?.id ??
          await _tagDao.insertTag(
            db.TagsCompanion.insert(name: name, createdAt: now, updatedAt: now),
          );
      await _tagDao.link(tagId, entityType, entityId, now: now);
    }
  }

  static Note _toNote(db.Note row, List<String> tags) => Note(
    id: row.id,
    title: row.title,
    content: row.content,
    source: row.source,
    rawInput: row.rawInput,
    confidence: row.confidence,
    tags: tags,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static db.NotesCompanion _insertCompanion(Note note, int now) =>
      db.NotesCompanion.insert(
        title: Value(note.title),
        content: note.content,
        source: Value(note.source),
        rawInput: Value(note.rawInput),
        confidence: Value(note.confidence),
        createdAt: now,
        updatedAt: now,
      );

  static db.NotesCompanion _updateCompanion(Note note, int now) =>
      db.NotesCompanion(
        title: Value(note.title),
        content: Value(note.content),
        source: Value(note.source),
        rawInput: Value(note.rawInput),
        confidence: Value(note.confidence),
        updatedAt: Value(now),
      );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return NoteRepositoryImpl(
    database.noteDao,
    database.tagDao,
    ref.watch(clockProvider),
  );
});

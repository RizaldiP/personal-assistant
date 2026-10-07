import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/journal_dao.dart';
import 'package:personal_offline/core/database/daos/tag_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/core/utils/combine_latest.dart';

import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_repository.dart';

/// Implementasi [JournalRepository] berbasis drift.
///
/// Tag ditautkan lewat tabel `tag_links` dengan entity type [entityType].
class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl(this._dao, this._tagDao, this._clock);

  static const String entityType = 'journal';

  final JournalDao _dao;
  final TagDao _tagDao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<JournalEntry>> watchEntries({String? query}) {
    return combineLatest(
      _dao.watchAll(query: query),
      _tagDao.watchNames(entityType),
      (rows, tagNames) {
        final grouped = <int, List<String>>{};
        for (final item in tagNames) {
          grouped.putIfAbsent(item.entityId, () => []).add(item.name);
        }
        return rows
            .map((row) => _toEntry(row, grouped[row.id] ?? const []))
            .toList();
      },
    );
  }

  @override
  Future<List<JournalEntry>> getAll({String? query}) async {
    final rows = await _dao.getAll(query: query);
    return Future.wait(rows.map(_withTags));
  }

  @override
  Future<JournalEntry?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _withTags(row);
  }

  @override
  Future<int> create(JournalEntry entry) async {
    final id = await _dao.insert(_insertCompanion(entry, _now));
    await _saveTags(id, entry.tags);
    return id;
  }

  @override
  Future<bool> update(JournalEntry entry) async {
    final id = entry.id;
    if (id == null) return false;
    final updated = await _dao.updateById(id, _updateCompanion(entry, _now));
    if (updated) await _saveTags(id, entry.tags);
    return updated;
  }

  @override
  Future<bool> deleteById(int id) async {
    final deleted = await _dao.deleteById(id);
    if (deleted) await _tagDao.deleteLinks(entityType, id);
    return deleted;
  }

  Future<JournalEntry> _withTags(db.JournalEntry row) async {
    final names = (await _tagDao.tagsForEntity(
      entityType,
      row.id,
    )).map((tag) => tag.name).toList();
    return _toEntry(row, names);
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

  static JournalEntry _toEntry(db.JournalEntry row, List<String> tags) =>
      JournalEntry(
        id: row.id,
        date: row.date,
        title: row.title,
        content: row.content,
        mood: row.mood,
        source: row.source,
        rawInput: row.rawInput,
        confidence: row.confidence,
        tags: tags,
        createdAt: _fromEpoch(row.createdAt),
        updatedAt: _fromEpoch(row.updatedAt),
      );

  static db.JournalEntriesCompanion _insertCompanion(
    JournalEntry entry,
    int now,
  ) => db.JournalEntriesCompanion.insert(
    date: entry.date,
    title: Value(entry.title),
    content: entry.content,
    mood: Value(entry.mood),
    source: Value(entry.source),
    rawInput: Value(entry.rawInput),
    confidence: Value(entry.confidence),
    createdAt: now,
    updatedAt: now,
  );

  static db.JournalEntriesCompanion _updateCompanion(
    JournalEntry entry,
    int now,
  ) => db.JournalEntriesCompanion(
    date: Value(entry.date),
    title: Value(entry.title),
    content: Value(entry.content),
    mood: Value(entry.mood),
    source: Value(entry.source),
    rawInput: Value(entry.rawInput),
    confidence: Value(entry.confidence),
    updatedAt: Value(now),
  );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
}

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return JournalRepositoryImpl(
    database.journalDao,
    database.tagDao,
    ref.watch(clockProvider),
  );
});

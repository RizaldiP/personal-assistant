import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/idea_dao.dart';
import 'package:personal_offline/core/database/daos/tag_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/core/utils/combine_latest.dart';

import '../../domain/entities/idea.dart';
import '../../domain/repositories/idea_repository.dart';

/// Implementasi [IdeaRepository] berbasis drift.
///
/// Tag ditautkan lewat tabel `tag_links` dengan entity type [entityType].
class IdeaRepositoryImpl implements IdeaRepository {
  IdeaRepositoryImpl(this._dao, this._tagDao, this._clock);

  static const String entityType = 'idea';

  final IdeaDao _dao;
  final TagDao _tagDao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Idea>> watchIdeas({String? query}) {
    return combineLatest(
      _dao.watchAll(query: query),
      _tagDao.watchNames(entityType),
      (rows, tagNames) {
        final grouped = <int, List<String>>{};
        for (final item in tagNames) {
          grouped.putIfAbsent(item.entityId, () => []).add(item.name);
        }
        return rows
            .map((row) => _toIdea(row, grouped[row.id] ?? const []))
            .toList();
      },
    );
  }

  @override
  Future<List<Idea>> getAll({String? query}) async {
    final rows = await _dao.getAll(query: query);
    return Future.wait(rows.map(_withTags));
  }

  @override
  Future<Idea?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _withTags(row);
  }

  @override
  Future<int> create(Idea idea) async {
    final id = await _dao.insert(_insertCompanion(idea, _now));
    await _saveTags(id, idea.tags);
    return id;
  }

  @override
  Future<bool> update(Idea idea) async {
    final id = idea.id;
    if (id == null) return false;
    final updated = await _dao.updateById(id, _updateCompanion(idea, _now));
    if (updated) await _saveTags(id, idea.tags);
    return updated;
  }

  @override
  Future<bool> deleteById(int id) async {
    final deleted = await _dao.deleteById(id);
    if (deleted) await _tagDao.deleteLinks(entityType, id);
    return deleted;
  }

  Future<Idea> _withTags(db.Idea row) async {
    final names = (await _tagDao.tagsForEntity(
      entityType,
      row.id,
    )).map((tag) => tag.name).toList();
    return _toIdea(row, names);
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

  static Idea _toIdea(db.Idea row, List<String> tags) => Idea(
    id: row.id,
    title: row.title,
    content: row.content,
    status: IdeaStatus.parse(row.status),
    source: row.source,
    rawInput: row.rawInput,
    confidence: row.confidence,
    tags: tags,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static db.IdeasCompanion _insertCompanion(Idea idea, int now) =>
      db.IdeasCompanion.insert(
        title: idea.title,
        content: Value(idea.content),
        status: Value(idea.status.storageValue),
        source: Value(idea.source),
        rawInput: Value(idea.rawInput),
        confidence: Value(idea.confidence),
        createdAt: now,
        updatedAt: now,
      );

  static db.IdeasCompanion _updateCompanion(Idea idea, int now) =>
      db.IdeasCompanion(
        title: Value(idea.title),
        content: Value(idea.content),
        status: Value(idea.status.storageValue),
        source: Value(idea.source),
        rawInput: Value(idea.rawInput),
        confidence: Value(idea.confidence),
        updatedAt: Value(now),
      );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
}

final ideaRepositoryProvider = Provider<IdeaRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return IdeaRepositoryImpl(
    database.ideaDao,
    database.tagDao,
    ref.watch(clockProvider),
  );
});

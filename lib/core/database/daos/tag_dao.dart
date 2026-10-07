import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tag_table.dart';

part 'tag_dao.g.dart';

/// Tag + junction-nya. Jenis entitas memakai kode `note` / `journal` / `idea`.
@DriftAccessor(tables: [Tags, TagLinks])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Stream<List<Tag>> watchAll() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Tag?> getByName(String name) =>
      (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  /// Semua link tag pada satu jenis entitas (dipakai repository menggabung).
  Stream<List<TagLink>> watchLinks(String entityType) =>
      (select(tagLinks)..where((l) => l.entityType.equals(entityType))).watch();

  /// Pasangan (entityId, nama tag) untuk satu jenis entitas — dipakai
  /// repository menggabungkan daftar entitas dengan tag-nya lewat stream.
  Stream<List<({int entityId, String name})>> watchNames(String entityType) {
    final query = select(tagLinks).join([
      innerJoin(tags, tags.id.equalsExp(tagLinks.tagId)),
    ])..where(tagLinks.entityType.equals(entityType));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => (
              entityId: row.readTable(tagLinks).entityId,
              name: row.readTable(tags).name,
            ),
          )
          .toList(),
    );
  }

  /// Tag milik satu entitas, urut nama.
  Future<List<Tag>> tagsForEntity(String entityType, int entityId) async {
    final query =
        select(
            tags,
          ).join([innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id))])
          ..where(
            tagLinks.entityType.equals(entityType) &
                tagLinks.entityId.equals(entityId),
          )
          ..orderBy([OrderingTerm.asc(tags.name)]);
    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList();
  }

  /// Menautkan tag ke entitas; abaikan bila sudah tertaut.
  Future<int> link(
    int tagId,
    String entityType,
    int entityId, {
    required int now,
  }) => into(tagLinks).insert(
    TagLinksCompanion.insert(
      tagId: tagId,
      entityType: entityType,
      entityId: entityId,
      createdAt: now,
      updatedAt: now,
    ),
    mode: InsertMode.insertOrIgnore,
  );

  /// Nama tag yang cocok dengan [pattern] LIKE (sudah di-escape), urut nama.
  Future<List<String>> matchingNames(String pattern) async {
    final rows =
        await (select(tags)
              ..where((t) => t.name.like(pattern, escapeChar: '\\'))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return rows.map((row) => row.name).toList();
  }

  /// Pasangan link yang nama tag-nya cocok dengan [pattern] LIKE — global
  /// search menemukan entitas lewat namanya (PHASE 13).
  Future<List<({String entityType, int entityId, String tagName})>>
  matchingLinks(String pattern, {int limit = 100}) async {
    final query =
        select(
            tagLinks,
          ).join([innerJoin(tags, tags.id.equalsExp(tagLinks.tagId))])
          ..where(tags.name.like(pattern, escapeChar: '\\'))
          ..orderBy([
            OrderingTerm.asc(tags.name),
            OrderingTerm.asc(tagLinks.entityType),
            OrderingTerm.asc(tagLinks.entityId),
          ])
          ..limit(limit);
    final rows = await query.get();
    return rows
        .map(
          (row) => (
            entityType: row.readTable(tagLinks).entityType,
            entityId: row.readTable(tagLinks).entityId,
            tagName: row.readTable(tags).name,
          ),
        )
        .toList();
  }

  /// Semua link milik satu nama tag persis.
  Future<List<({String entityType, int entityId})>> linksForTag(
    String tagName,
  ) async {
    final query = select(tagLinks).join([
      innerJoin(tags, tags.id.equalsExp(tagLinks.tagId)),
    ])..where(tags.name.equals(tagName));
    final rows = await query.get();
    return rows
        .map(
          (row) => (
            entityType: row.readTable(tagLinks).entityType,
            entityId: row.readTable(tagLinks).entityId,
          ),
        )
        .toList();
  }

  /// Tag milik banyak entitas sekaligus (batch untuk hasil search).
  Future<List<({int entityId, String name})>> tagsForEntities(
    String entityType,
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final query =
        select(
            tags,
          ).join([innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id))])
          ..where(
            tagLinks.entityType.equals(entityType) &
                tagLinks.entityId.isIn(ids),
          )
          ..orderBy([OrderingTerm.asc(tags.name)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => (
            entityId: row.readTable(tagLinks).entityId,
            name: row.readTable(tags).name,
          ),
        )
        .toList();
  }

  Future<int> deleteLinks(String entityType, int entityId) async {
    final deleted =
        await (delete(tagLinks)..where(
              (l) =>
                  l.entityType.equals(entityType) & l.entityId.equals(entityId),
            ))
            .go();
    return deleted;
  }
}

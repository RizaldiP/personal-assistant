import 'package:drift/drift.dart';

/// Tag global (PHASE 9). `name` selalu disimpan lowercase.
@TableIndex(name: 'idx_tags_name', columns: {#name}, unique: true)
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get color => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

/// Junction tag <-> entitas (note | journal | idea).
///
/// Tanpa kolom id: kombinasi (tag_id, entity_type, entity_id) sudah unik
/// menjadi primary key.
class TagLinks extends Table {
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  /// Jenis entitas pemilik tag (`note`, `journal`, `idea`).
  TextColumn get entityType => text()();

  IntColumn get entityId => integer()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {tagId, entityType, entityId};
}

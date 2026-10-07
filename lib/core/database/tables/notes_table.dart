import 'package:drift/drift.dart';

/// Tabel catatan bebas (PHASE 9).
@TableIndex(name: 'idx_notes_created_at', columns: {#createdAt})
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().nullable()();

  TextColumn get content => text()();

  TextColumn get source => text().nullable()();

  TextColumn get rawInput => text().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

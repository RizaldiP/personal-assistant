import 'package:drift/drift.dart';

/// Tabel ide (PHASE 9). Status mengikuti alur:
/// `inbox` -> `thinking` -> `working` -> `completed` / `archived`.
@TableIndex(name: 'idx_ideas_status', columns: {#status})
class Ideas extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get content => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('inbox'))();

  TextColumn get source => text().nullable()();

  TextColumn get rawInput => text().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

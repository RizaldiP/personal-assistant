import 'package:drift/drift.dart';

/// Tabel tugas (todo).
///
/// Kolom `source`, `rawInput`, `confidence` adalah jejak asal input
/// (dibuat dari chat/manual) — ditambahkan pada schema versi 2.
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  /// Tanggal murni `YYYY-MM-DD`.
  TextColumn get dueDate => text().nullable()();

  /// Jam `HH:mm`.
  TextColumn get dueTime => text().nullable()();

  TextColumn get priority => text().withDefault(const Constant('normal'))();

  TextColumn get category => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Epoch millisecond UTC.
  IntColumn get completedAt => integer().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get rawInput => text().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

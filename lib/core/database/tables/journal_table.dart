import 'package:drift/drift.dart';

/// Tabel entri jurnal harian (PHASE 9).
@TableIndex(name: 'idx_journal_entries_date', columns: {#date})
class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Tanggal kejadian `YYYY-MM-DD`.
  TextColumn get date => text()();

  TextColumn get title => text().nullable()();

  TextColumn get content => text()();

  /// Mood bebas, mis. `senang`, `capek`, `stres`.
  TextColumn get mood => text().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get rawInput => text().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

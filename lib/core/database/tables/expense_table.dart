import 'package:drift/drift.dart';

/// Tabel pengeluaran (PHASE 8). Nominal disimpan integer IDR tanpa desimal.
@TableIndex(name: 'idx_expenses_date', columns: {#date})
@TableIndex(name: 'idx_expenses_category', columns: {#category})
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get amount => integer()();

  TextColumn get currency => text().withDefault(const Constant('IDR'))();

  TextColumn get category => text().withDefault(const Constant('lainnya'))();

  TextColumn get description => text()();

  /// Tanggal kejadian `YYYY-MM-DD`.
  TextColumn get date => text()();

  TextColumn get paymentMethod => text().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get rawInput => text().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

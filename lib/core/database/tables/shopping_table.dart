import 'package:drift/drift.dart';

/// Tabel daftar belanja.
class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withDefault(const Constant('Belanja'))();

  TextColumn get status => text().withDefault(const Constant('open'))();

  /// Rencana tanggal belanja `YYYY-MM-DD`.
  TextColumn get date => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

/// Tabel item belanja.
@TableIndex(name: 'idx_shopping_items_list_id', columns: {#listId})
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get listId =>
      integer().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  RealColumn get quantity => real().nullable()();

  TextColumn get unit => text().nullable()();

  Column<bool> get isChecked => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

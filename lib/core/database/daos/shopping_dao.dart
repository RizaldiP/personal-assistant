import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_table.dart';

part 'shopping_dao.g.dart';

@DriftAccessor(tables: [ShoppingLists, ShoppingItems])
class ShoppingDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingDaoMixin {
  ShoppingDao(super.db);

  Stream<List<ShoppingList>> watchLists() =>
      (select(shoppingLists)..orderBy([(l) => OrderingTerm.asc(l.id)])).watch();

  Stream<List<ShoppingItem>> watchItems() =>
      (select(shoppingItems)..orderBy([
            (i) => OrderingTerm.asc(i.sortOrder),
            (i) => OrderingTerm.asc(i.id),
          ]))
          .watch();

  Future<ShoppingList?> getListById(int id) =>
      (select(shoppingLists)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<List<ShoppingList>> getAllLists() => select(shoppingLists).get();

  Future<List<ShoppingItem>> itemsForList(int listId) =>
      (select(shoppingItems)
            ..where((i) => i.listId.equals(listId))
            ..orderBy([
              (i) => OrderingTerm.asc(i.sortOrder),
              (i) => OrderingTerm.asc(i.id),
            ]))
          .get();

  Future<List<ShoppingItem>> getAllItems() => select(shoppingItems).get();

  /// Pencarian judul daftar atau nama barang untuk global search
  /// (PHASE 13).
  Future<List<ShoppingList>> searchLists(String query, {int limit = 30}) async {
    final like = '%${_escapeLike(query)}%';
    final matchingListIds = {
      for (final item in await (select(
        shoppingItems,
      )..where((i) => i.name.like(like, escapeChar: '\\'))).get())
        item.listId,
    };
    final statement = select(shoppingLists)
      ..where((l) {
        final titleMatch = l.title.like(like, escapeChar: '\\');
        return matchingListIds.isEmpty
            ? titleMatch
            : titleMatch | l.id.isIn(matchingListIds);
      })
      ..orderBy([
        (l) => OrderingTerm.desc(l.date),
        (l) => OrderingTerm.desc(l.id),
      ])
      ..limit(limit);
    return statement.get();
  }

  Future<int> insertList(ShoppingListsCompanion entry) =>
      into(shoppingLists).insert(entry);

  Future<bool> updateList(int id, ShoppingListsCompanion entry) async {
    final updated = await (update(
      shoppingLists,
    )..where((l) => l.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteList(int id) async {
    final deleted = await (delete(
      shoppingLists,
    )..where((l) => l.id.equals(id))).go();
    return deleted > 0;
  }

  Future<int> insertItem(ShoppingItemsCompanion entry) =>
      into(shoppingItems).insert(entry);

  Future<bool> updateItem(int id, ShoppingItemsCompanion entry) async {
    final updated = await (update(
      shoppingItems,
    )..where((i) => i.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteItem(int id) async {
    final deleted = await (delete(
      shoppingItems,
    )..where((i) => i.id.equals(id))).go();
    return deleted > 0;
  }

  /// Urutan (sortOrder) terbaru + 1 untuk item baru di [listId].
  Future<int> nextSortOrder(int listId) async {
    final row =
        await (selectOnly(shoppingItems)
              ..addColumns([shoppingItems.sortOrder.max()])
              ..where(shoppingItems.listId.equals(listId)))
            .getSingle();
    final maxValue = row.read(shoppingItems.sortOrder.max());
    return (maxValue ?? -1) + 1;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

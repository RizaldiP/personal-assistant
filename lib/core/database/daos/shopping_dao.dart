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
}

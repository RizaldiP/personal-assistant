import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/shopping_repository_impl.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';

/// Seluruh daftar belanja lengkap dengan itemnya.
final shoppingListsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(shoppingRepositoryProvider).watchLists(),
);

class ShoppingController extends Notifier<void> {
  @override
  void build() {}

  /// Id daftar yang masih terbuka; bila belum ada membuat `Belanja`.
  Future<int> ensureActiveList() async {
    final lists = await ref.read(shoppingRepositoryProvider).getAll();
    for (final list in lists) {
      if (!list.isDone) return list.id!;
    }
    return ref
        .read(shoppingRepositoryProvider)
        .createList(const ShoppingList(title: 'Belanja'));
  }

  /// Menambahkan beberapa item ke daftar yang masih terbuka.
  Future<void> addItems(List<String> names) async {
    final listId = await ensureActiveList();
    await ref.read(shoppingRepositoryProvider).addItems(listId, names);
  }

  Future<int> createList([String title = 'Belanja']) => ref
      .read(shoppingRepositoryProvider)
      .createList(ShoppingList(title: title));

  Future<bool> toggleItem(ShoppingItem item, bool checked) => ref
      .read(shoppingRepositoryProvider)
      .updateItem(item.copyWith(isChecked: checked));

  Future<bool> removeItem(ShoppingItem item) {
    final id = item.id;
    if (id == null) return Future.value(false);
    return ref.read(shoppingRepositoryProvider).deleteItem(id);
  }

  Future<bool> setDone(ShoppingList list, bool done) {
    final target = done ? ShoppingListStatus.done : ShoppingListStatus.open;
    return ref
        .read(shoppingRepositoryProvider)
        .updateList(list.copyWith(status: target));
  }

  Future<bool> deleteList(int id) =>
      ref.read(shoppingRepositoryProvider).deleteList(id);
}

final shoppingControllerProvider = NotifierProvider<ShoppingController, void>(
  ShoppingController.new,
);

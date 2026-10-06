import '../entities/shopping_item.dart';
import '../entities/shopping_list.dart';

/// Kontrak akses data daftar belanja. Implementasi ada di lapisan data.
abstract interface class ShoppingRepository {
  /// Aliran seluruh daftar lengkap dengan itemnya.
  Stream<List<ShoppingList>> watchLists();

  Future<List<ShoppingList>> getAll();

  Future<ShoppingList?> getById(int id);

  /// Mengembalikan id daftar yang dibuat.
  Future<int> createList(ShoppingList list);

  /// `list.id` wajib terisi.
  Future<bool> updateList(ShoppingList list);

  Future<bool> deleteList(int id);

  /// Menambahkan [names] ke [listId]; nama kosong dilewati, urutan naik.
  Future<void> addItems(int listId, List<String> names);

  /// `item.id` wajib terisi.
  Future<bool> updateItem(ShoppingItem item);

  Future<bool> deleteItem(int id);
}

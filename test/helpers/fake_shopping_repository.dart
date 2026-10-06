import 'dart:async';

import 'package:personal_offline/features/shopping/domain/entities/shopping_item.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_list.dart';
import 'package:personal_offline/features/shopping/domain/repositories/shopping_repository.dart';

/// Fake [ShoppingRepository] untuk test controller, layar, dan alur chat.
///
/// Data disimpan dalam memori; setiap perubahan memancarkan daftar terbaru
/// melalui stream agar UI yang menonton ikut terbarui.
class FakeShoppingRepository implements ShoppingRepository {
  FakeShoppingRepository({List<ShoppingList> seed = const []})
    : _lists = List.of(seed);

  final List<ShoppingList> _lists;
  final StreamController<List<ShoppingList>> _changes =
      StreamController<List<ShoppingList>>.broadcast();

  int _nextListId = 1;
  int _nextItemId = 1;

  List<ShoppingList> get lists => List.unmodifiable(_lists);

  void _emit() => _changes.add(_snapshot());

  List<ShoppingList> _snapshot() =>
      _lists.map((list) => list.copyWith(items: List.of(list.items))).toList();

  @override
  Stream<List<ShoppingList>> watchLists() async* {
    yield _snapshot();
    yield* _changes.stream;
  }

  @override
  Future<List<ShoppingList>> getAll() async => _snapshot();

  @override
  Future<ShoppingList?> getById(int id) async {
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  @override
  Future<int> createList(ShoppingList list) async {
    final id = _nextListId++;
    _lists.add(list.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<bool> updateList(ShoppingList list) async {
    final index = _lists.indexWhere((l) => l.id == list.id);
    if (index == -1) return false;
    _lists[index] = list;
    _emit();
    return true;
  }

  @override
  Future<bool> deleteList(int id) async {
    final length = _lists.length;
    _lists.removeWhere((l) => l.id == id);
    _emit();
    return _lists.length != length;
  }

  @override
  Future<void> addItems(int listId, List<String> names) async {
    final index = _lists.indexWhere((l) => l.id == listId);
    if (index == -1) return;
    final list = _lists[index];
    var sortOrder = list.items.length;
    final newItems = <ShoppingItem>[];
    for (final rawName in names) {
      final name = rawName.trim();
      if (name.isEmpty) continue;
      newItems.add(
        ShoppingItem(
          id: _nextItemId++,
          listId: listId,
          name: name,
          sortOrder: sortOrder++,
        ),
      );
    }
    _lists[index] = list.copyWith(items: [...list.items, ...newItems]);
    _emit();
  }

  @override
  Future<bool> updateItem(ShoppingItem item) async {
    for (final list in _lists) {
      final items = list.items;
      final index = items.indexWhere((i) => i.id == item.id);
      if (index == -1) continue;
      final updated = [...items]..[index] = item;
      final listIndex = _lists.indexOf(list);
      _lists[listIndex] = list.copyWith(items: updated);
      _emit();
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteItem(int id) async {
    for (final list in _lists) {
      final items = list.items;
      final index = items.indexWhere((i) => i.id == id);
      if (index == -1) continue;
      final listIndex = _lists.indexOf(list);
      _lists[listIndex] = list.copyWith(items: [...items]..removeAt(index));
      _emit();
      return true;
    }
    return false;
  }
}

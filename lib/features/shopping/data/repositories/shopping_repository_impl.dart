import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/shopping_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/repositories/shopping_repository.dart';

class ShoppingRepositoryImpl implements ShoppingRepository {
  ShoppingRepositoryImpl(this._dao, this._clock);

  final ShoppingDao _dao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<ShoppingList>> watchLists() {
    return _combineLatest(_dao.watchLists(), _dao.watchItems(), (lists, items) {
      final grouped = <int, List<ShoppingItem>>{};
      for (final item in items) {
        grouped.putIfAbsent(item.listId, () => []).add(_toItemDomain(item));
      }
      return lists
          .map((list) => _toListDomain(list, grouped[list.id] ?? const []))
          .toList();
    });
  }

  @override
  Future<List<ShoppingList>> getAll() async {
    final lists = await _dao.getAllLists();
    final items = await _dao.watchItems().first;
    final grouped = <int, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.listId, () => []).add(_toItemDomain(item));
    }
    return lists
        .map((list) => _toListDomain(list, grouped[list.id] ?? const []))
        .toList();
  }

  @override
  Future<ShoppingList?> getById(int id) async {
    final row = await _dao.getListById(id);
    if (row == null) return null;
    final items = (await _dao.itemsForList(id)).map(_toItemDomain).toList();
    return _toListDomain(row, items);
  }

  @override
  Future<int> createList(ShoppingList list) =>
      _dao.insertList(_insertListCompanion(list, _now));

  @override
  Future<bool> updateList(ShoppingList list) async {
    final id = list.id;
    if (id == null) return false;
    return _dao.updateList(id, _updateListCompanion(list, _now));
  }

  @override
  Future<bool> deleteList(int id) => _dao.deleteList(id);

  @override
  Future<void> addItems(int listId, List<String> names) async {
    var sortOrder = await _dao.nextSortOrder(listId);
    final now = _now;
    for (final rawName in names) {
      final name = rawName.trim();
      if (name.isEmpty) continue;
      await _dao.insertItem(
        db.ShoppingItemsCompanion.insert(
          listId: listId,
          name: name,
          sortOrder: Value(sortOrder),
          createdAt: now,
          updatedAt: now,
        ),
      );
      sortOrder++;
    }
  }

  @override
  Future<bool> updateItem(ShoppingItem item) async {
    final id = item.id;
    if (id == null) return false;
    return _dao.updateItem(id, _updateItemCompanion(item, _now));
  }

  @override
  Future<bool> deleteItem(int id) => _dao.deleteItem(id);

  static ShoppingList _toListDomain(
    db.ShoppingList row,
    List<ShoppingItem> items,
  ) => ShoppingList(
    id: row.id,
    title: row.title,
    status: ShoppingListStatus.parse(row.status),
    date: row.date,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
    items: items,
  );

  static ShoppingItem _toItemDomain(db.ShoppingItem row) => ShoppingItem(
    id: row.id,
    listId: row.listId,
    name: row.name,
    quantity: row.quantity,
    unit: row.unit,
    isChecked: row.isChecked,
    sortOrder: row.sortOrder,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static db.ShoppingListsCompanion _insertListCompanion(
    ShoppingList list,
    int now,
  ) => db.ShoppingListsCompanion.insert(
    title: Value(list.title),
    status: Value(list.status.storageValue),
    date: Value(list.date),
    createdAt: now,
    updatedAt: now,
  );

  static db.ShoppingListsCompanion _updateListCompanion(
    ShoppingList list,
    int now,
  ) => db.ShoppingListsCompanion(
    title: Value(list.title),
    status: Value(list.status.storageValue),
    date: Value(list.date),
    updatedAt: Value(now),
  );

  static db.ShoppingItemsCompanion _updateItemCompanion(
    ShoppingItem item,
    int now,
  ) => db.ShoppingItemsCompanion(
    name: Value(item.name),
    quantity: Value(item.quantity),
    unit: Value(item.unit),
    isChecked: Value(item.isChecked),
    sortOrder: Value(item.sortOrder),
    updatedAt: Value(now),
  );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);

  static Stream<R> _combineLatest<T1, T2, R>(
    Stream<T1> first,
    Stream<T2> second,
    R Function(T1, T2) combiner,
  ) async* {
    late T1 valueA;
    late T2 valueB;
    var haveA = false;
    var haveB = false;

    final controller = StreamController<R>();
    final subA = first.listen((value) {
      valueA = value;
      haveA = true;
      if (haveB) controller.add(combiner(valueA, valueB));
    });
    final subB = second.listen((value) {
      valueB = value;
      haveB = true;
      if (haveA) controller.add(combiner(valueA, valueB));
    });
    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
      controller.close();
    };

    yield* controller.stream;
  }
}

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ShoppingRepositoryImpl(database.shoppingDao, ref.watch(clockProvider));
});

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_item.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_list.dart';
import 'package:personal_offline/features/shopping/domain/repositories/shopping_repository.dart';

void main() {
  late db.AppDatabase database;
  late ShoppingRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = ShoppingRepositoryImpl(database.shoppingDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('createList memakai nilai default dan timestamp clock', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );

    final list = await repository.getById(id);

    expect(list, isNotNull);
    expect(list!.title, 'Belanja');
    expect(list.status, ShoppingListStatus.open);
    expect(list.date, isNull);
    expect(list.createdAt, start);
    expect(list.items, isEmpty);
  });

  test('addItems menambah item berurutan dan melewatkan nama kosong', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );

    await repository.addItems(id, ['Beras', '  ', 'Minyak', 'Telur']);

    final list = await repository.getById(id);
    expect(list!.items.map((i) => i.name), ['Beras', 'Minyak', 'Telur']);
    expect(list.items.map((i) => i.sortOrder), [0, 1, 2]);
    expect(list.items.every((i) => !i.isChecked), isTrue);
  });

  test('updateItem mengubah isChecked dan updatedAt', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );
    await repository.addItems(id, ['Telur']);
    final item = (await repository.getById(id))!.items.single;

    clock.value = start.add(const Duration(minutes: 5));
    await repository.updateItem(item.copyWith(isChecked: true));

    final updated = (await repository.getById(id))!.items.single;
    expect(updated.isChecked, isTrue);
    expect(updated.updatedAt, start.add(const Duration(minutes: 5)));
    expect(updated.createdAt, item.createdAt);
  });

  test('deleteItem menghapus item dan updateItem tanpa id false', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );
    await repository.addItems(id, ['Telur', 'Susu']);
    final item = (await repository.getById(id))!.items.first;

    expect(await repository.deleteItem(item.id!), isTrue);
    expect((await repository.getById(id))!.items.single.name, 'Susu');

    expect(
      await repository.updateItem(ShoppingItem(id: 999, listId: id, name: 'X')),
      isFalse,
    );
  });

  test('updateList mengubah status menjadi selesai lalu dibuka lagi', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );
    final list = (await repository.getById(id))!;

    await repository.updateList(list.copyWith(status: ShoppingListStatus.done));
    expect((await repository.getById(id))!.status, ShoppingListStatus.done);

    await repository.updateList(list.copyWith(status: ShoppingListStatus.open));
    expect((await repository.getById(id))!.status, ShoppingListStatus.open);
  });

  test('deleteList menghapus daftar beserta itemnya (cascade)', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );
    await repository.addItems(id, ['Beras']);

    expect(await repository.deleteList(id), isTrue);
    expect(await repository.getById(id), isNull);

    final itemRows = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM shopping_items WHERE list_id = $id',
        )
        .get();
    expect(itemRows.single.data['total'], 0);
  });

  test('watchLists memancarkan daftar lengkap dengan item', () async {
    final id = await repository.createList(
      const ShoppingList(title: 'Belanja'),
    );
    await repository.addItems(id, ['Beras', 'Telur']);

    final emitted = await repository.watchLists().first;

    expect(emitted, hasLength(1));
    expect(emitted.single.title, 'Belanja');
    expect(emitted.single.items.map((i) => i.name), ['Beras', 'Telur']);
  });

  test('getAll memakai watchItems dalam urutan sortOrder', () async {
    await repository.createList(const ShoppingList(title: 'Satu'));
    final id = await repository.createList(const ShoppingList(title: 'Dua'));
    await repository.addItems(id, ['Z', 'A']);
    await repository.addItems(id, ['B']);

    final all = await repository.getAll();

    expect(all, hasLength(2));
    expect(all.last.items.map((i) => i.name), ['Z', 'A', 'B']);
  });
}

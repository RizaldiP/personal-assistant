import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_list.dart';
import 'package:personal_offline/features/shopping/presentation/providers/shopping_controller.dart';

import '../../../helpers/fake_shopping_repository.dart';

void main() {
  late FakeShoppingRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeShoppingRepository();
    container = ProviderContainer(
      overrides: [shoppingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  ShoppingController controller() =>
      container.read(shoppingControllerProvider.notifier);

  test('ensureActiveList membuat daftar Belanja saat belum ada', () async {
    final id = await controller().ensureActiveList();

    expect(id, 1);
    expect(repository.lists, hasLength(1));
    expect(repository.lists.single.title, 'Belanja');
    expect(repository.lists.single.status, ShoppingListStatus.open);
  });

  test('ensureActiveList mengembalikan daftar yang masih terbuka', () async {
    final openId = await controller().createList('Pasar');
    await controller().createList('Selesai sudah');

    final active = await controller().ensureActiveList();

    expect(active, openId);
  });

  test('addItems membuat daftar dan menambahkan item', () async {
    await controller().addItems(['Beras', 'Minyak', 'Telur']);

    final list = repository.lists.single;
    expect(list.title, 'Belanja');
    expect(list.items.map((i) => i.name), ['Beras', 'Minyak', 'Telur']);
  });

  test('addItems menambah ke daftar terbuka yang sudah ada', () async {
    await controller().addItems(['Beras']);
    await controller().addItems(['Telur']);

    expect(repository.lists, hasLength(1));
    expect(repository.lists.single.items.map((i) => i.name), [
      'Beras',
      'Telur',
    ]);
  });

  test('toggleItem menandai checklist', () async {
    await controller().addItems(['Telur']);
    final item = repository.lists.single.items.single;

    await controller().toggleItem(item, true);

    expect(repository.lists.single.items.single.isChecked, isTrue);
  });

  test('removeItem menghapus item', () async {
    await controller().addItems(['Telur', 'Susu']);
    final item = repository.lists.single.items.first;

    await controller().removeItem(item);

    expect(repository.lists.single.items.single.name, 'Susu');
  });

  test('setDone dan dibuka kembali', () async {
    await controller().addItems(['Telur']);
    final list = repository.lists.single;

    await controller().setDone(list, true);
    expect(repository.lists.single.status, ShoppingListStatus.done);

    await controller().setDone(repository.lists.single, false);
    expect(repository.lists.single.status, ShoppingListStatus.open);
  });

  test('deleteList menghapus daftar', () async {
    final id = await controller().createList('Pasar');
    await controller().addItems(['Telur']);

    await controller().deleteList(id);

    expect(repository.lists, isEmpty);
  });
}

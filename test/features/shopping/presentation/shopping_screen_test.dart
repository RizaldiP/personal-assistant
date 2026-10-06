import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_item.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_list.dart';
import 'package:personal_offline/features/shopping/presentation/screens/shopping_screen.dart';

import '../../../helpers/fake_shopping_repository.dart';

void main() {
  Future<void> pumpShopping(
    WidgetTester tester,
    FakeShoppingRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shoppingRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ShoppingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ShoppingList listWith(
    String title, {
    List<String> items = const [],
    ShoppingListStatus status = ShoppingListStatus.open,
  }) {
    return ShoppingList(
      id: 1,
      title: title,
      status: status,
      items: [
        for (var i = 0; i < items.length; i++)
          ShoppingItem(id: i + 1, listId: 1, name: items[i], sortOrder: i),
      ],
    );
  }

  testWidgets('daftar kosong menampilkan empty state dan FAB', (tester) async {
    await pumpShopping(tester, FakeShoppingRepository());

    expect(find.text('Belum ada daftar belanja'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB menambah item dan membuat daftar', (tester) async {
    await pumpShopping(tester, FakeShoppingRepository());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Tambah item belanja'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Telur');
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // AppBar berjudul 'Belanja' dan bagian daftar terbuka juga 'Belanja'.
    expect(find.text('Belanja'), findsNWidgets(2));
    expect(find.text('Telur'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('checklist item bisa diceklis', (tester) async {
    final repository = FakeShoppingRepository(
      seed: [
        listWith('Belanja', items: ['Telur', 'Susu']),
      ],
    );
    await pumpShopping(tester, repository);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(repository.lists.single.items.first.isChecked, isTrue);
  });

  testWidgets('item bisa dihapus dari daftar', (tester) async {
    final repository = FakeShoppingRepository(
      seed: [
        listWith('Belanja', items: ['Telur', 'Susu']),
      ],
    );
    await pumpShopping(tester, repository);

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Telur'), findsNothing);
    expect(find.text('Susu'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('daftar selesai dikelompokkan di bawah SELESAI', (tester) async {
    final repository = FakeShoppingRepository(
      seed: [
        listWith('Pasar', items: ['Beras']),
        listWith('Buah', items: ['Apel'], status: ShoppingListStatus.done),
      ],
    );
    await pumpShopping(tester, repository);

    expect(find.text('BELANJA'), findsOneWidget);
    expect(find.text('SELESAI'), findsOneWidget);
    expect(find.text('Pasar'), findsOneWidget);
    expect(find.text('Buah'), findsOneWidget);
    expect(find.text('0/1'), findsNWidgets(2));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/finance/presentation/screens/finance_screen.dart';

import '../../../helpers/fake_expense_repository.dart';

void main() {
  final fixedClock = FixedClock(DateTime(2026, 10, 5, 9));

  Expense expense({
    required int amount,
    required ExpenseCategory category,
    required String description,
    String date = '2026-10-05',
    int? id,
  }) => Expense(
    id: id,
    amount: amount,
    category: category,
    description: description,
    date: date,
  );

  Future<void> pumpFinance(
    WidgetTester tester,
    FakeExpenseRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(fixedClock),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kosong menampilkan empty state dan FAB', (tester) async {
    await pumpFinance(tester, FakeExpenseRepository());

    expect(find.text('Belum ada pengeluaran'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB menambah pengeluaran dan muncul di daftar', (tester) async {
    final repository = FakeExpenseRepository();
    await pumpFinance(tester, repository);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Tambah pengeluaran'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '25000');
    await tester.enterText(find.byType(TextField).at(1), 'Makan ayam');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.expenses, hasLength(1));
    expect(repository.expenses.single.amount, 25000);
    expect(repository.expenses.single.description, 'Makan ayam');
    expect(repository.expenses.single.date, '2026-10-05');

    expect(find.text('Makan ayam'), findsOneWidget);
    expect(find.text('-Rp 25.000'), findsOneWidget);
    expect(
      find.text('Rp 25.000'),
      findsNWidgets(2),
      reason: 'ringkasan hari ini dan bulan ini',
    );
  });

  testWidgets('ringkasan menampilkan total hari ini dan bulan ini', (
    tester,
  ) async {
    final repository = FakeExpenseRepository(
      seed: [
        expense(
          amount: 10000,
          category: ExpenseCategory.makanan,
          description: 'Makan',
          date: '2026-10-05',
          id: 1,
        ),
        expense(
          amount: 40000,
          category: ExpenseCategory.transport,
          description: 'Tol',
          date: '2026-10-02',
          id: 2,
        ),
        expense(
          amount: 20000,
          category: ExpenseCategory.makanan,
          description: 'Makan lagi',
          date: '2026-09-30',
          id: 3,
        ),
      ],
    );
    await pumpFinance(tester, repository);

    expect(find.text('Rp 10.000'), findsOneWidget, reason: 'total hari ini');
    expect(
      find.text('Rp 50.000'),
      findsOneWidget,
      reason: 'total bulan ini (10/05 + 10/02)',
    );
    expect(find.text('Belanja'), findsNothing);
  });

  testWidgets('daftar dikelompokkan per tanggal dengan label', (tester) async {
    final repository = FakeExpenseRepository(
      seed: [
        expense(
          amount: 1000,
          category: ExpenseCategory.lainnya,
          description: 'Kopi',
          id: 1,
        ),
        expense(
          amount: 2000,
          category: ExpenseCategory.lainnya,
          description: 'Ojek',
          date: '2026-10-04',
          id: 2,
        ),
      ],
    );
    await pumpFinance(tester, repository);

    // 'Hari ini' dua kali: label ringkasan + label kelompok tanggal.
    expect(find.text('Hari ini'), findsNWidgets(2));
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('Kopi'), findsOneWidget);
    expect(find.text('Ojek'), findsOneWidget);
  });

  testWidgets('item bisa dihapus', (tester) async {
    final repository = FakeExpenseRepository(
      seed: [
        expense(
          amount: 5000,
          category: ExpenseCategory.lainnya,
          description: 'Jajan',
          id: 7,
        ),
      ],
    );
    await pumpFinance(tester, repository);

    await tester.tap(find.byTooltip('Hapus pengeluaran'));
    await tester.pumpAndSettle();

    expect(repository.expenses, isEmpty);
    expect(find.text('Belum ada pengeluaran'), findsOneWidget);
  });

  testWidgets('budget bisa diatur dari dialog dan sisa budget tampil', (
    tester,
  ) async {
    final repository = FakeExpenseRepository(
      seed: [
        expense(
          amount: 30000,
          category: ExpenseCategory.makanan,
          description: 'Makan',
          id: 1,
        ),
      ],
    );
    await pumpFinance(tester, repository);

    await tester.tap(find.byTooltip('Atur budget'));
    await tester.pumpAndSettle();

    expect(find.text('Budget bulan ini'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '100000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.budget, 100000);
    expect(
      find.textContaining('Budget bulan ini · Rp 100.000'),
      findsOneWidget,
    );
    expect(find.text('Sisa Rp 70.000'), findsOneWidget);
  });

  testWidgets('melebihi budget menampilkan peringatan', (tester) async {
    final repository = FakeExpenseRepository(
      seed: [
        expense(
          amount: 120000,
          category: ExpenseCategory.lainnya,
          description: 'Belanja',
          id: 1,
        ),
      ],
      budget: 100000,
    );
    await pumpFinance(tester, repository);

    expect(find.textContaining('Melebihi budget'), findsOneWidget);
  });
}

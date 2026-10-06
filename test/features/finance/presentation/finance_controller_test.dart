import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/finance/presentation/providers/finance_controller.dart';

import '../../../helpers/fake_expense_repository.dart';

void main() {
  late FakeExpenseRepository repository;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeExpenseRepository();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  FinanceController controller() =>
      container.read(financeControllerProvider.notifier);

  test('addExpense menyimpan dengan tanggal default hari ini', () async {
    await controller().addExpense(
      amount: 25000,
      category: ExpenseCategory.makanan,
      description: 'Ayam',
    );

    final expense = repository.expenses.single;
    expect(expense.amount, 25000);
    expect(expense.category, ExpenseCategory.makanan);
    expect(expense.description, 'Ayam');
    expect(expense.date, '2026-10-05');
  });

  test('addExpense memakai tanggal yang diberikan', () async {
    await controller().addExpense(
      amount: 50000,
      category: ExpenseCategory.transport,
      description: 'Bensin',
      date: '2026-10-06',
      source: 'rule',
      confidence: 0.95,
    );

    final expense = repository.expenses.single;
    expect(expense.date, '2026-10-06');
    expect(expense.source, 'rule');
    expect(expense.confidence, 0.95);
  });

  test('removeExpense menghapus pengeluaran', () async {
    final id = await controller().addExpense(
      amount: 10000,
      category: ExpenseCategory.lainnya,
      description: 'Jajan',
    );

    await controller().removeExpense(id);

    expect(repository.expenses, isEmpty);
  });

  test('setBudget menyimpan dan memicu provider budget baru', () async {
    expect(await container.read(financeBudgetProvider.future), isNull);

    await controller().setBudget(500000);
    expect(repository.budget, 500000);
    expect(await container.read(financeBudgetProvider.future), 500000);

    await controller().setBudget(null);
    expect(repository.budget, isNull);
  });

  test('expensesProvider memaparkan semua pengeluaran', () async {
    final subscription = container.listen(
      expensesProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    await controller().addExpense(
      amount: 1000,
      category: ExpenseCategory.lainnya,
      description: 'Kopi',
    );
    await controller().addExpense(
      amount: 2000,
      category: ExpenseCategory.transport,
      description: 'Ojek',
    );

    Future<void> waitForData() async {
      for (var i = 0; i < 100; i++) {
        final expenses = container.read(expensesProvider).asData?.value;
        if (expenses != null && expenses.length == 2) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await waitForData();
    expect(container.read(expensesProvider).asData?.value, hasLength(2));
  });
}

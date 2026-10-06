import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';

/// Seluruh pengeluaran urut tanggal terbaru.
final expensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(expenseRepositoryProvider).watchExpenses(),
);

/// Budget bulanan; null bila belum ditetapkan.
final financeBudgetProvider = FutureProvider<int?>(
  (ref) => ref.watch(expenseRepositoryProvider).getBudget(),
);

class FinanceController extends Notifier<void> {
  @override
  void build() {}

  /// Menyimpan pengeluaran; tanggal default = hari ini (dari clock).
  Future<int> addExpense({
    required int amount,
    required ExpenseCategory category,
    required String description,
    String? date,
    String? paymentMethod,
    String? source,
    double? confidence,
    String? rawInput,
  }) {
    final expense = Expense(
      amount: amount,
      category: category,
      description: description,
      date: date ?? _isoDate(ref.read(clockProvider).now()),
      paymentMethod: paymentMethod,
      source: source,
      rawInput: rawInput,
      confidence: confidence,
    );
    return ref.read(expenseRepositoryProvider).create(expense);
  }

  Future<bool> removeExpense(int id) =>
      ref.read(expenseRepositoryProvider).deleteById(id);

  Future<void> setBudget(int? amount) async {
    await ref.read(expenseRepositoryProvider).setBudget(amount);
    ref.invalidate(financeBudgetProvider);
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final financeControllerProvider = NotifierProvider<FinanceController, void>(
  FinanceController.new,
);

import 'dart:async';

import 'package:personal_offline/features/finance/domain/entities/expense.dart';
import 'package:personal_offline/features/finance/domain/repositories/expense_repository.dart';

/// Fake [ExpenseRepository] untuk test controller, layar, dan alur chat.
///
/// Data disimpan dalam memori; setiap perubahan memancarkan daftar terbaru
/// melalui stream agar UI yang menonton ikut terbarui.
class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository({List<Expense> seed = const [], this.budget}) {
    _expenses.addAll(seed);
  }

  final List<Expense> _expenses = [];
  late final StreamController<List<Expense>> _changes =
      StreamController.broadcast(
        sync: true,
        onListen: () => _changes.add(_snapshot()),
      );

  int _nextId = 1;
  int? budget;

  List<Expense> get expenses => List.unmodifiable(_expenses);

  void _emit() => _changes.add(_snapshot());

  List<Expense> _snapshot() => List.of(_expenses);

  @override
  Stream<List<Expense>> watchExpenses() => _changes.stream;

  @override
  Future<List<Expense>> getAll() async => _snapshot();

  @override
  Future<Expense?> getById(int id) async {
    for (final expense in _expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<int> create(Expense expense) async {
    final id = _nextId++;
    _expenses.add(expense.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<bool> update(Expense expense) async {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index == -1) return false;
    _expenses[index] = expense;
    _emit();
    return true;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = _expenses.length;
    _expenses.removeWhere((e) => e.id == id);
    _emit();
    return _expenses.length != before;
  }

  @override
  Future<int> dailyTotal(String date) async => _expenses
      .where((e) => e.date == date)
      .fold<int>(0, (sum, e) => sum + e.amount);

  @override
  Future<int> monthlyTotal(String month) async {
    final total = _expenses
        .where((e) => e.date.startsWith(month))
        .fold<int>(0, (sum, e) => sum + e.amount);
    return total;
  }

  @override
  Future<int?> getBudget() async => budget;

  @override
  Future<void> setBudget(int? amount) async {
    budget = amount;
  }
}

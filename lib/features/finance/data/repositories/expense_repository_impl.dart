import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/expense_dao.dart';
import 'package:personal_offline/core/database/daos/user_preferences_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';

/// Implementasi [ExpenseRepository] berbasis drift.
///
/// Budget bulanan disimpan pada tabel `user_preferences` (key `finance_budget`)
/// sebagai integer dalam teks — cukup untuk "simple budget".
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._dao, this._prefsDao, this._clock);

  static const String _budgetKey = 'finance_budget';

  final ExpenseDao _dao;
  final UserPreferencesDao _prefsDao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Expense>> watchExpenses() =>
      _dao.watchAll().map((rows) => rows.map(_toExpense).toList());

  @override
  Future<List<Expense>> getAll() async =>
      (await _dao.getAll()).map(_toExpense).toList();

  @override
  Future<Expense?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toExpense(row);
  }

  @override
  Future<int> create(Expense expense) =>
      _dao.insert(_insertCompanion(expense, _now));

  @override
  Future<bool> update(Expense expense) async {
    final id = expense.id;
    if (id == null) return false;
    return _dao.updateById(id, _updateCompanion(expense, _now));
  }

  @override
  Future<bool> deleteById(int id) => _dao.deleteById(id);

  @override
  Future<int> dailyTotal(String date) => _dao.totalBetween(date, date);

  @override
  Future<int> monthlyTotal(String month) {
    final parsed = DateTime.parse('$month-01');
    final lastDay = DateTime(parsed.year, parsed.month + 1, 0);
    return _dao.totalBetween('$month-01', _isoDate(lastDay));
  }

  @override
  Future<int?> getBudget() async {
    final raw = await _prefsDao.get(_budgetKey);
    return int.tryParse(raw ?? '');
  }

  @override
  Future<void> setBudget(int? amount) async {
    if (amount == null) {
      await _prefsDao.remove(_budgetKey);
    } else {
      await _prefsDao.set(_budgetKey, amount.toString(), nowEpochMs: _now);
    }
  }

  static Expense _toExpense(db.Expense row) => Expense(
    id: row.id,
    amount: row.amount,
    currency: row.currency,
    category: ExpenseCategory.parse(row.category),
    description: row.description,
    date: row.date,
    paymentMethod: row.paymentMethod,
    source: row.source,
    rawInput: row.rawInput,
    confidence: row.confidence,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static db.ExpensesCompanion _insertCompanion(Expense expense, int now) =>
      db.ExpensesCompanion.insert(
        amount: expense.amount,
        currency: Value(expense.currency),
        category: Value(expense.category.storageValue),
        description: expense.description,
        date: expense.date,
        paymentMethod: Value(expense.paymentMethod),
        source: Value(expense.source),
        rawInput: Value(expense.rawInput),
        confidence: Value(expense.confidence),
        createdAt: now,
        updatedAt: now,
      );

  static db.ExpensesCompanion _updateCompanion(Expense expense, int now) =>
      db.ExpensesCompanion(
        amount: Value(expense.amount),
        currency: Value(expense.currency),
        category: Value(expense.category.storageValue),
        description: Value(expense.description),
        date: Value(expense.date),
        paymentMethod: Value(expense.paymentMethod),
        source: Value(expense.source),
        rawInput: Value(expense.rawInput),
        confidence: Value(expense.confidence),
        updatedAt: Value(now),
      );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ExpenseRepositoryImpl(
    database.expenseDao,
    database.userPreferencesDao,
    ref.watch(clockProvider),
  );
});

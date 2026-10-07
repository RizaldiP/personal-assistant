import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/expense_table.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  Stream<List<Expense>> watchAll() =>
      (select(expenses)..orderBy([
            (e) => OrderingTerm.desc(e.date),
            (e) => OrderingTerm.desc(e.id),
          ]))
          .watch();

  Future<List<Expense>> getAll() =>
      (select(expenses)..orderBy([
            (e) => OrderingTerm.desc(e.date),
            (e) => OrderingTerm.desc(e.id),
          ]))
          .get();

  Future<Expense?> getById(int id) =>
      (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Pencarian deskripsi/kategori untuk global search (PHASE 13).
  Future<List<Expense>> search(String query, {int limit = 30}) {
    final like = '%${_escapeLike(query)}%';
    return (select(expenses)
          ..where(
            (e) =>
                e.description.like(like, escapeChar: '\\') |
                e.category.like(like, escapeChar: '\\'),
          )
          ..orderBy([
            (e) => OrderingTerm.desc(e.date),
            (e) => OrderingTerm.desc(e.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> insert(ExpensesCompanion entry) => into(expenses).insert(entry);

  Future<bool> updateById(int id, ExpensesCompanion entry) async {
    final updated = await (update(
      expenses,
    )..where((e) => e.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteById(int id) async {
    final deleted = await (delete(
      expenses,
    )..where((e) => e.id.equals(id))).go();
    return deleted > 0;
  }

  /// Total nominal pada rentang tanggal `YYYY-MM-DD` (inklusif).
  Future<int> totalBetween(String from, String to) async {
    final row =
        await (selectOnly(expenses)
              ..addColumns([expenses.amount.sum()])
              ..where(
                expenses.date.isBiggerOrEqualValue(from) &
                    expenses.date.isSmallerOrEqualValue(to),
              ))
            .getSingle();
    return row.read(expenses.amount.sum()) ?? 0;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

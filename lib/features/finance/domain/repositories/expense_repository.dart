import 'package:personal_offline/features/finance/domain/entities/expense.dart';

/// Repositori pengeluaran + budget sederhana.
abstract interface class ExpenseRepository {
  /// Semua pengeluaran urut tanggal terbaru.
  Stream<List<Expense>> watchExpenses();

  Future<List<Expense>> getAll();

  Future<Expense?> getById(int id);

  /// Menyimpan pengeluaran baru; mengembalikan id.
  Future<int> create(Expense expense);

  Future<bool> update(Expense expense);

  Future<bool> deleteById(int id);

  /// Total nominal pada tanggal `YYYY-MM-DD`.
  Future<int> dailyTotal(String date);

  /// Total nominal pada bulan `YYYY-MM` (pertama sd terakhir bulan).
  Future<int> monthlyTotal(String month);

  /// Budget bulanan (integer), null bila belum ditetapkan.
  Future<int?> getBudget();

  Future<void> setBudget(int? amount);
}

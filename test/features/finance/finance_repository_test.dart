import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/finance/domain/repositories/expense_repository.dart';

void main() {
  late db.AppDatabase database;
  late ExpenseRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = ExpenseRepositoryImpl(
      database.expenseDao,
      database.userPreferencesDao,
      clock,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('create menyimpan data, default, dan timestamp clock', () async {
    final id = await repository.create(
      Expense(
        amount: 25000,
        category: ExpenseCategory.makanan,
        description: 'Ayam',
        date: '2026-10-05',
        source: 'rule',
        rawInput: 'tadi makan ayam 25 ribu',
        confidence: 0.95,
      ),
    );

    final expense = await repository.getById(id);
    expect(expense, isNotNull);
    expect(expense!.amount, 25000);
    expect(expense.currency, 'IDR');
    expect(expense.category, ExpenseCategory.makanan);
    expect(expense.description, 'Ayam');
    expect(expense.date, '2026-10-05');
    expect(expense.source, 'rule');
    expect(expense.rawInput, 'tadi makan ayam 25 ribu');
    expect(expense.confidence, 0.95);
    expect(expense.createdAt, start);
    expect(expense.updatedAt, start);
  });

  test(
    'dailyTotal dan monthlyTotal menjumlahkan antar rentang tanggal',
    () async {
      await repository.create(
        Expense(
          amount: 10000,
          category: ExpenseCategory.makanan,
          description: 'A',
          date: '2026-09-30',
        ),
      );
      await repository.create(
        Expense(
          amount: 25000,
          category: ExpenseCategory.makanan,
          description: 'B',
          date: '2026-10-05',
        ),
      );
      await repository.create(
        Expense(
          amount: 75000,
          category: ExpenseCategory.transport,
          description: 'C',
          date: '2026-10-05',
        ),
      );
      await repository.create(
        Expense(
          amount: 5000,
          category: ExpenseCategory.lainnya,
          description: 'D',
          date: '2026-10-20',
        ),
      );

      expect(await repository.dailyTotal('2026-10-05'), 100000);
      expect(await repository.dailyTotal('2026-10-04'), 0);
      expect(await repository.monthlyTotal('2026-10'), 105000);
      expect(await repository.monthlyTotal('2026-09'), 10000);
    },
  );

  test('update mengubah nominal, kategori, dan updatedAt', () async {
    final id = await repository.create(
      Expense(
        amount: 10000,
        category: ExpenseCategory.makanan,
        description: 'Makan',
        date: '2026-10-05',
      ),
    );

    clock.value = start.add(const Duration(minutes: 5));
    final expense = await repository.getById(id);
    final updated = await repository.update(
      expense!.copyWith(amount: 15000, category: ExpenseCategory.hiburan),
    );

    expect(updated, isTrue);
    final reloaded = await repository.getById(id);
    expect(reloaded!.amount, 15000);
    expect(reloaded.category, ExpenseCategory.hiburan);
    expect(reloaded.updatedAt, start.add(const Duration(minutes: 5)));
    expect(reloaded.createdAt, start);
  });

  test('update tanpa id false dan deleteById menghapus', () async {
    expect(
      await repository.update(
        const Expense(
          amount: 100,
          category: ExpenseCategory.lainnya,
          description: 'X',
          date: '2026-10-05',
        ),
      ),
      isFalse,
    );

    final id = await repository.create(
      Expense(
        amount: 3000,
        category: ExpenseCategory.lainnya,
        description: 'Kopi',
        date: '2026-10-05',
      ),
    );
    expect(await repository.deleteById(id), isTrue);
    expect(await repository.getById(id), isNull);
  });

  test('watchExpenses berurutan tanggal terbaru dan id terbaru', () async {
    final first = await repository.create(
      Expense(
        amount: 1000,
        category: ExpenseCategory.lainnya,
        description: 'Lama',
        date: '2026-10-01',
      ),
    );
    final second = await repository.create(
      Expense(
        amount: 2000,
        category: ExpenseCategory.lainnya,
        description: 'Baru',
        date: '2026-10-03',
      ),
    );

    final emitted = await repository.watchExpenses().first;
    expect(emitted.map((e) => e.id), [second, first]);
  });

  test('budget disimpan dan dapat dihapus lewat user_preferences', () async {
    expect(await repository.getBudget(), isNull);

    await repository.setBudget(1000000);
    expect(await repository.getBudget(), 1000000);

    final row = await database.userPreferencesDao.get('finance_budget');
    expect(row, '1000000');

    await repository.setBudget(null);
    expect(await repository.getBudget(), isNull);
  });
}

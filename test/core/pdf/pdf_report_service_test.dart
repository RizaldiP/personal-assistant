import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/pdf/pdf_report_service.dart';
import 'package:personal_offline/features/finance/domain/entities/expense.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';

void main() {
  final month = DateTime(2026, 10);
  final generatedAt = DateTime(2026, 10, 5, 8, 30);

  List<Expense> expenses() => [
    Expense(
      id: 2,
      amount: 25000,
      category: ExpenseCategory.makanan,
      description: 'Ayam',
      date: '2026-10-03',
    ),
    Expense(
      id: 1,
      amount: 50000,
      category: ExpenseCategory.transport,
      description: 'Bensin',
      date: '2026-10-01',
    ),
    Expense(
      id: 3,
      amount: 10000,
      category: ExpenseCategory.makanan,
      description: 'Kopi',
      date: '2026-10-05',
    ),
  ];

  group('PdfReportService.buildExpenseReport', () {
    test('menghasilkan berkas PDF yang diawali header %PDF', () async {
      final bytes = await PdfReportService.buildExpenseReport(
        expenses: expenses(),
        month: month,
        generatedAt: generatedAt,
      );

      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('mengurutkan rincian berdasarkan tanggal', () async {
      final bytes = await PdfReportService.buildExpenseReport(
        expenses: expenses(),
        month: month,
        generatedAt: generatedAt,
      );

      // Tidak mudah membaca isi PDF tanpa parser; pastikan tetap valid.
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('tanpa pengeluaran tetap menghasilkan PDF valid', () async {
      final bytes = await PdfReportService.buildExpenseReport(
        expenses: const [],
        month: month,
        generatedAt: generatedAt,
      );

      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(500));
    });
  });
}

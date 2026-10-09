import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/finance/domain/entities/expense.dart';
import '../../shared/formatters/currency_formats.dart';
import '../../shared/formatters/date_formats.dart';

/// Pembuat laporan PDF pengeluaran (PHASE 14).
///
/// Murni Dart: menghasilkan byte PDF dari data yang sudah diambil repository.
/// Tidak membaca database dan tidak menyentuh plugin platform.
abstract final class PdfReportService {
  /// Laporan pengeluaran satu bulan: ringkasan total per kategori lalu
  /// rincian per baris. [expenses] boleh kosong (tetap menghasilkan PDF
  /// berisi keterangan tidak ada data).
  static Future<List<int>> buildExpenseReport({
    required List<Expense> expenses,
    required DateTime month,
    required DateTime generatedAt,
  }) async {
    final doc = pw.Document();
    final rows = [...expenses]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

    final total = rows.fold<int>(0, (sum, expense) => sum + expense.amount);
    final perCategory = <String, int>{};
    for (final expense in rows) {
      perCategory.update(
        expense.category.label,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    const heading = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
    const body = pw.TextStyle(fontSize: 10);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Laporan Pengeluaran',
            style: const pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Periode: ${DateFormats.monthName(month.month)} ${month.year}',
            style: body,
          ),
          pw.Text(
            'Dibuat: ${DateFormats.longFromDate(generatedAt)} · '
            '${DateFormats.shortTimeOfDay(generatedAt)}',
            style: body,
          ),
          pw.SizedBox(height: 16),
          pw.Text('Ringkasan', style: heading),
          pw.SizedBox(height: 4),
          pw.Text('Total: ${CurrencyFormats.idr(total)}', style: body),
          for (final entry in perCategory.entries)
            pw.Text(
              '${entry.key}: ${CurrencyFormats.idr(entry.value)}',
              style: body,
            ),
          pw.SizedBox(height: 16),
          if (rows.isEmpty)
            pw.Text('Tidak ada pengeluaran pada periode ini.', style: body)
          else ...[
            pw.Text('Rincian', style: heading),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Tanggal', 'Deskripsi', 'Kategori', 'Jumlah'],
              data: [
                for (final expense in rows)
                  [
                    expense.date,
                    expense.description,
                    expense.category.label,
                    CurrencyFormats.idr(expense.amount),
                  ],
              ],
              headerStyle: const pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: body,
              cellPadding: const pw.EdgeInsets.all(4),
              headerPadding: const pw.EdgeInsets.all(4),
              cellAlignments: {3: pw.Alignment.centerRight},
              headerAlignments: {3: pw.Alignment.centerRight},
            ),
          ],
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Halaman ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return doc.save();
  }
}

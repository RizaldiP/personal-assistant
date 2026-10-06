import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/nlp/date_parser.dart';

void main() {
  group('DateParser.resolusi relatif', () {
    final today = DateTime(2026, 10, 6);

    test('hari ini', () {
      final expr = DateParser(now: today).parse('bayar listrik hari ini');
      expect(expr, isNotNull);
      expect(expr!.date, DateTime(2026, 10, 6));
      expect(expr.matched, 'hari ini');
    });

    test('besok', () {
      final expr = DateParser(now: today).parse('besok jam 8 bayar listrik');
      expect(expr!.date, DateTime(2026, 10, 7));
    });

    test('lusa', () {
      final expr = DateParser(now: today).parse('lusa ketemu rekan');
      expect(expr!.date, DateTime(2026, 10, 8));
    });

    test('minggu depan', () {
      final expr = DateParser(now: today).parse('minggu depan rapat');
      expect(expr!.date, DateTime(2026, 10, 13));
    });

    test('bulan depan', () {
      final expr = DateParser(now: today).parse('bulan depan sewa kos');
      expect(expr!.date, DateTime(2026, 11, 6));
    });

    test('N hari lagi', () {
      final expr = DateParser(now: today).parse('3 hari lagi servis motor');
      expect(expr!.date, DateTime(2026, 10, 9));
    });

    test('N minggu lagi', () {
      final expr = DateParser(now: today).parse('2 minggu lagi ujian');
      expect(expr!.date, DateTime(2026, 10, 20));
    });

    test('N bulan lagi', () {
      final expr = DateParser(now: today).parse('1 bulan lagi bayar kontrakan');
      expect(expr!.date, DateTime(2026, 11, 6));
    });

    test('nama hari', () {
      expect(
        DateParser(now: today).parse('rabu rapat tim')!.date,
        DateTime(2026, 10, 7),
      );
      expect(
        DateParser(now: today).parse('senin laporan')!.date,
        DateTime(2026, 10, 12),
      );
    });

    test('tanggal N tanpa bulan menuju hari ke-N berikutnya', () {
      final expr = DateParser(now: today).parse('tanggal 25 gajian');
      expect(expr!.date, DateTime(2026, 10, 25));
    });

    test('tanggal N dengan bulan', () {
      final expr = DateParser(now: today).parse('tanggal 15 november servis');
      expect(expr!.date, DateTime(2026, 11, 15));
    });
  });

  group('DateParser.tanpa ekspresi tanggal', () {
    test('mengembalikan null', () {
      expect(DateParser(now: DateTime(2026, 10, 6)).parse('qwerty'), isNull);
      expect(
        DateParser(now: DateTime(2026, 10, 6)).parse('makan 25 ribu'),
        isNull,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/nlp/amount_parser.dart';

void main() {
  group('AmountParser.mengikuti format wajib', () {
    test('10 ribu', () {
      final expr = AmountParser().parse('tadi makan 10 ribu');
      expect(expr!.value, 10000);
      expect(expr.matched, '10 ribu');
    });

    test('10rb', () {
      expect(AmountParser().parse('beli pulsa 10rb')!.value, 10000);
    });

    test('10k', () {
      expect(AmountParser().parse('isyarah 10k')!.value, 10000);
    });

    test('10.000', () {
      expect(AmountParser().parse('keluar 10.000 untuk parkir')!.value, 10000);
    });

    test('1 juta', () {
      expect(AmountParser().parse('1 juta untuk pindah')!.value, 1000000);
    });

    test('1jt', () {
      expect(AmountParser().parse('transfer 1jt')!.value, 1000000);
    });

    test('Rp50.000', () {
      expect(AmountParser().parse('Rp50.000 untuk makan')!.value, 50000);
    });

    test('50 ribu rupiah', () {
      expect(AmountParser().parse('50 ribu rupiah habis')!.value, 50000);
    });

    test('2,5 juta', () {
      expect(AmountParser().parse('2,5 juta untuk kos')!.value, 2500000);
    });

    test('Rp25.000', () {
      expect(AmountParser().parse('Rp25.000')!.value, 25000);
    });
  });

  group('AmountParser.mengabaikan bukan nominal', () {
    test('angka tanggal tidak dianggap nominal', () {
      expect(AmountParser().parse('tanggal 25 gajian'), isNull);
    });

    test('teks bebas tanpa angka', () {
      expect(AmountParser().parse('kerjakan laporan'), isNull);
    });
  });
}

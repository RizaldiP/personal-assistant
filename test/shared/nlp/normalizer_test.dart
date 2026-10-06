import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/nlp/normalizer.dart';

void main() {
  group('Normalizer.normalize', () {
    test('huruf kecil, trencana, tanpa spasi ganda', () {
      expect(Normalizer.normalize('  Besok   beli SUSU  '), 'besok beli susu');
    });

    test('string kosong tetap kosong', () {
      expect(Normalizer.normalize('   '), '');
    });
  });

  group('Normalizer.capitalizeFirst', () {
    test('huruf pertama dikapital', () {
      expect(Normalizer.capitalizeFirst('bayar listrik'), 'Bayar listrik');
    });

    test('string kosong tetap kosong', () {
      expect(Normalizer.capitalizeFirst(''), '');
    });
  });
}

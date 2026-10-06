import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/nlp/time_parser.dart';

void main() {
  group('TimeParser.klock dengan kata jam', () {
    test('jam 8 -> 08:00', () {
      final expr = TimeParser().parse('besok jam 8 bayar listrik');
      expect(expr!.hourMinute, '08:00');
      expect(expr.period, isNull);
    });

    test('jam 8 pagi -> 08:00', () {
      final expr = TimeParser().parse('jam 8 pagi rapat');
      expect(expr!.hourMinute, '08:00');
      expect(expr.period, 'pagi');
    });

    test('jam 8 malam -> 20:00', () {
      expect(TimeParser().parse('jam 8 malam makan')!.hourMinute, '20:00');
    });

    test('jam 3 sore -> 15:00', () {
      expect(
        TimeParser().parse('jam 3 sore ketemu klien')!.hourMinute,
        '15:00',
      );
    });

    test('jam 12 siang -> 12:00', () {
      expect(TimeParser().parse('jam 12 siang makan')!.hourMinute, '12:00');
    });

    test('pukul 20:30 -> 20:30', () {
      expect(TimeParser().parse('pukul 20:30 nonton')!.hourMinute, '20:30');
    });

    test('pukul 9 -> 09:00', () {
      expect(TimeParser().parse('pukul 9 berangkat')!.hourMinute, '09:00');
    });

    test('jam 25 (invalid) -> null', () {
      expect(TimeParser().parse('jam 25 tiap hari'), isNull);
    });
  });

  group('TimeParser.tanpa kata jam', () {
    test('20:00 -> 20:00', () {
      expect(TimeParser().parse('nonton film 20:00')!.hourMinute, '20:00');
    });

    test('malam -> 19:00', () {
      final expr = TimeParser().parse('malam ini masak');
      expect(expr!.hourMinute, '19:00');
      expect(expr.period, 'malam');
    });
  });

  group('TimeParser.tanpa ekspresi waktu', () {
    test('mengembalikan null', () {
      expect(TimeParser().parse('qwerty'), isNull);
      expect(TimeParser().parse('besok beli susu'), isNull);
    });
  });
}

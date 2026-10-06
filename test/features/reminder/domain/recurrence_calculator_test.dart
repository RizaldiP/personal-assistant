import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/features/reminder/domain/recurrence_calculator.dart';

void main() {
  group('RecurrenceCalculator.nextOccurrence', () {
    final anchor = DateTime(2026, 10, 5, 8);

    test('none mengembalikan null', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'none',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        isNull,
      );
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: '',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        isNull,
      );
    });

    test('aturan tidak dikenal mengembalikan null', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'yearly:1',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        isNull,
      );
    });

    test('daily tetap setelah jam jadwal', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'daily',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        DateTime(2026, 10, 6, 8),
      );
    });

    test('daily tetap sebelum jam jadwal', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'daily',
          anchor: anchor,
          now: DateTime(2026, 10, 6, 7),
        ),
        DateTime(2026, 10, 6, 8),
      );
    });

    test('daily setelah beberapa hari melompat tanpa berhenti', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'daily',
          anchor: anchor,
          now: DateTime(2026, 10, 20, 12),
        ),
        DateTime(2026, 10, 21, 8),
      );
    });

    test('weekly:MON dari Senin menuju Senin berikutnya', () {
      // 5 Okt 2026 adalah Senin.
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'weekly:MON',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        DateTime(2026, 10, 12, 8),
      );
    });

    test('weekly:WED ketika hari ini sudah Rabu melompat 7 hari', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'weekly:WED',
          anchor: DateTime(2026, 10, 7, 8),
          now: DateTime(2026, 10, 7, 12),
        ),
        DateTime(2026, 10, 14, 8),
      );
    });

    test('weekly:FRI dari Senin menuju Jumat minggu ini', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'weekly:FRI',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        DateTime(2026, 10, 9, 8),
      );
    });

    test('monthly:15 menuju tanggal 15 bulan ini', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'monthly:15',
          anchor: anchor,
          now: DateTime(2026, 10, 5, 9),
        ),
        DateTime(2026, 10, 15, 8),
      );
    });

    test('monthly:15 setelah tanggal 15 pindah ke bulan berikutnya', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'monthly:15',
          anchor: anchor,
          now: DateTime(2026, 10, 20, 12),
        ),
        DateTime(2026, 11, 15, 8),
      );
    });

    test('monthly:31 melompati bulan tanpa tanggal 31', () {
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'monthly:31',
          anchor: anchor,
          now: DateTime(2026, 11, 1, 9),
        ),
        DateTime(2026, 12, 31, 8),
      );
    });

    test('interval:3d lompat kelipatan 3 hari', () {
      // anchor 5 Okt + 3 hari = 8 Okt; +3 = 11 Okt (11 sudah lampau dari 12 Okt).
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'interval:3d',
          anchor: anchor,
          now: DateTime(2026, 10, 12, 9),
        ),
        DateTime(2026, 10, 14, 8),
      );
    });

    test('interval:5d langsung dari now', () {
      // anchor 1 Okt 09:00; +5 = 6 Okt (6 Okt 17:00 sudah lampau) → 11 Okt.
      final anchor2 = DateTime(2026, 10, 1, 9);
      expect(
        RecurrenceCalculator.nextOccurrence(
          rule: 'interval:5d',
          anchor: anchor2,
          now: DateTime(2026, 10, 6, 17),
        ),
        DateTime(2026, 10, 11, 9),
      );
    });
  });
}

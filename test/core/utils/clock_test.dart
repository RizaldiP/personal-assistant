import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/utils/clock.dart';

void main() {
  group('SystemClock', () {
    test('mengembalikan waktu sistem yang mendekati sekarang', () {
      final before = DateTime.now();
      final value = const SystemClock().now();
      final after = DateTime.now();

      expect(
        !value.isBefore(before) && !value.isAfter(after),
        isTrue,
        reason: 'harus berada di antara before dan after',
      );
    });
  });

  group('FixedClock', () {
    test('selalu mengembalikan waktu yang sama', () {
      final clock = FixedClock(DateTime.utc(2026, 10, 5));
      final first = clock.now();

      expect(first, DateTime.utc(2026, 10, 5));
      expect(clock.now(), first);

      clock.value = DateTime.utc(2026, 12, 31, 23, 59);
      expect(clock.now(), DateTime.utc(2026, 12, 31, 23, 59));
    });
  });
}

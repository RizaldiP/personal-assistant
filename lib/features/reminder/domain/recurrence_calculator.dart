/// Logika pengulangan reminder (pure Dart, tanpa Flutter).
///
/// Format aturan:
/// - `none` — tidak berulang
/// - `daily` — setiap hari
/// - `weekly:MON` — tiap hari tertentu dalam seminggu (MON/TUE/WED/THU/FRI/SAT/SUN)
/// - `monthly:10` — tiap tanggal 10 setiap bulan
/// - `interval:3d` — tiap N hari terhitung dari [anchor]
abstract final class RecurrenceCalculator {
  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// Kemunculan berikutnya yang **lebih baru dari** [now], mempertahankan jam
  /// ([anchor].hour/min) agar sama dengan waktu jadwal awal. Mengembalikan
  /// `null` bila tidak ada lagi kemunculan.
  static DateTime? nextOccurrence({
    required String rule,
    required DateTime anchor,
    required DateTime now,
  }) {
    final normalized = rule.trim().toLowerCase();
    if (normalized == 'none' || normalized.isEmpty) return null;
    if (normalized == 'daily') return _after(anchor, 1, now);

    if (normalized.startsWith('weekly:')) {
      final weekday = _weekdays.indexOf(normalized.substring(7).toUpperCase());
      if (weekday == -1) return null;
      return _nextWeekday(weekday, anchor, now);
    }

    if (normalized.startsWith('monthly:')) {
      final day = int.tryParse(normalized.substring(8));
      if (day == null || day < 1 || day > 31) return null;
      return _nextMonthDay(day, anchor, now);
    }

    if (normalized.startsWith('interval:')) {
      final interval = int.tryParse(
        normalized.substring(9).replaceFirst('d', ''),
      );
      if (interval == null || interval < 1) return null;
      return _after(anchor, interval, now);
    }

    return null;
  }

  static DateTime _after(DateTime anchor, int stepDays, DateTime now) {
    final elapsed = now.difference(anchor).inDays;
    final steps = (elapsed < 0 ? -1 : elapsed) ~/ stepDays + 1;
    return anchor.add(Duration(days: stepDays * steps));
  }

  static DateTime? _nextWeekday(int weekday, DateTime anchor, DateTime now) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    for (var offset = 0; offset < 8; offset++) {
      final candidate = start.add(Duration(days: offset));
      if (candidate.weekday - 1 != weekday) continue;
      final result = _atTime(candidate, anchor);
      if (result.isAfter(now) && result.isAfter(anchor)) return result;
    }
    return null;
  }

  static DateTime? _nextMonthDay(int day, DateTime anchor, DateTime now) {
    for (var i = 0; i < 400; i++) {
      final month = DateTime(now.year, now.month + i);
      if (day > _daysInMonth(month.year, month.month)) continue;
      final result = _atTime(DateTime(month.year, month.month, day), anchor);
      if (result.isAfter(now) && result.isAfter(anchor)) return result;
    }
    return null;
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static DateTime _atTime(DateTime date, DateTime anchor) =>
      DateTime(date.year, date.month, date.day, anchor.hour, anchor.minute);
}

/// Ekspresi waktu: jam dalam format "HH:mm" + kata periode (opsional).
class TimeExpression {
  const TimeExpression({
    required this.hourMinute,
    this.period,
    required this.matched,
  });

  final String? hourMinute;
  final String? period;
  final String matched;
}

/// Mendeteksi ekspresi waktu Bahasa Indonesia.
///
/// Didukung: "jam 8", "jam 08:00", "jam 8 pagi", "20:00", dan kata periode
/// saja (pagi/siang/sore/malam).
class TimeParser {
  static final RegExp _clock = RegExp(
    r'(?:jam|pukul)\s*(\d{1,2})(?:[.:](\d{2}))?\s*(pagi|siang|sore|malam)?',
  );
  static final RegExp _hourMinute = RegExp(
    r'(?<!\d)(\d{1,2})[.:](\d{2})(?!\d)',
  );
  static final RegExp _period = RegExp(r'\b(pagi|siang|sore|malam)\b');

  static const Map<String, String> _periodDefaults = {
    'pagi': '06:00',
    'siang': '12:00',
    'sore': '15:00',
    'malam': '19:00',
  };

  TimeExpression? parse(String text) {
    final clock = _clock.firstMatch(text);
    if (clock != null) {
      final hour = int.parse(clock.group(1)!);
      if (hour > 23) return _periodOnly(text);
      final minute = clock.group(2) == null ? 0 : int.parse(clock.group(2)!);
      if (minute > 59) return _periodOnly(text);
      final period = clock.group(3);
      final resolved = _resolve(hour, minute, period);
      return TimeExpression(
        hourMinute: resolved,
        period: period,
        matched: clock.group(0)!,
      );
    }

    // "20:00" tanpa kata jam.
    final bare = _hourMinute.firstMatch(text);
    if (bare != null) {
      final hour = int.parse(bare.group(1)!);
      final minute = int.parse(bare.group(2)!);
      if (hour <= 23 && minute <= 59) {
        return TimeExpression(
          hourMinute: '${_pad(hour)}:${_pad(minute)}',
          matched: bare.group(0)!,
        );
      }
    }

    return _periodOnly(text);
  }

  TimeExpression? _periodOnly(String text) {
    final match = _period.firstMatch(text);
    if (match == null) return null;
    final period = match.group(1)!;
    return TimeExpression(
      hourMinute: _periodDefaults[period],
      period: period,
      matched: match.group(0)!,
    );
  }

  static String _resolve(int hour, int minute, String? period) {
    var resolved = hour;
    switch (period) {
      case 'siang' || 'sore' when hour < 12:
        resolved = hour + 12;
      case 'malam' when hour < 12:
        resolved = hour + 12;
      case 'pagi' when hour == 12:
        resolved = 0;
    }
    return '${_pad(resolved)}:${_pad(minute)}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

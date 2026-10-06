/// Ekspresi tanggal: tanggal ter-resolusi + teks yang cocok (untuk dihapus
/// dari judul/deskripsi).
class DateExpression {
  const DateExpression({required this.date, required this.matched});

  final DateTime date;
  final String matched;
}

/// Mendeteksi ekspresi tanggal Bahasa Indonesia.
///
/// Didukung: hari ini, besok, lusa, minggu depan, bulan depan, nama hari,
/// "tanggal N", "N hari/minggu/bulan lagi".
class DateParser {
  DateParser({required DateTime now})
    : _refDate = DateTime(now.year, now.month, now.day);

  final DateTime _refDate;

  static const Map<String, int> _months = {
    'januari': 1,
    'februari': 2,
    'maret': 3,
    'april': 4,
    'mei': 5,
    'juni': 6,
    'juli': 7,
    'agustus': 8,
    'september': 9,
    'oktober': 10,
    'november': 11,
    'desember': 12,
  };

  static const Map<String, int> _weekdays = {
    'senin': 1,
    'selasa': 2,
    'rabu': 3,
    'kamis': 4,
    'jumat': 5,
    'sabtu': 6,
    'minggu': 7,
  };

  DateExpression? parse(String text) {
    // Urutan penting: ekspresi lebih panjang/lebih spesifik didahulukan.
    final rules = <_DateRule>[
      _DateRule(RegExp(r'\bhari ini\b'), (m) => _refDate),
      _DateRule(
        RegExp(r'\bkemarin\b'),
        (m) => _refDate.subtract(const Duration(days: 1)),
      ),
      _DateRule(
        RegExp(r'\blusa\b'),
        (m) => _refDate.add(const Duration(days: 2)),
      ),
      _DateRule(
        RegExp(r'\bbesok\b'),
        (m) => _refDate.add(const Duration(days: 1)),
      ),
      _DateRule(
        RegExp(r'\bminggu depan\b'),
        (m) => _refDate.add(const Duration(days: 7)),
      ),
      _DateRule(RegExp(r'\bbulan depan\b'), (m) => _addMonths(_refDate, 1)),
      _DateRule(
        RegExp(r'(\d{1,2})\s+hari\s+lagi'),
        (m) => _refDate.add(Duration(days: int.parse(m.group(1)!))),
      ),
      _DateRule(
        RegExp(r'(\d{1,2})\s+minggu\s+lagi'),
        (m) => _refDate.add(Duration(days: int.parse(m.group(1)!) * 7)),
      ),
      _DateRule(
        RegExp(r'(\d{1,2})\s+bulan\s+lagi'),
        (m) => _addMonths(_refDate, int.parse(m.group(1)!)),
      ),
      _DateRule(RegExp(r'tanggal\s+(\d{1,2})(?:\s+([a-z]+))?'), (m) {
        final day = int.parse(m.group(1)!);
        final monthName = m.group(2);
        if (monthName != null && _months.containsKey(monthName)) {
          return _nextMonthDay(_months[monthName]!, day);
        }
        return _nextDayOfMonth(day);
      }),
      _DateRule(RegExp(r'\b(senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b'), (
        m,
      ) {
        return _nextWeekday(_weekdays[m.group(1)!]!);
      }),
    ];

    for (final rule in rules) {
      final match = rule.pattern.firstMatch(text);
      if (match != null) {
        return DateExpression(
          date: rule.resolve(match),
          matched: match.group(0)!,
        );
      }
    }
    return null;
  }

  static DateTime _addMonths(DateTime date, int months) =>
      DateTime(date.year, date.month + months, date.day);

  DateTime _nextDayOfMonth(int day) {
    for (var offset = 0; offset <= 12; offset++) {
      final candidate = DateTime(_refDate.year, _refDate.month + offset, day);
      if (candidate.day == day && !candidate.isBefore(_refDate)) {
        return candidate;
      }
    }
    return _refDate;
  }

  DateTime _nextMonthDay(int month, int day) {
    for (var year = _refDate.year; year <= _refDate.year + 1; year++) {
      final candidate = DateTime(year, month, day);
      if (candidate.month == month &&
          candidate.day == day &&
          !candidate.isBefore(_refDate)) {
        return candidate;
      }
    }
    return _nextDayOfMonth(day);
  }

  DateTime _nextWeekday(int target) {
    final delta = (target - _refDate.weekday + 7) % 7;
    return _refDate.add(Duration(days: delta));
  }
}

class _DateRule {
  const _DateRule(this.pattern, this.resolve);

  final RegExp pattern;
  final DateTime Function(Match match) resolve;
}

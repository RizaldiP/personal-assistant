/// Ekspresi nominal: nilai integer + teks yang cocok (untuk dihapus dari
/// deskripsi).
class AmountExpression {
  const AmountExpression({required this.value, required this.matched});

  final int value;
  final String matched;
}

/// Mendeteksi nominal uang Bahasa Indonesia.
///
/// Didukung: "10 ribu", "10rb", "10k", "10.000", "1 juta", "1jt",
/// "2,5 juta", "miliar", dan prefiks "Rp" (mis. "Rp50.000").
class AmountParser {
  static final RegExp _rp = RegExp(r'\brp\s*(\d[\d.,]*)');
  static final RegExp _withMultiplier = RegExp(
    r'(?<!\d)(\d{1,3}(?:\.\d{3})+|\d{1,3}(?:,\d{1,2})?)\s*'
    r'(ribu|rb|juta|jt|miliar|milyar|k)\b',
  );
  static final RegExp _thousands = RegExp(r'(?<!\d)\d{1,3}(?:\.\d{3})+(?!\d)');

  static const Map<String, int> _multipliers = {
    'ribu': 1000,
    'rb': 1000,
    'k': 1000,
    'juta': 1000000,
    'jt': 1000000,
    'miliar': 1000000000,
    'milyar': 1000000000,
  };

  AmountExpression? parse(String text) {
    final rp = _rp.firstMatch(text);
    if (rp != null) {
      return AmountExpression(
        value: _toInt(rp.group(1)!),
        matched: rp.group(0)!,
      );
    }

    final multiplier = _withMultiplier.firstMatch(text);
    if (multiplier != null) {
      final base = _toDouble(multiplier.group(1)!);
      return AmountExpression(
        value: (base * _multipliers[multiplier.group(2)!]!).round(),
        matched: multiplier.group(0)!,
      );
    }

    final thousands = _thousands.firstMatch(text);
    if (thousands != null) {
      return AmountExpression(
        value: _toInt(thousands.group(0)!),
        matched: thousands.group(0)!,
      );
    }

    return null;
  }

  static double _toDouble(String raw) {
    final cleaned = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.parse(cleaned);
  }

  static int _toInt(String raw) => _toDouble(raw).round();
}

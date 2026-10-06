/// Format tampilan uang Rupiah: `25000` → `Rp 25.000`.
abstract final class CurrencyFormats {
  static String idr(int amount) {
    final negative = amount < 0;
    final digits = amount.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    return negative ? '-Rp $grouped' : 'Rp $grouped';
  }
}

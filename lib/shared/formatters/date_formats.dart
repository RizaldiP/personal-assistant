/// Format tanggal/waktu untuk tampilan Bahasa Indonesia.
abstract final class DateFormats {
  static const List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// `YYYY-MM-DD` (atau null) → `5 Oktober 2026`.
  static String longIndonesia(String? yyyyMmDd) {
    if (yyyyMmDd == null || yyyyMmDd.isEmpty) return '';
    final parts = yyyyMmDd.split('-');
    if (parts.length != 3) return yyyyMmDd;
    final day = int.tryParse(parts[2]);
    final month = int.tryParse(parts[1]);
    if (day == null || month == null || month < 1 || month > 12) {
      return yyyyMmDd;
    }
    return '$day ${_months[month - 1]} ${parts[0]}';
  }

  static String shortTime(String? hhMm) => (hhMm ?? '').trim();
}

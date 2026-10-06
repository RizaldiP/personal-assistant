/// Pembersih teks mentah sebelum diproses parser.
///
/// Semua fungsi murni (tanpa state) agar mudah diuji.
abstract final class Normalizer {
  /// Huruf kecil, satu spasi, tanpa spasi pinggir.
  static String normalize(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Kapital di huruf pertama, sisanya apa adanya.
  static String capitalizeFirst(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

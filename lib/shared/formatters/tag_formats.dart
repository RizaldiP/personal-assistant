/// Utilitas memecah/menggabung input tag (`"Rumah, kantor"` →
/// `['rumah', 'kantor']`).
abstract final class TagFormats {
  /// Memecah teks koma menjadi daftar nama tag lowercase tanpa duplikat
  /// berurutan.
  static List<String> split(String raw) => raw
      .split(',')
      .map((part) => part.trim().toLowerCase())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  /// Menggabung daftar tag untuk ditampilkan pada field input.
  static String join(List<String> tags) => tags.join(', ');
}

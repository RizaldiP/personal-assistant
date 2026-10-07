/// Tipe entitas yang dicari global search (PHASE 13).
abstract final class SearchTypes {
  static const String todo = 'todo';
  static const String reminder = 'reminder';
  static const String note = 'note';
  static const String journal = 'journal';
  static const String idea = 'idea';
  static const String shopping = 'shopping';
  static const String expense = 'expense';

  /// Urutan tampil pada hasil pencarian.
  static const List<String> all = [
    todo,
    reminder,
    note,
    journal,
    idea,
    shopping,
    expense,
  ];
}

/// Satu hasil pencarian global — bebas dari drift maupun UI.
class SearchResult {
  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.date,
    this.tags = const [],
  });

  /// Tipe entitas, salah satu dari [SearchTypes.all].
  final String type;

  final int id;

  final String title;

  /// Baris kedua (tanggal, nominal, cuplikan konten, ...).
  final String subtitle;

  /// Tanggal kejadian `YYYY-MM-DD` bila ada — dipakai urutan & tampilan.
  final String? date;

  /// Nama tag entitas ini (lowercase), urut abjad.
  final List<String> tags;

  SearchResult copyWith({List<String>? tags}) => SearchResult(
    type: type,
    id: id,
    title: title,
    subtitle: subtitle,
    date: date,
    tags: tags ?? this.tags,
  );
}

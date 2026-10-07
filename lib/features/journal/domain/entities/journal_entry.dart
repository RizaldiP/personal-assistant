/// Entri jurnal harian milik domain.
class JournalEntry {
  const JournalEntry({
    this.id,
    required this.date,
    this.title,
    required this.content,
    this.mood,
    this.source,
    this.rawInput,
    this.confidence,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Tanggal kejadian `YYYY-MM-DD`.
  final String date;
  final String? title;
  final String content;

  /// Mood bebas, mis. `senang`, `capek`, `stres`.
  final String? mood;
  final String? source;
  final String? rawInput;
  final double? confidence;

  /// Nama tag (lowercase), urut abjad.
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  JournalEntry copyWith({
    int? id,
    String? date,
    String? title,
    String? content,
    String? mood,
    String? source,
    String? rawInput,
    double? confidence,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      source: source ?? this.source,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

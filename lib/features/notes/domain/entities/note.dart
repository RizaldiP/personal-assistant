/// Entitas catatan bebas milik domain — tidak bergantung pada drift maupun UI.
class Note {
  const Note({
    this.id,
    this.title,
    required this.content,
    this.source,
    this.rawInput,
    this.confidence,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? title;
  final String content;
  final String? source;
  final String? rawInput;
  final double? confidence;

  /// Nama tag (lowercase), urut abjad.
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? source,
    String? rawInput,
    double? confidence,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      source: source ?? this.source,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

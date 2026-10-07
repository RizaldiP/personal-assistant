/// Status alur sebuah ide.
enum IdeaStatus {
  inbox('inbox'),
  thinking('thinking'),
  working('working'),
  completed('completed'),
  archived('archived');

  const IdeaStatus(this.storageValue);

  final String storageValue;

  static IdeaStatus parse(String? value) => values.firstWhere(
    (status) => status.storageValue == value,
    orElse: () => IdeaStatus.inbox,
  );

  String get label => switch (this) {
    IdeaStatus.inbox => 'Inbox',
    IdeaStatus.thinking => 'Thinking',
    IdeaStatus.working => 'Working',
    IdeaStatus.completed => 'Completed',
    IdeaStatus.archived => 'Archived',
  };
}

/// Entitas ide milik domain.
class Idea {
  const Idea({
    this.id,
    required this.title,
    this.content,
    this.status = IdeaStatus.inbox,
    this.source,
    this.rawInput,
    this.confidence,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String title;
  final String? content;
  final IdeaStatus status;
  final String? source;
  final String? rawInput;
  final double? confidence;

  /// Nama tag (lowercase), urut abjad.
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Idea copyWith({
    int? id,
    String? title,
    String? content,
    IdeaStatus? status,
    String? source,
    String? rawInput,
    double? confidence,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Idea(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      source: source ?? this.source,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

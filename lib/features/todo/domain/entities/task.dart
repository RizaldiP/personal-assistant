enum TaskPriority {
  low,
  normal,
  high,
  urgent;

  static TaskPriority parse(String? value) => switch (value) {
    'low' => TaskPriority.low,
    'high' => TaskPriority.high,
    'urgent' => TaskPriority.urgent,
    _ => TaskPriority.normal,
  };

  String get storageValue => name;
}

enum TaskStatus {
  pending,
  done;

  static TaskStatus parse(String? value) =>
      value == 'done' ? TaskStatus.done : TaskStatus.pending;

  String get storageValue => name;
}

/// Entitas tugas (todo) milik domain — tidak bergantung pada drift maupun UI.
class Task {
  const Task({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.normal,
    this.category,
    this.status = TaskStatus.pending,
    this.completedAt,
    this.source,
    this.rawInput,
    this.confidence,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String title;
  final String? description;

  /// `YYYY-MM-DD`.
  final String? dueDate;

  /// `HH:mm`.
  final String? dueTime;
  final TaskPriority priority;
  final String? category;
  final TaskStatus status;
  final DateTime? completedAt;
  final String? source;
  final String? rawInput;
  final double? confidence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? dueDate,
    String? dueTime,
    TaskPriority? priority,
    String? category,
    TaskStatus? status,
    DateTime? completedAt,
    String? source,
    String? rawInput,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      source: source ?? this.source,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

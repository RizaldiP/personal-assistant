enum ReminderStatus {
  active,
  completed,
  dismissed;

  static ReminderStatus parse(String? value) => switch (value) {
    'completed' => ReminderStatus.completed,
    'dismissed' => ReminderStatus.dismissed,
    _ => ReminderStatus.active,
  };

  String get storageValue => name;
}

/// Entitas reminder milik domain — tidak bergantung pada drift maupun UI.
class Reminder {
  const Reminder({
    this.id,
    required this.title,
    this.notes,
    required this.date,
    required this.time,
    required this.scheduledAt,
    this.priority = 'normal',
    this.status = ReminderStatus.active,
    this.isRecurring = false,
    this.recurrenceRule = 'none',
    this.recurrenceAnchor,
    this.nextFireAt,
    this.snoozedUntil,
    this.lastFiredAt,
    this.completedAt,
    this.source,
    this.rawInput,
    this.confidence,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String title;
  final String? notes;

  /// Tanggal murni `YYYY-MM-DD`.
  final String date;

  /// Jam `HH:mm`.
  final String time;

  /// Hasil resolve [date] + [time] dalam epoch millisecond UTC.
  final int scheduledAt;
  final String priority;
  final ReminderStatus status;
  final bool isRecurring;

  /// Contoh: `none`, `daily`, `weekly:MON`, `monthly:10`, `interval:3d`.
  final String recurrenceRule;
  final String? recurrenceAnchor;
  final int? nextFireAt;
  final int? snoozedUntil;
  final int? lastFiredAt;
  final int? completedAt;
  final String? source;
  final String? rawInput;
  final double? confidence;
  final int? createdAt;
  final int? updatedAt;

  Reminder copyWith({
    int? id,
    String? title,
    String? notes,
    String? date,
    String? time,
    int? scheduledAt,
    String? priority,
    ReminderStatus? status,
    bool? isRecurring,
    String? recurrenceRule,
    String? recurrenceAnchor,
    int? nextFireAt,
    int? snoozedUntil,
    int? lastFiredAt,
    int? completedAt,
    String? source,
    String? rawInput,
    double? confidence,
    int? createdAt,
    int? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      time: time ?? this.time,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceAnchor: recurrenceAnchor ?? this.recurrenceAnchor,
      nextFireAt: nextFireAt ?? this.nextFireAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
      completedAt: completedAt ?? this.completedAt,
      source: source ?? this.source,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

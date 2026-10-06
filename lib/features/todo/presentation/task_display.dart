import '../../../shared/formatters/date_formats.dart';
import '../domain/entities/task.dart';

/// Tampilan bantu untuk entitas [Task] (label, format, keterangan).
abstract final class TaskDisplay {
  static String priorityLabel(TaskPriority priority) => switch (priority) {
    TaskPriority.low => 'Rendah',
    TaskPriority.normal => 'Biasa',
    TaskPriority.high => 'Penting',
    TaskPriority.urgent => 'Segera',
  };

  /// Baris keterangan: tanggal • jam • prioritas. Bagian kosong dihilangkan.
  static String subtitle(Task task) {
    final parts = <String>[
      if (task.dueDate != null) DateFormats.longIndonesia(task.dueDate),
      if (task.dueTime != null) DateFormats.shortTime(task.dueTime),
      priorityLabel(task.priority),
    ];
    return parts.join(' • ');
  }
}

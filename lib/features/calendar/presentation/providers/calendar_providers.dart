import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/combine_latest.dart';
import '../../../journal/data/repositories/journal_repository_impl.dart';
import '../../../journal/domain/entities/journal_entry.dart';
import '../../../reminder/data/repositories/reminder_repository_impl.dart';
import '../../../reminder/domain/entities/reminder.dart';
import '../../../todo/data/repositories/task_repository_impl.dart';
import '../../../todo/domain/entities/task.dart';
import '../../domain/calendar_event.dart';

/// Kelompok kejadian per tanggal `YYYY-MM-DD` — gabungan stream tugas,
/// reminder, dan jurnal; diperbarui live (PHASE 13).
final calendarEventsProvider = StreamProvider<Map<String, List<CalendarEvent>>>(
  (ref) {
    final tasks = ref.watch(taskRepositoryProvider).watchTasks();
    final reminders = ref.watch(reminderRepositoryProvider).watchAll();
    final journals = ref.watch(journalRepositoryProvider).watchEntries();
    return combineLatest(
      combineLatest(tasks, reminders, _Pair.new),
      journals,
      (pair, journals) => _build(pair.tasks, pair.reminders, journals),
    );
  },
);

class _Pair {
  const _Pair(this.tasks, this.reminders);

  final List<Task> tasks;
  final List<Reminder> reminders;
}

Map<String, List<CalendarEvent>> _build(
  List<Task> tasks,
  List<Reminder> reminders,
  List<JournalEntry> journals,
) {
  final byDate = <String, List<CalendarEvent>>{};

  void put(String? date, CalendarEvent event) {
    if (date == null || date.isEmpty) return;
    (byDate[date] ??= []).add(event);
  }

  for (final task in tasks) {
    put(
      task.dueDate,
      CalendarEvent(
        type: CalendarEventTypes.task,
        id: task.id ?? 0,
        title: task.title,
        time: task.dueTime,
      ),
    );
  }
  for (final reminder in reminders) {
    put(
      reminder.date,
      CalendarEvent(
        type: CalendarEventTypes.reminder,
        id: reminder.id ?? 0,
        title: reminder.title,
        time: reminder.time,
      ),
    );
  }
  for (final entry in journals) {
    put(
      entry.date,
      CalendarEvent(
        type: CalendarEventTypes.journal,
        id: entry.id ?? 0,
        title: _journalTitle(entry),
      ),
    );
  }
  return byDate;
}

String _journalTitle(JournalEntry entry) {
  final hasTitle = entry.title?.trim().isNotEmpty ?? false;
  if (hasTitle) return entry.title!;
  final text = entry.content.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= 60 ? text : '${text.substring(0, 60)}…';
}

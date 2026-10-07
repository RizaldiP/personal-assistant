import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/journal/domain/entities/journal_entry.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/reminder/domain/entities/reminder.dart';
import 'package:personal_offline/features/reminder/domain/reminder_schedule.dart';
import 'package:personal_offline/features/search/data/repositories/search_repository_impl.dart';
import 'package:personal_offline/features/search/presentation/screens/search_screen.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';

import '../../../helpers/fake_journal_repository.dart';
import '../../../helpers/fake_reminder_repository.dart';
import '../../../helpers/fake_search_repository.dart';
import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository taskRepository;
  late FakeReminderRepository reminderRepository;
  late FakeJournalRepository journalRepository;

  final today = DateTime.now();
  final monthLabel = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ][today.month - 1];

  String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  setUp(() {
    taskRepository = FakeTaskRepository();
    reminderRepository = FakeReminderRepository();
    journalRepository = FakeJournalRepository();
  });

  Future<void> pumpCalendar(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepository),
          reminderRepositoryProvider.overrideWithValue(reminderRepository),
          journalRepositoryProvider.overrideWithValue(journalRepository),
          searchRepositoryProvider.overrideWithValue(FakeSearchRepository()),
          clockProvider.overrideWithValue(FixedClock(today)),
          ...overrides,
        ],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan label bulan, hari, dan empty state', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('Kalender'), findsOneWidget);
    expect(find.byKey(const Key('calendar-month-label')), findsOneWidget);
    expect(find.text('$monthLabel ${today.year}'), findsOneWidget);
    expect(find.byKey(const Key('calendar-prev-month')), findsOneWidget);
    expect(find.byKey(const Key('calendar-next-month')), findsOneWidget);
    expect(find.byKey(const Key('calendar-today-button')), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Min'), findsOneWidget);
    expect(find.text('Tidak ada kejadian'), findsOneWidget);
  });

  testWidgets('titik kejadian muncul pada hari bertanggal', (tester) async {
    final eventDay = DateTime(today.year, today.month, 15);
    final key = dateKey(eventDay);
    await taskRepository.create(Task(title: 'Kirim laporan', dueDate: key));
    await reminderRepository.create(
      Reminder(
        title: 'Bayar listrik',
        date: key,
        time: '08:00',
        scheduledAt: reminderToEpochUtc(reminderLocalDateTime(key, '08:00')),
      ),
    );
    await journalRepository.create(
      JournalEntry(date: key, content: 'Hari di galangan'),
    );

    await pumpCalendar(tester);

    expect(find.byKey(ValueKey('calendar-dot-task-$key')), findsOneWidget);
    expect(find.byKey(ValueKey('calendar-dot-reminder-$key')), findsOneWidget);
    expect(find.byKey(ValueKey('calendar-dot-journal-$key')), findsOneWidget);
    expect(
      find.byKey(
        ValueKey(
          'calendar-dot-task-${dateKey(DateTime(today.year, today.month, 16))}',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('memilih hari menampilkan kejadian hari itu', (tester) async {
    final eventDay = DateTime(today.year, today.month, 20);
    final key = dateKey(eventDay);
    await taskRepository.create(Task(title: 'Inspeksi lambung', dueDate: key));
    await taskRepository.create(
      Task(title: 'Tugas hari ini', dueDate: dateKey(today)),
    );

    await pumpCalendar(tester);

    expect(find.text('Tugas hari ini'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('calendar-day-$key')));
    await tester.pumpAndSettle();

    expect(find.text('Inspeksi lambung'), findsOneWidget);
    expect(find.text('Tugas hari ini'), findsNothing);
    expect(find.textContaining('20 '), findsWidgets);
  });

  testWidgets('navigasi bulan mengubah label dan tombol Hari ini kembali', (
    tester,
  ) async {
    await pumpCalendar(tester);

    await tester.tap(find.byKey(const Key('calendar-prev-month')));
    await tester.pumpAndSettle();

    final prevMonth = today.month == 1 ? 12 : today.month - 1;
    final prevYear = today.month == 1 ? today.year - 1 : today.year;
    final prevNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    expect(find.text('${prevNames[prevMonth - 1]} $prevYear'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-next-month')));
    await tester.pumpAndSettle();
    expect(find.text('$monthLabel ${today.year}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-next-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-today-button')));
    await tester.pumpAndSettle();
    expect(find.text('$monthLabel ${today.year}'), findsOneWidget);
  });

  testWidgets('filter tipe menyaring titik dan daftar kejadian', (
    tester,
  ) async {
    final eventDay = DateTime(today.year, today.month, 15);
    final key = dateKey(eventDay);
    await taskRepository.create(Task(title: 'Kirim laporan', dueDate: key));
    await reminderRepository.create(
      Reminder(
        title: 'Bayar listrik',
        date: key,
        time: '08:00',
        scheduledAt: reminderToEpochUtc(reminderLocalDateTime(key, '08:00')),
      ),
    );

    await pumpCalendar(tester);
    await tester.tap(find.byKey(ValueKey('calendar-day-$key')));
    await tester.pumpAndSettle();

    expect(find.text('Kirim laporan'), findsOneWidget);
    expect(find.text('Bayar listrik'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-filter-reminder')));
    await tester.pumpAndSettle();

    expect(find.text('Bayar listrik'), findsOneWidget);
    expect(find.text('Kirim laporan'), findsNothing);
    expect(
      find.byKey(ValueKey('calendar-dot-task-$key')),
      findsNothing,
      reason: 'titik tugas tersembunyi saat filter reminder',
    );
    expect(find.byKey(ValueKey('calendar-dot-reminder-$key')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Kirim laporan'), findsOneWidget);
  });

  testWidgets('tombol cari di AppBar membuka layar Pencarian', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byKey(const Key('calendar-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
  });
}

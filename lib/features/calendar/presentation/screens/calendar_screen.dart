import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../domain/calendar_event.dart';
import '../providers/calendar_providers.dart';

/// Layar Kalender (PHASE 13): grid bulanan (Senin pertama) dengan titik
/// kejadian tugas/reminder/jurnal, pilihan hari, dan filter tipe.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const List<String> _months = [
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

  static const Map<String, String> _filterLabels = {
    'all': 'Semua',
    CalendarEventTypes.task: 'Tugas',
    CalendarEventTypes.reminder: 'Reminder',
    CalendarEventTypes.journal: 'Jurnal',
  };

  late DateTime _month;
  late DateTime _selected;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      if (_selected.year != _month.year || _selected.month != _month.month) {
        _selected = DateTime(_month.year, _month.month, 1);
      }
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
    });
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider);
    final events = eventsAsync.value ?? const <String, List<CalendarEvent>>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          IconButton(
            key: const Key('calendar-search-button'),
            tooltip: 'Pencarian',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _MonthHeader(
            month: _month,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onToday: _goToday,
          ),
          const _WeekdayRow(),
          _MonthGrid(
            month: _month,
            selected: _selected,
            events: events,
            filter: _filter,
            onSelect: (date) => setState(() => _selected = date),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                for (final entry in _filterLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: Key('calendar-filter-${entry.key}'),
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          _DayEventList(
            selected: _selected,
            events: (events[_dateKey(_selected)] ?? const []).where((
              CalendarEvent event,
            ) {
              return _filter == 'all' || event.type == _filter;
            }).toList(),
            loading: eventsAsync.isLoading,
            error: eventsAsync.hasError,
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = _CalendarScreenState._months[month.month - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('calendar-prev-month'),
            tooltip: 'Bulan sebelumnya',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              key: const Key('calendar-month-label'),
              '$monthName ${month.year}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('calendar-next-month'),
            tooltip: 'Bulan berikutnya',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          TextButton(
            key: const Key('calendar-today-button'),
            onPressed: onToday,
            child: const Text('Hari ini'),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const List<String> _labels = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final label in _labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.filter,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Map<String, List<CalendarEvent>> events;
  final String filter;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final offset = (first.weekday + 6) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    final cells = <Widget>[
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          day: day,
          selected:
              selected.year == month.year &&
              selected.month == month.month &&
              selected.day == day,
          isToday:
              today.year == month.year &&
              today.month == month.month &&
              today.day == day,
          events: events[_key(month.year, month.month, day)] ?? const [],
          filter: filter,
          onTap: () => onSelect(DateTime(month.year, month.month, day)),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        return GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cellWidth / 46,
          children: cells,
        );
      },
    );
  }

  static String _key(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.events,
    required this.filter,
    required this.onTap,
  });

  final DateTime date;
  final int day;
  final bool selected;
  final bool isToday;
  final List<CalendarEvent> events;
  final String filter;
  final VoidCallback onTap;

  String get _key =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibleTypes = <String>{
      for (final event in events)
        if (filter == 'all' || event.type == filter) event.type,
    };

    return InkWell(
      key: ValueKey('calendar-day-$_key'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: isToday
              ? Border.all(color: scheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final type in const [
                  CalendarEventTypes.task,
                  CalendarEventTypes.reminder,
                  CalendarEventTypes.journal,
                ])
                  if (visibleTypes.contains(type))
                    Container(
                      key: ValueKey('calendar-dot-$type-$_key'),
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: type == CalendarEventTypes.task
                            ? scheme.primary
                            : type == CalendarEventTypes.reminder
                            ? scheme.tertiary
                            : scheme.secondary,
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayEventList extends StatelessWidget {
  const _DayEventList({
    required this.selected,
    required this.events,
    required this.loading,
    required this.error,
  });

  final DateTime selected;
  final List<CalendarEvent> events;
  final bool loading;
  final bool error;

  static const List<String> _monthNames = [
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = _weekdayName(selected.weekday);
    final label =
        '$weekday, ${selected.day} '
        '${_monthNames[selected.month - 1]} ${selected.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            key: const Key('calendar-day-label'),
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LinearProgressIndicator(),
          )
        else if (error)
          const EmptyState(
            icon: Icons.error_outline,
            title: 'Gagal memuat kejadian',
            message: 'Coba buka lagi layarnya.',
          )
        else if (events.isEmpty)
          const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Tidak ada kejadian',
            message:
                'Tugas, reminder, dan jurnal dengan tanggal ini akan '
                'muncul di sini.',
          )
        else
          for (final event in events)
            ListTile(
              key: Key('calendar-event-${event.type}-${event.id}'),
              leading: Icon(switch (event.type) {
                CalendarEventTypes.task => Icons.check_circle_outline,
                CalendarEventTypes.reminder => Icons.alarm,
                _ => Icons.menu_book_outlined,
              }),
              title: Text(event.title),
              subtitle: event.time == null ? null : Text('jam ${event.time}'),
            ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static String _weekdayName(int weekday) => switch (weekday) {
    1 => 'Senin',
    2 => 'Selasa',
    3 => 'Rabu',
    4 => 'Kamis',
    5 => 'Jumat',
    6 => 'Sabtu',
    _ => 'Minggu',
  };
}

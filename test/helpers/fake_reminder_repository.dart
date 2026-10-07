import 'dart:async';

import 'package:personal_offline/features/reminder/domain/entities/reminder.dart';
import 'package:personal_offline/features/reminder/domain/repositories/reminder_repository.dart';

/// Fake [ReminderRepository] untuk test controller dan alur chat.
class FakeReminderRepository implements ReminderRepository {
  FakeReminderRepository({List<Reminder> seed = const []})
    : _reminders = List.of(seed);

  final List<Reminder> _reminders;
  final StreamController<List<Reminder>> _changes =
      StreamController<List<Reminder>>.broadcast();

  int _nextId = 1;

  List<Reminder> get reminders => List.unmodifiable(_reminders);

  @override
  Stream<List<Reminder>> watchActive() async* {
    yield _active();
    yield* _changes.stream.map((_) => _active());
  }

  @override
  Stream<List<Reminder>> watchAll() async* {
    yield List.of(_reminders);
    yield* _changes.stream.map((_) => List.of(_reminders));
  }

  List<Reminder> _active() =>
      _reminders.where((r) => r.status == ReminderStatus.active).toList();

  @override
  Future<Reminder?> getById(int id) async {
    for (final reminder in _reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  @override
  Future<List<Reminder>> getAll() async => List.of(_reminders);

  @override
  Future<List<Reminder>> dueAt(DateTime moment) async {
    final epoch = moment.toUtc().millisecondsSinceEpoch;
    return _reminders
        .where(
          (r) =>
              r.status == ReminderStatus.active &&
              (r.nextFireAt ?? r.scheduledAt) <= epoch,
        )
        .toList();
  }

  @override
  Future<List<Reminder>> search(String query) async {
    final lower = query.toLowerCase();
    return _reminders
        .where(
          (r) =>
              r.title.toLowerCase().contains(lower) ||
              (r.notes?.toLowerCase().contains(lower) ?? false),
        )
        .toList();
  }

  @override
  Future<int> create(Reminder reminder) async {
    final id = _nextId++;
    _reminders.add(reminder.copyWith(id: id));
    _changes.add(List.of(_reminders));
    return id;
  }

  @override
  Future<bool> update(Reminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) return false;
    _reminders[index] = reminder;
    _changes.add(List.of(_reminders));
    return true;
  }

  @override
  Future<bool> delete(int id) async {
    final length = _reminders.length;
    _reminders.removeWhere((r) => r.id == id);
    _changes.add(List.of(_reminders));
    return _reminders.length != length;
  }
}

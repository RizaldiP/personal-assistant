import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/reminder_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl(this._dao, this._clock);

  final ReminderDao _dao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Reminder>> watchActive() =>
      _dao.watchActive().map((rows) => rows.map(_toDomain).toList());

  @override
  Stream<List<Reminder>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Reminder?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Reminder>> getAll() async =>
      (await _dao.getAll()).map(_toDomain).toList();

  @override
  Future<List<Reminder>> dueAt(DateTime moment) async => (await _dao.dueAt(
    moment.toUtc().millisecondsSinceEpoch,
  )).map(_toDomain).toList();

  @override
  Future<List<Reminder>> search(String query) async =>
      (await _dao.search(query)).map(_toDomain).toList();

  @override
  Future<int> create(Reminder reminder) =>
      _dao.insertReminder(_insertCompanion(reminder, _now));

  @override
  Future<bool> update(Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return false;
    return _dao.updateReminder(id, _updateCompanion(reminder, _now));
  }

  @override
  Future<bool> delete(int id) => _dao.deleteReminder(id);

  static Reminder _toDomain(db.Reminder row) => Reminder(
    id: row.id,
    title: row.title,
    notes: row.notes,
    date: row.date,
    time: row.time,
    scheduledAt: row.scheduledAt,
    priority: row.priority,
    status: ReminderStatus.parse(row.status),
    isRecurring: row.isRecurring,
    recurrenceRule: row.recurrenceRule,
    recurrenceAnchor: row.recurrenceAnchor,
    nextFireAt: row.nextFireAt,
    snoozedUntil: row.snoozedUntil,
    lastFiredAt: row.lastFiredAt,
    completedAt: row.completedAt,
    source: row.source,
    rawInput: row.rawInput,
    confidence: row.confidence,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  static db.RemindersCompanion _insertCompanion(Reminder reminder, int now) =>
      db.RemindersCompanion.insert(
        title: reminder.title,
        notes: Value(reminder.notes),
        date: reminder.date,
        time: reminder.time,
        scheduledAt: reminder.scheduledAt,
        priority: Value(reminder.priority),
        status: Value(reminder.status.storageValue),
        isRecurring: Value(reminder.isRecurring),
        recurrenceRule: Value(reminder.recurrenceRule),
        recurrenceAnchor: Value(reminder.recurrenceAnchor),
        nextFireAt: Value(reminder.nextFireAt),
        snoozedUntil: Value(reminder.snoozedUntil),
        lastFiredAt: Value(reminder.lastFiredAt),
        completedAt: Value(reminder.completedAt),
        source: Value(reminder.source),
        rawInput: Value(reminder.rawInput),
        confidence: Value(reminder.confidence),
        createdAt: now,
        updatedAt: now,
      );

  static db.RemindersCompanion _updateCompanion(Reminder reminder, int now) =>
      db.RemindersCompanion(
        title: Value(reminder.title),
        notes: Value(reminder.notes),
        date: Value(reminder.date),
        time: Value(reminder.time),
        scheduledAt: Value(reminder.scheduledAt),
        priority: Value(reminder.priority),
        status: Value(reminder.status.storageValue),
        isRecurring: Value(reminder.isRecurring),
        recurrenceRule: Value(reminder.recurrenceRule),
        recurrenceAnchor: Value(reminder.recurrenceAnchor),
        nextFireAt: Value(reminder.nextFireAt),
        snoozedUntil: Value(reminder.snoozedUntil),
        lastFiredAt: Value(reminder.lastFiredAt),
        completedAt: Value(reminder.completedAt),
        source: Value(reminder.source),
        rawInput: Value(reminder.rawInput),
        confidence: Value(reminder.confidence),
        updatedAt: Value(now),
      );
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ReminderRepositoryImpl(database.reminderDao, ref.watch(clockProvider));
});

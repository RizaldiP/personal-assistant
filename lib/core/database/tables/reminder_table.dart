import 'package:drift/drift.dart';

/// Tabel reminder.
///
/// `date`/`time` adalah tampilan manusiawi, `scheduledAt`/`nextFireAt`
/// adalah epoch millisecond UTC untuk scheduler notifikasi (PHASE 6).
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get notes => text().nullable()();

  /// `YYYY-MM-DD`.
  TextColumn get date => text()();

  /// `HH:mm`.
  TextColumn get time => text()();

  IntColumn get scheduledAt => integer()();

  TextColumn get priority => text().withDefault(const Constant('normal'))();

  TextColumn get status => text().withDefault(const Constant('active'))();

  Column<bool> get isRecurring =>
      boolean().withDefault(const Constant(false))();

  TextColumn get recurrenceRule => text().withDefault(const Constant('none'))();

  /// Acuan hitung ulang `YYYY-MM-DD`.
  TextColumn get recurrenceAnchor => text().nullable()();

  IntColumn get nextFireAt => integer().nullable()();

  IntColumn get snoozedUntil => integer().nullable()();

  IntColumn get lastFiredAt => integer().nullable()();

  IntColumn get completedAt => integer().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get rawInput => text().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

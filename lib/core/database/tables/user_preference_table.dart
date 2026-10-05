import 'package:drift/drift.dart';

/// Preferensi aplikasi berbasis database.
///
/// Berbeda dari SharedPreferences (tema UI), tabel ini menyimpan preferensi
/// terstruktur milik aplikasi.
class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get key => text()();

  TextColumn get value => text()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

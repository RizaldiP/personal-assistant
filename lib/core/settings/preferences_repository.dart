import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/user_preferences_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

/// Preferensi aplikasi berbasis database (bukan tema UI).
class PreferencesRepository {
  PreferencesRepository(this._dao, this._clock);

  final UserPreferencesDao _dao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  Future<String?> get(String key) => _dao.get(key);

  Future<void> set(String key, String value) =>
      _dao.set(key, value, nowEpochMs: _now);

  Future<bool> remove(String key) => _dao.remove(key);

  Stream<Map<String, String>> watchAll() => _dao.watchAll().map(
    (rows) => {for (final row in rows) row.key: row.value},
  );

  /// Baris preferensi untuk keperluan inspeksi/test.
  Future<List<db.UserPreference>> getAll() async => _dao.watchAll().first;
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return PreferencesRepository(
    database.userPreferencesDao,
    ref.watch(clockProvider),
  );
});

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_preference_table.dart';

part 'user_preferences_dao.g.dart';

@DriftAccessor(tables: [UserPreferences])
class UserPreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$UserPreferencesDaoMixin {
  UserPreferencesDao(super.db);

  Future<String?> get(String key) async {
    final row =
        await (select(userPreferences)
              ..where((p) => p.key.equals(key))
              ..limit(1))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value, {required int nowEpochMs}) async {
    await into(userPreferences).insert(
      UserPreferencesCompanion.insert(
        key: key,
        value: value,
        createdAt: nowEpochMs,
        updatedAt: nowEpochMs,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<bool> remove(String key) async {
    final deleted = await (delete(
      userPreferences,
    )..where((p) => p.key.equals(key))).go();
    return deleted > 0;
  }

  Stream<List<UserPreference>> watchAll() => (select(
    userPreferences,
  )..orderBy([(p) => OrderingTerm.asc(p.key)])).watch();
}

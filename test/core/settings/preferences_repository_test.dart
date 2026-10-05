import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/settings/preferences_repository.dart';
import 'package:personal_offline/core/utils/clock.dart';

void main() {
  late db.AppDatabase database;
  late PreferencesRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = PreferencesRepository(database.userPreferencesDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('set lalu get menyimpan nilai string', () async {
    await repository.set('nlp_model', 'indo-bert');

    expect(await repository.get('nlp_model'), 'indo-bert');
    expect(await repository.get('belum-ada'), isNull);
  });

  test('set dua kali pada key yang sama tidak membuat duplikat', () async {
    await repository.set('nlp_model', 'v1');
    clock.value = start.add(const Duration(days: 1));
    await repository.set('nlp_model', 'v2');

    expect(await repository.get('nlp_model'), 'v2');

    final snapshot = await repository.watchAll().first;
    expect(snapshot, {'nlp_model': 'v2'});
    expect(
      await repository.getAll(),
      hasLength(1),
      reason: 'unique index membuat set menjadi upsert',
    );
  });

  test('remove menghapus preferensi', () async {
    await repository.set('locale', 'id');

    expect(await repository.remove('locale'), isTrue);
    expect(await repository.remove('locale'), isFalse);
    expect(await repository.get('locale'), isNull);
  });

  test('watchAll memantau perubahan', () async {
    final emissions = <Map<String, String>>[];
    final subscription = repository.watchAll().listen(emissions.add);
    addTearDown(subscription.cancel);

    await repository.set('a', '1');
    await repository.set('b', '2');
    await pumpEventQueue();

    expect(emissions, isNotEmpty);
    expect(emissions.last, {'a': '1', 'b': '2'});
  });
}

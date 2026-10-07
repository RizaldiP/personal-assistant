import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/ideas/data/repositories/idea_repository_impl.dart';
import 'package:personal_offline/features/ideas/domain/entities/idea.dart';
import 'package:personal_offline/features/ideas/domain/repositories/idea_repository.dart';

void main() {
  late db.AppDatabase database;
  late IdeaRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = IdeaRepositoryImpl(database.ideaDao, database.tagDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('create memakai status default inbox dan timestamp clock', () async {
    final id = await repository.create(
      const Idea(title: 'Aplikasi inventory kapal'),
    );

    final idea = await repository.getById(id);
    expect(idea, isNotNull);
    expect(idea!.title, 'Aplikasi inventory kapal');
    expect(idea.status, IdeaStatus.inbox);
    expect(idea.content, isNull);
    expect(idea.tags, isEmpty);
    expect(idea.createdAt, start.toUtc());
    expect(idea.updatedAt, start.toUtc());
  });

  test('create dari NLP menyimpan source dan confidence', () async {
    final id = await repository.create(
      const Idea(
        title: 'Aplikasi pemantau utang',
        source: 'rule',
        rawInput: 'ide: aplikasi pemantau utang',
        confidence: 0.8,
      ),
    );

    final idea = await repository.getById(id);
    expect(idea!.source, 'rule');
    expect(idea.confidence, 0.8);
  });

  test('update mengubah judul status dan tag', () async {
    final id = await repository.create(
      const Idea(title: 'Lama', tags: ['lama']),
    );
    final idea = (await repository.getById(id))!;

    clock.value = start.add(const Duration(minutes: 5));
    await repository.update(
      idea.copyWith(
        title: 'Baru',
        status: IdeaStatus.completed,
        tags: ['sudah'],
      ),
    );

    final updated = (await repository.getById(id))!;
    expect(updated.title, 'Baru');
    expect(updated.status, IdeaStatus.completed);
    expect(updated.tags, ['sudah']);
    expect(updated.updatedAt, start.add(const Duration(minutes: 5)));
    expect(updated.createdAt, start.toUtc());
  });

  test('update tanpa id mengembalikan false', () async {
    expect(await repository.update(const Idea(title: 'X')), isFalse);
  });

  test('deleteById menghapus ide beserta tautan tag', () async {
    final id = await repository.create(
      const Idea(title: 'Hapus', tags: ['bekas']),
    );

    expect(await repository.deleteById(id), isTrue);
    expect(await repository.getById(id), isNull);
    expect(await repository.deleteById(999), isFalse);

    final linkRows = await database
        .customSelect(
          "SELECT COUNT(*) AS total FROM tag_links WHERE entity_type = 'idea'",
        )
        .get();
    expect(linkRows.single.data['total'], 0);
  });

  test('watchIdeas memancarkan urutan terbaru dengan tag', () async {
    await repository.create(const Idea(title: 'Pertama'));
    final secondId = await repository.create(
      const Idea(title: 'Kedua', tags: ['penting']),
    );

    final emitted = await repository.watchIdeas().first;

    expect(emitted, hasLength(2));
    expect(emitted.first.id, secondId);
    expect(emitted.first.tags, ['penting']);
    expect(emitted.last.title, 'Pertama');
  });

  test('getAll dan watchIdeas mencari berdasarkan judul dan konten', () async {
    await repository.create(
      const Idea(title: 'Aplikasi inventory kapal', content: 'Untuk gudang'),
    );
    await repository.create(
      const Idea(title: 'Skuadron pengecoran', content: 'Ide bisnis'),
    );

    expect(await repository.getAll(query: 'inventory'), hasLength(1));

    final byContent = await repository.getAll(query: 'bisnis');
    expect(byContent.single.title, 'Skuadron pengecoran');

    final emitted = await repository.watchIdeas(query: 'kapal').first;
    expect(emitted.single.title, 'Aplikasi inventory kapal');

    expect(await repository.getAll(query: 'tidak-ada'), isEmpty);
  });
}

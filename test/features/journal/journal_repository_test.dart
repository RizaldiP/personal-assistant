import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/journal/domain/entities/journal_entry.dart';
import 'package:personal_offline/features/journal/domain/repositories/journal_repository.dart';

void main() {
  late db.AppDatabase database;
  late JournalRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = JournalRepositoryImpl(
      database.journalDao,
      database.tagDao,
      clock,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('create memakai timestamp clock dan mengembalikan id', () async {
    final id = await repository.create(
      const JournalEntry(
        date: '2026-10-05',
        content: 'Capek banget',
        mood: 'capek',
      ),
    );

    final entry = await repository.getById(id);
    expect(entry, isNotNull);
    expect(entry!.date, '2026-10-05');
    expect(entry.content, 'Capek banget');
    expect(entry.mood, 'capek');
    expect(entry.title, isNull);
    expect(entry.tags, isEmpty);
    expect(entry.createdAt, start.toUtc());
    expect(entry.updatedAt, start.toUtc());
  });

  test('create menyimpan tags lowercase', () async {
    final id = await repository.create(
      const JournalEntry(
        date: '2026-10-05',
        content: 'Kerja lembur',
        tags: ['Kapal'],
      ),
    );

    final entry = await repository.getById(id);
    expect(entry!.tags, ['kapal']);
  });

  test('update mengubah konten dan mengganti tag', () async {
    final id = await repository.create(
      const JournalEntry(date: '2026-10-05', content: 'Lama'),
    );
    final entry = (await repository.getById(id))!;

    clock.value = start.add(const Duration(hours: 1));
    await repository.update(
      entry.copyWith(content: 'Baru', tags: ['refleksi']),
    );

    final updated = (await repository.getById(id))!;
    expect(updated.content, 'Baru');
    expect(updated.tags, ['refleksi']);
    expect(updated.updatedAt, start.add(const Duration(hours: 1)));
  });

  test('update tanpa id mengembalikan false', () async {
    expect(
      await repository.update(
        const JournalEntry(date: '2026-10-05', content: 'X'),
      ),
      isFalse,
    );
  });

  test('deleteById menghapus entri beserta tautan tag', () async {
    final id = await repository.create(
      const JournalEntry(date: '2026-10-05', content: 'Hapus', tags: ['x']),
    );

    expect(await repository.deleteById(id), isTrue);
    expect(await repository.getById(id), isNull);
    expect(await repository.deleteById(999), isFalse);

    final linkRows = await database
        .customSelect(
          "SELECT COUNT(*) AS total FROM tag_links WHERE entity_type = 'journal'",
        )
        .get();
    expect(linkRows.single.data['total'], 0);
  });

  test('watchEntries memancarkan urutan tanggal terbaru', () async {
    await repository.create(
      const JournalEntry(date: '2026-10-03', content: 'Tiga'),
    );
    final latestId = await repository.create(
      const JournalEntry(date: '2026-10-05', content: 'Terbaru'),
    );
    await repository.create(
      const JournalEntry(date: '2026-10-04', content: 'Empat'),
    );

    final emitted = await repository.watchEntries().first;

    expect(emitted.first.id, latestId, reason: 'tanggal terbaru di atas');
    expect(emitted.map((e) => e.content), ['Terbaru', 'Empat', 'Tiga']);
  });

  test('getAll dan watchEntries mencari berdasarkan konten dan mood', () async {
    await repository.create(
      const JournalEntry(
        date: '2026-10-05',
        content: 'Capek banget',
        mood: 'capek',
      ),
    );
    await repository.create(
      const JournalEntry(
        date: '2026-10-04',
        content: 'Senang sekali',
        mood: 'senang',
      ),
    );

    expect(await repository.getAll(query: 'sekali'), hasLength(1));

    final byMood = await repository.getAll(query: 'capek');
    expect(byMood.single.content, 'Capek banget');

    final emitted = await repository.watchEntries(query: 'senang sekali').first;
    expect(emitted.single.mood, 'senang');
  });
}

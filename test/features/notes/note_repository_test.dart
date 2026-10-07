import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/notes/domain/entities/note.dart';
import 'package:personal_offline/features/notes/domain/repositories/note_repository.dart';

void main() {
  late db.AppDatabase database;
  late NoteRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = NoteRepositoryImpl(database.noteDao, database.tagDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('create memakai timestamp clock dan mengembalikan id', () async {
    final id = await repository.create(
      const Note(content: 'Resep rendang', title: 'Resep'),
    );

    final note = await repository.getById(id);
    expect(note, isNotNull);
    expect(note!.title, 'Resep');
    expect(note.content, 'Resep rendang');
    expect(note.source, isNull);
    expect(note.tags, isEmpty);
    expect(note.createdAt, start.toUtc());
    expect(note.updatedAt, start.toUtc());
  });

  test('create menyimpan tags lowercase tanpa duplikat', () async {
    final id = await repository.create(
      const Note(content: 'Suku cadang', tags: ['Kapal', ' spares ', 'KAPAL']),
    );

    final note = await repository.getById(id);
    expect(note!.tags, ['kapal', 'spares']);
  });

  test('create dari NLP menyimpan source rawInput confidence', () async {
    final id = await repository.create(
      const Note(
        content: 'Nomor sparepart 12345',
        source: 'rule',
        rawInput: 'catatan: nomor sparepart 12345',
        confidence: 0.8,
      ),
    );

    final note = await repository.getById(id);
    expect(note!.source, 'rule');
    expect(note.rawInput, 'catatan: nomor sparepart 12345');
    expect(note.confidence, 0.8);
  });

  test('update mengubah konten dan mengganti seluruh tag', () async {
    final id = await repository.create(
      const Note(content: 'Lama', tags: ['lama']),
    );
    final note = (await repository.getById(id))!;

    clock.value = start.add(const Duration(minutes: 5));
    await repository.update(
      note.copyWith(content: 'Baru', tags: ['baru', 'penting']),
    );

    final updated = (await repository.getById(id))!;
    expect(updated.content, 'Baru');
    expect(updated.tags, ['baru', 'penting']);
    expect(updated.updatedAt, start.add(const Duration(minutes: 5)));
    expect(updated.createdAt, start.toUtc());
  });

  test('update tanpa id mengembalikan false', () async {
    expect(await repository.update(const Note(content: 'X')), isFalse);
  });

  test('deleteById menghapus catatan beserta tautan tag', () async {
    final id = await repository.create(
      const Note(content: 'Hapus saya', tags: ['bekas']),
    );

    expect(await repository.deleteById(id), isTrue);
    expect(await repository.getById(id), isNull);
    expect(await repository.deleteById(999), isFalse);

    final linkRows = await database
        .customSelect(
          "SELECT COUNT(*) AS total FROM tag_links WHERE entity_type = 'note'",
        )
        .get();
    expect(linkRows.single.data['total'], 0);
  });

  test('watchNotes memancarkan urutan terbaru dengan tag tergabung', () async {
    await repository.create(const Note(content: 'Pertama'));
    final secondId = await repository.create(
      const Note(content: 'Kedua', tags: ['penting']),
    );

    final emitted = await repository.watchNotes().first;

    expect(emitted, hasLength(2));
    expect(emitted.first.id, secondId, reason: 'createdAt desc');
    expect(emitted.first.tags, ['penting']);
    expect(emitted.last.content, 'Pertama');
    expect(emitted.last.tags, isEmpty);
  });

  test('getAll dan watchNotes mencari berdasarkan konten', () async {
    await repository.create(const Note(content: 'Resep sup ayam'));
    await repository.create(const Note(content: 'Nomor kontak agen'));

    final all = await repository.getAll();
    expect(all, hasLength(2));

    final found = await repository.getAll(query: 'resep');
    expect(found.single.content, 'Resep sup ayam');

    final emitted = await repository.watchNotes(query: 'agen').first;
    expect(emitted.single.content, 'Nomor kontak agen');

    expect(await repository.getAll(query: 'kosong-tidak-ada'), isEmpty);
  });
}

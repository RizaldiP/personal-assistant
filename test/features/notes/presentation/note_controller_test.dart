import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/notes/presentation/providers/note_controller.dart';

import '../../../helpers/fake_note_repository.dart';

void main() {
  late FakeNoteRepository repository;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeNoteRepository();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  NoteController controller() =>
      container.read(noteControllerProvider.notifier);

  test('create menyimpan catatan dengan tag', () async {
    await controller().create(content: 'Resep rendang', tags: ['resep']);

    final note = repository.notes.single;
    expect(note.content, 'Resep rendang');
    expect(note.tags, ['resep']);
    expect(note.source, isNull);
  });

  test('create meneruskan metadata NLP', () async {
    await controller().create(
      content: 'Nomor sparepart 12345',
      source: 'rule',
      rawInput: 'catatan: nomor sparepart 12345',
      confidence: 0.8,
    );

    final note = repository.notes.single;
    expect(note.source, 'rule');
    expect(note.confidence, 0.8);
  });

  test('update mengubah konten lalu delete menghapus', () async {
    final id = await controller().create(content: 'Lama');
    final note = repository.notes.single;

    await controller().update(note.copyWith(content: 'Baru'));
    expect(repository.notes.single.content, 'Baru');

    expect(await controller().delete(id), isTrue);
    expect(repository.notes, isEmpty);

    expect(await controller().delete(999), isFalse);
  });

  test('notesProvider memancarkan perubahan dengan query', () async {
    await controller().create(content: 'Resep sup ayam');
    await controller().create(content: 'Nomor agen kapal');

    final all = await container.read(notesProvider('').future);
    expect(all, hasLength(2));

    final filtered = await container.read(notesProvider('resep').future);
    expect(filtered.single.content, 'Resep sup ayam');
  });
}

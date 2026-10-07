import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/journal/presentation/providers/journal_controller.dart';

import '../../../helpers/fake_journal_repository.dart';

void main() {
  late FakeJournalRepository repository;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeJournalRepository();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  JournalController controller() =>
      container.read(journalControllerProvider.notifier);

  test('create memakai tanggal default hari ini dari clock', () async {
    await controller().create(content: 'Capek banget', mood: 'capek');

    final entry = repository.entries.single;
    expect(entry.date, '2026-10-05');
    expect(entry.content, 'Capek banget');
    expect(entry.mood, 'capek');
    expect(entry.tags, isEmpty);
  });

  test('create memakai tanggal yang diberikan', () async {
    await controller().create(
      content: 'Kerja lembur',
      date: '2026-10-06',
      tags: ['kerja'],
      source: 'rule',
      confidence: 0.9,
    );

    final entry = repository.entries.single;
    expect(entry.date, '2026-10-06');
    expect(entry.tags, ['kerja']);
    expect(entry.source, 'rule');
    expect(entry.confidence, 0.9);
  });

  test('update mengubah konten lalu delete menghapus', () async {
    final id = await controller().create(content: 'Lama');
    final entry = repository.entries.single;

    await controller().update(entry.copyWith(content: 'Baru'));
    expect(repository.entries.single.content, 'Baru');

    expect(await controller().delete(id), isTrue);
    expect(repository.entries, isEmpty);

    expect(await controller().delete(999), isFalse);
  });

  test('journalEntriesProvider memancarkan perubahan dengan query', () async {
    await controller().create(content: 'Capek banget', mood: 'capek');
    await controller().create(content: 'Senang sekali', mood: 'senang');

    final all = await container.read(journalEntriesProvider('').future);
    expect(all, hasLength(2));

    final filtered = await container.read(
      journalEntriesProvider('senang').future,
    );
    expect(filtered.single.content, 'Senang sekali');
  });
}

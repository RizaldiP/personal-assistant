import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/ideas/data/repositories/idea_repository_impl.dart';
import 'package:personal_offline/features/ideas/domain/entities/idea.dart';
import 'package:personal_offline/features/ideas/presentation/providers/idea_controller.dart';

import '../../../helpers/fake_idea_repository.dart';

void main() {
  late FakeIdeaRepository repository;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeIdeaRepository();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    container = ProviderContainer(
      overrides: [
        ideaRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  IdeaController controller() =>
      container.read(ideaControllerProvider.notifier);

  test('create menyimpan ide dengan status default inbox', () async {
    await controller().create(title: 'Aplikasi inventory kapal');

    final idea = repository.ideas.single;
    expect(idea.title, 'Aplikasi inventory kapal');
    expect(idea.status, IdeaStatus.inbox);
    expect(idea.tags, isEmpty);
  });

  test('create meneruskan metadata NLP dan tag', () async {
    await controller().create(
      title: 'Aplikasi pemantau utang',
      source: 'rule',
      rawInput: 'ide: aplikasi pemantau utang',
      confidence: 0.8,
      tags: ['aplikasi'],
    );

    final idea = repository.ideas.single;
    expect(idea.source, 'rule');
    expect(idea.confidence, 0.8);
    expect(idea.tags, ['aplikasi']);
  });

  test('setStatus mengubah status ide', () async {
    final id = await controller().create(title: 'Ide lama');
    final idea = repository.ideas.single;

    await controller().setStatus(idea, IdeaStatus.completed);
    expect(repository.ideas.single.status, IdeaStatus.completed);

    await controller().setStatus(idea.copyWith(id: id), IdeaStatus.archived);
    expect(repository.ideas.single.status, IdeaStatus.archived);
  });

  test('update mengubah judul lalu delete menghapus', () async {
    final id = await controller().create(title: 'Lama');
    final idea = repository.ideas.single;

    await controller().update(idea.copyWith(title: 'Baru'));
    expect(repository.ideas.single.title, 'Baru');

    expect(await controller().delete(id), isTrue);
    expect(repository.ideas, isEmpty);

    expect(await controller().delete(999), isFalse);
  });

  test('ideasProvider memancarkan perubahan dengan query', () async {
    await controller().create(title: 'Aplikasi inventory kapal');
    await controller().create(title: 'Skuadron pengecoran');

    final all = await container.read(ideasProvider('').future);
    expect(all, hasLength(2));

    final filtered = await container.read(ideasProvider('inventory').future);
    expect(filtered.single.title, 'Aplikasi inventory kapal');
  });
}

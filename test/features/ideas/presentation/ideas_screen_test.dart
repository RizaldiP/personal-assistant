import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/ideas/data/repositories/idea_repository_impl.dart';
import 'package:personal_offline/features/ideas/domain/entities/idea.dart';
import 'package:personal_offline/features/ideas/presentation/screens/ideas_screen.dart';

import '../../../helpers/fake_idea_repository.dart';

void main() {
  final fixedClock = FixedClock(DateTime(2026, 10, 5, 9));

  Future<void> pumpIdeas(
    WidgetTester tester,
    FakeIdeaRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ideaRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(fixedClock),
        ],
        child: const MaterialApp(home: IdeasScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kosong menampilkan empty state dan FAB', (tester) async {
    await pumpIdeas(tester, FakeIdeaRepository());

    expect(find.text('Belum ada ide'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB membuat ide baru dengan validasi judul', (tester) async {
    final repository = FakeIdeaRepository();
    await pumpIdeas(tester, repository);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Ide baru'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Judul wajib diisi'), findsOneWidget);
    expect(repository.ideas, isEmpty);

    await tester.enterText(
      find.byType(TextField).at(0),
      'Aplikasi inventory kapal',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Untuk gudang');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final idea = repository.ideas.single;
    expect(idea.title, 'Aplikasi inventory kapal');
    expect(idea.content, 'Untuk gudang');
    expect(idea.status, IdeaStatus.inbox);

    expect(find.text('INBOX'), findsOneWidget);
    expect(find.text('Aplikasi inventory kapal'), findsOneWidget);
  });

  testWidgets('menu status memindahkan ide ke kelompok lain', (tester) async {
    final repository = FakeIdeaRepository(
      seed: [const Idea(id: 1, title: 'Ide lama')],
    );
    await pumpIdeas(tester, repository);

    expect(find.text('INBOX'), findsOneWidget);

    await tester.tap(find.byTooltip('Ubah status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindah ke Completed'));
    await tester.pumpAndSettle();

    expect(repository.ideas.single.status, IdeaStatus.completed);
    expect(find.text('INBOX'), findsNothing);
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('pencarian memfilter daftar ide', (tester) async {
    final repository = FakeIdeaRepository(
      seed: const [
        Idea(id: 1, title: 'Aplikasi inventory kapal'),
        Idea(id: 2, title: 'Skuadron pengecoran'),
      ],
    );
    await pumpIdeas(tester, repository);

    await tester.tap(find.byTooltip('Cari ide'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inventory');
    await tester.pumpAndSettle();

    expect(find.text('Aplikasi inventory kapal'), findsOneWidget);
    expect(find.text('Skuadron pengecoran'), findsNothing);
  });

  testWidgets('hapus ide lewat dialog', (tester) async {
    final repository = FakeIdeaRepository(
      seed: [const Idea(id: 1, title: 'Hapus saya')],
    );
    await pumpIdeas(tester, repository);

    await tester.tap(find.text('Hapus saya'));
    await tester.pumpAndSettle();
    expect(find.text('Edit ide'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus ide'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus ide?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(repository.ideas, isEmpty);
    expect(find.text('Belum ada ide'), findsOneWidget);
  });
}

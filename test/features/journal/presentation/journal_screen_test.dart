import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/journal/domain/entities/journal_entry.dart';
import 'package:personal_offline/features/journal/presentation/screens/journal_screen.dart';

import '../../../helpers/fake_journal_repository.dart';

void main() {
  final fixedClock = FixedClock(DateTime(2026, 10, 5, 9));

  Future<void> pumpJournal(
    WidgetTester tester,
    FakeJournalRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(fixedClock),
        ],
        child: const MaterialApp(home: JournalScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kosong menampilkan empty state dan FAB', (tester) async {
    await pumpJournal(tester, FakeJournalRepository());

    expect(find.text('Belum ada jurnal'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB menulis jurnal baru dengan mood dan tanggal hari ini', (
    tester,
  ) async {
    final repository = FakeJournalRepository();
    await pumpJournal(tester, repository);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Jurnal baru'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Cerita wajib diisi'), findsOneWidget);
    expect(repository.entries, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'Capek banget');
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('capek').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final entry = repository.entries.single;
    expect(entry.content, 'Capek banget');
    expect(entry.mood, 'capek');
    expect(entry.date, '2026-10-05');

    expect(find.text('Capek banget'), findsOneWidget);
    expect(find.text('Jurnal baru'), findsNothing);
  });

  testWidgets('pencarian memfilter daftar jurnal', (tester) async {
    final repository = FakeJournalRepository(
      seed: [
        const JournalEntry(id: 1, date: '2026-10-04', content: 'Hari lembur'),
        const JournalEntry(id: 2, date: '2026-10-05', content: 'Libur pantai'),
      ],
    );
    await pumpJournal(tester, repository);

    expect(find.text('Hari lembur'), findsOneWidget);
    expect(find.text('Libur pantai'), findsOneWidget);

    await tester.tap(find.byTooltip('Cari jurnal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lembur');
    await tester.pumpAndSettle();

    expect(find.text('Hari lembur'), findsOneWidget);
    expect(find.text('Libur pantai'), findsNothing);
  });

  testWidgets('hapus entri jurnal lewat dialog', (tester) async {
    final repository = FakeJournalRepository(
      seed: [
        const JournalEntry(id: 1, date: '2026-10-05', content: 'Hapus saya'),
      ],
    );
    await pumpJournal(tester, repository);

    await tester.tap(find.text('Hapus saya'));
    await tester.pumpAndSettle();
    expect(find.text('Edit jurnal'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus entri'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus entri jurnal?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(repository.entries, isEmpty);
    expect(find.text('Belum ada jurnal'), findsOneWidget);
  });
}

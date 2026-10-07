import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/notes/domain/entities/note.dart';
import 'package:personal_offline/features/notes/presentation/screens/notes_screen.dart';

import '../../../helpers/fake_note_repository.dart';

void main() {
  final fixedClock = FixedClock(DateTime(2026, 10, 5, 9));

  Future<void> pumpNotes(
    WidgetTester tester,
    FakeNoteRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(fixedClock),
        ],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kosong menampilkan empty state dan FAB', (tester) async {
    await pumpNotes(tester, FakeNoteRepository());

    expect(find.text('Belum ada catatan'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB membuat catatan baru dengan validasi wajib isi', (
    tester,
  ) async {
    final repository = FakeNoteRepository();
    await pumpNotes(tester, repository);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Catatan baru'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Isi wajib diisi'), findsOneWidget);
    expect(repository.notes, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'Suku cadang');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Nomor sparepart 12345',
    );
    await tester.enterText(find.byType(TextField).at(2), 'Kapal, spares');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final note = repository.notes.single;
    expect(note.title, 'Suku cadang');
    expect(note.content, 'Nomor sparepart 12345');
    expect(note.tags, ['kapal', 'spares']);

    expect(find.text('Suku cadang'), findsOneWidget);
    expect(find.text('Catatan baru'), findsNothing);
  });

  testWidgets('pencarian memfilter daftar catatan', (tester) async {
    final repository = FakeNoteRepository(
      seed: [
        const Note(id: 1, content: 'Resep sup ayam'),
        const Note(id: 2, content: 'Nomor kontak agen'),
      ],
    );
    await pumpNotes(tester, repository);

    expect(find.text('Resep sup ayam'), findsOneWidget);
    expect(find.text('Nomor kontak agen'), findsOneWidget);

    await tester.tap(find.byTooltip('Cari catatan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'resep');
    await tester.pumpAndSettle();

    expect(find.text('Resep sup ayam'), findsOneWidget);
    expect(find.text('Nomor kontak agen'), findsNothing);

    await tester.tap(find.byTooltip('Tutup pencarian'));
    await tester.pumpAndSettle();

    expect(find.text('Resep sup ayam'), findsOneWidget);
    expect(find.text('Nomor kontak agen'), findsOneWidget);
  });

  testWidgets('menyentuh tile membuka edit dan menyimpan perubahan', (
    tester,
  ) async {
    final repository = FakeNoteRepository(
      seed: [const Note(id: 1, content: 'Resep lama')],
    );
    await pumpNotes(tester, repository);

    await tester.tap(find.text('Resep lama'));
    await tester.pumpAndSettle();
    expect(find.text('Edit catatan'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Resep baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.notes.single.content, 'Resep baru');
    expect(find.text('Resep baru'), findsOneWidget);
    expect(find.text('Edit catatan'), findsNothing);
  });

  testWidgets('hapus catatan lewat dialog menghapus dan kembali', (
    tester,
  ) async {
    final repository = FakeNoteRepository(
      seed: [const Note(id: 1, content: 'Hapus saya')],
    );
    await pumpNotes(tester, repository);

    await tester.tap(find.text('Hapus saya'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hapus catatan'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus catatan?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(repository.notes, isEmpty);
    expect(find.text('Belum ada catatan'), findsOneWidget);
  });
}

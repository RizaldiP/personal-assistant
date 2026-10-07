import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/presentation/providers/pending_confirmation.dart';
import 'package:personal_offline/features/chat/presentation/screens/chat_screen.dart';
import 'package:personal_offline/features/inbox/data/repositories/inbox_repository_impl.dart';
import 'package:personal_offline/features/inbox/domain/entities/inbox_item.dart';
import 'package:personal_offline/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/search/data/repositories/search_repository_impl.dart';
import 'package:personal_offline/features/search/presentation/screens/search_screen.dart';

import '../../../helpers/fake_chat_repository.dart';
import '../../../helpers/fake_inbox_repository.dart';
import '../../../helpers/fake_note_repository.dart';
import '../../../helpers/fake_search_repository.dart';

void main() {
  late FakeInboxRepository repository;
  late FakeNoteRepository noteRepository;
  late FakeChatRepository chatRepository;

  setUp(() {
    repository = FakeInboxRepository();
    noteRepository = FakeNoteRepository();
    chatRepository = FakeChatRepository();
  });

  Future<void> pumpInbox(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repository),
          noteRepositoryProvider.overrideWithValue(noteRepository),
          chatRepositoryProvider.overrideWithValue(chatRepository),
          searchRepositoryProvider.overrideWithValue(FakeSearchRepository()),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 8))),
          ...overrides,
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('inbox kosong menampilkan empty state', (tester) async {
    await pumpInbox(tester);

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Inbox kosong'), findsOneWidget);
    expect(find.byKey(const Key('inbox-filter-open')), findsOneWidget);
    expect(find.byKey(const Key('inbox-filter-done')), findsOneWidget);
    expect(find.byKey(const Key('inbox-filter-all')), findsOneWidget);
  });

  testWidgets('daftar item menampilkan teks dan label saran', (tester) async {
    await repository.addOpen(
      rawText: 'lusa rapat kapal',
      suggestion: 'create_reminder',
    );
    await repository.addOpen(rawText: 'hm begini deh');

    await pumpInbox(tester);

    expect(find.byKey(const Key('inbox-item-1')), findsOneWidget);
    expect(find.byKey(const Key('inbox-item-2')), findsOneWidget);
    expect(find.text('lusa rapat kapal'), findsOneWidget);
    expect(find.text('Saran: reminder'), findsOneWidget);
    expect(find.text('hm begini deh'), findsOneWidget);
    expect(find.text('Inbox kosong'), findsNothing);
  });

  testWidgets('filter status menyembunyikan item di luar status', (
    tester,
  ) async {
    final openId = await repository.addOpen(rawText: 'masih terbuka');
    final doneId = await repository.addOpen(rawText: 'sudah selesai');
    await repository.markDiscarded(doneId);
    expect(openId, isNotNull);

    await pumpInbox(tester);

    expect(find.text('masih terbuka'), findsOneWidget);
    expect(find.text('sudah selesai'), findsNothing);

    await tester.tap(find.byKey(const Key('inbox-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('masih terbuka'), findsOneWidget);
    expect(find.text('sudah selesai'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox-filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('masih terbuka'), findsNothing);
    expect(find.text('sudah selesai'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox-filter-open')));
    await tester.pumpAndSettle();
    expect(find.text('masih terbuka'), findsOneWidget);
  });

  testWidgets('filter dengan hasil kosong menampilkan pesan khusus', (
    tester,
  ) async {
    await repository.addOpen(rawText: 'item terbuka');
    await pumpInbox(tester);

    await tester.tap(find.byKey(const Key('inbox-filter-done')));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada item'), findsOneWidget);
    expect(find.text('Inbox kosong'), findsNothing);
  });

  testWidgets('aksi Simpan sebagai Catatan membuat catatan lalu menandai', (
    tester,
  ) async {
    final id = await repository.addOpen(
      rawText: 'nomor kontak agen kapal',
      suggestion: 'create_note',
    );

    await pumpInbox(tester);
    await tester.tap(find.byKey(Key('inbox-item-$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inbox-action-note')), findsOneWidget);
    expect(find.byKey(const Key('inbox-action-chat')), findsOneWidget);
    expect(find.byKey(const Key('inbox-action-discard')), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox-action-note')));
    await tester.pumpAndSettle();

    expect(find.text('Disimpan sebagai catatan.'), findsOneWidget);
    expect(noteRepository.notes.single.content, 'nomor kontak agen kapal');
    final item = (await repository.getById(id))!;
    expect(item.resolution, InboxResolution.converted);
    expect(item.resolvedEntityType, 'note');
    expect(item.resolvedEntityId, noteRepository.notes.single.id);
    expect(
      find.text('Tidak ada item'),
      findsOneWidget,
      reason: 'item pindah ke status selesai',
    );
  });

  testWidgets('aksi Buka di Chat mengisi draf lalu membuka percakapan', (
    tester,
  ) async {
    final id = await repository.addOpen(rawText: 'tadi makan ayam 25 ribu');

    await pumpInbox(tester);
    await tester.tap(find.byKey(Key('inbox-item-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox-action-chat')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatScreen)),
    );
    expect(
      container.read(chatDraftProvider),
      'tadi makan ayam 25 ribu',
      reason: 'draf terisi di provider chat',
    );
    final item = (await repository.getById(id))!;
    expect(
      item.resolution,
      InboxResolution.open,
      reason: 'item tetap terbuka sampai teksnya dieksekusi',
    );
  });

  testWidgets('aksi Abaikan menandai item dibuang', (tester) async {
    final id = await repository.addOpen(rawText: 'buang ini');

    await pumpInbox(tester);
    await tester.tap(find.byKey(Key('inbox-item-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox-action-discard')));
    await tester.pumpAndSettle();

    final item = (await repository.getById(id))!;
    expect(item.resolution, InboxResolution.discarded);
    expect(find.text('Tidak ada item'), findsOneWidget);
  });

  testWidgets('item yang sudah selesai tidak membuka bottom sheet aksi', (
    tester,
  ) async {
    final id = await repository.addOpen(rawText: 'sudah dikonversi');
    await repository.markConverted(id, entityType: 'note', entityId: 1);

    await pumpInbox(tester);
    expect(
      find.byKey(Key('inbox-item-$id')),
      findsNothing,
      reason: 'filter Terbuka menyembunyikan item selesai',
    );

    await tester.tap(find.byKey(const Key('inbox-filter-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('inbox-item-$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('inbox-item-$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inbox-action-note')), findsNothing);
    expect(find.byKey(const Key('inbox-action-discard')), findsNothing);
  });

  testWidgets('tombol cari di AppBar membuka layar Pencarian', (tester) async {
    await pumpInbox(tester);

    await tester.tap(find.byKey(const Key('inbox-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
  });
}

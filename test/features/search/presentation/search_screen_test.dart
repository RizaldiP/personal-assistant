import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/notes/presentation/screens/notes_screen.dart';
import 'package:personal_offline/features/search/data/repositories/search_repository_impl.dart';
import 'package:personal_offline/features/search/domain/search_result.dart';
import 'package:personal_offline/features/search/presentation/screens/search_screen.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';

import '../../../helpers/fake_note_repository.dart';
import '../../../helpers/fake_search_repository.dart';
import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeSearchRepository repository;

  setUp(() {
    repository = FakeSearchRepository();
  });

  Future<void> pumpSearch(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(repository),
          noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 8))),
          ...overrides,
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeQuery(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('search-input')), text);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('sebelum mengetik menampilkan empty state pencarian', (
    tester,
  ) async {
    await pumpSearch(tester);

    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Mulai mencari'), findsOneWidget);
    expect(find.byKey(const Key('search-input')), findsOneWidget);
    expect(repository.searchCalls, 0);
  });

  testWidgets('mengetik mencari setelah debounce 250 ms', (tester) async {
    repository.results = [
      const SearchResult(
        type: SearchTypes.note,
        id: 1,
        title: 'Catatan liburan Bali',
        subtitle: 'Pantai Kuta',
        tags: ['liburan'],
      ),
    ];
    await pumpSearch(tester);

    await tester.enterText(find.byKey(const Key('search-input')), 'bali');
    expect(repository.searchCalls, 0, reason: 'belum lewat debounce');

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);
    expect(repository.lastQuery, 'bali');
    expect(repository.lastType, isNull);
    expect(find.text('Catatan'), findsWidgets, reason: 'section label');
    expect(find.byKey(const Key('search-result-note-1')), findsOneWidget);
    expect(find.text('Catatan liburan Bali'), findsOneWidget);
  });

  testWidgets('filter tipe meneruskan tipe ke repository', (tester) async {
    repository.results = [
      const SearchResult(type: SearchTypes.todo, id: 2, title: 'Tugas liburan'),
    ];
    await pumpSearch(tester);
    await typeQuery(tester, 'liburan');
    expect(find.byKey(const Key('search-result-todo-2')), findsOneWidget);
    expect(repository.lastType, isNull);

    await tester.tap(find.byKey(const Key('search-filter-todo')));
    await tester.pumpAndSettle();

    expect(repository.lastType, SearchTypes.todo);
    expect(repository.lastQuery, 'liburan');
    expect(find.byKey(const Key('search-result-todo-2')), findsOneWidget);
    expect(find.text('Tugas liburan'), findsOneWidget);
  });

  testWidgets('chip tag tersedia dan meneruskan tag ke repository', (
    tester,
  ) async {
    repository.tagNames = ['kapal', 'liburan'];
    repository.results = [
      const SearchResult(
        type: SearchTypes.note,
        id: 3,
        title: 'Catatan kapal',
        tags: ['kapal'],
      ),
    ];
    await pumpSearch(tester);

    expect(find.byKey(const Key('search-filter-tag-all')), findsOneWidget);
    expect(find.byKey(const Key('search-tag-kapal')), findsOneWidget);
    expect(find.byKey(const Key('search-tag-liburan')), findsOneWidget);

    await typeQuery(tester, 'kapal');
    expect(find.byKey(const Key('search-result-note-3')), findsOneWidget);
    expect(repository.lastTag, isNull);

    await tester.ensureVisible(find.byKey(const Key('search-tag-kapal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-tag-kapal')));
    await tester.pumpAndSettle();

    expect(repository.lastTag, 'kapal');
    expect(find.byKey(const Key('search-result-note-3')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('search-filter-tag-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-filter-tag-all')));
    await tester.pumpAndSettle();
    expect(repository.lastTag, isNull, reason: 'Semua tag = tanpa filter');
  });

  testWidgets('hasil kosong menampilkan empty state tidak ada hasil', (
    tester,
  ) async {
    repository.results = [];
    await pumpSearch(tester);

    await typeQuery(tester, 'zzz-tidak-ada');

    expect(find.text('Tidak ada hasil'), findsOneWidget);
  });

  testWidgets('hasil dikelompokkan per tipe dengan section label', (
    tester,
  ) async {
    repository.results = [
      const SearchResult(
        type: SearchTypes.note,
        id: 4,
        title: 'Catatan pertama',
      ),
      const SearchResult(type: SearchTypes.todo, id: 5, title: 'Tugas pertama'),
      const SearchResult(
        type: SearchTypes.reminder,
        id: 6,
        title: 'Ingatkan rapat',
      ),
    ];
    await pumpSearch(tester);

    await typeQuery(tester, 'a');

    expect(
      find.byKey(const Key('search-result-todo-5')),
      findsOneWidget,
      reason: 'section Tugas tampil',
    );
    expect(find.byKey(const Key('search-result-reminder-6')), findsOneWidget);
    expect(find.byKey(const Key('search-result-note-4')), findsOneWidget);
    final todoTop = tester.getTopLeft(
      find.byKey(const Key('search-result-todo-5')),
    );
    final reminderTop = tester.getTopLeft(
      find.byKey(const Key('search-result-reminder-6')),
    );
    final noteTop = tester.getTopLeft(
      find.byKey(const Key('search-result-note-4')),
    );
    expect(
      todoTop.dy,
      lessThan(reminderTop.dy),
      reason: 'urut sesuai SearchTypes.all (todo dulu)',
    );
    expect(reminderTop.dy, lessThan(noteTop.dy));
  });

  testWidgets('mengetuk hasil catatan membuka layar Catatan', (tester) async {
    repository.results = [
      const SearchResult(type: SearchTypes.note, id: 7, title: 'Resep rendang'),
    ];
    await pumpSearch(tester);
    await typeQuery(tester, 'rendang');

    await tester.tap(find.byKey(const Key('search-result-note-7')));
    await tester.pumpAndSettle();

    expect(find.byType(NotesScreen), findsOneWidget);
  });

  testWidgets('hasil reminder tanpa navigasi (belum punya layar)', (
    tester,
  ) async {
    repository.results = [
      const SearchResult(
        type: SearchTypes.reminder,
        id: 8,
        title: 'Bayar listrik',
      ),
    ];
    await pumpSearch(tester);
    await typeQuery(tester, 'listrik');

    await tester.tap(find.byKey(const Key('search-result-reminder-8')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget, reason: 'tetap di sini');
  });
}

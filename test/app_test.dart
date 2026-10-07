import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_offline/app.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/home/presentation/screens/home_screen.dart';
import 'package:personal_offline/features/ideas/data/repositories/idea_repository_impl.dart';
import 'package:personal_offline/features/inbox/data/repositories/inbox_repository_impl.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_chat_repository.dart';
import 'helpers/fake_idea_repository.dart';
import 'helpers/fake_inbox_repository.dart';
import 'helpers/fake_journal_repository.dart';
import 'helpers/fake_local_ai.dart';
import 'helpers/fake_note_repository.dart';
import 'helpers/fake_reminder_repository.dart';
import 'helpers/fake_task_repository.dart';

Finder _navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  FakeTaskRepository? taskRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(
          taskRepository ?? FakeTaskRepository(),
        ),
        // Repo diganti fake: layar Kalender/Inbox menonton stream; stream
        // drift menytupkan query stream lewat timer yang gagal diinvarian
        // widget test bila provider dibuang saat tree dibongkar.
        reminderRepositoryProvider.overrideWithValue(FakeReminderRepository()),
        journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
        inboxRepositoryProvider.overrideWithValue(FakeInboxRepository()),
        localAiRuntimeProvider.overrideWithValue(buildFakeRuntime()),
        ...overrides,
      ],
      child: const PersonalOfflineApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Home', () {
    testWidgets('menampilkan sapaan, tanggal, section hari ini, dan input', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.textContaining('Selamat'), findsOneWidget);
      expect(find.text('HARI INI'), findsOneWidget);
      expect(find.text('Belum ada tugas hari ini'), findsOneWidget);
      expect(find.text('Apa yang ingin kamu lakukan?'), findsOneWidget);
      expect(find.text('Ketik di sini...'), findsOneWidget);
    });

    testWidgets('format tanggal memakai Bahasa Indonesia', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(body: HomeScreen(today: DateTime(2026, 10, 5))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Senin, 5 Oktober 2026'), findsOneWidget);
    });

    testWidgets('HARI INI menampilkan tugas pending hari ini', (tester) async {
      await _pumpApp(
        tester,
        taskRepository: FakeTaskRepository(
          seed: [
            const Task(title: 'Beresin kamar', dueDate: '2026-10-05'),
            const Task(title: 'Tugas besok', dueDate: '2026-10-06'),
          ],
        ),
        overrides: [
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 7))),
        ],
      );

      expect(find.text('Beresin kamar'), findsOneWidget);
      expect(find.text('Tugas besok'), findsNothing);
      expect(find.text('Lihat semua tugas'), findsOneWidget);
    });

    testWidgets('Lihat semua tugas membuka layar Tugas', (tester) async {
      await _pumpApp(
        tester,
        taskRepository: FakeTaskRepository(
          seed: [const Task(title: 'Pagi ini', dueDate: '2026-10-05')],
        ),
        overrides: [
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 7))),
        ],
      );

      await tester.tap(find.text('Lihat semua tugas'));
      await tester.pumpAndSettle();

      expect(find.text('Tugas'), findsOneWidget);
      expect(find.text('Pagi ini'), findsOneWidget);
    });

    testWidgets('mengetuk input chat membuka layar percakapan', (tester) async {
      await _pumpApp(
        tester,
        overrides: [
          chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        ],
      );

      await tester.tap(find.text('Ketik di sini...'));
      await tester.pumpAndSettle();

      expect(find.text('Percakapan'), findsOneWidget);
      expect(find.text('Belum ada percakapan'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('entri Catatan, Jurnal, dan Ide membuka layar masing-masing', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        overrides: [
          noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
          ideaRepositoryProvider.overrideWithValue(FakeIdeaRepository()),
        ],
      );

      await tester.ensureVisible(find.text('Catatan'));
      await tester.tap(find.text('Catatan'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada catatan'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Jurnal'));
      await tester.tap(find.text('Jurnal'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada jurnal'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ide'));
      await tester.tap(find.text('Ide'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada ide'), findsOneWidget);
    });
  });

  group('Navigasi', () {
    testWidgets('bottom navigation berpindah antar lima layar', (tester) async {
      await _pumpApp(tester);
      expect(find.text('HARI INI'), findsOneWidget);

      await tester.tap(_navDestination('Kalender'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada kejadian'), findsOneWidget);

      await tester.tap(_navDestination('Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Inbox kosong'), findsOneWidget);

      await tester.tap(_navDestination('Insight'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada data'), findsOneWidget);

      await tester.tap(_navDestination('Pengaturan'));
      await tester.pumpAndSettle();
      expect(find.text('Mode tema'), findsOneWidget);

      await tester.tap(_navDestination('Beranda'));
      await tester.pumpAndSettle();
      expect(find.text('HARI INI'), findsOneWidget);
    });
  });

  group('Tema', () {
    testWidgets('bisa berpindah light, dark, dan sistem', (tester) async {
      await _pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(app.themeMode, ThemeMode.system);

      await tester.tap(_navDestination('Pengaturan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terang'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });

    testWidgets('pilihan tema tersimpan ke preferensi lokal', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_navDestination('Pengaturan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), 'dark');
    });

    testWidgets('mode tersimpan dipakai ulang saat aplikasi dibuka', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});

      await _pumpApp(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}

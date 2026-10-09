import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/core/widget/home_widget_service.dart';
import 'package:personal_offline/core/widget/widget_keys.dart';
import 'package:personal_offline/core/widget/widget_sync_scope.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/presentation/screens/chat_screen.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';

import '../../helpers/fake_chat_repository.dart';
import '../../helpers/fake_home_widget_service.dart';
import '../../helpers/fake_local_ai.dart';
import '../../helpers/fake_task_repository.dart';

void main() {
  Future<void> pumpScope(
    WidgetTester tester, {
    required FakeHomeWidgetService service,
    required GlobalKey<NavigatorState> navigatorKey,
    List<Override> overrides = const [],
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeWidgetServiceProvider.overrideWithValue(service),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 9, 7))),
          ...overrides,
        ],
        child: WidgetSyncScope(
          navigatorKey: navigatorKey,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  testWidgets('menyinkronkan tugas hari ini ke widget saat data berubah', (
    tester,
  ) async {
    final service = FakeHomeWidgetService();
    addTearDown(service.dispose);
    final repository = FakeTaskRepository(
      seed: const [
        Task(
          id: 1,
          title: 'Masak',
          dueDate: '2026-10-09',
          dueTime: '08:00',
        ),
        Task(
          id: 2,
          title: 'Olahraga',
          dueDate: '2026-10-09',
          status: TaskStatus.done,
        ),
        Task(id: 3, title: 'Besok', dueDate: '2026-10-10'),
      ],
    );

    await pumpScope(
      tester,
      service: service,
      navigatorKey: GlobalKey<NavigatorState>(),
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(service.synced, isNotEmpty);
    expect(
      service.synced.last.map((task) => task.title),
      ['Masak', 'Olahraga'],
    );
  });

  testWidgets('klik tombol chat pada widget membuka layar Percakapan', (
    tester,
  ) async {
    final service = FakeHomeWidgetService();
    addTearDown(service.dispose);
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await pumpScope(
      tester,
      service: service,
      navigatorKey: GlobalKey<NavigatorState>(),
      overrides: [
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        appDatabaseProvider.overrideWithValue(database),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        localAiRuntimeProvider.overrideWithValue(buildFakeRuntime()),
      ],
    );
    await tester.pumpAndSettle();

    service.emitClick(WidgetKeys.chatUri);
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('app yang diluncurkan dari widget langsung membuka Percakapan', (
    tester,
  ) async {
    final service = FakeHomeWidgetService()..initialUri = WidgetKeys.chatUri;
    addTearDown(service.dispose);
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await pumpScope(
      tester,
      service: service,
      navigatorKey: GlobalKey<NavigatorState>(),
      overrides: [
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        appDatabaseProvider.overrideWithValue(database),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        localAiRuntimeProvider.overrideWithValue(buildFakeRuntime()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
  });
}

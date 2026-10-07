import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/ai/ai_config.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_ai.dart';

Future<void> _pumpSettings(
  WidgetTester tester, {
  required LocalAiRuntime runtime,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localAiRuntimeProvider.overrideWithValue(runtime)],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(FilledButton, label);

/// Scroll ke target (kartu AI berada di bawah layar) lalu ketuk.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen — kartu AI lokal', () {
    testWidgets('menampilkan identitas model dan status awal', (tester) async {
      await _pumpSettings(tester, runtime: buildFakeRuntime());

      expect(find.text('AI LOKAL'), findsOneWidget);
      expect(find.text('Model AI lokal'), findsOneWidget);
      expect(find.textContaining(AiConfig.defaultModelName), findsOneWidget);
      expect(find.textContaining('Apache-2.0'), findsWidgets);
      expect(find.text('Model belum diunduh.'), findsOneWidget);
      expect(_button('Unduh model'), findsOneWidget);
    });

    testWidgets('dialog unduh dibatalkan → tidak ada unduhan', (tester) async {
      final manager = FakeAiModelManager();
      await _pumpSettings(tester, runtime: buildFakeRuntime(manager: manager));

      await _tap(tester, _button('Unduh model'));

      expect(find.text('Unduh model AI?'), findsOneWidget);
      expect(find.textContaining('penyimpanan perangkat'), findsOneWidget);
      expect(
        find.textContaining('tidak pernah dikirim keluar'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Batal'));

      expect(manager.downloadCalls, 0);
      expect(find.text('Model belum diunduh.'), findsOneWidget);
    });

    testWidgets('konfirmasi unduh → status jadi terunduh, tombol muat muncul', (
      tester,
    ) async {
      final manager = FakeAiModelManager();
      await _pumpSettings(tester, runtime: buildFakeRuntime(manager: manager));

      await _tap(tester, _button('Unduh model'));
      await _tap(tester, find.text('Unduh'));

      expect(manager.downloadCalls, 1);
      expect(
        find.text('Model sudah diunduh, belum dimuat ke memori.'),
        findsOneWidget,
      );
      expect(_button('Muat model'), findsOneWidget);
    });

    testWidgets('muat model lalu lepas kembali', (tester) async {
      final manager = FakeAiModelManager(cached: true);
      final engine = FakeLocalAiEngine();
      await _pumpSettings(
        tester,
        runtime: buildFakeRuntime(manager: manager, engine: engine),
      );

      expect(_button('Muat model'), findsOneWidget);

      await _tap(tester, _button('Muat model'));

      expect(engine.initializeCalls, 1);
      expect(find.text('Model siap dipakai.'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Lepas model'),
        findsOneWidget,
      );

      await _tap(tester, find.widgetWithText(OutlinedButton, 'Lepas model'));

      expect(manager.unloadCalls, 1);
      expect(
        find.text('Model sudah diunduh, belum dimuat ke memori.'),
        findsOneWidget,
      );
    });

    testWidgets('model sudah dimuat sejak awal ditampilkan siap', (
      tester,
    ) async {
      final manager = FakeAiModelManager(cached: true)..loaded = true;
      final engine = FakeLocalAiEngine()..ready = true;
      await _pumpSettings(
        tester,
        runtime: buildFakeRuntime(manager: manager, engine: engine),
      );

      expect(find.text('Model siap dipakai.'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Lepas model'),
        findsOneWidget,
      );
    });

    testWidgets('kegagalan muat menampilkan pesan error, bukan crash', (
      tester,
    ) async {
      final manager = FakeAiModelManager(cached: true);
      final engine = FakeLocalAiEngine(canLoad: false);
      await _pumpSettings(
        tester,
        runtime: buildFakeRuntime(manager: manager, engine: engine),
      );

      await _tap(tester, _button('Muat model'));

      expect(find.textContaining('Model gagal dimuat'), findsOneWidget);
      expect(find.textContaining('Aplikasi tetap berfungsi'), findsOneWidget);
      expect(_button('Muat model'), findsOneWidget);
    });

    testWidgets('unduhan gagal menampilkan pesan error', (tester) async {
      final manager = FakeAiModelManager()..downloadResult = false;
      await _pumpSettings(tester, runtime: buildFakeRuntime(manager: manager));

      await _tap(tester, _button('Unduh model'));
      await _tap(tester, find.text('Unduh'));

      expect(find.textContaining('Unduhan model gagal'), findsOneWidget);
      expect(_button('Unduh model'), findsOneWidget);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/ai/ai_config.dart';
import 'package:personal_offline/core/ai/llamadart_local_ai_engine.dart';
import 'package:personal_offline/core/ai/local_ai_engine.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';
import 'package:personal_offline/shared/nlp/rule_parser.dart';

void main() {
  late Directory emptyCache;
  late LlamadartLocalAiEngine engine;

  setUp(() {
    emptyCache = Directory.systemTemp.createTempSync('pa_ai_empty_cache_');
    engine = LlamadartLocalAiEngine(
      config: AiConfig(cacheDirectory: emptyCache.path),
    );
  });

  tearDown(() async {
    await engine.dispose();
    if (emptyCache.existsSync()) {
      emptyCache.deleteSync(recursive: true);
    }
  });

  group('LocalAiEngine tanpa model (DoD: app tetap bekerja)', () {
    test('initialize tidak melempar exception saat model tidak ada', () async {
      await expectLater(engine.initialize(), completes);
    });

    test('isAvailable false ketika model tidak dimuat', () async {
      await engine.initialize();

      expect(await engine.isAvailable(), false);
      expect(engine.modelManager.isLoaded, false);
    });

    test(
      'understand melempar LocalAiUnavailableException, bukan crash',
      () async {
        await engine.initialize();

        expect(
          engine.understand('bayar listrik besok jam 8'),
          throwsA(isA<LocalAiUnavailableException>()),
        );
      },
    );

    test('manager menolak load dari cache kosong tanpa crash', () async {
      expect(await engine.modelManager.loadModel(), false);
      expect(engine.modelManager.isLoaded, false);
    });

    test('manager mengekspos identitas model dari config', () {
      expect(engine.modelManager.modelName, contains('Qwen2.5-0.5B'));
      expect(engine.modelManager.sizeBytes, 491400032);
    });

    test('RuleParser tetap bekerja penuh tanpa AI', () {
      final result = RuleParser(
        now: DateTime(2026, 10, 6),
      ).parse('besok jam 8 bayar listrik');

      expect(result.intent, AppIntent.createReminder);
      expect(result.needsConfirmation, false);
    });
  });
}

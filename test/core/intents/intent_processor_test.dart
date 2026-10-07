import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/ai/ai_config.dart';
import 'package:personal_offline/core/ai/local_ai_engine.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/intents/intent_processor.dart';
import 'package:personal_offline/core/intents/last_item_context.dart';
import 'package:personal_offline/core/settings/preferences_repository.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/shared/intents/ai_intent_result.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

import '../../helpers/fake_local_ai.dart';

void main() {
  late FakeLocalAiEngine engine;
  late db.AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    engine = FakeLocalAiEngine();
    database = db.AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        localAiRuntimeProvider.overrideWithValue(
          buildFakeRuntime(engine: engine),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 5, 9))),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
  });

  IntentProcessor processor() => container.read(intentProcessorProvider);

  Future<void> setPreference(String key, String value) =>
      container.read(preferencesRepositoryProvider).set(key, value);

  AiIntentResult aiResult({
    AppIntent intent = AppIntent.createTodo,
    double confidence = 0.9,
    bool needsConfirmation = false,
    Map<String, dynamic> entities = const {'title': 'Kirim laporan'},
  }) => AiIntentResult(
    intent: intent,
    confidence: confidence,
    entities: entities,
    needsConfirmation: needsConfirmation,
  );

  group('routing Rule Parser vs AI', () {
    test('Rule Parser dikenal → execute tanpa memanggil AI', () async {
      engine.ready = true;
      engine.understandResult = aiResult();

      final processed = await processor().process('besok jam 8 bayar listrik');

      expect(processed.disposition, IntentDisposition.execute);
      expect(processed.source, 'rule');
      expect(processed.result.intent, AppIntent.createReminder);
      expect(engine.understandCalls, 0);
    });

    test('Rule Parser tidak dikenal + AI yakin → confirm', () async {
      engine.ready = true;
      engine.understandResult = aiResult(confidence: 0.9);

      final processed = await processor().process(
        'laporan kapal harus selesai minggu depan',
      );

      expect(processed.disposition, IntentDisposition.confirm);
      expect(processed.source, 'ai');
      expect(processed.highConfidence, isTrue);
      expect(processed.message, startsWith('Aku menangkap:'));
      expect(engine.understandCalls, 1);
    });

    test('contoh PHASE 11: kalimat informal diteruskan ke Local AI', () async {
      engine.ready = true;
      engine.understandResult = AiIntentResult(
        intent: AppIntent.createTodo,
        confidence: 0.8,
        entities: const {'title': 'Ngurus pajak motor'},
      );

      final processed = await processor().process(
        'kayaknya minggu depan gue harus ngurus pajak motor',
      );

      expect(processed.disposition, IntentDisposition.confirm);
      expect(processed.source, 'ai');
      expect(processed.highConfidence, isFalse, reason: '0.8 → band menengah');
      expect(processed.result.entities['title'], 'Ngurus pajak motor');
    });

    test('AI confidence menengah → confirm tanpa highConfidence', () async {
      engine.ready = true;
      engine.understandResult = aiResult(confidence: 0.6);

      final processed = await processor().process(
        'laporan kapal harus selesai minggu depan',
      );

      expect(processed.disposition, IntentDisposition.confirm);
      expect(processed.highConfidence, isFalse);
    });

    test('AI confidence di bawah ambang → uncertain, jangan menebak', () async {
      engine.ready = true;
      engine.understandResult = aiResult(confidence: 0.4);

      final processed = await processor().process(
        'laporan kapal harus selesai minggu depan',
      );

      expect(processed.disposition, IntentDisposition.uncertain);
      expect(processed.message, contains('belum yakin'));
    });

    test('AI menjawab unknown → uncertain', () async {
      engine.ready = true;
      engine.understandResult = aiResult(intent: AppIntent.unknown);

      final processed = await processor().process(
        'laporan kapal harus selesai minggu depan',
      );

      expect(processed.disposition, IntentDisposition.uncertain);
    });

    test(
      'AI kehilangan entity wajib → confirm dengan needsConfirmation',
      () async {
        engine.ready = true;
        engine.understandResult = aiResult(
          intent: AppIntent.createExpense,
          confidence: 0.9,
          entities: const {'description': 'Ayam'},
        );

        final processed = await processor().process(
          'laporan kapal harus selesai minggu depan',
        );

        expect(processed.disposition, IntentDisposition.confirm);
        expect(processed.result.needsConfirmation, isTrue);
      },
    );

    test('output AI berisi kemampuan terlarang → rejected', () async {
      engine.ready = true;
      engine.understandResult = const AiIntentResult(
        intent: AppIntent.unknown,
        confidence: 0.9,
        rawJson:
            '{"intent":"execute_shell","confidence":0.9,'
            '"entities":{},"needs_confirmation":false}',
      );

      final processed = await processor().process(
        'laporan kapal harus selesai minggu depan',
      );

      expect(processed.disposition, IntentDisposition.rejected);
      expect(processed.message, contains('terlarang'));
      expect(processed.result.intent, AppIntent.unknown);
    });
  });

  group('fallback saat AI tidak tersedia', () {
    test('rule tidak dikenal → unavailable dengan saran penulisan', () async {
      final processed = await processor().process('qwerty asdf');

      expect(processed.disposition, IntentDisposition.unavailable);
      expect(processed.result.intent, AppIntent.unknown);
      expect(processed.message, contains('belum bisa memahami'));
      expect(engine.understandCalls, 0);
    });

    test(
      'AI tersedia tapi inference gagal → fallback tanpa exception',
      () async {
        engine.ready = true;
        engine.understandError = const LocalAiInferenceException('rusak');

        final processed = await processor().process('qwerty asdf');

        expect(processed.disposition, IntentDisposition.unavailable);
      },
    );

    test('AI melempar error tak terduga → tetap tidak crash', () async {
      engine.ready = true;
      engine.understandError = StateError('aneh');

      final processed = await processor().process('qwerty asdf');

      expect(processed.disposition, IntentDisposition.unavailable);
    });

    test('preferensi menaikkan ambang → hasil rule ikut dieksekusi', () async {
      await setPreference('ai_confidence_uncertain', '0.99');

      final processed = await processor().process('besok jam 8 bayar listrik');

      expect(processed.disposition, IntentDisposition.execute);
      expect(processed.source, 'rule');
      expect(engine.understandCalls, 0);
    });
  });

  group('threshold dari preferensi pengguna', () {
    test('thresholds() membaca preferensi yang tersimpan', () async {
      await setPreference('ai_confidence_accept', '0.7');
      await setPreference('ai_confidence_uncertain', '0.3');

      final thresholds = await processor().thresholds();

      expect(thresholds.accept, 0.7);
      expect(thresholds.uncertain, 0.3);
    });

    test('preferensi tidak valid → memakai default bawaan', () async {
      await setPreference('ai_confidence_accept', 'bukan-angka');

      final thresholds = await processor().thresholds();

      expect(thresholds.accept, const AiConfig().acceptThreshold);
      expect(thresholds.uncertain, const AiConfig().uncertainThreshold);
    });

    test('preferensi tidak konsisten → kembali ke default', () async {
      await setPreference('ai_confidence_accept', '0.3');
      await setPreference('ai_confidence_uncertain', '0.9');

      final thresholds = await processor().thresholds();

      expect(thresholds.accept, const AiConfig().acceptThreshold);
      expect(thresholds.uncertain, const AiConfig().uncertainThreshold);
    });

    test('ambang accept dari preferensi mengubah band kartu', () async {
      await setPreference('ai_confidence_accept', '0.95');
      engine.ready = true;
      engine.understandResult = aiResult(confidence: 0.9);

      final processed = await processor().process(
        'laporan kapal harus selesai minggu depan',
      );

      expect(processed.disposition, IntentDisposition.confirm);
      expect(processed.highConfidence, isFalse);
    });
  });

  group('perintah lanjutan (PHASE 12)', () {
    Future<void> seedContext({
      String type = 'todo',
      int id = 7,
      String label = 'Kirim laporan',
    }) => container
        .read(lastItemContextProvider)
        .write(LastItemContext(type: type, id: id, label: label));

    test('ubah tanpa item terakhir → noTarget, AI tidak dipanggil', () async {
      engine.ready = true;

      final processed = await processor().process('ubah jadi jam 10');

      expect(processed.disposition, IntentDisposition.noTarget);
      expect(processed.message, contains('Belum ada item sebelumnya'));
      expect(engine.understandCalls, 0);
    });

    test('ubah dengan konteks → execute + entity target terisi', () async {
      await seedContext();

      final processed = await processor().process('ubah jadi jam 10');

      expect(processed.disposition, IntentDisposition.execute);
      expect(processed.source, 'rule');
      expect(processed.result.intent, AppIntent.updateItem);
      expect(processed.result.entities['time'], '10:00');
      expect(processed.result.entities['target_type'], 'todo');
      expect(processed.result.entities['target_id'], 7);
      expect(processed.result.entities['target_label'], 'Kirim laporan');
      expect(engine.understandCalls, 0);
    });

    test('hapus → confirm meski dari jalur Rule Parser', () async {
      await seedContext();

      final processed = await processor().process('hapus');

      expect(processed.disposition, IntentDisposition.confirm);
      expect(processed.source, 'rule');
      expect(processed.highConfidence, isTrue);
      expect(processed.message, 'Hapus Kirim laporan?');
      expect(processed.result.entities['target_label'], 'Kirim laporan');
    });

    test('selesaikan dengan konteks → execute completeItem', () async {
      await seedContext(type: 'reminder', id: 3, label: 'Bayar listrik');

      final processed = await processor().process('selesaikan');

      expect(processed.disposition, IntentDisposition.execute);
      expect(processed.result.intent, AppIntent.completeItem);
      expect(processed.result.entities['target_type'], 'reminder');
      expect(processed.result.entities['target_id'], 3);
    });

    test('tunda 2 jam dengan konteks → execute snooze_minutes', () async {
      await seedContext(type: 'reminder', label: 'Bayar listrik');

      final processed = await processor().process('tunda 2 jam');

      expect(processed.disposition, IntentDisposition.execute);
      expect(processed.result.entities['snooze'], isTrue);
      expect(processed.result.entities['snooze_minutes'], 120);
      expect(processed.result.entities['target_type'], 'reminder');
    });

    test('konteks tipe tidak didukung → noTarget + penjelasan', () async {
      await seedContext(type: 'expense', id: 2, label: 'Makan siang');

      final processed = await processor().process('selesaikan');

      expect(processed.disposition, IntentDisposition.noTarget);
      expect(processed.message, contains('todo dan reminder'));
      expect(processed.message, contains('Makan siang'));
    });

    test('konteks bertahan setelah dibaca ulang dari preferensi', () async {
      await seedContext(id: 11, label: 'Bayar listrik');

      final stored = await container.read(lastItemContextProvider).read();

      expect(stored, isNotNull);
      expect(stored!.id, 11);
      expect(stored.type, 'todo');
      expect(stored.label, 'Bayar listrik');
    });

    test('AI menjawab update_item + ada konteks → confirm bertarget', () async {
      await seedContext();
      engine.ready = true;
      engine.understandResult = aiResult(
        intent: AppIntent.updateItem,
        confidence: 0.9,
        entities: const {'time': '10:00'},
      );

      final processed = await processor().process('pindahkan waktunya dong');

      expect(processed.disposition, IntentDisposition.confirm);
      expect(processed.result.entities['target_label'], 'Kirim laporan');
      expect(processed.message, contains('Kirim laporan'));
      expect(engine.understandCalls, 1);
    });

    test('AI menjawab update_item tanpa konteks → noTarget', () async {
      engine.ready = true;
      engine.understandResult = aiResult(
        intent: AppIntent.deleteItem,
        confidence: 0.9,
      );

      final processed = await processor().process(
        'ingin menghapus data minggu lalu',
      );

      expect(processed.disposition, IntentDisposition.noTarget);
      expect(processed.message, contains('Belum ada item sebelumnya'));
      expect(engine.understandCalls, 1);
    });
  });
}

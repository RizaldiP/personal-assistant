import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/ai/intent_validator.dart';
import 'package:personal_offline/shared/intents/ai_intent_result.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

void main() {
  const validator = DefaultIntentValidator();

  AiIntentResult expense({double confidence = 0.9, String? rawJson}) =>
      AiIntentResult(
        intent: AppIntent.createExpense,
        confidence: confidence,
        entities: const {
          'amount': 50000,
          'currency': 'IDR',
          'date': '2026-10-06',
        },
        rawJson: rawJson,
      );

  group('DefaultIntentValidator — hasil valid', () {
    test('hasil layak dipakai tanpa perubahan', () {
      const input = AiIntentResult(
        intent: AppIntent.createReminder,
        confidence: 0.96,
        entities: {
          'title': 'Bayar listrik',
          'date': '2026-10-07',
          'time': '08:00',
        },
      );

      final validated = validator.validate(input);

      expect(validated.isValid, true);
      expect(identical(validated.result, input), true);
    });

    test('rawJson dipertahankan pada hasil valid', () {
      final validated = validator.validate(expense(rawJson: '{"a":1}'));

      expect(validated.isValid, true);
      expect(validated.result!.rawJson, '{"a":1}');
    });
  });

  group('DefaultIntentValidator — aturan confidence', () {
    test('confidence > 1 di-clamp dan minta konfirmasi', () {
      final validated = validator.validate(expense(confidence: 1.5));

      expect(validated.isValid, true);
      expect(validated.result!.confidence, 1.0);
      expect(validated.result!.needsConfirmation, true);
    });

    test('confidence < 0 di-clamp dan minta konfirmasi', () {
      final validated = validator.validate(expense(confidence: -0.3));

      expect(validated.result!.confidence, 0.0);
      expect(validated.result!.needsConfirmation, true);
    });

    test('confidence tak-finite di-clamp ke 0 dan minta konfirmasi', () {
      final validated = validator.validate(
        expense(confidence: double.infinity),
      );

      expect(validated.result!.confidence, 0.0);
      expect(validated.result!.needsConfirmation, true);
    });
  });

  group('DefaultIntentValidator — aturan intent', () {
    test('unknown selalu butuh konfirmasi', () {
      const input = AiIntentResult(intent: AppIntent.unknown, confidence: 0.4);

      final validated = validator.validate(input);

      expect(validated.isValid, true);
      expect(validated.result!.intent, AppIntent.unknown);
      expect(validated.result!.needsConfirmation, true);
    });
  });

  group('DefaultIntentValidator — aturan entity wajib', () {
    test('create_expense tanpa amount butuh konfirmasi', () {
      const input = AiIntentResult(
        intent: AppIntent.createExpense,
        confidence: 0.95,
        entities: {'description': 'Makan siang'},
      );

      final validated = validator.validate(input);

      expect(validated.result!.needsConfirmation, true);
    });

    test('create_expense dengan amount memenuhi syarat', () {
      final validated = validator.validate(expense());

      expect(validated.result!.needsConfirmation, false);
    });

    test('create_shopping items kosong butuh konfirmasi', () {
      const input = AiIntentResult(
        intent: AppIntent.createShopping,
        confidence: 0.9,
        entities: {'items': <String>[]},
      );

      expect(validator.validate(input).result!.needsConfirmation, true);
    });

    test('create_reminder tanpa title butuh konfirmasi', () {
      const input = AiIntentResult(
        intent: AppIntent.createReminder,
        confidence: 0.9,
        entities: {'date': '2026-10-07'},
      );

      expect(validator.validate(input).result!.needsConfirmation, true);
    });

    test('create_note tanpa content butuh konfirmasi', () {
      const input = AiIntentResult(
        intent: AppIntent.createNote,
        confidence: 0.9,
        entities: {},
      );

      expect(validator.validate(input).result!.needsConfirmation, true);
    });
  });

  group('DefaultIntentValidator — normalisasi tanggal/jam', () {
    test('tanggal relatif tidak dipercaya → konfirmasi', () {
      const input = AiIntentResult(
        intent: AppIntent.createReminder,
        confidence: 0.95,
        entities: {'title': 'Rapat', 'date': 'besok'},
      );

      expect(validator.validate(input).result!.needsConfirmation, true);
    });

    test('jam natural language → konfirmasi', () {
      const input = AiIntentResult(
        intent: AppIntent.createReminder,
        confidence: 0.95,
        entities: {
          'title': 'Rapat',
          'date': '2026-10-07',
          'time': 'jam 8 pagi',
        },
      );

      expect(validator.validate(input).result!.needsConfirmation, true);
    });

    test('tanggal ISO + jam HH:MM diterima', () {
      const input = AiIntentResult(
        intent: AppIntent.createReminder,
        confidence: 0.95,
        entities: {'title': 'Rapat', 'date': '2026-10-07', 'time': '08:00'},
      );

      expect(validator.validate(input).result!.needsConfirmation, false);
    });

    test('due_date ISO diterima', () {
      const input = AiIntentResult(
        intent: AppIntent.createTodo,
        confidence: 0.9,
        entities: {'title': 'Laporan', 'due_date': '2026-10-10'},
      );

      expect(validator.validate(input).result!.needsConfirmation, false);
    });
  });

  group('DefaultIntentValidator — larangan keras (docs/05 §5)', () {
    test('intent execute_shell ditolak sebagai error', () {
      const input = AiIntentResult(
        intent: AppIntent.unknown,
        confidence: 0.9,
        rawJson:
            '{"intent":"execute_shell","confidence":0.9,'
            '"entities":{},"needs_confirmation":false}',
      );

      final validated = validator.validate(input);

      expect(validated.isValid, false);
      expect(validated.errorCode, 'forbidden_capability');
      expect(validated.errorMessage, contains('execute_shell'));
      expect(validated.result, isNull);
    });

    test('field action: send_network_request ditolak', () {
      const input = AiIntentResult(
        intent: AppIntent.unknown,
        confidence: 0.5,
        rawJson: '{"action":"send_network_request"}',
      );

      expect(validator.validate(input).errorCode, 'forbidden_capability');
    });

    test('seluruh kemampuan terlarang masuk daftar', () {
      expect(
        DefaultIntentValidator.forbiddenCapabilities,
        containsAll(<String>[
          'execute_shell',
          'delete_database',
          'send_network_request',
          'file_write',
          'send_notification',
        ]),
      );
    });
  });

  group('DefaultIntentValidator.validateRaw', () {
    test('JSON gagal parse → tolak dengan parse_failed', () {
      final validated = validator.validateRaw('ini bukan json');

      expect(validated.isValid, false);
      expect(validated.errorCode, 'parse_failed');
      expect(validated.errorMessage, isNotEmpty);
    });

    test('JSON valid → diteruskan ke validate', () {
      final validated = validator.validateRaw(
        '{"intent":"create_shopping","confidence":0.9,'
        '"entities":{"items":["telur"]},"needs_confirmation":false}',
      );

      expect(validated.isValid, true);
      expect(validated.result!.intent, AppIntent.createShopping);
    });

    test('JSON berisi kemampuan terlarang → ditolak', () {
      final validated = validator.validateRaw(
        '{"intent":"file_write","confidence":0.9,'
        '"entities":{},"needs_confirmation":false}',
      );

      expect(validated.isValid, false);
      expect(validated.errorCode, 'forbidden_capability');
    });
  });
}

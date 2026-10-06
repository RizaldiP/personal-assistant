import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/intents/ai_intent_result.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

void main() {
  group('AiIntentResult.fromJson/toJson', () {
    test('round-trip mempertahankan seluruh field', () {
      const result = AiIntentResult(
        intent: AppIntent.createTodo,
        confidence: 0.9,
        entities: {'title': 'Kerjakan laporan', 'due_date': '2026-10-06'},
      );

      final json = result.toJson();
      final restored = AiIntentResult.fromJson(json);

      expect(json['intent'], 'create_todo');
      expect(json['confidence'], 0.9);
      expect(restored.intent, AppIntent.createTodo);
      expect(restored.confidence, 0.9);
      expect(restored.entities, result.entities);
      expect(restored.needsConfirmation, false);
    });

    test('entitas dan needsConfirmation dibawa masuk', () {
      final restored = AiIntentResult.fromJson({
        'intent': 'create_shopping',
        'confidence': 0.95,
        'entities': {
          'items': ['Telur', 'Susu'],
        },
        'needs_confirmation': true,
      });

      expect(restored.intent, AppIntent.createShopping);
      expect(restored.entities['items'], ['Telur', 'Susu']);
      expect(restored.needsConfirmation, true);
    });

    test('JSON tanpa field memakai nilai default', () {
      final restored = AiIntentResult.fromJson({
        'intent': 'tidak-dikenal',
        'confidence': 0,
      });

      expect(restored.intent, AppIntent.unknown);
      expect(restored.confidence, 0);
      expect(restored.entities, isEmpty);
      expect(restored.needsConfirmation, false);
    });
  });

  group('AiIntentResult.isKnown', () {
    test('true untuk intent dikenal', () {
      const result = AiIntentResult(
        intent: AppIntent.createReminder,
        confidence: 0.9,
      );
      expect(result.isKnown, true);
    });

    test('false untuk unknown', () {
      const result = AiIntentResult(intent: AppIntent.unknown, confidence: 0.1);
      expect(result.isKnown, false);
    });
  });
}

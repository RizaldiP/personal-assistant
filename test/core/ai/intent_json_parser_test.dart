import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/ai/intent_json_parser.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

void main() {
  group('IntentJsonParser.parse', () {
    test('JSON polos menghasilkan intent dan rawJson', () {
      final result = IntentJsonParser.parse(
        '{"intent":"create_reminder","confidence":0.96,'
        '"entities":{"title":"Bayar listrik"},'
        '"needs_confirmation":false}',
      );

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.createReminder);
      expect(result.confidence, 0.96);
      expect(result.entities['title'], 'Bayar listrik');
      expect(result.needsConfirmation, false);
      expect(result.rawJson, contains('"create_reminder"'));
    });

    test('code fence ```json dibuang', () {
      final result = IntentJsonParser.parse(
        '```json\n'
        '{"intent":"create_todo","confidence":0.8,'
        '"entities":{"title":"Kerja"},'
        '"needs_confirmation":true}\n'
        '```',
      );

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.createTodo);
    });

    test('teks sebelum/sesudah objek tetap terparse', () {
      final result = IntentJsonParser.parse(
        'Berikut hasilnya: {"intent":"search","confidence":0.7,'
        '"entities":{"query":"liburan"},"needs_confirmation":true} semoga '
        'membantu',
      );

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.search);
    });

    test('JSON rusak ditolak (null)', () {
      expect(IntentJsonParser.parse('bukan json sama sekali'), isNull);
      expect(IntentJsonParser.parse('{"intent": "create_todo",'), isNull);
      expect(IntentJsonParser.parse(''), isNull);
    });

    test('JSON non-objek ditolak (null)', () {
      expect(IntentJsonParser.parse('[1, 2, 3]'), isNull);
      expect(IntentJsonParser.parse('"create_todo"'), isNull);
    });

    test('intent tak dikenal menjadi unknown', () {
      final result = IntentJsonParser.parse(
        '{"intent":"hack_system","confidence":0.9,'
        '"entities":{},"needs_confirmation":false}',
      );

      expect(result!.intent, AppIntent.unknown);
    });

    test('needs_confirmation hilang dianggap true (aman)', () {
      final result = IntentJsonParser.parse(
        '{"intent":"create_note","confidence":0.9,"entities":{}}',
      );

      expect(result!.needsConfirmation, true);
    });

    test('tipe keliru tidak melempar exception', () {
      final result = IntentJsonParser.parse(
        '{"intent":123,"confidence":"tinggi","entities":"harusnya objek",'
        '"needs_confirmation":"ya"}',
      );

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.unknown);
      expect(result.confidence, 0.0);
      expect(result.entities, isEmpty);
      expect(result.needsConfirmation, true);
    });

    test('entities non-objek menjadi map kosong', () {
      final result = IntentJsonParser.parse(
        '{"intent":"create_shopping","confidence":0.9,'
        '"entities":["telur"],"needs_confirmation":true}',
      );

      expect(result!.entities, isEmpty);
    });
  });

  group('IntentJsonParser.fromMap', () {
    test('rawJson default berisi JSON ter-encode', () {
      final result = IntentJsonParser.fromMap({
        'intent': 'create_idea',
        'confidence': 0.75,
        'entities': {'content': 'aplikasi catatan'},
        'needs_confirmation': true,
      });

      expect(result.rawJson, contains('"create_idea"'));
    });
  });
}

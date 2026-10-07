import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:personal_offline/core/ai/ai_config.dart';

void main() {
  group('AiConfig', () {
    test('default memakai model terpilih PHASE 10', () {
      const config = AiConfig();

      expect(config.modelSource, startsWith('hf://Qwen/Qwen2.5-0.5B'));
      expect(config.modelName, contains('Qwen2.5-0.5B'));
      expect(config.modelSizeBytes, greaterThan(400 * 1024 * 1024));
      expect(config.modelSizeBytes, lessThan(600 * 1024 * 1024));
      expect(AiConfig.modelLicense, 'Apache-2.0');
    });

    test('threshold mengikuti docs/05 bagian 6', () {
      const config = AiConfig();

      expect(config.acceptThreshold, 0.85);
      expect(config.uncertainThreshold, 0.50);
    });

    test('userMessage menyertakan tanggal hari ini', () {
      const config = AiConfig();

      final message = config.userMessage(
        now: DateTime(2026, 10, 6),
        text: 'bayar listrik besok',
      );

      expect(message, contains('2026-10-06'));
      expect(message, contains('bayar listrik besok'));
    });

    test('parameter inference deterministik dan hemat RAM', () {
      const config = AiConfig();

      expect(config.contextSize, 4096);
      expect(config.temperature, 0.0);
      expect(config.seed, 42);
      expect(config.maxOutputTokens, greaterThanOrEqualTo(128));
      expect(config.gpuLayers, 0);
    });
  });

  group('AiConfig.intentSchema', () {
    test('diterima converter grammar llamadart (json_schema ketat)', () {
      final output = LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(
        schema: AiConfig.intentSchema,
        decoder: (json) => json,
      );

      expect(output.schema, isNotNull);
      expect(output.responseFormat['type'], 'json_schema');
    });

    test('memuat seluruh intent aplikasi dan kunci wajib', () {
      final properties =
          AiConfig.intentSchema['properties'] as Map<String, dynamic>;
      final intent = properties['intent'] as Map<String, dynamic>;

      expect(
        intent['enum'],
        containsAll(<String>[
          'create_reminder',
          'create_todo',
          'create_shopping',
          'create_expense',
          'create_note',
          'create_journal',
          'create_idea',
          'update_item',
          'delete_item',
          'complete_item',
          'search',
          'unknown',
        ]),
      );
      expect(AiConfig.intentSchema['required'], [
        'intent',
        'confidence',
        'entities',
        'needs_confirmation',
      ]);
      expect(AiConfig.intentSchema['additionalProperties'], false);
    });

    test('entity schema melarang kunci asing', () {
      final properties =
          AiConfig.intentSchema['properties'] as Map<String, dynamic>;
      final entities = properties['entities'] as Map<String, dynamic>;

      expect(entities['additionalProperties'], false);
      expect((entities['properties'] as Map<String, dynamic>).keys, [
        'title',
        'content',
        'description',
        'category',
        'currency',
        'mood',
        'priority',
        'date',
        'time',
        'due_date',
        'query',
        'amount',
        'items',
      ]);
    });
  });
}

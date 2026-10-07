import 'package:llamadart/llamadart.dart';

import '../../shared/intents/ai_intent_result.dart';
import '../utils/clock.dart';
import 'ai_config.dart';
import 'ai_model_manager.dart';
import 'intent_json_parser.dart';
import 'local_ai_engine.dart';

/// [LocalAiEngine] berbasis llamadart + llama.cpp (inference lokal penuh).
///
/// Memakai structured output grammar-constrained sehingga output model
/// terjamin JSON valid; jalur fallback tersedia bila backend tidak
/// mendukung grammar. Model dimuat dari cache (offline) — unduhan hanya
/// lewat [AiModelManager.downloadModel] setelah consent user.
class LlamadartLocalAiEngine implements LocalAiEngine {
  factory LlamadartLocalAiEngine({
    AiConfig config = const AiConfig(),
    LlamaEngine? engine,
    Clock clock = const SystemClock(),
  }) {
    final llama = engine ?? LlamaEngine(LlamaBackend());
    return LlamadartLocalAiEngine._(
      config,
      clock,
      llama,
      LlamadartModelManager(llama, config),
    );
  }

  LlamadartLocalAiEngine._(
    this._config,
    this._clock,
    this._llama,
    this.modelManager,
  );

  final AiConfig _config;
  final Clock _clock;
  final LlamaEngine _llama;

  /// Manager model (unduh dengan consent / muat dari cache).
  final AiModelManager modelManager;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_llama.isReady) {
      _initialized = true;
      return;
    }
    _initialized = await modelManager.loadModel();
  }

  @override
  Future<bool> isAvailable() async => _initialized && _llama.isReady;

  @override
  Future<AiIntentResult> understand(String text) async {
    if (!_initialized || !_llama.isReady) {
      throw const LocalAiUnavailableException();
    }

    final messages = <LlamaChatMessage>[
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: _config.systemPrompt,
      ),
      for (final example in AiConfig.fewShotExamples) ...[
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: example.user),
        LlamaChatMessage.fromText(
          role: LlamaChatRole.assistant,
          text: example.assistant,
        ),
      ],
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: _config.userMessage(now: _clock.now(), text: text),
      ),
    ];
    final params = GenerationParams(
      maxTokens: _config.maxOutputTokens,
      temp: _config.temperature,
      topP: _config.topP,
      seed: _config.seed,
    );

    try {
      final output = LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(
        schema: AiConfig.intentSchema,
        decoder: (json) => json,
      );
      final json = await _llama.createStructuredJson(
        messages,
        output: output,
        params: params,
        enableThinking: false,
      );
      return IntentJsonParser.fromMap(json);
    } on LlamaUnsupportedException {
      return _understandWithoutGrammar(messages, params);
    } on LlamaException catch (error) {
      // Keluaran grammar terpotong/bukan JSON → satu percobaan ulang lewat
      // jalur teks biasa sebelum menyerah (tetap exception ter-tipe).
      try {
        return await _understandWithoutGrammar(messages, params);
      } catch (_) {
        throw LocalAiInferenceException('Inference lokal gagal: $error');
      }
    } catch (error) {
      throw LocalAiInferenceException('Inference lokal gagal: $error');
    }
  }

  Future<AiIntentResult> _understandWithoutGrammar(
    List<LlamaChatMessage> messages,
    GenerationParams params,
  ) async {
    final buffer = StringBuffer();
    await for (final chunk in _llama.create(
      messages,
      params: params,
      enableThinking: false,
    )) {
      for (final choice in chunk.choices) {
        final content = choice.delta.content;
        if (content != null) {
          buffer.write(content);
        }
      }
    }
    final parsed = IntentJsonParser.parse(buffer.toString());
    if (parsed == null) {
      throw const LocalAiInferenceException(
        'Output model bukan JSON intent yang valid.',
      );
    }
    return parsed;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    await _llama.dispose();
  }
}

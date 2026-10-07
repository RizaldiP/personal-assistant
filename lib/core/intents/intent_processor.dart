import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/intents/ai_intent_result.dart';
import '../../shared/intents/app_intent.dart';
import '../../shared/nlp/followup_parser.dart';
import '../../shared/nlp/rule_parser.dart';
import '../ai/ai_config.dart';
import '../ai/intent_validator.dart';
import '../ai/local_ai_engine.dart';
import '../ai/local_ai_runtime.dart';
import '../database/database_provider.dart';
import '../settings/preferences_repository.dart';
import 'intent_description.dart';
import 'last_item_context.dart';

/// Apa yang harus dilakukan aplikasi terhadap satu kalimat user.
enum IntentDisposition {
  /// Intent Rule Parser dikenal → langsung dieksekusi ke repository.
  execute,

  /// Intent dari AI cukup meyakinkan → tampilkan kartu konfirmasi dulu.
  confirm,

  /// AI tidak yakin (confidence rendah / unknown) → jangan menebak.
  uncertain,

  /// Output AI ditolak validator (JSON gagal / kemampuan terlarang).
  rejected,

  /// AI tidak tersedia dan Rule Parser tidak mengenali kalimat.
  unavailable,

  /// Perintah lanjutan (ubah/hapus/selesaikan/tunda) tanpa item terakhir
  /// yang bisa dirujuk, atau itemnya tipe yang belum didukung.
  noTarget,
}

/// Hasil pemrosesan satu kalimat: intent + keputusan routing.
class ProcessedIntent {
  const ProcessedIntent({
    required this.result,
    required this.source,
    required this.disposition,
    this.message,
    this.highConfidence = false,
  });

  /// Intent yang dihasilkan (dari Rule Parser atau AI).
  final AiIntentResult result;

  /// Asal intent: `'rule'` (Rule Parser/fallback) atau `'ai'` (Local AI).
  final String source;

  /// Keputusan routing sesuai docs/05 bagian 6-7.
  final IntentDisposition disposition;

  /// Pesan untuk user (interpretasi, galat, atau saran) — Bahasa Indonesia.
  final String? message;

  /// true bila confidence ≥ ambang `accept` (kartu `Simpan` satu langkah).
  final bool highConfidence;
}

/// Ambang confidence dari preferensi pengguna (docs/05 bagian 6).
class IntentThresholds {
  const IntentThresholds({required this.accept, required this.uncertain});

  /// Confidence ≥ ini → kartu konfirmasi ringkas (`Simpan`).
  final double accept;

  /// Confidence < ini → jangan menebak (tawarkan penulisan ulang).
  final double uncertain;

  factory IntentThresholds.defaults() {
    const config = AiConfig();
    return IntentThresholds(
      accept: config.acceptThreshold,
      uncertain: config.uncertainThreshold,
    );
  }
}

/// Orkesterasi pemahaman satu kalimat (docs/05 bagian 7):
///
/// `RuleParser → (confidence rendah?) → LocalAiEngine → IntentValidator`
///
/// Satu-satunya pemilik panggilan `LocalAiEngine.understand()`; UI tidak
/// memanggil AI langsung. Selalu menghasilkan keputusan, tidak pernah
/// melempar exception — AI gagal pun tetap jatuh ke jalur Rule Parser.
class IntentProcessor {
  IntentProcessor(this._ref);

  final Ref _ref;

  /// Kunci preferensi threshold di `user_preferences`.
  Future<IntentThresholds> thresholds() async {
    const config = AiConfig();
    try {
      final preferences = _ref.read(preferencesRepositoryProvider);
      final accept =
          double.tryParse(
            await preferences.get(AiConfig.prefKeyConfidenceAccept) ?? '',
          ) ??
          config.acceptThreshold;
      final uncertain =
          double.tryParse(
            await preferences.get(AiConfig.prefKeyConfidenceUncertain) ?? '',
          ) ??
          config.uncertainThreshold;
      if (uncertain > accept) {
        // Preferensi tidak konsisten → kembali ke default bawaan.
        return IntentThresholds.defaults();
      }
      return IntentThresholds(accept: accept, uncertain: uncertain);
    } on Object {
      return IntentThresholds.defaults();
    }
  }

  /// Memproses [text] menjadi intent + keputusan routing.
  Future<ProcessedIntent> process(String text) async {
    // 0. Perintah lanjutan (PHASE 12): diawali kata kerja ubah/hapus/
    //    selesaikan/tunda → rujuk item terakhir, tanpa memanggil AI.
    final followUp = FollowUpParser(
      now: _ref.read(clockProvider).now(),
    ).parse(text);
    if (followUp != null) return _followUp(followUp);

    final thresholds = await this.thresholds();
    final rule = RuleParser(now: _ref.read(clockProvider).now()).parse(text);

    // 1. Rule Parser dikenal dan cukup yakin → jalur aturan penuh.
    if (rule.isKnown && rule.confidence >= thresholds.uncertain) {
      return ProcessedIntent(
        result: rule,
        source: 'rule',
        disposition: IntentDisposition.execute,
      );
    }

    // 2. Rule Parser tidak dikenal/yakin → coba Local AI.
    final aiResult = await _understand(text);
    if (aiResult == null) {
      return _fallback(rule);
    }

    // 3. Validasi output AI (docs/05 bagian 4-5).
    const validator = DefaultIntentValidator();
    final validated = validator.validate(aiResult);
    if (!validated.isValid) {
      return ProcessedIntent(
        result: rule,
        source: 'ai',
        disposition: IntentDisposition.rejected,
        message: validated.errorMessage,
      );
    }

    final result = validated.result!;
    if (!result.isKnown || result.confidence < thresholds.uncertain) {
      // 4. Confidence rendah / unknown → jangan pernah menebak.
      return ProcessedIntent(
        result: result,
        source: 'ai',
        disposition: IntentDisposition.uncertain,
        message:
            'Aku belum yakin maksudnya. Coba tulis ulang lebih jelas, '
            'misalnya "besok jam 8 bayar listrik" atau "tadi makan ayam 25 ribu".',
      );
    }

    // 5. Cukup yakin → minta konfirmasi (tidak pernah auto-save).
    final enriched = await _contextualize(result);
    if (enriched == null) {
      // Intent kontekstual tanpa item terakhir → jangan menebak target.
      final context = await _ref.read(lastItemContextProvider).read();
      return ProcessedIntent(
        result: result,
        source: 'ai',
        disposition: IntentDisposition.noTarget,
        message: _targetFailure(context),
      );
    }
    return ProcessedIntent(
      result: enriched,
      source: 'ai',
      disposition: IntentDisposition.confirm,
      message: 'Aku menangkap: ${describeIntent(enriched)}.',
      highConfidence: enriched.confidence >= thresholds.accept,
    );
  }

  /// Intent yang dirujukkan ke item terakhir percakapan (PHASE 12).
  static const Set<AppIntent> _contextualIntents = {
    AppIntent.updateItem,
    AppIntent.deleteItem,
    AppIntent.completeItem,
  };

  /// Menangani perintah lanjutan dari FollowUpParser: rujuk item terakhir,
  /// atau jelaskan bila konteksnya tidak ada/tidak didukung.
  Future<ProcessedIntent> _followUp(AiIntentResult result) async {
    final context = await _ref.read(lastItemContextProvider).read();
    final failure = _targetFailure(context);
    if (failure != null) {
      return ProcessedIntent(
        result: result,
        source: 'rule',
        disposition: IntentDisposition.noTarget,
        message: failure,
      );
    }

    final enriched = _withTarget(result, context!);
    if (result.intent == AppIntent.deleteItem) {
      // Destruktif → tetap minta konfirmasi walau dari jalur Rule Parser.
      return ProcessedIntent(
        result: enriched,
        source: 'rule',
        disposition: IntentDisposition.confirm,
        message: 'Hapus ${context.label}?',
        highConfidence: true,
      );
    }
    return ProcessedIntent(
      result: enriched,
      source: 'rule',
      disposition: IntentDisposition.execute,
    );
  }

  /// Menambahkan `target_*` ke intent kontekstual; null bila tidak ada
  /// konteks yang layak (dipakai jalur AI — jalur rule sudah dicek di
  /// [_followUp]).
  Future<AiIntentResult?> _contextualize(AiIntentResult result) async {
    if (!_contextualIntents.contains(result.intent)) return result;
    final context = await _ref.read(lastItemContextProvider).read();
    if (context == null || !context.supportsFollowUp) return null;
    return _withTarget(result, context);
  }

  AiIntentResult _withTarget(AiIntentResult result, LastItemContext context) =>
      AiIntentResult(
        intent: result.intent,
        confidence: result.confidence,
        entities: {
          ...result.entities,
          'target_type': context.type,
          if (context.id != null) 'target_id': context.id,
          'target_label': context.label,
        },
        needsConfirmation: result.needsConfirmation,
      );

  /// Pesan galat bila [context] tidak bisa dipakai sebagai target;
  /// null bila konteksnya layak dipakai.
  String? _targetFailure(LastItemContext? context) {
    if (context == null) {
      return 'Belum ada item sebelumnya yang bisa dirujuk. Buat dulu, '
          'misalnya "besok jam 8 bayar listrik".';
    }
    if (!context.supportsFollowUp) {
      return 'Perintah ini (ubah/hapus/selesaikan/tunda) baru mendukung todo '
          'dan reminder. Item terakhirmu: ${context.label}.';
    }
    return null;
  }

  /// Panggilan ke AI; null bila model tidak tersedia atau inference gagal.
  Future<AiIntentResult?> _understand(String text) async {
    try {
      final engine = _ref.read(localAiRuntimeProvider).engine;
      if (!await engine.isAvailable()) return null;
      return await engine.understand(text);
    } on LocalAiException {
      return null;
    } on Object {
      // AI tidak boleh menjatuhkan aplikasi (DoD PHASE 10/11).
      return null;
    }
  }

  /// Fallback saat AI tidak bisa dipakai (docs/05 bagian 7).
  ProcessedIntent _fallback(AiIntentResult rule) {
    if (rule.isKnown) {
      return ProcessedIntent(
        result: rule,
        source: 'rule',
        disposition: IntentDisposition.execute,
      );
    }
    return ProcessedIntent(
      result: rule,
      source: 'rule',
      disposition: IntentDisposition.unavailable,
      message:
          'Aku belum bisa memahami itu. Model AI belum dimuat, jadi tulis '
          'dengan format jelas, misalnya "besok jam 8 bayar listrik" atau '
          '"catat: nomor penting 1234".',
    );
  }
}

final intentProcessorProvider = Provider<IntentProcessor>((ref) {
  return IntentProcessor(ref);
});

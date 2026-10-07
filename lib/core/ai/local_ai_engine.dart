import '../../shared/intents/ai_intent_result.dart';

/// Kontrak engine AI lokal (docs/05 bagian 2).
///
/// Hanya boleh dipanggil oleh IntentProcessor; UI tidak memanggil AI
/// secara langsung. Implementasi wajib tetap aman saat model tidak ada:
/// [understand] melempar [LocalAiUnavailableException], tidak pernah crash
/// atau hang.
abstract class LocalAiEngine {
  /// Menyiapkan engine. Gagal memuat model TIDAK melempar exception —
  /// periksa [isAvailable] setelahnya.
  Future<void> initialize();

  /// Mengubah satu kalimat menjadi intent terstruktur.
  ///
  /// Melempar [LocalAiUnavailableException] bila model belum dimuat dan
  /// [LocalAiInferenceException] bila inference/JSON gagal.
  Future<AiIntentResult> understand(String text);

  /// true bila model sudah dimuat dan siap dipakai.
  Future<bool> isAvailable();

  /// Melepaskan resource model dan backend.
  Future<void> dispose();
}

sealed class LocalAiException implements Exception {
  const LocalAiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class LocalAiUnavailableException extends LocalAiException {
  const LocalAiUnavailableException([
    super.message = 'Model AI lokal belum dimuat.',
  ]);
}

class LocalAiInferenceException extends LocalAiException {
  const LocalAiInferenceException(super.message);
}

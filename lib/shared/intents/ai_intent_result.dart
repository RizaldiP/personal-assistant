import 'app_intent.dart';

/// Hasil pemahaman satu kalimat menjadi intent terstruktur.
///
/// Dipakai bersama oleh Rule Parser dan (nanti) Local AI, agar lapisan
/// validasi/konfirmasi dapat memproses keluaran keduanya dengan cara sama.
class AiIntentResult {
  const AiIntentResult({
    required this.intent,
    required this.confidence,
    this.entities = const {},
    this.needsConfirmation = false,
    this.rawJson,
  });

  final AppIntent intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final bool needsConfirmation;

  /// JSON mentah hasil model, hanya untuk log/debug lokal; tidak pernah
  /// dikirim ke mana pun dan tidak ikut diserialisasi oleh [toJson].
  final String? rawJson;

  bool get isKnown => intent != AppIntent.unknown;

  Map<String, dynamic> toJson() => {
    'intent': intent.storageValue,
    'confidence': confidence,
    'entities': entities,
    'needs_confirmation': needsConfirmation,
  };

  factory AiIntentResult.fromJson(Map<String, dynamic> json) => AiIntentResult(
    intent: AppIntent.fromStorage(json['intent'] as String?),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    entities: (json['entities'] as Map<String, dynamic>?) ?? const {},
    needsConfirmation: json['needs_confirmation'] as bool? ?? false,
  );
}

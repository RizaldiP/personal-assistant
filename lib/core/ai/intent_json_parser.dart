import 'dart:convert';

import '../../shared/intents/ai_intent_result.dart';
import '../../shared/intents/app_intent.dart';

/// Parser JSON mentah hasil model → [AiIntentResult].
///
/// Menangani keluaran yang dibungkus code fence atau teks tambahan di
/// depan/belakang. Mengembalikan null bila JSON tidak valid — input seperti
/// ini wajib ditolak (docs/05 bagian 4, aturan 1), bukan ditebak.
class IntentJsonParser {
  const IntentJsonParser._();

  /// Parse JSON mentah model; null bila gagal (ditolak).
  static AiIntentResult? parse(String raw) {
    final object = decodeObject(raw);
    if (object == null) {
      return null;
    }
    return fromMap(object, rawJson: raw);
  }

  /// Objek JSON pertama dari teks model; null bila tidak ada/bukan objek.
  static Map<String, dynamic>? decodeObject(String raw) {
    final text = _stripFences(raw).trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Bangun hasil dari objek JSON yang sudah ter-decode.
  ///
  /// Defensif terhadap tipe keliru dari jalur fallback tanpa grammar.
  /// `needs_confirmation` yang hilang dianggap true (aman: jangan auto-save).
  static AiIntentResult fromMap(Map<String, dynamic> json, {String? rawJson}) {
    final rawIntent = json['intent'];
    final intent = AppIntent.fromStorage(
      rawIntent is String ? rawIntent : null,
    );
    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num && rawConfidence.isFinite
        ? rawConfidence.toDouble()
        : 0.0;
    final rawEntities = json['entities'];
    final entities = rawEntities is Map
        ? Map<String, dynamic>.from(rawEntities)
        : const <String, dynamic>{};
    final rawNeedsConfirmation = json['needs_confirmation'];
    final needsConfirmation = rawNeedsConfirmation is bool
        ? rawNeedsConfirmation
        : true;

    return AiIntentResult(
      intent: intent,
      confidence: confidence,
      entities: entities,
      needsConfirmation: needsConfirmation,
      rawJson: rawJson ?? jsonEncode(json),
    );
  }

  static String _stripFences(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }
    final firstBreak = trimmed.indexOf('\n');
    if (firstBreak < 0) {
      return trimmed;
    }
    final withoutOpening = trimmed.substring(firstBreak + 1);
    final closing = withoutOpening.lastIndexOf('```');
    if (closing < 0) {
      return withoutOpening;
    }
    return withoutOpening.substring(0, closing);
  }
}

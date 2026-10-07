import '../../shared/intents/ai_intent_result.dart';
import '../../shared/intents/app_intent.dart';
import 'intent_json_parser.dart';

/// Hasil validasi: hasil valid, atau error yang bisa ditampilkan ke user.
class ValidatedIntent {
  const ValidatedIntent.valid(this.result)
    : isValid = true,
      errorCode = null,
      errorMessage = null;

  const ValidatedIntent.invalid({
    required this.errorCode,
    required this.errorMessage,
  }) : isValid = false,
       result = null;

  final bool isValid;
  final AiIntentResult? result;

  /// Kode mesin untuk logging/pengujian, mis. `parse_failed`.
  final String? errorCode;

  /// Pesan yang aman ditampilkan ke user (Bahasa Indonesia).
  final String? errorMessage;

  @override
  String toString() =>
      isValid ? 'ValidatedIntent.valid($result)' : 'invalid($errorCode)';
}

/// Aturan validasi output AI (docs/05 bagian 4 dan 5).
abstract interface class IntentValidator {
  ValidatedIntent validate(AiIntentResult input);
}

class DefaultIntentValidator implements IntentValidator {
  const DefaultIntentValidator();

  /// Kapabilitas yang dilarang (docs/05 bagian 5) — bukan fitur, batas
  /// keamanan; permintaan model untuk salah satunya wajib ditolak.
  static const Set<String> forbiddenCapabilities = {
    'execute_shell',
    'delete_database',
    'send_network_request',
    'file_write',
    'send_notification',
  };

  /// Entity wajib per intent; kurang → needsConfirmation, jangan auto-save.
  static const Map<String, Set<String>> requiredEntities = {
    'create_reminder': {'title'},
    'create_todo': {'title'},
    'create_shopping': {'items'},
    'create_expense': {'amount'},
    'create_note': {'content'},
    'create_journal': {'content'},
    'create_idea': {'content'},
    'search': {'query'},
  };

  static final RegExp _isoDate = RegExp(
    r'^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?)?$',
  );
  static const Set<String> _dateKeys = {'date', 'due_date'};

  /// Aturan 1: parse JSON gagal → tolak.
  ValidatedIntent validateRaw(String rawJson) {
    final parsed = IntentJsonParser.parse(rawJson);
    if (parsed == null) {
      return const ValidatedIntent.invalid(
        errorCode: 'parse_failed',
        errorMessage:
            'Hasil AI tidak berupa JSON valid. '
            'Coba ulangi atau gunakan input manual.',
      );
    }
    return validate(parsed);
  }

  @override
  ValidatedIntent validate(AiIntentResult input) {
    final forbidden = _forbiddenCapability(input);
    if (forbidden != null) {
      return ValidatedIntent.invalid(
        errorCode: 'forbidden_capability',
        errorMessage:
            'Permintaan AI memuat kemampuan terlarang '
            '("$forbidden") dan ditolak.',
      );
    }

    var confidence = input.confidence;
    var needsConfirmation = input.needsConfirmation;

    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      confidence = confidence.isFinite ? confidence.clamp(0.0, 1.0) : 0.0;
      needsConfirmation = true;
    }

    if (input.intent == AppIntent.unknown) {
      needsConfirmation = true;
    }

    final required = requiredEntities[input.intent.storageValue];
    if (required != null) {
      for (final key in required) {
        if (!_hasValue(input.entities[key])) {
          needsConfirmation = true;
          break;
        }
      }
    }

    if (!_datesNormalized(input.entities)) {
      needsConfirmation = true;
    }

    if (confidence == input.confidence &&
        needsConfirmation == input.needsConfirmation) {
      return ValidatedIntent.valid(input);
    }

    return ValidatedIntent.valid(
      AiIntentResult(
        intent: input.intent,
        confidence: confidence,
        entities: input.entities,
        needsConfirmation: needsConfirmation,
        rawJson: input.rawJson,
      ),
    );
  }

  String? _forbiddenCapability(AiIntentResult input) {
    final rawJson = input.rawJson;
    if (rawJson == null) {
      return null;
    }
    try {
      final object = IntentJsonParser.decodeObject(rawJson);
      if (object == null) {
        return null;
      }
      for (final key in const ['intent', 'action', 'capability']) {
        final value = object[key];
        if (value is String && forbiddenCapabilities.contains(value)) {
          return value;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  bool _hasValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return true;
  }

  bool _datesNormalized(Map<String, dynamic> entities) {
    for (final key in _dateKeys) {
      final value = entities[key];
      if (value is String && value.trim().isNotEmpty) {
        if (!_isoDate.hasMatch(value.trim())) {
          return false;
        }
      }
    }
    final time = entities['time'];
    if (time is String && time.trim().isNotEmpty) {
      final normalized = time.trim();
      final isTime =
          RegExp(r'^\d{2}:\d{2}$').hasMatch(normalized) ||
          _isoDate.hasMatch(normalized);
      if (!isTime) {
        return false;
      }
    }
    return true;
  }
}

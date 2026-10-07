import '../intents/ai_intent_result.dart';
import '../intents/app_intent.dart';
import 'date_parser.dart';
import 'normalizer.dart';
import 'time_parser.dart';

/// Perintah lanjutan tanpa target eksplisit (PHASE 12 — Contextual Chat).
///
/// Mengenali kalimat yang merujuk ke item terakhir di percakapan:
/// - `ubah jadi jam 10`, `jadikan besok`, `ganti jadi ...` → [AppIntent.updateItem]
/// - `tunda 2 jam`, `tunda besok`, `tunda jam 10` → [AppIntent.updateItem]
///   dengan entity `snooze` (khusus reminder)
/// - `selesaikan`, `done` → [AppIntent.completeItem]
/// - `hapus`, `buang` → [AppIntent.deleteItem]
///
/// Diproses **sebelum** [RuleParser] di `IntentProcessor` dan hanya aktif
/// bila kalimat diawali kata kerja perintah (opsional diawali `tolong`);
/// kalimat lain dikembalikan sebagai `null` sehingga alur Rule Parser /
/// Local AI tidak terganggu. Target item diketahui oleh `IntentProcessor`
/// lewat `LastItemContext`, bukan oleh parser ini.
class FollowUpParser {
  FollowUpParser({required DateTime now})
    : _dateParser = DateParser(now: DateTime(now.year, now.month, now.day));

  final DateParser _dateParser;
  final TimeParser _timeParser = TimeParser();

  static const String _lead = r'^(?:tolong\s+)?';

  static final RegExp _completeVerb = RegExp(
    '$_lead(?:selesaikan|selesaiin|centang|tandai\\s+(?:selesai|done)|done)\\b\\s*',
  );
  static final RegExp _deleteVerb = RegExp('$_lead(?:hapus|buang)\\b\\s*');
  static final RegExp _snoozeVerb = RegExp('${_lead}tunda\\b\\s*');
  static final RegExp _updateVerb = RegExp(
    '$_lead(?:ubah|ganti|jadikan|pindah)\\b\\s*',
  );

  static final RegExp _duration = RegExp(r'^(\d{1,3})\s*(menit|jam|hari)\b');
  static final RegExp _connector = RegExp(r'\b(?:jadi|menjadi)\b');
  static final RegExp _spaces = RegExp(r'\s+');

  /// Mengembalikan intent lanjutan, atau `null` bila [raw] bukan perintah
  /// lanjutan (mis. "besok jam 8 bayar listrik" atau "beli telur").
  AiIntentResult? parse(String raw) {
    final text = Normalizer.normalize(raw);
    final body = text.startsWith('tolong ')
        ? text.substring('tolong '.length)
        : text;
    if (body.isEmpty) return null;

    if (_completeVerb.hasMatch(body)) {
      return _result(AppIntent.completeItem);
    }
    if (_deleteVerb.hasMatch(body)) {
      return _result(AppIntent.deleteItem);
    }
    if (_snoozeVerb.hasMatch(body)) {
      return _snooze(_rest(_snoozeVerb, body));
    }
    if (_updateVerb.hasMatch(body)) {
      return _update(_rest(_updateVerb, body));
    }
    return null;
  }

  String _rest(RegExp verb, String body) =>
      body.replaceFirst(verb, '').replaceAll(_spaces, ' ').trim();

  AiIntentResult _result(AppIntent intent) =>
      AiIntentResult(intent: intent, confidence: 0.95);

  /// `tunda 2 jam` → menit; `tunda besok` / `tunda jam 10` → tanggal/jam;
  /// `tunda` saja → tanpa entity (executor menawarkan contoh durasi).
  AiIntentResult _snooze(String rest) {
    final duration = _duration.firstMatch(rest);
    if (duration != null) {
      final value = int.parse(duration.group(1)!);
      final unit = duration.group(2)!;
      final minutes = switch (unit) {
        'jam' => value * 60,
        'hari' => value * 1440,
        _ => value,
      };
      return AiIntentResult(
        intent: AppIntent.updateItem,
        confidence: 0.95,
        entities: {'snooze': true, 'snooze_minutes': minutes},
      );
    }

    final date = _dateParser.parse(rest);
    final time = _timeParser.parse(rest);
    return AiIntentResult(
      intent: AppIntent.updateItem,
      confidence: 0.95,
      entities: {
        'snooze': true,
        if (date != null) 'date': _iso(date.date),
        if (time != null) 'time': time.hourMinute,
      },
    );
  }

  /// `ubah jadi jam 10` → jam; `jadikan besok` → tanggal;
  /// `ganti jadi beli susu` → judul; `ubah` saja → tanpa entity.
  AiIntentResult _update(String rest) {
    final cleaned = rest
        .replaceAll(_connector, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    final date = _dateParser.parse(cleaned);
    final time = _timeParser.parse(cleaned);

    String leftover = cleaned;
    if (date != null) leftover = leftover.replaceFirst(date.matched, ' ');
    if (time != null) leftover = leftover.replaceFirst(time.matched, ' ');
    leftover = leftover.replaceAll(_spaces, ' ').trim();

    return AiIntentResult(
      intent: AppIntent.updateItem,
      confidence: 0.95,
      entities: {
        if (date != null) 'date': _iso(date.date),
        if (time != null) 'time': time.hourMinute,
        if (date == null && time == null && leftover.isNotEmpty)
          'title': Normalizer.capitalizeFirst(leftover),
      },
    );
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

import '../intents/ai_intent_result.dart';
import '../intents/app_intent.dart';
import 'amount_parser.dart';
import 'date_parser.dart';
import 'normalizer.dart';
import 'time_parser.dart';

/// Parser berbasis aturan: mengubah kalimat bebas (Bahasa Indonesia) menjadi
/// [AiIntentResult] terstruktur.
///
/// Urutan prioritas intent: ide -> catatan -> pengeluaran -> belanja ->
/// pengingat -> tugas -> jurnal -> tidak dikenal.
class RuleParser {
  RuleParser({required DateTime now})
    : _reference = DateTime(now.year, now.month, now.day),
      _dateParser = DateParser(now: DateTime(now.year, now.month, now.day));

  final DateTime _reference;
  final DateParser _dateParser;
  final TimeParser _timeParser = TimeParser();
  final AmountParser _amountParser = AmountParser();

  static const List<String> _noteMarkers = ['catat:', 'catatan:', 'note:'];
  static const List<String> _ideaMarkers = ['ide:', 'trik:', 'inspirasi:'];

  static const Set<String> _spendWords = {
    'makan',
    'minum',
    'ngopi',
    'kopi',
    'jajan',
    'belanja',
    'beli',
    'belikan',
    'nongkrong',
    'bayar',
  };

  static const Set<String> _shoppingWords = {
    'beli',
    'belikan',
    'beliin',
    'belanja',
  };

  static const Set<String> _reminderWords = {'ingatkan', 'alarm', 'reminder'};

  static const Set<String> _todoWords = {
    'kerjakan',
    'kerjain',
    'selesaikan',
    'selesaiin',
    'beresin',
    'rapikan',
    'buat',
    'bikin',
    'kirim',
    'servis',
    'cicil',
    'jemput',
  };

  static const Set<String> _moodWords = {
    'capek',
    'lelah',
    'senang',
    'bahagia',
    'sedih',
    'galau',
    'bingung',
    'kesel',
    'stress',
    'stres',
    'khawatir',
    'semangat',
    'happy',
    'excited',
  };

  static const Set<String> _temporal = {
    'tadi',
    'barusan',
    'kemarin',
    'nanti',
    'segera',
    'sekarang',
    'hari',
    'ini',
    'besok',
    'lusa',
  };

  AiIntentResult parse(String raw) {
    final text = Normalizer.normalize(raw);

    final idea = _contentAfterMarkers(text, _ideaMarkers, leadingWord: 'ide');
    if (idea != null) {
      return AiIntentResult(
        intent: AppIntent.createIdea,
        confidence: 0.8,
        entities: {'content': idea},
      );
    }

    final note = _contentAfterMarkers(text, _noteMarkers, leadingWord: 'catat');
    if (note != null) {
      return AiIntentResult(
        intent: AppIntent.createNote,
        confidence: 0.8,
        entities: {'content': note},
      );
    }

    final date = _dateParser.parse(text);
    final time = _timeParser.parse(text);
    final amount = _amountParser.parse(text);
    final tokens = text.split(' ');

    if (amount != null && _hasSpendWord(tokens)) {
      return _expense(text, date, amount);
    }

    if (_matchesAny(tokens, _shoppingWords)) {
      return _shopping(text, date);
    }

    final relay = <String>{
      ..._matchedWords(tokens, _reminderWords),
      if (text.contains('jangan lupa')) 'jangan lupa',
    }.toList();
    final hasClock = RegExp(r'(jam|pukul)\s*\d|:\d{2}').hasMatch(text);
    if (hasClock || relay.isNotEmpty) {
      return _reminder(text, date, time, relay);
    }

    if (_matchesAny(tokens, _todoWords)) {
      return _todo(text, date);
    }

    final moods = _matchedWords(tokens, _moodWords);
    if (moods.isNotEmpty) {
      return AiIntentResult(
        intent: AppIntent.createJournal,
        confidence: 0.7,
        entities: {
          'content': _capitalize(_remaining(text, date)),
          'mood': moods.first,
        },
      );
    }

    return const AiIntentResult(
      intent: AppIntent.unknown,
      confidence: 0.1,
      needsConfirmation: true,
    );
  }

  AiIntentResult _expense(
    String text,
    DateExpression? date,
    AmountExpression amount,
  ) {
    var rest = _remaining(
      text,
      date,
      dropWords: {...amount.matched.split(' ')},
    ).split(' ');
    rest = rest.where((w) => w.isNotEmpty).toList();
    if (rest.length > 1 && _spendWords.contains(rest.first)) {
      rest = rest.sublist(1);
    }
    final description = _capitalize(rest.join(' '));
    final words = rest.map((w) => w.replaceAll(RegExp(r'[^a-z]'), '')).toList();

    return AiIntentResult(
      intent: AppIntent.createExpense,
      confidence: 0.95,
      entities: {
        'amount': amount.value,
        'currency': 'IDR',
        'category': _categoryOf(words),
        'description': description,
        'date': _isoDate(date?.date ?? _reference),
      },
    );
  }

  AiIntentResult _shopping(String text, DateExpression? date) {
    final bought = _remaining(text, date, dropWords: _shoppingWords);
    return AiIntentResult(
      intent: AppIntent.createShopping,
      confidence: 0.95,
      entities: {'items': _itemsOf(bought)},
    );
  }

  AiIntentResult _reminder(
    String text,
    DateExpression? date,
    TimeExpression? time,
    List<String> relayWords,
  ) {
    final title = _capitalize(
      _remaining(
        text,
        date,
        dropWords: {
          ...?time?.matched.split(' '),
          ...relayWords.expand((w) => w.split(' ')),
        },
      ),
    );
    return AiIntentResult(
      intent: AppIntent.createReminder,
      confidence: 0.9,
      entities: {
        'title': title,
        'date': _isoDate(date?.date ?? _reference),
        'time': time?.hourMinute ?? '',
        'priority': 'normal',
      },
    );
  }

  AiIntentResult _todo(String text, DateExpression? date) {
    final title = _capitalize(_remaining(text, date));
    return AiIntentResult(
      intent: AppIntent.createTodo,
      confidence: 0.9,
      entities: {
        'title': title,
        'due_date': _isoDate(date?.date ?? _reference),
        'priority': 'normal',
      },
    );
  }

  String _remaining(
    String text,
    DateExpression? date, {
    Set<String> dropWords = const {},
  }) {
    final drop = <String>{
      ...?date?.matched.split(' '),
      ..._temporal,
      ...dropWords,
    };
    return text.split(' ').where((w) => !drop.contains(w)).join(' ').trim();
  }

  bool _hasSpendWord(List<String> tokens) => _spendWords.any(tokens.contains);

  static bool _matchesAny(List<String> tokens, Set<String> words) =>
      _matchedWords(tokens, words).isNotEmpty;

  static List<String> _matchedWords(List<String> tokens, Set<String> words) =>
      words.where((w) => tokens.contains(w)).toList();

  static List<String> _itemsOf(String bought) {
    if (bought.contains(',')) {
      return bought
          .split(',')
          .map((part) => _capitalize(part.trim()))
          .where((part) => part.isNotEmpty)
          .toList();
    }
    return bought
        .split(' ')
        .map(_capitalize)
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _categoryOf(List<String> words) {
    const categories = {
      'makanan': [
        'makan',
        'ngopi',
        'kopi',
        'minum',
        'jajan',
        'snack',
        'camilan',
        'kantin',
        'ayam',
        'nasi',
        'mie',
        'roti',
        'kue',
        'sarapan',
        'makanan',
      ],
      'transport': [
        'bensin',
        'bbm',
        'ojek',
        'parkir',
        'tol',
        'grab',
        'gojek',
        'tiket',
        'bus',
        'kereta',
        'transport',
      ],
      'tagihan': [
        'listrik',
        'air',
        'pulsa',
        'wifi',
        'internet',
        'token',
        'iuran',
        'gas',
        'tagihan',
      ],
      'belanja': [
        'belanja',
        'beras',
        'gula',
        'minyak',
        'telur',
        'susu',
        'sabun',
        'sampo',
        'shampo',
        'deterjen',
        'sayur',
        'daging',
        'bumbu',
        'sembako',
      ],
      'kesehatan': [
        'obat',
        'apotek',
        'apotik',
        'dokter',
        'vitamin',
        'klinik',
        'faskes',
        'kesehatan',
      ],
      'hiburan': [
        'nonton',
        'bioskop',
        'game',
        'streaming',
        'netflix',
        'spotify',
        'konser',
        'hobi',
        'hiburan',
      ],
    };
    for (final entry in categories.entries) {
      if (words.any(entry.value.contains)) return entry.key;
    }
    return 'lainnya';
  }

  static String? _contentAfterMarkers(
    String text,
    List<String> markers, {
    required String leadingWord,
  }) {
    for (final marker in markers) {
      if (text == marker || text.startsWith('$marker ')) {
        final content = text.substring(marker.length).trim();
        if (content.isNotEmpty) return _capitalize(content);
      }
    }
    if (text.split(' ').first == leadingWord) {
      final content = text.split(' ').skip(1).join(' ').trim();
      if (content.isNotEmpty) return _capitalize(content);
    }
    return null;
  }

  static String _capitalize(String text) => Normalizer.capitalizeFirst(text);

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

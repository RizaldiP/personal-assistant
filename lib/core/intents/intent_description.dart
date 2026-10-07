import '../../shared/formatters/currency_formats.dart';
import '../../shared/formatters/date_formats.dart';
import '../../shared/intents/ai_intent_result.dart';
import '../../shared/intents/app_intent.dart';

/// Ringkasan pendek sebuah intent dalam Bahasa Indonesia untuk ditampilkan
/// ke pengguna (kartu konfirmasi dan balasan chat).
///
/// Membaca entity secara defensif: entity hilang tidak menyebabkan error,
/// hanya menghasilkan deskripsi yang lebih pendek.
String describeIntent(AiIntentResult result) {
  final entities = result.entities;
  final title = _text(entities['title']);
  final content = _text(entities['content']);
  final target = _target(entities);

  return switch (result.intent) {
    AppIntent.createReminder => _with('Pengingat ${_quoted(title)}', [
      if (_text(entities['date']).isNotEmpty)
        DateFormats.longIndonesia(entities['date'] as String?),
      if (_text(entities['time']).isNotEmpty) 'jam ${entities['time']}',
    ]),
    AppIntent.createTodo => _with('Tugas ${_quoted(title)}', [
      if (_text(entities['due_date']).isNotEmpty)
        'jatuh tempo ${DateFormats.longIndonesia(entities['due_date'] as String?)}',
    ]),
    AppIntent.createShopping => 'Belanja: ${_items(entities['items'])}',
    AppIntent.createExpense => _with(
      'Pengeluaran ${CurrencyFormats.idr((entities['amount'] as num?)?.toInt() ?? 0)}',
      [
        if (_text(entities['description']).isNotEmpty)
          'untuk ${entities['description']}',
      ],
    ),
    AppIntent.createNote => 'Catatan ${_quoted(content)}',
    AppIntent.createJournal => 'Jurnal ${_quoted(content)}',
    AppIntent.createIdea => 'Ide ${_quoted(content)}',
    AppIntent.search => 'Cari ${_quoted(_text(entities['query']))}',
    AppIntent.updateItem =>
      entities['snooze'] == true
          ? _snoozeDescription(entities, target)
          : _with('Ubah ${_quoted(target)}', [
              if (title.isNotEmpty) 'judul jadi ${_quoted(title)}',
              if (_text(entities['date']).isNotEmpty)
                DateFormats.longIndonesia(entities['date'] as String?),
              if (_text(entities['time']).isNotEmpty) 'jam ${entities['time']}',
            ]),
    AppIntent.deleteItem => 'Hapus ${_quoted(target)}',
    AppIntent.completeItem => 'Selesaikan ${_quoted(target)}',
    AppIntent.unknown => 'Belum bisa menentukan maksud pesan',
  };
}

String _snoozeDescription(Map<String, dynamic> entities, String target) {
  final minutes = (entities['snooze_minutes'] as num?)?.toInt();
  if (minutes != null) {
    return _with('Tunda ${_quoted(target)}', ['$minutes menit']);
  }
  return _with('Tunda ${_quoted(target)}', [
    if (_text(entities['date']).isNotEmpty)
      DateFormats.longIndonesia(entities['date'] as String?),
    if (_text(entities['time']).isNotEmpty) 'jam ${entities['time']}',
  ]);
}

/// Target perintah lanjutan; "item terakhir" bila label belum terisi.
String _target(Map<String, dynamic> entities) {
  final label = _text(entities['target_label']);
  return label.isEmpty ? 'item terakhir' : label;
}

String _quoted(String value) => value.isEmpty ? '' : '"$value"';

String _with(String head, List<String> details) =>
    details.isEmpty ? head : '$head (${details.join(', ')})';

String _text(Object? value) => value == null ? '' : value.toString().trim();

String _items(Object? value) {
  if (value is! List || value.isEmpty) return 'belum ada item';
  return value.map((item) => item.toString().trim()).join(', ');
}

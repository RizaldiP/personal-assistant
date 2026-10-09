import 'dart:convert';

import '../../features/todo/domain/entities/task.dart';

/// Satu baris tugas yang dikirim ke widget layar utama.
class TodayTaskEntry {
  const TodayTaskEntry({
    required this.id,
    required this.title,
    this.time,
    required this.done,
  });

  final int id;
  final String title;

  /// `HH:mm` atau `null` bila tugas tanpa jam.
  final String? time;
  final bool done;
}

/// Mengubah daftar tugas menjadi JSON ringkas untuk widget.
///
/// Kunci sengaja pendek agar data SharedPreferences tetap kecil. Urutan daftar
/// dipertahankan apa adanya (provider sudah mengurutkan pending lebih dulu).
String encodeTodayTasks(List<Task> tasks) {
  final entries = <Map<String, Object?>>[
    for (final task in tasks)
      if (task.id != null)
        <String, Object?>{
          'i': task.id,
          't': task.title,
          'm': task.dueTime,
          'd': task.status == TaskStatus.done,
        },
  ];
  return jsonEncode(entries);
}

/// Mengurai JSON hasil [encodeTodayTasks]; aman terhadap data kosong/rusak.
List<TodayTaskEntry> decodeTodayTasks(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];

  final entries = <TodayTaskEntry>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final id = item['i'];
    final title = item['t'];
    if (id is! int || title is! String) continue;
    final time = item['m'];
    entries.add(
      TodayTaskEntry(
        id: id,
        title: title,
        time: time is String ? time : null,
        done: item['d'] == true,
      ),
    );
  }
  return entries;
}

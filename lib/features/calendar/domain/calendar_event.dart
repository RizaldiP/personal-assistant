/// Tipe kejadian kalender (PHASE 13): hanya tugas, reminder, dan jurnal
/// sesuai rencana docs/07.
abstract final class CalendarEventTypes {
  static const String task = 'task';
  static const String reminder = 'reminder';
  static const String journal = 'journal';
}

/// Satu kejadian pada kalender untuk satu tanggal.
class CalendarEvent {
  const CalendarEvent({
    required this.type,
    required this.id,
    required this.title,
    this.time,
  });

  /// Salah satu dari [CalendarEventTypes].
  final String type;

  /// Id entitas asli (todo/reminder/jurnal).
  final int id;

  final String title;

  /// Jam (`HH:mm`) bila tersedia — tugas dan reminder saja.
  final String? time;
}

// Bantuan konversi tanggal/jam reminder (pure Dart).
//
// `date` berbentuk `YYYY-MM-DD`, `time` berbentuk `HH:mm`. Representasi
// tersimpan (`scheduledAt`, `nextFireAt`, dst) memakai epoch millisecond UTC.

/// `'2026-10-07'` + `'08:00'` → `DateTime(2026, 10, 7, 8, 0)` (waktu lokal).
DateTime reminderLocalDateTime(String date, String time) {
  final parts = date.split('-').map(int.parse).toList();
  final clock = time.split(':').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2], clock[0], clock[1]);
}

/// Epoch millisecond UTC dari [local] (waktu lokal).
int reminderToEpochUtc(DateTime local) => local.toUtc().millisecondsSinceEpoch;

/// Waktu lokal dari epoch millisecond UTC.
DateTime reminderFromEpochUtc(int epochMs) =>
    DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();

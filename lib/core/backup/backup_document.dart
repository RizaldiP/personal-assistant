import 'dart:convert';

/// Berkas cadangan Personal Offline (PHASE 14).
///
/// Format JSON bernama `personal-offline-backup` dengan nomor versi format
/// dan `schema_version` berisi `AppDatabase.schemaVersion` saat ekspor, agar
/// pemulihan dari database lebih baru dapat ditolak oleh validator.
class BackupDocument {
  const BackupDocument({
    required this.version,
    required this.schemaVersion,
    required this.exportedAt,
    required this.tables,
  });

  /// Nilai wajib pada kolom `format` setiap berkas cadangan.
  static const String formatName = 'personal-offline-backup';

  /// Versi format berkas tertinggi yang dipahami aplikasi ini.
  static const int currentVersion = 1;

  final int version;
  final int schemaVersion;
  final DateTime exportedAt;

  /// Nama tabel database → daftar baris (kolom asli database, nilai
  /// primitif JSON: null / num / String / bool).
  final Map<String, List<Map<String, dynamic>>> tables;

  /// Total baris di seluruh tabel.
  int get totalRows => tables.values.fold(0, (sum, rows) => sum + rows.length);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': formatName,
    'version': version,
    'schema_version': schemaVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'data': tables,
  };

  /// Serialisasi ke JSON rapi (indentasi 2 spasi) untuk berkas.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Nama berkas ekspor: `personal-offline-backup-YYYY-MM-DD.<extension>`.
  static String fileNameFor(DateTime date, {String extension = 'json'}) {
    final local = date.toLocal();
    return 'personal-offline-backup-${_stamp(local)}.$extension';
  }

  /// Nama cadangan otomatis sebelum pemulihan: sama dengan
  /// [fileNameFor] tetapi ditandai `sebelum-pulihkan-<jam>`.
  static String safetyFileNameFor(DateTime date) {
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return 'personal-offline-backup-sebelum-pulihkan-${_stamp(local)}-$hh$mm$ss.json';
  }

  /// Nama laporan PDF pengeluaran: `laporan-pengeluaran-YYYY-MM.pdf`.
  static String reportFileNameFor(DateTime month) {
    return 'laporan-pengeluaran-${_stamp(month).substring(0, 7)}.pdf';
  }

  static String _stamp(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

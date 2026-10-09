import 'dart:convert';

import 'backup_document.dart';

/// Skema satu tabel yang diketahui aplikasi (hasil pembacaan database:
/// `PRAGMA table_info`).
class TableSchema {
  const TableSchema({
    required this.name,
    required this.columns,
    required this.primaryKey,
  });

  final String name;
  final Set<String> columns;

  /// Nama kolom primary key menurut urutan `pk` di SQLite; kosong bila tidak
  /// ada (tidak terjadi pada tabel aplikasi ini).
  final List<String> primaryKey;
}

/// Hasil validasi berkas cadangan.
///
/// Bila [isValid], [document] berisi dokumen siap dipulihkan dan [warnings]
/// berisi catatan non-fatal (mis. tabel tidak dikenal yang dilewati).
class BackupValidationResult {
  const BackupValidationResult.valid({
    required this.document,
    this.warnings = const [],
  }) : isValid = true,
       error = null;

  const BackupValidationResult.invalid(this.error)
    : isValid = false,
      document = null,
      warnings = const [];

  final bool isValid;
  final BackupDocument? document;
  final String? error;
  final List<String> warnings;

  /// Jumlah baris per tabel (hanya bila valid).
  Map<String, int> get counts {
    final doc = document;
    if (doc == null) return const {};
    return {
      for (final entry in doc.tables.entries) entry.key: entry.value.length,
    };
  }

  int get totalRows => document?.totalRows ?? 0;
}

/// Validator berkas cadangan (dokumen 29: validasi sebelum restore).
///
/// Pemeriksaan dilakukan sepenuhnya di memori terhadap skema yang diberikan
/// aplikasi — tidak ada satu pun baris database yang disentuh sebelum
/// seluruh isi berkas dinyatakan valid.
class BackupValidator {
  const BackupValidator();

  /// [raw] isi berkas; [appSchemaVersion] `AppDatabase.schemaVersion`;
  /// [schema] daftar tabel yang dikenal database saat ini.
  BackupValidationResult validate(
    String raw, {
    required int appSchemaVersion,
    required List<TableSchema> schema,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      return const BackupValidationResult.invalid(
        'File bukan JSON yang valid.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return const BackupValidationResult.invalid(
        'File bukan cadangan Personal Offline (bukan objek JSON).',
      );
    }
    if (decoded['format'] != BackupDocument.formatName) {
      return const BackupValidationResult.invalid(
        'File bukan cadangan Personal Offline.',
      );
    }

    final version = decoded['version'];
    if (version is! int) {
      return const BackupValidationResult.invalid(
        'Nomor versi cadangan tidak ditemukan atau tidak valid.',
      );
    }
    if (version > BackupDocument.currentVersion) {
      return BackupValidationResult.invalid(
        'Versi cadangan ($version) lebih baru dari aplikasi '
        '(${BackupDocument.currentVersion}).',
      );
    }

    final schemaVersion = decoded['schema_version'];
    if (schemaVersion is! int) {
      return const BackupValidationResult.invalid(
        'Versi database pada cadangan tidak ditemukan atau tidak valid.',
      );
    }
    if (schemaVersion > appSchemaVersion) {
      return BackupValidationResult.invalid(
        'Cadangan dibuat dengan database versi $schemaVersion, '
        'aplikasi ini masih versi $appSchemaVersion.',
      );
    }

    final exportedRaw = decoded['exported_at'];
    if (exportedRaw is! String) {
      return const BackupValidationResult.invalid(
        'Waktu ekspor pada cadangan tidak ditemukan.',
      );
    }
    final exportedAt = DateTime.tryParse(exportedRaw);
    if (exportedAt == null) {
      return const BackupValidationResult.invalid(
        'Waktu ekspor pada cadangan tidak valid.',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return const BackupValidationResult.invalid(
        'Isi cadangan (data) tidak ditemukan.',
      );
    }

    final known = {for (final table in schema) table.name: table};
    final warnings = <String>[];
    if (schemaVersion < appSchemaVersion) {
      warnings.add(
        'Cadangan berasal dari database versi $schemaVersion '
        '(aplikasi ini $appSchemaVersion); kolom baru diisi nilai default.',
      );
    }

    final tables = <String, List<Map<String, dynamic>>>{};
    var knownTables = 0;
    for (final entry in data.entries) {
      final tableSchema = known[entry.key];
      if (tableSchema == null) {
        warnings.add('Tabel ${entry.key} tidak dikenal dan dilewati.');
        continue;
      }
      knownTables++;
      final rows = entry.value;
      if (rows is! List) {
        return BackupValidationResult.invalid(
          'Isi tabel ${entry.key} bukan daftar baris.',
        );
      }
      final parsed = <Map<String, dynamic>>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row is! Map<String, dynamic>) {
          return BackupValidationResult.invalid(
            'Baris ke-${i + 1} pada tabel ${entry.key} bukan objek.',
          );
        }
        for (final cell in row.entries) {
          if (!tableSchema.columns.contains(cell.key)) {
            return BackupValidationResult.invalid(
              'Kolom ${cell.key} tidak dikenal di tabel ${entry.key}.',
            );
          }
          final value = cell.value;
          if (value != null &&
              value is! String &&
              value is! num &&
              value is! bool) {
            return BackupValidationResult.invalid(
              'Nilai kolom ${cell.key} pada tabel ${entry.key} '
              'bukan tipe yang didukung.',
            );
          }
        }
        parsed.add(row);
      }
      tables[entry.key] = parsed;
    }

    if (knownTables == 0) {
      return const BackupValidationResult.invalid(
        'File tidak berisi tabel yang dikenal aplikasi.',
      );
    }

    return BackupValidationResult.valid(
      document: BackupDocument(
        version: version,
        schemaVersion: schemaVersion,
        exportedAt: exportedAt,
        tables: tables,
      ),
      warnings: warnings,
    );
  }
}

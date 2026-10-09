import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/clock.dart';
import 'backup_document.dart';
import 'backup_validator.dart';

/// Mode pemulihan cadangan (dokumen 29: preview + konfirmasi).
enum RestoreMode {
  /// Pertahankan data lama; baris yang primary key-nya sudah ada dilewati.
  merge,

  /// Hapus seluruh data lama lalu isi dengan isi cadangan.
  replace,
}

/// Jumlah baris per tabel pada satu kali pemulihan.
class RestoreTableCounts {
  const RestoreTableCounts({required this.inserted, required this.skipped});

  final int inserted;
  final int skipped;
}

/// Hasil pemulihan. Bila [success] false, database dijamin tidak berubah
/// (seluruh pekerjaan dibatalkan lewat transaksi).
class RestoreResult {
  const RestoreResult._({
    required this.success,
    this.error,
    this.counts = const {},
    this.warnings = const [],
  });

  factory RestoreResult.ok(
    Map<String, RestoreTableCounts> counts, {
    List<String> warnings = const [],
  }) => RestoreResult._(success: true, counts: counts, warnings: warnings);

  factory RestoreResult.failed(String error) =>
      RestoreResult._(success: false, error: error);

  final bool success;
  final String? error;
  final Map<String, RestoreTableCounts> counts;
  final List<String> warnings;

  int get inserted => counts.values.fold(0, (sum, item) => sum + item.inserted);
  int get skipped => counts.values.fold(0, (sum, item) => sum + item.skipped);
  int get totalRows => inserted + skipped;
}

/// Ekspor & pemulihan seluruh tabel aplikasi (PHASE 14).
///
/// Ekspor membaca langsung dari SQLite (`SELECT *` per tabel) sehingga semua
/// tabel ikut tercakup tanpa method khusus per DAO. Pemulihan berlangsung di
/// dalam satu transaksi: kegagalan di tengah jalan = rollback penuh, data
/// lama tidak tersentuh.
class BackupService {
  BackupService(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Membaca seluruh tabel aplikasi menjadi [BackupDocument].
  Future<BackupDocument> exportDocument() async {
    final tables = await _appTables();
    final data = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      final rows = await _db.customSelect('SELECT * FROM "$table"').get();
      data[table] = [
        for (final row in rows) Map<String, dynamic>.from(row.data),
      ];
    }
    return BackupDocument(
      version: BackupDocument.currentVersion,
      schemaVersion: _db.schemaVersion,
      exportedAt: _clock.now(),
      tables: data,
    );
  }

  /// Memvalidasi isi berkas terhadap skema database saat ini.
  Future<BackupValidationResult> validate(String raw) async {
    final schema = await tableSchemas();
    return BackupValidator().validate(
      raw,
      appSchemaVersion: _db.schemaVersion,
      schema: schema,
    );
  }

  /// Memulihkan [document] ke database.
  ///
  /// [RestoreMode.replace] menghapus seluruh data lama terlebih dahulu;
  /// [RestoreMode.merge] menyisipkan baris yang belum ada dan melewati yang
  /// sudah. Urutan antar tabel dihitung dari `foreign_key_list` sehingga
  /// delete selalu diawali anak dan insert diawali induk.
  Future<RestoreResult> restore(
    BackupDocument document, {
    required RestoreMode mode,
  }) async {
    final schemas = await tableSchemas();
    final byName = {for (final schema in schemas) schema.name: schema};
    final ordered = await _topologicalTables(byName.keys.toSet());

    try {
      final counts = await _db.transaction(() async {
        if (mode == RestoreMode.replace) {
          for (final table in ordered.reversed) {
            await _db.customStatement('DELETE FROM "$table"');
          }
        }
        final result = <String, RestoreTableCounts>{};
        for (final table in ordered) {
          final rows = document.tables[table];
          if (rows == null) continue;
          final schema = byName[table]!;
          var inserted = 0;
          var skipped = 0;
          for (final row in rows) {
            if (mode == RestoreMode.merge && await _exists(schema, row)) {
              skipped++;
              continue;
            }
            await _insert(schema, row);
            inserted++;
          }
          result[table] = RestoreTableCounts(
            inserted: inserted,
            skipped: skipped,
          );
        }
        return result;
      });

      // customStatement tidak memicu stream drift; beri tahu pendengar.
      _db.markTablesUpdated(_db.allTables);

      final warnings = <String>[
        if (document.schemaVersion < _db.schemaVersion)
          'Cadangan dari database versi ${document.schemaVersion}; '
              'kolom baru memakai nilai default.',
      ];
      return RestoreResult.ok(counts, warnings: warnings);
    } on Object catch (error) {
      return RestoreResult.failed('Pemulihan dibatalkan: ${_message(error)}');
    }
  }

  /// Skema seluruh tabel aplikasi (kolom + primary key).
  Future<List<TableSchema>> tableSchemas() async {
    final schemas = <TableSchema>[];
    for (final table in await _appTables()) {
      final info = await _db.customSelect('PRAGMA table_info("$table")').get();
      final columns = <String>{};
      final keyed = <int, String>{};
      for (final row in info) {
        final name = row.data['name'];
        if (name is! String) continue;
        columns.add(name);
        final pk = row.data['pk'];
        if (pk is int && pk > 0) keyed[pk] = name;
      }
      final primaryKey = (keyed.keys.toList()..sort())
          .map((order) => keyed[order]!)
          .toList();
      schemas.add(
        TableSchema(name: table, columns: columns, primaryKey: primaryKey),
      );
    }
    return schemas;
  }

  /// Nama tabel aplikasi (tanpa tabel internal SQLite/drift), urut abjad.
  Future<List<String>> _appTables() async {
    final rows = await _db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'drift_%' "
          'ORDER BY name',
        )
        .get();
    return [for (final row in rows) row.data['name'] as String];
  }

  /// Urutan tabel: induk lebih dulu (untuk insert); kebalikannya untuk delete.
  Future<List<String>> _topologicalTables(Set<String> tables) async {
    final parents = <String, Set<String>>{
      for (final table in tables) table: <String>{},
    };
    for (final table in tables) {
      final fks = await _db
          .customSelect('PRAGMA foreign_key_list("$table")')
          .get();
      for (final row in fks) {
        final parent = row.data['table'];
        if (parent is String && tables.contains(parent)) {
          parents[table]!.add(parent);
        }
      }
    }

    final ordered = <String>[];
    final placed = <String>{};
    final remaining = Set<String>.of(tables);
    while (remaining.isNotEmpty) {
      final ready =
          remaining
              .where((table) => parents[table]!.every(placed.contains))
              .toList()
            ..sort();
      if (ready.isEmpty) {
        // Sirkulasi (tidak ada pada skema aplikasi) → fallback abjad.
        ordered.addAll(remaining.toList()..sort());
        break;
      }
      for (final table in ready) {
        ordered.add(table);
        placed.add(table);
        remaining.remove(table);
      }
    }
    return ordered;
  }

  /// Apakah baris dengan primary key yang sama sudah ada di tabel.
  Future<bool> _exists(TableSchema schema, Map<String, dynamic> row) async {
    final pk = schema.primaryKey;
    if (pk.isEmpty || !pk.every((column) => row[column] != null)) return false;
    final condition = pk.map((column) => '"$column" = ?').join(' AND ');
    final result = await _db
        .customSelect(
          'SELECT 1 FROM "${schema.name}" WHERE $condition',
          variables: [for (final column in pk) _bind(row[column])],
        )
        .getSingleOrNull();
    return result != null;
  }

  /// Insert satu baris dengan kolom eksplisit; kolom yang tidak ada di baris
  /// memakai default kolomnya.
  Future<void> _insert(TableSchema schema, Map<String, dynamic> row) async {
    final columns = row.keys.where(schema.columns.contains).toList();
    if (columns.isEmpty) {
      throw StateError('Baris tabel ${schema.name} tidak berisi kolom valid.');
    }
    final placeholders = List.filled(columns.length, '?').join(', ');
    final quoted = columns.map((column) => '"$column"').join(', ');
    await _db.customStatement(
      'INSERT INTO "${schema.name}" ($quoted) VALUES ($placeholders)',
      [for (final column in columns) _raw(row[column])],
    );
  }

  static Object? _raw(Object? value) => switch (value) {
    final bool flag => flag ? 1 : 0,
    _ => value,
  };

  static Variable<Object> _bind(Object? value) => switch (value) {
    null => const Variable<Object>(null),
    final int number => Variable.withInt(number),
    final String text => Variable.withString(text),
    final bool flag => Variable.withInt(flag ? 1 : 0),
    final double number => Variable.withReal(number),
    final other => Variable.withString(other.toString()),
  };

  static String _message(Object error) {
    final text = error.toString();
    return text.isEmpty ? 'kesalahan tidak dikenal' : text;
  }
}

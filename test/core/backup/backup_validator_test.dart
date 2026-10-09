import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/backup/backup_document.dart';
import 'package:personal_offline/core/backup/backup_validator.dart';

TableSchema schema(
  String name, {
  List<String> columns = const ['id', 'title'],
}) {
  return TableSchema(
    name: name,
    columns: columns.toSet(),
    primaryKey: const ['id'],
  );
}

String _encode({
  Object? format = BackupDocument.formatName,
  Object? version = BackupDocument.currentVersion,
  Object? schemaVersion = 6,
  Object? exportedAt = '2026-10-05T08:30:00.000Z',
  Object? data,
}) {
  return jsonEncode({
    'format': ?format,
    'version': ?version,
    'schema_version': ?schemaVersion,
    'exported_at': ?exportedAt,
    'data': ?data,
  });
}

void main() {
  const validator = BackupValidator();
  final tasks = schema('tasks');
  final notes = schema('notes');
  final known = [tasks, notes];

  group('BackupValidator.valid', () {
    test('dokumen lengkap dan dikenal → valid dengan parse', () {
      final raw = _encode(
        data: {
          'tasks': [
            {'id': 1, 'title': 'Bayar listrik'},
          ],
          'notes': <Map<String, dynamic>>[],
        },
      );

      final result = validator.validate(
        raw,
        appSchemaVersion: 6,
        schema: known,
      );

      expect(result.isValid, isTrue);
      expect(result.document, isNotNull);
      expect(result.warnings, isEmpty);
      expect(result.counts['tasks'], 1);
      expect(result.counts['notes'], 0);
      expect(result.totalRows, 1);
    });

    test('kuci nama tabel memakai nama database asli', () {
      final raw = _encode(
        data: {
          'tasks': [
            {'id': 1, 'title': 'A'},
          ],
        },
      );

      final result = validator.validate(
        raw,
        appSchemaVersion: 6,
        schema: known,
      );

      expect(result.document!.tables['tasks']!.single['title'], 'A');
    });

    test('skema cadangan lebih lama → valid dengan peringatan', () {
      final raw = _encode(
        schemaVersion: 4,
        data: {
          'tasks': [
            {'id': 1, 'title': 'A'},
          ],
        },
      );

      final result = validator.validate(
        raw,
        appSchemaVersion: 6,
        schema: known,
      );

      expect(result.isValid, isTrue);
      expect(result.warnings.single, contains('versi 4'));
    });

    test('tabel tidak dikenal dilewati dengan peringatan', () {
      final raw = _encode(
        data: {
          'tasks': [
            {'id': 1, 'title': 'A'},
          ],
          'habits': [
            {'id': 1, 'name': 'Olahraga'},
          ],
        },
      );

      final result = validator.validate(
        raw,
        appSchemaVersion: 6,
        schema: known,
      );

      expect(result.isValid, isTrue);
      expect(result.document!.tables.containsKey('habits'), isFalse);
      expect(result.warnings.single, contains('habits'));
    });
  });

  group('BackupValidator.invalid', () {
    test('bukan JSON → invalid', () {
      final result = validator.validate(
        'bukan json',
        appSchemaVersion: 6,
        schema: known,
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('bukan JSON'));
    });

    test('bukan objek JSON → invalid', () {
      expect(
        validator.validate('[1,2]', appSchemaVersion: 6, schema: known).error,
        contains('bukan cadangan'),
      );
    });

    test('format bukan cadangan Personal Offline → invalid', () {
      expect(
        validator
            .validate(
              _encode(format: 'lain'),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('bukan cadangan'),
      );
    });

    test('version hilang atau bukan angka → invalid', () {
      expect(
        validator
            .validate(
              _encode(version: null),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('versi cadangan'),
      );
      expect(
        validator
            .validate(_encode(version: 'x'), appSchemaVersion: 6, schema: known)
            .error,
        contains('versi cadangan'),
      );
    });

    test('version lebih baru dari aplikasi → invalid', () {
      expect(
        validator
            .validate(_encode(version: 99), appSchemaVersion: 6, schema: known)
            .error,
        contains('lebih baru'),
      );
    });

    test('schema_version hilang atau lebih baru → invalid', () {
      expect(
        validator
            .validate(
              _encode(schemaVersion: null),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('Versi database'),
      );
      expect(
        validator
            .validate(
              _encode(schemaVersion: 99),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('masih versi'),
      );
    });

    test('exported_at hilang atau tidak valid → invalid', () {
      expect(
        validator
            .validate(
              _encode(exportedAt: null),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('Waktu ekspor'),
      );
      expect(
        validator
            .validate(
              _encode(exportedAt: 'kemarin'),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('tidak valid'),
      );
    });

    test('data bukan objek → invalid', () {
      expect(
        validator
            .validate(_encode(data: [1]), appSchemaVersion: 6, schema: known)
            .error,
        contains('data'),
      );
    });

    test('isi tabel bukan daftar baris → invalid', () {
      expect(
        validator
            .validate(
              _encode(data: {'tasks': 'bukan-list'}),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('bukan daftar baris'),
      );
    });

    test('baris bukan objek → invalid', () {
      expect(
        validator
            .validate(
              _encode(
                data: {
                  'tasks': [1],
                },
              ),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('bukan objek'),
      );
    });

    test('kolom tidak dikenal pada tabel → invalid', () {
      expect(
        validator
            .validate(
              _encode(
                data: {
                  'tasks': [
                    {'id': 1, 'title': 'A', 'kabur': true},
                  ],
                },
              ),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('kabur'),
      );
    });

    test('nilai kolom bertipe tidak didukung → invalid', () {
      expect(
        validator
            .validate(
              _encode(
                data: {
                  'tasks': [
                    {
                      'id': 1,
                      'title': {'a': 1},
                    },
                  ],
                },
              ),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('bukan tipe yang didukung'),
      );
    });

    test('tidak ada tabel yang dikenal aplikasi → invalid', () {
      expect(
        validator
            .validate(
              _encode(
                data: {
                  'habits': [
                    {'id': 1, 'name': 'A'},
                  ],
                },
              ),
              appSchemaVersion: 6,
              schema: known,
            )
            .error,
        contains('tidak berisi tabel'),
      );
    });
  });
}

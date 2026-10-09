import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/backup/backup_document.dart';

void main() {
  final exportedAt = DateTime.utc(2026, 10, 5, 8, 30);

  BackupDocument document() => BackupDocument(
    version: BackupDocument.currentVersion,
    schemaVersion: 6,
    exportedAt: exportedAt,
    tables: {
      'tasks': [
        {'id': 1, 'title': 'Bayar listrik'},
      ],
      'notes': [],
    },
  );

  group('BackupDocument', () {
    test('encode menghasilkan kunci format, versi, dan data per tabel', () {
      final json = document().encode();

      expect(json, contains('"format": "personal-offline-backup"'));
      expect(json, contains('"version": ${BackupDocument.currentVersion}'));
      expect(json, contains('"schema_version": 6'));
      expect(json, contains('"exported_at": "2026-10-05T08:30:00.000Z"'));
      expect(json, contains('"Bayar listrik"'));
    });

    test('encode memakai indentasi dua spasi agar berkas mudah dibaca', () {
      expect(document().encode(), contains('\n  "format"'));
    });

    test('totalRows menjumlahkan baris seluruh tabel', () {
      final doc = document();

      expect(doc.totalRows, 1);
    });

    test('fileNameFor memakai tanggal lokal dan ekspsi yang diberikan', () {
      final json = BackupDocument.fileNameFor(DateTime(2026, 10, 5));
      final zip = BackupDocument.fileNameFor(
        DateTime(2026, 10, 5),
        extension: 'zip',
      );

      expect(json, 'personal-offline-backup-2026-10-05.json');
      expect(zip, 'personal-offline-backup-2026-10-05.zip');
    });

    test('safetyFileNameFor ditandai sebelum-pulihkan beserta jam', () {
      final name = BackupDocument.safetyFileNameFor(DateTime(2026, 10, 5));

      expect(
        name,
        startsWith('personal-offline-backup-sebelum-pulihkan-2026-10-05-'),
      );
      expect(name, endsWith('.json'));
    });

    test('reportFileNameFor memakai tahun dan bulan', () {
      expect(
        BackupDocument.reportFileNameFor(DateTime(2026, 10)),
        'laporan-pengeluaran-2026-10.pdf',
      );
    });
  });
}

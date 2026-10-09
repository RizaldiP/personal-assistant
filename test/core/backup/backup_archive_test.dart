import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/backup/backup_archive.dart';

void main() {
  group('BackupArchive.encode', () {
    test('roundtrip dokumen tanpa lampiran', () {
      final bytes = BackupArchive.encode(documentJson: '{"format":"x"}');

      final decoded = BackupArchive.decode(bytes);

      expect(decoded, isNotNull);
      expect(decoded!.documentJson, '{"format":"x"}');
      expect(decoded.attachments, isEmpty);
      expect(decoded.attachmentCount, 0);
    });

    test('roundtrip dokumen dengan lampiran', () {
      final content = BackupArchive.encode(
        documentJson: '{"format":"x"}',
        attachments: {
          'foto.png': const [1, 2, 3],
          'catatan.txt': utf8.encode('isi catatan'),
        },
      );

      final decoded = BackupArchive.decode(content);

      expect(decoded!.documentJson, '{"format":"x"}');
      expect(
        decoded.attachments.keys,
        containsAll(['foto.png', 'catatan.txt']),
      );
      expect(decoded.attachments['foto.png'], [1, 2, 3]);
      expect(decoded.attachmentCount, 2);
    });

    test('nama lampiran membuang pemisah path', () {
      final content = BackupArchive.encode(
        documentJson: '{}',
        attachments: const {
          '../evil.txt': [1],
          'a\\b.txt': [2],
        },
      );

      final decoded = BackupArchive.decode(content);

      for (final name in decoded!.attachments.keys) {
        expect(name.contains('/'), isFalse);
        expect(name.contains('\\'), isFalse);
      }
      expect(decoded.attachments.keys, containsAll(['.._evil.txt', 'a_b.txt']));
    });
  });

  group('BackupArchive.decode', () {
    test('byte bukan ZIP → null', () {
      expect(BackupArchive.decode(utf8.encode('halo dunia')), isNull);
    });

    test('ZIP tanpa backup.json → null', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('attachments/foto.png', [1, 2]));
      final bytes = ZipEncoder().encodeBytes(archive);

      expect(BackupArchive.decode(bytes), isNull);
    });

    test('ZIP dengan nama lampiran mengandung path dibersihkan saat baca', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string(BackupArchive.documentEntry, '{}'))
        ..addFile(ArchiveFile.bytes('attachments/../bahaya.txt', [9]));
      final bytes = ZipEncoder().encodeBytes(archive);

      final decoded = BackupArchive.decode(bytes);

      final names = decoded!.attachments.keys.toList();
      expect(names.single.contains('/'), isFalse);
    });
  });
}

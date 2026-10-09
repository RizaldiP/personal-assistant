import 'dart:convert';

import 'package:archive/archive.dart';

/// Isi berkas cadangan ZIP.
class BackupArchiveContent {
  const BackupArchiveContent({
    required this.documentJson,
    required this.attachments,
  });

  /// Isi `backup.json` di dalam arsip.
  final String documentJson;

  /// Nama lampiran → isi berkas (prefix `attachments/` sudah dibuang).
  final Map<String, List<int>> attachments;

  int get attachmentCount => attachments.length;
}

/// Berkas cadangan ZIP: `backup.json` + folder `attachments/`.
///
/// Dokumen 29: ZIP hanya dipakai bila ada lampiran; ZIP tetap bisa dibuat
/// manual oleh pengguna (folder lampiran akan kosong).
abstract final class BackupArchive {
  static const String documentEntry = 'backup.json';
  static const String attachmentsPrefix = 'attachments/';

  /// Membuat arsip ZIP dari isi dokumen cadangan.
  static List<int> encode({
    required String documentJson,
    Map<String, List<int>> attachments = const {},
  }) {
    final archive = Archive()
      ..addFile(ArchiveFile.string(documentEntry, documentJson));
    attachments.forEach((name, bytes) {
      archive.addFile(
        ArchiveFile.bytes('$attachmentsPrefix${_safeName(name)}', bytes),
      );
    });
    return ZipEncoder().encodeBytes(archive);
  }

  /// Membaca arsip ZIP. Mengembalikan null bila bukan ZIP valid atau
  /// `backup.json` tidak ada di dalamnya.
  static BackupArchiveContent? decode(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      String? json;
      final attachments = <String, List<int>>{};
      for (final file in archive) {
        if (file.name == documentEntry) {
          json = utf8.decode(file.content);
          continue;
        }
        if (!file.name.startsWith(attachmentsPrefix)) continue;
        final name = file.name.substring(attachmentsPrefix.length);
        if (name.isEmpty) continue;
        attachments[_safeName(name)] = file.content;
      }
      if (json == null) return null;
      return BackupArchiveContent(documentJson: json, attachments: attachments);
    } on Object {
      return null;
    }
  }

  /// Buang pemisah path dari nama berkas (lindungi dari `../` di ZIP luar).
  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[/\\]'), '_');
}

import 'dart:async';
import 'dart:convert';

import 'package:personal_offline/core/backup/backup_storage.dart';

/// Fake [BackupStorage] in-memory untuk test cadangan (PHASE 14).
///
/// Semua akses file, share sheet, dan picker berjalan di memori sehingga test
/// tidak menyentuh plugin platform. [gate] menahan operasi sampai di-complete
/// untuk menguji state sibuk, [writeError]/[readError] menyuntikkan kegagalan.
class FakeBackupStorage implements BackupStorage {
  /// Berkas cadangan yang sudah ditulis: nama file → isi.
  final Map<String, List<int>> backupFiles = {};

  /// Path yang dibagikan lewat share sheet, berurutan.
  final List<String> sharedPaths = [];

  /// Path yang dibuka dengan aplikasi eksternal, berurutan.
  final List<String> openedPaths = [];

  /// Lampiran yang terbaca dari folder `attachments/`.
  final Map<String, List<int>> attachments = {};

  /// Berkas yang dikembalikan picker; null = pengguna membatalkan.
  PickedBackupFile? pickedFile;

  /// Bila di-set, `writeBackup` menunggu future ini (untuk test state sibuk).
  Completer<void>? gate;

  /// Bila di-set, `writeBackup` melempar error ini.
  Object? writeError;

  /// Bila di-set, `pickBackupFile` melempar error ini.
  Object? readError;

  @override
  Future<String> writeBackup(String fileName, List<int> bytes) async {
    final pendingGate = gate;
    if (pendingGate != null) await pendingGate.future;
    final error = writeError;
    if (error != null) throw error;
    backupFiles[fileName] = bytes;
    return 'memory://backups/$fileName';
  }

  @override
  Future<PickedBackupFile?> pickBackupFile() async {
    final error = readError;
    if (error != null) throw error;
    return pickedFile;
  }

  @override
  Future<void> shareBackup(String path) async {
    sharedPaths.add(path);
  }

  @override
  Future<bool> openBackup(String path) async {
    openedPaths.add(path);
    return true;
  }

  @override
  Future<Map<String, List<int>>> readAttachmentFiles() async {
    return Map<String, List<int>>.of(attachments);
  }

  @override
  Future<void> writeAttachmentFiles(Map<String, List<int>> files) async {
    attachments.addAll(files);
  }

  /// Membuat [PickedBackupFile] dari teks (mis. isi berkas cadangan).
  static PickedBackupFile jsonFile(String name, String content) =>
      PickedBackupFile(name: name, bytes: utf8.encode(content));

  /// Membuat [PickedBackupFile] dari byte mentah.
  static PickedBackupFile binaryFile(String name, List<int> bytes) =>
      PickedBackupFile(name: name, bytes: bytes);
}

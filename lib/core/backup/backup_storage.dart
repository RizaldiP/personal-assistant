import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_provider.dart';
import 'backup_service.dart';

/// Berkas yang dipilih pengguna untuk dipulihkan.
class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Akses file sistem yang dipakai fitur cadangan.
///
/// Dipisah dari implementasi platform agar widget/unit test dapat memakai
/// fake tanpa channel platform (file picker, share sheet, path_provider).
abstract interface class BackupStorage {
  /// Menulis berkas ke folder cadangan; mengembalikan path lengkap.
  Future<String> writeBackup(String fileName, List<int> bytes);

  /// Membuka picker berkas `.json`/`.zip`; null bila pengguna membatalkan.
  Future<PickedBackupFile?> pickBackupFile();

  /// Membuka share sheet untuk berkas hasil ekspor.
  Future<void> shareBackup(String path);

  /// Membuka berkas dengan aplikasi eksternal; false bila gagal.
  Future<bool> openBackup(String path);

  /// Seluruh lampiran tersimpan (nama → isi), kosong bila belum ada.
  Future<Map<String, List<int>>> readAttachmentFiles();

  /// Menyimpan lampiran ke folder `attachments/` (nama dinetralkan).
  Future<void> writeAttachmentFiles(Map<String, List<int>> files);
}

/// Implementasi nyata berbasis plugin platform (PHASE 14).
class PlatformBackupStorage implements BackupStorage {
  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> writeBackup(String fileName, List<int> bytes) async {
    final dir = await _dir('backups');
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<PickedBackupFile?> pickBackupFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Pilih berkas cadangan',
      type: FileType.custom,
      allowedExtensions: const ['json', 'zip'],
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return PickedBackupFile(name: picked.name, bytes: bytes);
  }

  @override
  Future<void> shareBackup(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], title: 'Cadangan Personal Offline'),
    );
  }

  @override
  Future<bool> openBackup(String path) async {
    final result = await OpenFilex.open(path);
    return result.type == ResultType.done;
  }

  @override
  Future<Map<String, List<int>>> readAttachmentFiles() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}attachments');
    if (!await dir.exists()) return const {};
    final files = <String, List<int>>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      files[entity.uri.pathSegments.last] = await entity.readAsBytes();
    }
    return files;
  }

  @override
  Future<void> writeAttachmentFiles(Map<String, List<int>> files) async {
    if (files.isEmpty) return;
    final dir = await _dir('attachments');
    for (final entry in files.entries) {
      final safe = entry.key.replaceAll(RegExp(r'[/\\]'), '_');
      await File(
        '${dir.path}${Platform.pathSeparator}$safe',
      ).writeAsBytes(entry.value, flush: true);
    }
  }
}

/// Storage cadangan yang dipakai aplikasi. Test meng-override dengan fake.
final backupStorageProvider = Provider<BackupStorage>((ref) {
  return PlatformBackupStorage();
});

/// Layanan ekspor/pemulihan yang dipakai aplikasi.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  );
});

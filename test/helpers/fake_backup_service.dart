import 'package:personal_offline/core/backup/backup_document.dart';
import 'package:personal_offline/core/backup/backup_service.dart';
import 'package:personal_offline/core/backup/backup_validator.dart';

/// Fake [BackupService] untuk widget test (PHASE 14).
///
/// Menggantikan seluruh operasi database drift sehingga widget test berjalan
/// di bawah FakeAsync tanpa menyentuh query nyata (yang bisa menggantung).
class FakeBackupService extends BackupService {
  FakeBackupService(super.database, super.clock);

  int exportCalls = 0;
  int validateCalls = 0;
  int restoreCalls = 0;

  BackupDocument? exportResult;
  BackupValidationResult? validateResult;
  RestoreResult? restoreResult;
  Object? restoreError;

  RestoreMode? lastRestoreMode;
  BackupDocument? lastRestoreDocument;

  @override
  Future<BackupDocument> exportDocument() async {
    exportCalls++;
    final result = exportResult;
    if (result != null) return result;
    throw StateError('FakeBackupService.exportDocument: atur exportResult.');
  }

  @override
  Future<BackupValidationResult> validate(String raw) async {
    validateCalls++;
    final result = validateResult;
    if (result != null) return result;
    throw StateError('FakeBackupService.validate: atur validateResult.');
  }

  @override
  Future<RestoreResult> restore(
    BackupDocument document, {
    required RestoreMode mode,
  }) async {
    restoreCalls++;
    lastRestoreDocument = document;
    lastRestoreMode = mode;
    final error = restoreError;
    if (error != null) throw error;
    final result = restoreResult;
    if (result != null) return result;
    throw StateError('FakeBackupService.restore: atur restoreResult.');
  }
}

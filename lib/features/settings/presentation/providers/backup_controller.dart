import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backup/backup_archive.dart';
import '../../../../core/backup/backup_document.dart';
import '../../../../core/backup/backup_service.dart';
import '../../../../core/backup/backup_storage.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/pdf/pdf_report_service.dart';
import '../../../finance/data/repositories/expense_repository_impl.dart';

/// Format berkas ekspor cadangan.
enum BackupFormat { json, zip }

/// Status pemilihan berkas cadangan.
enum BackupPickStatus { cancelled, invalid, ready }

/// Hasil pemilihan berkas cadangan dari pengguna.
class BackupPickResult {
  const BackupPickResult.cancelled()
    : status = BackupPickStatus.cancelled,
      document = null,
      error = null,
      attachments = const {};

  const BackupPickResult.invalid(String this.error)
    : status = BackupPickStatus.invalid,
      document = null,
      attachments = const {};

  const BackupPickResult.ready(
    BackupDocument this.document, {
    this.attachments = const {},
  }) : status = BackupPickStatus.ready,
       error = null;

  final BackupPickStatus status;
  final BackupDocument? document;
  final String? error;

  /// Lampiran dari berkas ZIP (kosong untuk JSON).
  final Map<String, List<int>> attachments;

  int get attachmentCount => attachments.length;
}

/// State controller: true saat ada operasi berjalan (tombol nonaktif).
class BackupController extends Notifier<bool> {
  @override
  bool build() => false;

  BackupService get _service => ref.read(backupServiceProvider);
  BackupStorage get _storage => ref.read(backupStorageProvider);

  /// Membuat berkas cadangan lalu membuka share sheet.
  /// Mengembalikan path berkas, atau null bila gagal.
  Future<String?> exportBackup(BackupFormat format) async {
    if (state) return null;
    state = true;
    try {
      final document = await _service.exportDocument();
      final attachments = await _storage.readAttachmentFiles();
      final asZip = format == BackupFormat.zip || attachments.isNotEmpty;

      final String name;
      final List<int> bytes;
      if (asZip) {
        bytes = BackupArchive.encode(
          documentJson: document.encode(),
          attachments: attachments,
        );
        name = BackupDocument.fileNameFor(
          document.exportedAt,
          extension: 'zip',
        );
      } else {
        bytes = utf8.encode(document.encode());
        name = BackupDocument.fileNameFor(document.exportedAt);
      }

      final path = await _storage.writeBackup(name, bytes);
      await _storage.shareBackup(path);
      return path;
    } on Object {
      return null;
    } finally {
      state = false;
    }
  }

  /// Memilih berkas lalu memvalidasinya. [BackupPickStatus.cancelled] bila
  /// pengguna menutup picker.
  Future<BackupPickResult> pickAndValidate() async {
    if (state) return const BackupPickResult.cancelled();
    state = true;
    try {
      final file = await _storage.pickBackupFile();
      if (file == null) return const BackupPickResult.cancelled();

      final String raw;
      final Map<String, List<int>> attachments;
      if (file.name.toLowerCase().endsWith('.zip')) {
        final content = BackupArchive.decode(file.bytes);
        if (content == null) {
          return const BackupPickResult.invalid(
            'File ZIP tidak berisi cadangan yang valid.',
          );
        }
        raw = content.documentJson;
        attachments = content.attachments;
      } else {
        raw = utf8.decode(file.bytes, allowMalformed: true);
        attachments = const {};
      }

      final validation = await _service.validate(raw);
      if (!validation.isValid) {
        return BackupPickResult.invalid(
          validation.error ?? 'File cadangan tidak valid.',
        );
      }
      return BackupPickResult.ready(
        validation.document!,
        attachments: attachments,
      );
    } on Object catch (error) {
      return BackupPickResult.invalid('File tidak dapat dibaca: $error');
    } finally {
      state = false;
    }
  }

  /// Memulihkan data. Sebelumnya membuat cadangan aman (best effort); seluruh
  /// pemulihan berjalan dalam satu transaksi sehingga kegagalan = data lama
  /// utuh.
  Future<RestoreResult> restore(
    BackupDocument document,
    RestoreMode mode, {
    Map<String, List<int>> attachments = const {},
  }) async {
    if (state) {
      return RestoreResult.failed('Masih memproses permintaan sebelumnya.');
    }
    state = true;
    try {
      try {
        final snapshot = await _service.exportDocument();
        await _storage.writeBackup(
          BackupDocument.safetyFileNameFor(snapshot.exportedAt),
          utf8.encode(snapshot.encode()),
        );
      } on Object {
        // Snapshot gagal tidak menghalangi pemulihan: transaksi di bawah
        // tetap menjamin database lama tidak rusak bila restore gagal.
      }

      final result = await _service.restore(document, mode: mode);
      if (!result.success || attachments.isEmpty) return result;

      try {
        await _storage.writeAttachmentFiles(attachments);
      } on Object {
        return RestoreResult.ok(
          result.counts,
          warnings: [...result.warnings, 'Lampiran gagal disimpan.'],
        );
      }
      return result;
    } finally {
      state = false;
    }
  }

  /// Membuat PDF laporan pengeluaran bulan berjalan lalu membukanya.
  /// Mengembalikan path berkas, atau null bila gagal.
  Future<String?> exportMonthlyExpenseReport() async {
    if (state) return null;
    state = true;
    try {
      final now = ref.read(clockProvider).now();
      final monthPrefix =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';
      final expenses = await ref.read(expenseRepositoryProvider).getAll();
      final inMonth = expenses
          .where((expense) => expense.date.startsWith(monthPrefix))
          .toList();

      final bytes = await PdfReportService.buildExpenseReport(
        expenses: inMonth,
        month: now,
        generatedAt: now,
      );
      final path = await _storage.writeBackup(
        BackupDocument.reportFileNameFor(now),
        bytes,
      );
      await _storage.openBackup(path);
      return path;
    } on Object {
      return null;
    } finally {
      state = false;
    }
  }
}

final backupControllerProvider = NotifierProvider<BackupController, bool>(
  BackupController.new,
);

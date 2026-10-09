import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backup/backup_document.dart';
import '../../../../core/backup/backup_labels.dart';
import '../../../../core/backup/backup_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../providers/backup_controller.dart';

/// Widget untuk mengekspor/memulihkan cadangan (PHASE 14).
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = ref.watch(backupControllerProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.backup_outlined, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Cadangan & Data',
                  style: AppTypography.titleOnSurface(theme.textTheme),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ekspor database ke JSON/ZIP lalu pulihkan. Sebelum pulihkan dibuat cadangan aman.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () => _export(context, ref, BackupFormat.json),
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Ekspor JSON'),
              ),
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () => _export(context, ref, BackupFormat.zip),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Ekspor ZIP'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async => await _importBackup(context, ref),
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Pulihkan'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _exportPdf(context, ref),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Laporan PDF (bulan ini)'),
              ),
            ],
          ),
          if (busy)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: const LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    BackupFormat format,
  ) async {
    final path = await ref
        .read(backupControllerProvider.notifier)
        .exportBackup(format);
    if (!context.mounted || path != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ekspor cadangan gagal. Coba lagi.')),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final path = await ref
        .read(backupControllerProvider.notifier)
        .exportMonthlyExpenseReport();
    if (!context.mounted || path != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan PDF gagal dibuat. Coba lagi.')),
    );
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(backupControllerProvider.notifier)
        .pickAndValidate();
    if (!context.mounted) return;

    switch (result.status) {
      case BackupPickStatus.cancelled:
        return;
      case BackupPickStatus.invalid:
        _showError(context, result.error ?? 'File tidak valid.');
        return;
      case BackupPickStatus.ready:
        final doc = result.document!;
        await _confirmRestore(context, ref, doc, result.attachments);
    }
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    BackupDocument doc,
    Map<String, List<int>> attachments,
  ) async {
    final counts = doc.tables.entries
        .map(
          (entry) =>
              '${BackupTableLabels.of(entry.key)}: ${entry.value.length}',
        )
        .join('\n');
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulihkan cadangan?'),
        content: SingleChildScrollView(
          child: Text(
            'Dibuat: ${DateFormats.longFromDate(doc.exportedAt)}\n'
            'Versi DB: ${doc.schemaVersion}\n'
            'Baris: ${doc.totalRows}\n\n$counts\n\n'
            'Operasi akan berjalan dalam satu transaksi. Sebelum ini dibuat cadangan aman. Pilih mode:',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gabung (lewati duplikat)'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Timpa (hapus data lama)'),
          ),
        ],
      ),
    );
    if (!context.mounted || proceed == null) return;

    final mode = proceed ? RestoreMode.merge : RestoreMode.replace;
    final restore = await ref
        .read(backupControllerProvider.notifier)
        .restore(doc, mode, attachments: attachments);
    if (!context.mounted) return;

    if (!restore.success) {
      _showError(context, restore.error ?? 'Pemulihan gagal.');
      return;
    }

    final inserted = restore.inserted;
    final skipped = restore.skipped;
    final warnings = restore.warnings.join('\n');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pemulihan selesai'),
        content: Text(
          'Disisipkan: $inserted\nDilewati (duplikat): $skipped\n'
          '${warnings.isEmpty ? '' : '\nPeringatan:\n$warnings'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gagal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

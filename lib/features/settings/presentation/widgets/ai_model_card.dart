import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/ai/ai_model_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Kartu pengelolaan model AI lokal di layar Pengaturan (PHASE 10).
///
/// UI hanya mengelola siklus hidup model (unduh dengan consent, muat, lepas);
/// UI tidak pernah memanggil `LocalAiEngine.understand()` (docs/05 bagian 3).
class AiModelCard extends ConsumerWidget {
  const AiModelCard({super.key});

  static String formatSize(int bytes) =>
      '${(bytes / (1024 * 1024)).round()} MB';

  Future<void> _confirmDownload(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unduh model AI?'),
        content: Text(
          '${AiConfig.defaultModelName} berukuran '
          '${formatSize(AiConfig.defaultModelSizeBytes)} '
          '(${AiConfig.modelLicense}) dan diunduh sekali ke penyimpanan '
          'perangkat.\n\n'
          'Proses memerlukan koneksi internet; setelah selesai semua '
          'pemrosesan berjalan offline di perangkat. Data kamu tidak '
          'pernah dikirim keluar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unduh'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(aiModelControllerProvider.notifier).download();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(aiModelControllerProvider);
    final controller = ref.read(aiModelControllerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.ensureInitialized();
    });

    final captionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Model AI lokal',
            style: AppTypography.titleOnSurface(theme.textTheme),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${AiConfig.defaultModelName} · '
            '${formatSize(AiConfig.defaultModelSizeBytes)} · '
            '${AiConfig.modelLicense}',
            style: captionStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mengenali kalimat yang tidak ditangani aturan, langsung di '
            'perangkat. Tanpa model, aplikasi tetap berfungsi penuh.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.isDownloading)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: state.downloadProgress,
                    minHeight: AppSpacing.xs,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Mengunduh model… '
                    '${((state.downloadProgress ?? 0) * 100).round()}%',
                    style: captionStyle,
                  ),
                ],
              ),
            ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                state.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            )
          else if (!state.isBusy)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(_statusText(state), style: captionStyle),
            ),
          if (state.isBusy)
            Text(
              state.isDownloading ? 'Mohon tunggu…' : 'Memuat model…',
              style: captionStyle,
            )
          else if (!state.isCached)
            FilledButton.icon(
              onPressed: () => _confirmDownload(context, ref),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Unduh model'),
            )
          else if (!state.isLoaded)
            FilledButton.icon(
              onPressed: controller.load,
              icon: const Icon(Icons.memory_outlined),
              label: const Text('Muat model'),
            )
          else
            OutlinedButton.icon(
              onPressed: controller.unload,
              icon: const Icon(Icons.eject_outlined),
              label: const Text('Lepas model'),
            ),
        ],
      ),
    );
  }

  static String _statusText(AiModelState state) {
    if (state.isLoaded) return 'Model siap dipakai.';
    if (state.isCached) return 'Model sudah diunduh, belum dimuat ke memori.';
    return 'Model belum diunduh.';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/intents/app_intent.dart';
import '../providers/pending_confirmation.dart';

/// Kartu konfirmasi intent AI / perintah destruktif di atas input chat
/// (docs/05 bagian 6, PHASE 12).
///
/// Confidence ≥ 0.85 → `Simpan` + `Batal`; 0.50–0.84 → `Ya` + `Ubah` +
/// `Batal`; intent `hapus` → `Hapus` + `Batal`. Tidak ada yang disimpan
/// sebelum user menekan tombol.
class ConfirmationBar extends ConsumerWidget {
  const ConfirmationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingConfirmationProvider);
    if (pending == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(pendingConfirmationProvider.notifier);

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: AppSpacing.lg,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pending.busy
                        ? 'Memproses...'
                        : 'Konfirmasi: ${pending.summary}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: pending.busy
                      ? null
                      : () => _run(context, controller.confirm),
                  child: Text(_primaryLabel(pending)),
                ),
                if (!pending.highConfidence &&
                    pending.result.intent != AppIntent.deleteItem)
                  OutlinedButton(
                    onPressed: pending.busy
                        ? null
                        : () => _run(context, controller.edit),
                    child: const Text('Ubah'),
                  ),
                TextButton(
                  onPressed: pending.busy
                      ? null
                      : () => _run(context, controller.reject),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _primaryLabel(PendingConfirmation pending) {
    if (pending.result.intent == AppIntent.deleteItem) return 'Hapus';
    return pending.highConfidence ? 'Simpan' : 'Ya';
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Gagal memproses. Coba lagi.')),
        );
    }
  }
}

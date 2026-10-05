import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';

/// Layar utama: sapaan, daftar hari ini, dan input natural language.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.today});

  /// Disuntikkan untuk test; default = waktu sekarang.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                Text(
                  'Selamat ${_greeting(now.hour)} 👋',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id').format(now),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'HARI INI',
                  style: AppTypography.sectionLabel(
                    theme.textTheme,
                  )?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _TodayPlaceholder(),
              ],
            ),
          ),
          const _InputPlaceholder(),
        ],
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 11) return 'pagi';
    if (hour < 15) return 'siang';
    if (hour < 18) return 'sore';
    return 'malam';
  }
}

class _TodayPlaceholder extends StatelessWidget {
  const _TodayPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'Belum ada tugas hari ini',
        message: 'Tugas dan reminder yang kamu buat akan muncul di sini.',
      ),
    );
  }
}

class _InputPlaceholder extends StatelessWidget {
  const _InputPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apa yang ingin kamu lakukan?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            readOnly: true,
            onTap: () => _showNotAvailable(context),
            decoration: InputDecoration(
              hintText: 'Ketik di sini...',
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                onPressed: () => _showNotAvailable(context),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tulis apa saja, aplikasi akan memahami maksudmu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotAvailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Fitur chat belum tersedia.')),
      );
  }
}

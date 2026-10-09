import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widget/home_widget_service.dart';

/// Kartu penyematan widget layar utama (tugas hari ini + tombol chat).
class HomeWidgetCard extends ConsumerStatefulWidget {
  const HomeWidgetCard({super.key});

  @override
  ConsumerState<HomeWidgetCard> createState() => _HomeWidgetCardState();
}

class _HomeWidgetCardState extends ConsumerState<HomeWidgetCard> {
  bool? _supported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var supported = false;
      try {
        supported = await ref.read(homeWidgetServiceProvider).isPinSupported();
      } on Object {
        supported = false;
      }
      if (mounted) setState(() => _supported = supported);
    });
  }

  Future<void> _pin() async {
    try {
      await ref.read(homeWidgetServiceProvider).requestPin();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat menyematkan widget.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            'Widget layar utama',
            style: AppTypography.titleOnSurface(theme.textTheme),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tampilkan daftar tugas hari ini di layar utama. Tugas bisa '
            'langsung dicentang dari widget, dan tombol Chat membuka layar '
            'Percakapan.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_supported == null)
            Text('Memeriksa dukungan launcher…', style: captionStyle)
          else if (_supported == false)
            Text(
              'Launcher perangkat ini tidak mendukung penyematan otomatis. '
              'Tambahkan widget "Tugas Hari Ini" lewat menu widget launcher.',
              style: captionStyle,
            )
          else
            FilledButton.icon(
              onPressed: _pin,
              icon: const Icon(Icons.add_to_home_screen_outlined),
              label: const Text('Pin ke layar utama'),
            ),
        ],
      ),
    );
  }
}

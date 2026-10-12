import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Kartu pengaturan notifikasi: mengizinkan notifikasi, status izin, dan uji.
class NotificationPermissionCard extends ConsumerStatefulWidget {
  const NotificationPermissionCard({super.key});

  @override
  ConsumerState<NotificationPermissionCard> createState() =>
      _NotificationPermissionCardState();
}

class _NotificationPermissionCardState
    extends ConsumerState<NotificationPermissionCard> {
  bool? _enabled;
  bool? _exact;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    var enabled = false;
    var exact = false;
    try {
      final scheduler = ref.read(notificationSchedulerProvider);
      enabled = await scheduler.notificationsEnabled();
      exact = await scheduler.canScheduleExactNotifications();
    } on Object {
      enabled = false;
      exact = false;
    }
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _exact = exact;
      });
    }
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationSchedulerProvider).requestPermissions();
    } on Object {
      // Tetap segarkan status di bawah.
    }
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permintaan izin notifikasi diproses.')),
    );
  }

  Future<void> _test() async {
    try {
      await ref.read(notificationSchedulerProvider).showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi uji dikirim.')),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim notifikasi uji.')),
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

    final String statusText;
    if (_enabled == null) {
      statusText = 'Memeriksa status izin…';
    } else if (_enabled == false) {
      statusText = 'Notifikasi belum diizinkan. Aktifkan agar pengingat muncul.';
    } else if (_exact == false) {
      statusText =
          'Notifikasi aktif, tetapi alarm presisi belum diizinkan. Pengingat '
          'mungkin tidak tepat waktu.';
    } else {
      statusText = 'Notifikasi dan alarm presisi aktif.';
    }

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
            'Notifikasi',
            style: AppTypography.titleOnSurface(theme.textTheme),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pengingat tugas harian (08.00) dan reminder dikirim lewat '
            'notifikasi perangkat. Aktifkan izin agar selalu tampil.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(statusText, style: captionStyle),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _request,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Izinkan notifikasi'),
              ),
              OutlinedButton.icon(
                onPressed: _test,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Uji notifikasi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

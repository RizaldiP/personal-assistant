import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../shopping/presentation/screens/shopping_screen.dart';
import '../../../todo/domain/entities/task.dart';
import '../../../todo/presentation/providers/task_controller.dart';
import '../../../todo/presentation/screens/todo_screen.dart';
import '../../../todo/presentation/task_display.dart';

/// Layar utama: sapaan, daftar hari ini, dan input natural language.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.today});

  /// Disuntikkan untuk test; default = waktu sekarang.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const _TodaySection(),
                const SizedBox(height: AppSpacing.sm),
                const _ShoppingEntry(),
                const _FinanceEntry(),
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

/// Tugas pending hari ini; bila kosong menampilkan state kosong.
class _TodaySection extends ConsumerWidget {
  const _TodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(todayTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => const _TodayContainer(
        child: EmptyState(
          icon: Icons.check_circle_outline,
          title: 'Belum ada tugas hari ini',
          message: 'Tugas dan reminder yang kamu buat akan muncul di sini.',
        ),
      ),
      data: (tasks) => tasks.isEmpty
          ? const _TodayContainer(
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Belum ada tugas hari ini',
                message:
                    'Tugas dan reminder yang kamu buat akan muncul di sini.',
              ),
            )
          : _TodayContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...tasks
                      .take(5)
                      .map(
                        (task) => _TodayTaskRow(
                          task: task,
                          onTap: () => _openTodos(context),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => _openTodos(context),
                    icon: const Icon(Icons.checklist),
                    label: const Text('Lihat semua tugas'),
                  ),
                ],
              ),
            ),
    );
  }

  void _openTodos(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const TodoScreen()));
  }
}

class _ShoppingEntry extends StatelessWidget {
  const _ShoppingEntry();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ShoppingScreen())),
        icon: const Icon(Icons.shopping_basket_outlined),
        label: const Text('Daftar belanja'),
      ),
    );
  }
}

class _FinanceEntry extends StatelessWidget {
  const _FinanceEntry();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const FinanceScreen())),
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: const Text('Keuangan'),
      ),
    );
  }
}

class _TodayContainer extends StatelessWidget {
  const _TodayContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: child,
    );
  }
}

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = TaskDisplay.subtitle(task);

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.radio_button_unchecked,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
          Semantics(
            button: true,
            label: 'Buka percakapan',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
              ),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.arrow_upward_rounded),
                ),
                child: Text(
                  'Ketik di sini...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
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
}

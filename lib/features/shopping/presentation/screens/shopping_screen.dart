import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_controller.dart';

/// Layar daftar belanja: checklist item, tambah/hapus, kelompok selesai.
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(shoppingListsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Belanja')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah item belanja',
        onPressed: () => _promptAddItem(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: listsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorState(onRetry: () => ref.invalidate(shoppingListsProvider)),
          data: (lists) => lists.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_basket_outlined,
                  title: 'Belum ada daftar belanja',
                  message:
                      'Ketuk tombol + untuk menambah item, atau ketik di '
                      'percakapan seperti "besok beli beras minyak telur".',
                )
              : _ShoppingList(lists: lists),
        ),
      ),
    );
  }

  Future<void> _promptAddItem(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah item belanja'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Misal: beras 2 kg'),
          onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final name = controller.text;
    if (name.trim().isEmpty) return;
    try {
      await ref.read(shoppingControllerProvider.notifier).addItems([name]);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    }
  }
}

class _ShoppingList extends ConsumerWidget {
  const _ShoppingList({required this.lists});

  final List<ShoppingList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = lists.where((list) => !list.isDone).toList();
    final done = lists.where((list) => list.isDone).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        _SectionLabel('BELANJA'),
        ...open.map((list) => _ShoppingListCard(list: list)),
        if (done.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionLabel('SELESAI'),
          ...done.map((list) => _ShoppingListCard(list: list)),
        ],
      ],
    );
  }
}

class _ShoppingListCard extends ConsumerWidget {
  const _ShoppingListCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(shoppingControllerProvider.notifier);

    void showError() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    }

    Future<void> toggle(ShoppingItem item, bool value) async {
      try {
        await controller.toggleItem(item, value);
      } on Object {
        showError();
      }
    }

    Future<void> remove(ShoppingItem item) async {
      try {
        await controller.removeItem(item);
      } on Object {
        showError();
      }
    }

    Future<void> deleteList() async {
      final confirmed = await _confirmDeleteList(context);
      if (confirmed != true || !context.mounted) return;
      try {
        await controller.deleteList(list.id!);
      } on Object {
        showError();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              children: [
                Checkbox(
                  value: list.isDone,
                  onChanged: (value) =>
                      controller.setDone(list, value ?? false),
                ),
                Expanded(
                  child: Text(
                    list.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${list.items.where((i) => i.isChecked).length}/'
                  '${list.items.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus daftar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: deleteList,
                ),
              ],
            ),
          ),
          if (list.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Text(
                'Belum ada item. Ketuk + untuk menambah.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...list.items.map(
              (item) => _ItemRow(
                item: item,
                onToggle: (value) => toggle(item, value),
                onRemove: () => remove(item),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeleteList(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus daftar?'),
        content: Text(
          '"${list.title}" beserta ${list.items.length} itemnya tidak bisa '
          'dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onToggle,
    required this.onRemove,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      item.name,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: item.isChecked ? scheme.onSurfaceVariant : scheme.onSurface,
        decoration: item.isChecked ? TextDecoration.lineThrough : null,
        decorationColor: scheme.onSurfaceVariant,
      ),
    );

    return Row(
      children: [
        Checkbox(
          value: item.isChecked,
          onChanged: (value) {
            if (value != null) onToggle(value);
          },
        ),
        Expanded(child: label),
        IconButton(
          tooltip: 'Hapus item',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.sectionLabel(
          theme.textTheme,
        )?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: AppSpacing.lg),
          const Text('Belanja gagal dimuat'),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

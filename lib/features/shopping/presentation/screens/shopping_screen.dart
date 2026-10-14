import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_controller.dart';

/// Layar daftar belanja: checklist item, tambah/hapus, kelompok selesai.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(shoppingListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belanja'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari belanja',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _query = '';
                }
              });
            },
          ),
        ],
        bottom: _searching
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                  72 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Cari item belanja...',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah item belanja',
        onPressed: () => _promptAddItem(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: listsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ErrorState(
            title: 'Belanja gagal dimuat',
            onRetry: () => ref.invalidate(shoppingListsProvider),
          ),
          data: (lists) {
            if (lists.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_basket_outlined,
                title: 'Belum ada daftar belanja',
                message:
                    'Ketuk tombol + untuk menambah item, atau ketik di '
                    'percakapan seperti "besok beli beras minyak telur".',
              );
            }
            final filtered = _filterLists(lists, _query);
            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'Tidak ditemukan',
                message: 'Tidak ada item yang cocok dengan "$_query".',
              );
            }
            return _ShoppingList(lists: filtered);
          },
        ),
      ),
    );
  }

  Future<void> _promptAddItem(BuildContext context) async {
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

List<ShoppingList> _filterLists(List<ShoppingList> lists, String query) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return lists;
  final result = <ShoppingList>[];
  for (final list in lists) {
    if (list.title.toLowerCase().contains(keyword)) {
      result.add(list);
      continue;
    }
    final matchingItems = list.items
        .where((item) => item.name.toLowerCase().contains(keyword))
        .toList();
    if (matchingItems.isNotEmpty) {
      result.add(list.copyWith(items: matchingItems));
    }
  }
  return result;
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    '${list.items.where((i) => i.isChecked).length}/'
                    '${list.items.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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

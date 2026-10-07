import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../domain/entities/inbox_item.dart';
import '../providers/inbox_controller.dart';

/// Layar Smart Inbox (PHASE 13): kumpulan input chat yang belum berhasil
/// dipahami aplikasi — user bisa menentukan aksinya sendiri.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inboxItemsProvider);
    final filter = ref.watch(inboxUiProvider).filter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            key: const Key('inbox-search-button'),
            tooltip: 'Pencarian',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat inbox',
          message: 'Coba buka lagi layarnya.',
        ),
        data: (items) {
          final visible = items.where((item) {
            return switch (filter) {
              InboxStatusFilter.open => item.resolution == InboxResolution.open,
              InboxStatusFilter.done => item.resolution != InboxResolution.open,
              InboxStatusFilter.all => true,
            };
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    for (final status in InboxStatusFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          key: Key('inbox-filter-${status.name}'),
                          label: Text(status.label),
                          selected: filter == status,
                          onSelected: (_) => ref
                              .read(inboxUiProvider.notifier)
                              .setFilter(status),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Inbox kosong',
                        message:
                            'Input yang belum pasti maksudnya akan muncul '
                            'di sini agar kamu bisa menentukannya sendiri.',
                      )
                    : visible.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_alt_outlined,
                        title: 'Tidak ada item',
                        message: 'Belum ada item dengan status ini.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          final isOpen =
                              item.resolution == InboxResolution.open;
                          final suggestion = inboxSuggestionLabel(
                            item.suggestion,
                          );
                          return ListTile(
                            key: Key('inbox-item-${item.id}'),
                            title: Text(
                              item.rawText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: suggestion.isEmpty
                                ? null
                                : Text(suggestion),
                            trailing: isOpen
                                ? const Icon(Icons.chevron_right)
                                : Icon(
                                    item.resolution == InboxResolution.converted
                                        ? Icons.check_circle_outline
                                        : Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                            onTap: isOpen
                                ? () => _showActions(context, ref, item)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Aksi item terbuka: simpan sebagai catatan, buka di chat, atau abaikan.
  void _showActions(BuildContext context, WidgetRef ref, InboxItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('inbox-action-note'),
              leading: const Icon(Icons.edit_note),
              title: const Text('Simpan sebagai Catatan'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _saveAsNote(context, ref, item);
              },
            ),
            ListTile(
              key: const Key('inbox-action-chat'),
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Buka di Chat'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                prepareInboxChatDraft(ref, item);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
                );
              },
            ),
            ListTile(
              key: const Key('inbox-action-discard'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('Abaikan'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _discard(ref, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsNote(
    BuildContext context,
    WidgetRef ref,
    InboxItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await saveInboxAsNote(ref, item);
      messenger.showSnackBar(
        const SnackBar(content: Text('Disimpan sebagai catatan.')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan catatan.')),
      );
    }
  }

  Future<void> _discard(WidgetRef ref, InboxItem item) async {
    try {
      await discardInboxItem(ref, item);
    } on Object {
      // Gagal menandai item tidak merusak layar; stream tetap sinkron.
    }
  }
}

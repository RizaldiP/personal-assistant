import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/tag_chips.dart';
import '../../domain/entities/journal_entry.dart';
import '../providers/journal_controller.dart';
import 'journal_form_screen.dart';

/// Layar jurnal: daftar entri urut tanggal, pencarian, tambah/edit/hapus.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
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
    final entriesAsync = ref.watch(journalEntriesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jurnal'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari jurnal',
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
                preferredSize: const Size.fromHeight(72),
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
                      hintText: 'Cari jurnal...',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tulis jurnal',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const JournalFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            onRetry: () => ref.invalidate(journalEntriesProvider(_query)),
          ),
          data: (entries) => entries.isEmpty
              ? EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: _query.isEmpty
                      ? 'Belum ada jurnal'
                      : 'Tidak ditemukan',
                  message: _query.isEmpty
                      ? 'Ketuk tombol + untuk menulis, atau ketik di '
                            'percakapan seperti "hari ini capek banget".'
                      : 'Tidak ada jurnal yang cocok dengan "$_query".',
                )
              : _JournalList(entries: entries),
        ),
      ),
    );
  }
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _JournalTile(entry: entries[index]),
    );
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = <String>[
      DateFormats.longIndonesia(entry.date),
      if (entry.mood != null && entry.mood!.isNotEmpty) entry.mood!,
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => JournalFormScreen(entry: entry),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty) ...[
                Text(
                  meta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                entry.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              TagChips(tags: entry.tags),
            ],
          ),
        ),
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
          const Text('Jurnal gagal dimuat'),
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

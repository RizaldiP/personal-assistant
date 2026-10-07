import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/tag_chips.dart';
import '../../domain/entities/note.dart';
import '../providers/note_controller.dart';
import 'note_form_screen.dart';

/// Layar daftar catatan: list, pencarian, tambah/edit/hapus.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
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
    final notesAsync = ref.watch(notesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari catatan',
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
                      hintText: 'Cari catatan...',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah catatan',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const NoteFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: notesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorState(onRetry: () => ref.invalidate(notesProvider(_query))),
          data: (notes) => notes.isEmpty
              ? EmptyState(
                  icon: Icons.notes_outlined,
                  title: _query.isEmpty
                      ? 'Belum ada catatan'
                      : 'Tidak ditemukan',
                  message: _query.isEmpty
                      ? 'Ketuk tombol + untuk menulis, atau ketik di '
                            'percakapan seperti "catatan: nomor sparepart 12345".'
                      : 'Tidak ada catatan yang cocok dengan "$_query".',
                )
              : _NoteList(notes: notes),
        ),
      ),
    );
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: notes.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _NoteTile(note: notes[index]),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = (note.title == null || note.title!.isEmpty)
        ? note.content
        : note.title!;
    final hasTitle = note.title != null && note.title!.isNotEmpty;
    final dateLabel = DateFormats.longFromDate(note.createdAt);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => NoteFormScreen(note: note)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasTitle) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  note.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dateLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              TagChips(tags: note.tags),
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
          const Text('Catatan gagal dimuat'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/tag_chips.dart';
import '../../domain/entities/idea.dart';
import '../providers/idea_controller.dart';
import 'idea_form_screen.dart';

/// Layar ide: dikelompok per status, pencarian, tambah/edit/hapus, ubah
/// status lewat menu.
class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key});

  @override
  ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
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
    final ideasAsync = ref.watch(ideasProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ide'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari ide',
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
                    decoration: const InputDecoration(hintText: 'Cari ide...'),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah ide',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const IdeaFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ideasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorState(onRetry: () => ref.invalidate(ideasProvider(_query))),
          data: (ideas) => ideas.isEmpty
              ? EmptyState(
                  icon: Icons.lightbulb_outline,
                  title: _query.isEmpty ? 'Belum ada ide' : 'Tidak ditemukan',
                  message: _query.isEmpty
                      ? 'Ketuk tombol + untuk menulis, atau ketik di '
                            'percakapan seperti "ide: aplikasi inventory kapal".'
                      : 'Tidak ada ide yang cocok dengan "$_query".',
                )
              : _IdeaSections(ideas: ideas),
        ),
      ),
    );
  }
}

class _IdeaSections extends StatelessWidget {
  const _IdeaSections({required this.ideas});

  final List<Idea> ideas;

  @override
  Widget build(BuildContext context) {
    final grouped = <IdeaStatus, List<Idea>>{
      for (final status in IdeaStatus.values) status: [],
    };
    for (final idea in ideas) {
      grouped[idea.status]!.add(idea);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        for (final status in IdeaStatus.values)
          if (grouped[status]!.isNotEmpty) ...[
            _SectionLabel(status.label.toUpperCase()),
            ...grouped[status]!.map((idea) => _IdeaTile(idea: idea)),
          ],
      ],
    );
  }
}

class _IdeaTile extends ConsumerWidget {
  const _IdeaTile({required this.idea});

  final Idea idea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(ideaControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(
            idea.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (idea.content != null && idea.content!.isNotEmpty) ...[
                Text(
                  idea.content!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              TagChips(tags: idea.tags),
            ],
          ),
          trailing: PopupMenuButton<IdeaStatus>(
            tooltip: 'Ubah status',
            icon: const Icon(Icons.more_vert),
            onSelected: (status) async {
              try {
                await controller.setStatus(idea, status);
              } on Object {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal menyimpan. Coba lagi.'),
                    ),
                  );
                }
              }
            },
            itemBuilder: (dialogContext) => [
              for (final status in IdeaStatus.values)
                if (status != idea.status)
                  PopupMenuItem<IdeaStatus>(
                    value: status,
                    child: Text('Pindah ke ${status.label}'),
                  ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => IdeaFormScreen(idea: idea)),
          ),
        ),
      ),
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
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
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
          const Text('Ide gagal dimuat'),
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

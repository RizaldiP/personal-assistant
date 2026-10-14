import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/task.dart';
import '../providers/task_controller.dart';
import '../widgets/task_tile.dart';
import 'todo_form_screen.dart';

/// Layar daftar tugas: grup belum selesai (di atas) dan selesai.
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
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
    final tasksAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Tutup pencarian' : 'Cari tugas',
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
                    decoration: const InputDecoration(hintText: 'Cari tugas...'),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah tugas',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ErrorState(
            title: 'Tugas gagal dimuat',
            onRetry: () => ref.invalidate(todoListProvider),
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const EmptyState(
                icon: Icons.checklist,
                title: 'Belum ada tugas',
                message:
                    'Ketuk tombol + untuk menambah tugas, atau ketik '
                    'di percakapan seperti "besok selesaikan laporan".',
              );
            }
            final filtered = _filterTasks(tasks, _query);
            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'Tidak ditemukan',
                message: 'Tidak ada tugas yang cocok dengan "$_query".',
              );
            }
            return _TaskList(tasks: filtered);
          },
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const TodoFormScreen()));
  }
}

List<Task> _filterTasks(List<Task> tasks, String query) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return tasks;
  return tasks
      .where(
        (task) =>
            task.title.toLowerCase().contains(keyword) ||
            (task.description?.toLowerCase().contains(keyword) ?? false),
      )
      .toList();
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    final today = _isoDate(now);
    final pending = tasks.where((t) => t.status == TaskStatus.pending).toList();
    final done = tasks.where((t) => t.status == TaskStatus.done).toList();

    void showError() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    }

    Future<void> toggle(Task task, bool value) async {
      try {
        await ref
            .read(todoControllerProvider.notifier)
            .setCompleted(task, value);
      } on Object {
        showError();
      }
    }

    Future<void> delete(Task task) async {
      final confirmed = await _confirmDelete(context, task);
      if (confirmed != true || !context.mounted) return;
      try {
        await ref.read(todoControllerProvider.notifier).delete(task.id!);
      } on Object {
        showError();
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        _SectionLabel('BELUM SELESAI'),
        if (pending.isEmpty)
          _InlineEmpty('Tidak ada tugas yang belum selesai.')
        else
          ...pending.map(
            (task) => TaskTile(
              task: task,
              overdue:
                  task.dueDate != null && task.dueDate!.compareTo(today) < 0,
              onToggle: (value) => toggle(task, value),
              onDelete: () => delete(task),
              onTap: () => _openForm(context, ref, task),
            ),
          ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionLabel('SELESAI'),
          ...done.map(
            (task) => TaskTile(
              task: task,
              onToggle: (value) => toggle(task, value),
              onDelete: () => delete(task),
              onTap: () => _openForm(context, ref, task),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, [Task? task]) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => TodoFormScreen(task: task)));
  }

  Future<bool?> _confirmDelete(BuildContext context, Task task) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('"${task.title}" tidak bisa dikembalikan.'),
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

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

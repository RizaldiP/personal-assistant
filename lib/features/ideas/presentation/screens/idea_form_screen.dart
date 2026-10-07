import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/formatters/tag_formats.dart';
import '../../domain/entities/idea.dart';
import '../providers/idea_controller.dart';

/// Form buat/edit ide: judul wajib, isi, status, tag.
class IdeaFormScreen extends ConsumerStatefulWidget {
  const IdeaFormScreen({super.key, this.idea});

  /// Ide yang diedit; null = ide baru.
  final Idea? idea;

  @override
  ConsumerState<IdeaFormScreen> createState() => _IdeaFormScreenState();
}

class _IdeaFormScreenState extends ConsumerState<IdeaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  late IdeaStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final idea = widget.idea;
    _title = TextEditingController(text: idea?.title ?? '');
    _content = TextEditingController(text: idea?.content ?? '');
    _tags = TextEditingController(
      text: TagFormats.join(idea?.tags ?? const []),
    );
    _status = idea?.status ?? IdeaStatus.inbox;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.idea != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit ide' : 'Ide baru'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Hapus ide',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Judul ide'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _content,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Detail (opsional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<IdeaStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final status in IdeaStatus.values)
                    DropdownMenuItem<IdeaStatus>(
                      value: status,
                      child: Text(status.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tag (pisahkan koma)',
                  hintText: 'Misal: proyek, kapal',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final controller = ref.read(ideaControllerProvider.notifier);
    final title = _title.text.trim();
    final content = _content.text.trim();
    final tags = TagFormats.split(_tags.text);

    try {
      final existing = widget.idea;
      if (existing == null) {
        await controller.create(
          title: title,
          content: content.isEmpty ? null : content,
          status: _status,
          tags: tags,
        );
      } else {
        // Bangun ulang entitas agar isi bisa dikosongkan (copyWith null
        // mempertahankan nilai lama).
        await controller.update(
          Idea(
            id: existing.id,
            title: title,
            content: content.isEmpty ? null : content,
            status: _status,
            source: existing.source,
            rawInput: existing.rawInput,
            confidence: existing.confidence,
            tags: tags,
            createdAt: existing.createdAt,
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus ide?'),
        content: const Text('Ide ini tidak bisa dikembalikan.'),
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

    if (confirmed != true || !mounted) return;

    final deleted = await ref
        .read(ideaControllerProvider.notifier)
        .delete(widget.idea!.id!);
    if (!mounted) return;

    if (deleted) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus. Coba lagi.')),
      );
    }
  }
}

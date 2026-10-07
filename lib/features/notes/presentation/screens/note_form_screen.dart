import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/formatters/tag_formats.dart';
import '../../domain/entities/note.dart';
import '../providers/note_controller.dart';

/// Form buat/edit catatan: judul opsional, isi wajib, tag opsional.
class NoteFormScreen extends ConsumerStatefulWidget {
  const NoteFormScreen({super.key, this.note});

  /// Catatan yang diedit; null = catatan baru.
  final Note? note;

  @override
  ConsumerState<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends ConsumerState<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _title = TextEditingController(text: note?.title ?? '');
    _content = TextEditingController(text: note?.content ?? '');
    _tags = TextEditingController(
      text: TagFormats.join(note?.tags ?? const []),
    );
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
    final editing = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit catatan' : 'Catatan baru'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Hapus catatan',
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
                decoration: const InputDecoration(
                  labelText: 'Judul (opsional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _content,
                textCapitalization: TextCapitalization.sentences,
                minLines: 4,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Isi catatan'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Isi wajib diisi'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tag (pisahkan koma)',
                  hintText: 'Misal: rumah, penting',
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

    final controller = ref.read(noteControllerProvider.notifier);
    final title = _title.text.trim();
    final content = _content.text.trim();
    final tags = TagFormats.split(_tags.text);

    try {
      final existing = widget.note;
      if (existing == null) {
        await controller.create(
          content: content,
          title: title.isEmpty ? null : title,
          tags: tags,
        );
      } else {
        // Bangun ulang entitas agar judul bisa dikosongkan (copyWith null
        // mempertahankan nilai lama).
        await controller.update(
          Note(
            id: existing.id,
            title: title.isEmpty ? null : title,
            content: content,
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
        title: const Text('Hapus catatan?'),
        content: const Text('Catatan ini tidak bisa dikembalikan.'),
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
        .read(noteControllerProvider.notifier)
        .delete(widget.note!.id!);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../../../shared/formatters/tag_formats.dart';
import '../../domain/entities/journal_entry.dart';
import '../providers/journal_controller.dart';

/// Mood yang tersedia di form; hasil NLP lain tetap disimpan apa adanya.
const List<String> kJournalMoods = [
  'senang',
  'netral',
  'capek',
  'sedih',
  'stres',
];

/// Form buat/edit entri jurnal: isi wajib, mood, tanggal, tag.
class JournalFormScreen extends ConsumerStatefulWidget {
  const JournalFormScreen({super.key, this.entry});

  /// Entri yang diedit; null = entri baru.
  final JournalEntry? entry;

  @override
  ConsumerState<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends ConsumerState<JournalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _content;
  late final TextEditingController _tags;
  String? _mood;
  String? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _content = TextEditingController(text: entry?.content ?? '');
    _tags = TextEditingController(
      text: TagFormats.join(entry?.tags ?? const []),
    );
    _mood = entry?.mood;
    _date = entry?.date;
  }

  @override
  void dispose() {
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    final moodValue = _mood != null && !kJournalMoods.contains(_mood)
        ? null
        : _mood;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit jurnal' : 'Jurnal baru'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Hapus entri',
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
                controller: _content,
                textCapitalization: TextCapitalization.sentences,
                minLines: 4,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Ceritakan hari ini',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Cerita wajib diisi'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: moodValue,
                decoration: const InputDecoration(labelText: 'Mood'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tanpa mood'),
                  ),
                  for (final mood in kJournalMoods)
                    DropdownMenuItem<String?>(value: mood, child: Text(mood)),
                ],
                onChanged: (value) => setState(() => _mood = value),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _date == null
                        ? 'Hari ini'
                        : DateFormats.longIndonesia(_date),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tag (pisahkan koma)',
                  hintText: 'Misal: kerja, kesehatan',
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date == null ? now : DateTime.parse(_date!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final controller = ref.read(journalControllerProvider.notifier);
    final content = _content.text.trim();
    final tags = TagFormats.split(_tags.text);

    try {
      final existing = widget.entry;
      if (existing == null) {
        await controller.create(
          content: content,
          mood: _mood,
          date: _date,
          tags: tags,
        );
      } else {
        // Bangun ulang entitas agar mood/judul bisa dikosongkan (copyWith
        // null mempertahankan nilai lama).
        await controller.update(
          JournalEntry(
            id: existing.id,
            date: _date ?? existing.date,
            title: existing.title,
            content: content,
            mood: _mood,
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
        title: const Text('Hapus entri jurnal?'),
        content: const Text('Entri ini tidak bisa dikembalikan.'),
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
        .read(journalControllerProvider.notifier)
        .delete(widget.entry!.id!);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../domain/entities/task.dart';
import '../providers/task_controller.dart';
import '../task_display.dart';

/// Form membuat / mengubah tugas.
class TodoFormScreen extends ConsumerStatefulWidget {
  const TodoFormScreen({super.key, this.task});

  /// Bila diisi, form berada dalam mode edit.
  final Task? task;

  @override
  ConsumerState<TodoFormScreen> createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends ConsumerState<TodoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late TaskPriority _priority;
  String? _dueDate;
  String? _dueTime;
  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _priority = task?.priority ?? TaskPriority.normal;
    _dueDate = task?.dueDate;
    _dueTime = task?.dueTime;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_dueDate ?? '') ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = _isoDate(picked);
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial =
        _parseTime(_dueTime) ?? TimeOfDay(hour: now.hour, minute: now.minute);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      _dueTime = '${_pad(picked.hour)}:${_pad(picked.minute)}';
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final task = Task(
      id: widget.task?.id,
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      dueDate: _dueDate,
      dueTime: _dueTime,
      priority: _priority,
      status: widget.task?.status ?? TaskStatus.pending,
      completedAt: widget.task?.completedAt,
      source: widget.task?.source,
      rawInput: widget.task?.rawInput,
      confidence: widget.task?.confidence,
    );

    try {
      final notifier = ref.read(todoControllerProvider.notifier);
      if (_isEdit) {
        await notifier.update(task);
      } else {
        await notifier.create(task);
      }
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit tugas' : 'Tugas baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                controller: _title,
                autofocus: !_isEdit,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  hintText: 'Contoh: Selesaikan laporan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _dueDate == null
                            ? 'Pilih tanggal'
                            : DateFormats.longIndonesia(_dueDate),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_dueTime ?? 'Pilih jam'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Prioritas',
                  border: OutlineInputBorder(),
                ),
                items: TaskPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(TaskDisplay.priorityLabel(priority)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isEdit ? 'Simpan perubahan' : 'Tambahkan tugas'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

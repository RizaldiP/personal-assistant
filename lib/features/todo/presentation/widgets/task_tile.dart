import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/task.dart';
import '../task_display.dart';

/// Satu baris tugas dalam daftar: checkbox selesai, judul, keterangan, hapus.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.overdue = false,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = task.status == TaskStatus.done;
    final subtitle = TaskDisplay.subtitle(task);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: done,
                  onChanged: (value) => onToggle(value ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: overdue
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus tugas',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

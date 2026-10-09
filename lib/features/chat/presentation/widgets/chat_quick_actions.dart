import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../notes/presentation/screens/notes_screen.dart';
import '../../../todo/presentation/screens/todo_screen.dart';

/// Pintasan cepat chat: buka daftar tugas, catatan, dan reminder.
///
/// Selalu tampil di atas kolom input. Navigasi memakai [MaterialPageRoute]
/// sesuai konvensi aplikasi (tidak ada named route).
class ChatQuickActions extends StatelessWidget {
  const ChatQuickActions({super.key});

  static const List<({IconData icon, String label, Widget screen})> _actions = [
    (
      icon: Icons.checklist_rounded,
      label: 'Daftar Tugas',
      screen: TodoScreen(),
    ),
    (
      icon: Icons.sticky_note_2_outlined,
      label: 'Daftar Catatan',
      screen: NotesScreen(),
    ),
    (
      icon: Icons.alarm_rounded,
      label: 'Daftar Reminder',
      screen: CalendarScreen(initialFilter: CalendarEventTypes.reminder),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (var i = 0; i < _actions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            ActionChip(
              avatar: Icon(_actions[i].icon, size: 18),
              label: Text(_actions[i].label),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => _actions[i].screen),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

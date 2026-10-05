import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Kalender kosong',
        message:
            'Tugas, reminder, dan jurnal yang punya tanggal akan muncul di sini.',
      ),
    );
  }
}

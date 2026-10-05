import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight')),
      body: const EmptyState(
        icon: Icons.insights_outlined,
        title: 'Belum ada data',
        message:
            'Ringkasan pengeluaran, tugas, dan kebiasaanmu akan muncul di sini.',
      ),
    );
  }
}

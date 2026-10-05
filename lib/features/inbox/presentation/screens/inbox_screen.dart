import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Inbox kosong',
        message:
            'Input yang belum pasti maksudnya akan muncul di sini agar kamu bisa menentukannya sendiri.',
      ),
    );
  }
}

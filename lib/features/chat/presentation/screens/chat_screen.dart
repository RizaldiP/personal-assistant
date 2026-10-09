import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_messages_provider.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_quick_actions.dart';
import '../widgets/confirmation_bar.dart';
import '../widgets/message_bubble.dart';

/// Layar percakapan: riwayat pesan tersimpan + input kirim.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Percakapan')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.when(
                loading: () => const _LoadingState(),
                error: (error, stackTrace) => ErrorState(
                  title: 'Riwayat gagal dimuat',
                  message: 'Terjadi kesalahan pada penyimpanan lokal.',
                  onRetry: () => ref.invalidate(chatMessagesProvider),
                ),
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Belum ada percakapan',
                        message:
                            'Ketik apa saja di bawah. Pesan disimpan di '
                            'perangkatmu, tanpa internet.',
                      )
                    : _MessageList(messages: items),
              ),
            ),
            const ConfirmationBar(),
            const ChatQuickActions(),
            const ChatInput(),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return MessageBubble(message: message);
      },
    );
  }
}

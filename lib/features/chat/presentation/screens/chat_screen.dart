import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_messages_provider.dart';
import '../widgets/chat_input.dart';
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
                error: (error, stackTrace) => _ErrorState(
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: scheme.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Riwayat gagal dimuat',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Terjadi kesalahan pada penyimpanan lokal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
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

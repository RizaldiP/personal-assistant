import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';

/// Gelembung pesan: user di kanan, assistant di kiri.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == ChatRole.user;
    final createdAt = message.createdAt;
    final time = createdAt == null
        ? null
        : DateFormat('HH:mm').format(createdAt.toLocal());

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppSpacing.radiusMd),
              topRight: const Radius.circular(AppSpacing.radiusMd),
              bottomLeft: Radius.circular(
                isUser ? AppSpacing.radiusMd : AppSpacing.xs,
              ),
              bottomRight: Radius.circular(
                isUser ? AppSpacing.xs : AppSpacing.radiusMd,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isUser ? scheme.onPrimary : scheme.onSurface,
                  height: 1.35,
                ),
              ),
              if (time != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isUser ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

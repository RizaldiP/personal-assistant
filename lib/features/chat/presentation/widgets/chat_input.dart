import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../providers/chat_controller.dart';
import '../providers/pending_confirmation.dart';

/// Input pesan di bagian bawah layar chat.
class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_hasText) return;
    final text = _controller.text;
    try {
      await ref.read(chatControllerProvider.notifier).send(text);
      if (!mounted) return;
      ref.read(chatDraftProvider.notifier).clear();
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Pesan gagal disimpan. Coba lagi.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSending = ref.watch(chatControllerProvider).isLoading;

    // Draf dari kartu konfirmasi (`Ubah`) mengisi kolom teks.
    ref.listen(chatDraftProvider, (previous, next) {
      if (next == null || next.isEmpty) return;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      ref.read(chatDraftProvider.notifier).clear();
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Ketik di sini...'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            tooltip: 'Kirim',
            onPressed: _hasText ? _send : null,
            icon: isSending
                ? SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/intents/intent_processor.dart';
import '../../../../shared/intents/ai_intent_result.dart';
import '../../../../shared/intents/app_intent.dart';
import '../../../inbox/data/repositories/inbox_repository_impl.dart';
import '../../../inbox/domain/entities/inbox_item.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import 'intent_executor.dart';
import 'pending_confirmation.dart';

/// Aksi chat: menyimpan pesan user lalu memprosesnya lewat [IntentProcessor].
///
/// Alur routing (docs/05 bagian 6-7, PHASE 11):
/// 1. Rule Parser dikenal → eksekusi langsung ke repository (jalur `rule`).
/// 2. Rule Parser tidak dikenal → Local AI (bila model dimuat) → validator.
/// 3. AI cukup yakin → pesan ditandai `needs_confirmation` dan kartu
///    konfirmasi muncul; tidak ada data tersimpan sebelum user memilih.
/// 4. AI tidak yakin / ditolak / tidak tersedia → balasan penjelasan,
///    tanpa menyimpan data, tanpa crash — dan masuk Smart Inbox (PHASE 13).
///
/// Riwayat pesan tidak dipegang di sini; sumber kebenaran tetap
/// [chatMessagesProvider] yang membaca database.
class ChatController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Menyimpan [rawText] sebagai pesan user dan memproses intentnya.
  ///
  /// Melempar error bila penyimpanan gagal; state ikut menjadi [AsyncError].
  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isLoading) return;

    state = const AsyncLoading();
    try {
      final repository = ref.read(chatRepositoryProvider);
      final processed = await ref.read(intentProcessorProvider).process(text);

      // Konfirmasi lama tidak lagi relevan begitu pesan baru masuk.
      await ref.read(pendingConfirmationProvider.notifier).abandon();

      final needsConfirmation =
          processed.disposition == IntentDisposition.confirm;
      final userMessage = ChatMessage(
        role: ChatRole.user,
        content: text,
        intent: processed.result.intent.storageValue,
        payload: jsonEncode(processed.result.toJson()),
        status: needsConfirmation
            ? ChatStatus.needsConfirmation
            : ChatStatus.sent,
      );
      final userMessageId = await repository.save(userMessage);
      await _captureUnresolved(processed, text, userMessageId);

      final reply = await _reply(processed, text);
      await repository.save(
        ChatMessage(role: ChatRole.assistant, content: reply),
      );
      if (processed.disposition == IntentDisposition.execute) {
        await _resolveInbox(text, processed.result.intent);
      }

      if (needsConfirmation) {
        ref
            .read(pendingConfirmationProvider.notifier)
            .set(
              PendingConfirmation(
                userMessageId: userMessageId,
                rawText: text,
                result: processed.result,
                source: processed.source,
                highConfidence: processed.highConfidence,
              ),
            );
      }
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  /// Balasan asisten untuk satu hasil routing.
  Future<String> _reply(ProcessedIntent processed, String rawText) async {
    return switch (processed.disposition) {
      IntentDisposition.execute =>
        ref
            .read(intentExecutorProvider)
            .execute(
              processed.result,
              rawText: rawText,
              source: processed.source,
            ),
      _ => Future.value(processed.message ?? 'Aku belum bisa memprosesnya.'),
    };
  }

  /// Menaruh input yang belum berhasil dipahami ke Smart Inbox (PHASE 13);
  /// kegagalan menulis inbox tidak menggagalkan chat.
  Future<void> _captureUnresolved(
    ProcessedIntent processed,
    String text,
    int userMessageId,
  ) async {
    const unresolved = {
      IntentDisposition.uncertain,
      IntentDisposition.unavailable,
      IntentDisposition.rejected,
    };
    if (!unresolved.contains(processed.disposition)) return;
    try {
      await ref
          .read(inboxRepositoryProvider)
          .addOpen(
            chatMessageId: userMessageId,
            rawText: text,
            suggestion: _suggestion(processed.result),
          );
    } on Object {
      // Gagal menulis inbox tidak menggagalkan pesan user.
    }
  }

  static String? _suggestion(AiIntentResult result) =>
      result.isKnown && result.intent != AppIntent.unknown
      ? result.intent.storageValue
      : null;

  /// Saat teks yang sama akhirnya berhasil dieksekusi lewat chat, item
  /// inbox terkait otomatis ditandai selesai (auto-resolve, PHASE 13).
  Future<void> _resolveInbox(String text, AppIntent intent) async {
    final entityType = inboxEntityType(intent);
    if (entityType == null) return;
    try {
      await ref
          .read(inboxRepositoryProvider)
          .resolveByText(text, entityType: entityType);
    } on Object {
      // Gagal menandai inbox tidak menggagalkan chat.
    }
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, AsyncValue<void>>(ChatController.new);

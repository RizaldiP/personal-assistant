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
import 'pending_time_prompt.dart';

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
      // Bila asisten sedang menanyakan jam (awalan tugas:/reminder:), pesan
      // berikutnya diperlakukan sebagai jawaban jam.
      if (ref.read(pendingTimePromptProvider) != null) {
        await ref.read(pendingTimePromptProvider.notifier).answer(text);
        state = const AsyncData(null);
        return;
      }

      final repository = ref.read(chatRepositoryProvider);
      final processed = await ref.read(intentProcessorProvider).process(text);

      // Konfirmasi lama tidak lagi relevan begitu pesan baru masuk.
      await ref.read(pendingConfirmationProvider.notifier).abandon();

      final needsConfirmation =
          processed.disposition == IntentDisposition.confirm;
      // Awalan tugas:/reminder: tanpa jam → tanyakan jam dulu (PHASE: fitur).
      final needsTime =
          processed.disposition == IntentDisposition.execute &&
          processed.result.entities['needs_time'] == true;
      final userMessage = ChatMessage(
        role: ChatRole.user,
        content: text,
        intent: processed.result.intent.storageValue,
        payload: jsonEncode(processed.result.toJson()),
        status: needsConfirmation || needsTime
            ? ChatStatus.needsConfirmation
            : ChatStatus.sent,
      );
      final userMessageId = await repository.save(userMessage);
      await _captureUnresolved(processed, text, userMessageId);

      final reply = needsTime
          ? _timePrompt(processed)
          : await _reply(processed, text);
      await repository.save(
        ChatMessage(role: ChatRole.assistant, content: reply),
      );
      if (processed.disposition == IntentDisposition.execute && !needsTime) {
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
      if (needsTime) {
        ref
            .read(pendingTimePromptProvider.notifier)
            .set(
              PendingTimePrompt(
                userMessageId: userMessageId,
                rawText: text,
                result: processed.result,
                source: processed.source,
              ),
            );
      }
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  /// Pertanyaan jam untuk todo/reminder tanpa jam (awalan tugas:/reminder:).
  String _timePrompt(ProcessedIntent processed) {
    final title = (processed.result.entities['title'] as String?)?.trim() ?? '';
    final label = title.isEmpty ? 'ini' : '"$title"';
    return 'Jam berapa untuk $label? Balas dengan jam (mis. "jam 9" atau '
        '"10:30"), atau ketik "tidak" untuk memakai jam 08.00.';
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

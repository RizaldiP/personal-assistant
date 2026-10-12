import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/intents/ai_intent_result.dart';
import '../../../../shared/intents/app_intent.dart';
import '../../../../shared/nlp/time_parser.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import 'intent_executor.dart';

/// Jam default saat user tidak menyebut jam untuk awalan `tugas:`/`reminder:`.
const String defaultPromptTime = '08:00';

/// Pertanyaan "mau jam berapa?" yang sedang menunggu jawaban user.
///
/// Dibuat oleh `ChatController` saat user memakai awalan `tugas:`/`reminder:`
/// tanpa menyebut jam; disimpan di memori dan tidak menulis entitas apa pun
/// sebelum user menjawab.
class PendingTimePrompt {
  const PendingTimePrompt({
    required this.userMessageId,
    required this.rawText,
    required this.result,
    required this.source,
    this.busy = false,
  });

  /// Id pesan user yang menunggu keputusan (untuk penandaan status).
  final int userMessageId;

  /// Kalimat user apa adanya.
  final String rawText;

  /// Hasil parser yang menunggu jam.
  final AiIntentResult result;

  /// Asal intent (`rule`).
  final String source;

  /// Sedang diproses (menunggu jawaban) — pesan berikutnya diabaikan bila true.
  final bool busy;

  PendingTimePrompt copyWith({bool? busy}) => PendingTimePrompt(
    userMessageId: userMessageId,
    rawText: rawText,
    result: result,
    source: source,
    busy: busy ?? this.busy,
  );
}

final pendingTimePromptProvider =
    NotifierProvider<PendingTimePromptController, PendingTimePrompt?>(
      PendingTimePromptController.new,
    );

/// Mengelola siklus pertanyaan jam: set → answer / abandon.
class PendingTimePromptController extends Notifier<PendingTimePrompt?> {
  @override
  PendingTimePrompt? build() => null;

  /// Menampilkan pertanyaan jam (dipanggil ChatController).
  void set(PendingTimePrompt value) => state = value;

  /// Menyelesaikan pertanyaan lama tanpa aksi saat user mengirim pesan baru
  /// yang bukan jawaban (mis. disubstitusi).
  Future<void> abandon() async {
    final pending = state;
    if (pending == null) return;
    state = null;
    await _resolveUserMessage(pending);
  }

  /// Menjawab pertanyaan jam: ambil jam dari [text], lengkapi intent yang
  /// tertunda, lalu eksekusi ke repository.
  Future<void> answer(String text) async {
    final pending = state;
    if (pending == null || pending.busy) return;
    state = pending.copyWith(busy: true);
    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.save(
        ChatMessage(role: ChatRole.user, content: text),
      );

      final timeKey = pending.result.intent == AppIntent.createTodo
          ? 'due_time'
          : 'time';
      final entities = <String, dynamic>{
        ...pending.result.entities,
        timeKey: resolveTime(text),
      }..remove('needs_time');
      final result = AiIntentResult(
        intent: pending.result.intent,
        confidence: pending.result.confidence,
        entities: entities,
      );

      final reply = await ref
          .read(intentExecutorProvider)
          .execute(result, rawText: pending.rawText, source: pending.source);
      await repository.save(
        ChatMessage(role: ChatRole.assistant, content: reply),
      );
      await _resolveUserMessage(pending);
      state = null;
    } catch (_) {
      state = pending.copyWith(busy: false);
      rethrow;
    }
  }

  Future<void> _resolveUserMessage(PendingTimePrompt pending) async {
    final repository = ref.read(chatRepositoryProvider);
    final message = await repository.getById(pending.userMessageId);
    if (message == null) return;
    await repository.update(
      message.copyWith(
        status: ChatStatus.sent,
        resolvedAt: ref.read(clockProvider).now(),
      ),
    );
  }
}

/// Jam dari jawaban user: ekspresi waktu ("jam 9", "jam 8 malam"), angka polos
/// 0–23, atau [defaultPromptTime] bila tidak ada jam.
String resolveTime(String text) {
  final parsed = TimeParser().parse(text);
  final hourMinute = parsed?.hourMinute;
  if (hourMinute != null && hourMinute.isNotEmpty) return hourMinute;

  final bare = int.tryParse(text.trim());
  if (bare != null && bare >= 0 && bare <= 23) {
    return '${bare.toString().padLeft(2, '0')}:00';
  }
  return defaultPromptTime;
}

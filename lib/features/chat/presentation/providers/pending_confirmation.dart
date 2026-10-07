import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/intents/intent_description.dart';
import '../../../../shared/intents/ai_intent_result.dart';
import '../../../inbox/data/repositories/inbox_repository_impl.dart';
import '../../../inbox/domain/entities/inbox_item.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import 'intent_executor.dart';

/// Konfirmasi intent AI yang sedang menunggu keputusan user.
///
/// Dibuat oleh [ChatController] saat hasil AI cukup yakin tetapi tidak
/// boleh auto-save (docs/05 bagian 6); disimpan di memori — pesan user
/// terkait sudah ditandai `needs_confirmation` di riwayat.
class PendingConfirmation {
  const PendingConfirmation({
    required this.userMessageId,
    required this.rawText,
    required this.result,
    required this.source,
    required this.highConfidence,
    this.busy = false,
  });

  /// Id pesan user yang menunggu keputusan (untuk penandaan status).
  final int userMessageId;

  /// Kalimat user apa adanya (dipakai ulang saat `Ubah`).
  final String rawText;

  /// Hasil AI yang menunggu konfirmasi.
  final AiIntentResult result;

  /// Asal intent (`ai`).
  final String source;

  /// true bila confidence ≥ ambang accept → tombol `Simpan`/`Batal`.
  final bool highConfidence;

  /// Sedang diproses (simpan/batal/ubah) — tombol nonaktif saat true.
  final bool busy;

  /// Ringkasan intent untuk kartu konfirmasi.
  String get summary => describeIntent(result);

  PendingConfirmation copyWith({bool? busy}) => PendingConfirmation(
    userMessageId: userMessageId,
    rawText: rawText,
    result: result,
    source: source,
    highConfidence: highConfidence,
    busy: busy ?? this.busy,
  );
}

final pendingConfirmationProvider =
    NotifierProvider<PendingConfirmationController, PendingConfirmation?>(
      PendingConfirmationController.new,
    );

/// Mengelola siklus konfirmasi: set → confirm/reject/edit/abandon.
///
/// Konfirmasi mengeksekusi intent ke repository (source `ai`), membalas
/// chat, dan menandai pesan user sebagai selesai; pembatalan hanya
/// menandai selesai tanpa menyimpan data apa pun.
class PendingConfirmationController extends Notifier<PendingConfirmation?> {
  @override
  PendingConfirmation? build() => null;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  /// Menampilkan kartu konfirmasi (dipanggil ChatController).
  void set(PendingConfirmation value) => state = value;

  /// Menyelesaikan konfirmasi lama tanpa aksi saat user mengirim pesan baru.
  Future<void> abandon() async {
    final pending = state;
    if (pending == null) return;
    state = null;
    await _resolveUserMessage(_repository, pending);
  }

  /// Menyimpan intent ke repository.
  Future<void> confirm() async {
    final pending = state;
    if (pending == null || pending.busy) return;
    state = pending.copyWith(busy: true);
    try {
      final reply = await ref
          .read(intentExecutorProvider)
          .execute(
            pending.result,
            rawText: pending.rawText,
            source: pending.source,
          );
      await _repository.save(
        ChatMessage(role: ChatRole.assistant, content: reply),
      );
      await _resolveUserMessage(_repository, pending);
      await _resolveInbox(pending);
      state = null;
    } catch (_) {
      state = pending.copyWith(busy: false);
      rethrow;
    }
  }

  /// Membatalkan: tidak ada data yang disimpan.
  Future<void> reject() async {
    final pending = state;
    if (pending == null || pending.busy) return;
    state = pending.copyWith(busy: true);
    try {
      await _resolveUserMessage(_repository, pending);
      await _repository.save(
        const ChatMessage(
          role: ChatRole.assistant,
          content: 'Oke, tidak jadi disimpan.',
        ),
      );
      state = null;
    } catch (_) {
      state = pending.copyWith(busy: false);
      rethrow;
    }
  }

  /// Mengembalikan kalimat user ke input untuk diperbaiki.
  Future<void> edit() async {
    final pending = state;
    if (pending == null || pending.busy) return;
    state = pending.copyWith(busy: true);
    try {
      await _resolveUserMessage(_repository, pending);
      ref.read(chatDraftProvider.notifier).set(pending.rawText);
      state = null;
    } catch (_) {
      state = pending.copyWith(busy: false);
      rethrow;
    }
  }

  Future<void> _resolveUserMessage(
    ChatRepository repository,
    PendingConfirmation pending,
  ) async {
    final message = await repository.getById(pending.userMessageId);
    if (message == null) return;
    await repository.update(
      message.copyWith(
        status: ChatStatus.sent,
        resolvedAt: ref.read(clockProvider).now(),
      ),
    );
  }

  /// Menandai item inbox terbuka yang teksnya sama sebagai selesai bila
  /// intent menghasilkan entitas (auto-resolve, PHASE 13).
  Future<void> _resolveInbox(PendingConfirmation pending) async {
    final entityType = inboxEntityType(pending.result.intent);
    if (entityType == null) return;
    try {
      await ref
          .read(inboxRepositoryProvider)
          .resolveByText(pending.rawText, entityType: entityType);
    } on Object {
      // Gagal menandai inbox tidak menggagalkan konfirmasi.
    }
  }
}

/// Draf pesan yang akan tampil di input chat (hasil tombol `Ubah`).
final chatDraftProvider = NotifierProvider<ChatDraftController, String?>(
  ChatDraftController.new,
);

class ChatDraftController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String text) => state = text;

  void clear() => state = null;
}

import '../../../../shared/intents/app_intent.dart';

/// Status penyelesaian item inbox (docs/04 bagian 3).
enum InboxResolution {
  open('open'),
  converted('converted'),
  discarded('discarded');

  const InboxResolution(this.storageValue);

  final String storageValue;

  static InboxResolution parse(String? value) =>
      InboxResolution.values.firstWhere(
        (resolution) => resolution.storageValue == value,
        orElse: () => InboxResolution.open,
      );
}

/// Item Smart Inbox: input chat yang belum berhasil dipahami aplikasi.
class InboxItem {
  const InboxItem({
    this.id,
    this.chatMessageId,
    required this.rawText,
    this.suggestion,
    this.resolution = InboxResolution.open,
    this.resolvedEntityType,
    this.resolvedEntityId,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Pesan chat asal item; null bila item dibuat manual.
  final int? chatMessageId;

  /// Teks input user apa adanya.
  final String rawText;

  /// Intent saran (`create_reminder`, ...) bila AI sempat menebak.
  final String? suggestion;

  final InboxResolution resolution;

  /// Tipe entitas hasil konversi (`note`, `todo`, ...) bila [resolution]
  /// adalah [InboxResolution.converted].
  final String? resolvedEntityType;

  final int? resolvedEntityId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  InboxItem copyWith({
    int? id,
    int? chatMessageId,
    String? rawText,
    String? suggestion,
    InboxResolution? resolution,
    String? resolvedEntityType,
    int? resolvedEntityId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InboxItem(
      id: id ?? this.id,
      chatMessageId: chatMessageId ?? this.chatMessageId,
      rawText: rawText ?? this.rawText,
      suggestion: suggestion ?? this.suggestion,
      resolution: resolution ?? this.resolution,
      resolvedEntityType: resolvedEntityType ?? this.resolvedEntityType,
      resolvedEntityId: resolvedEntityId ?? this.resolvedEntityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Tipe entitas hasil eksekusi [intent] pembuatan — dipakai untuk menandai
/// item inbox yang teksnya berhasil diproses lewat chat (auto-resolve).
String? inboxEntityType(AppIntent intent) => switch (intent) {
  AppIntent.createTodo => 'todo',
  AppIntent.createReminder => 'reminder',
  AppIntent.createNote => 'note',
  AppIntent.createJournal => 'journal',
  AppIntent.createIdea => 'idea',
  AppIntent.createExpense => 'expense',
  AppIntent.createShopping => 'shopping',
  _ => null,
};

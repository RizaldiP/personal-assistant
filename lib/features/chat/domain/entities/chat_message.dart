enum ChatRole {
  user,
  assistant;

  static ChatRole parse(String? value) =>
      value == 'assistant' ? ChatRole.assistant : ChatRole.user;

  String get storageValue => name;
}

enum ChatStatus {
  sent,
  processing,
  failed,
  needsConfirmation;

  static ChatStatus parse(String? value) => switch (value) {
    'processing' => ChatStatus.processing,
    'failed' => ChatStatus.failed,
    'needs_confirmation' => ChatStatus.needsConfirmation,
    _ => ChatStatus.sent,
  };

  String get storageValue => switch (this) {
    ChatStatus.sent => 'sent',
    ChatStatus.processing => 'processing',
    ChatStatus.failed => 'failed',
    ChatStatus.needsConfirmation => 'needs_confirmation',
  };
}

/// Entitas pesan chat milik domain.
///
/// Pesan disimpan apa adanya; hasil ekstraksi (`intent`, `payload`) disimpan
/// terpisah sehingga riwayat tidak pernah tertimpa.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.intent,
    this.payload,
    this.status = ChatStatus.sent,
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final ChatRole role;
  final String content;
  final String? intent;
  final String? payload;
  final ChatStatus status;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatMessage copyWith({
    int? id,
    ChatRole? role,
    String? content,
    String? intent,
    String? payload,
    ChatStatus? status,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      intent: intent ?? this.intent,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

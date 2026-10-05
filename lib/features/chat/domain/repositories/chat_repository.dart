import '../entities/chat_message.dart';

/// Kontrak akses data chat. Implementasi ada di lapisan data.
abstract interface class ChatRepository {
  Stream<List<ChatMessage>> watchMessages();

  Future<ChatMessage?> getById(int id);

  Future<ChatMessage?> getLatest();

  Future<List<ChatMessage>> getAll();

  /// Menyimpan pesan; mengembalikan id baris.
  Future<int> save(ChatMessage message);

  Future<bool> update(ChatMessage message);

  Future<bool> delete(int id);
}

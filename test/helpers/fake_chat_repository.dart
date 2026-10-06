import 'dart:async';

import 'package:personal_offline/features/chat/domain/entities/chat_message.dart';
import 'package:personal_offline/features/chat/domain/repositories/chat_repository.dart';

/// Fake [ChatRepository] untuk test controller dan layar chat.
///
/// Riwayat disimpan dalam memori dan setiap perubahan memancarkan daftar
/// terbaru agar UI yang menonton stream ikut terbarui.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({this.failSave = false});

  /// Bila true, [save] melempar error seperti database rusak.
  bool failSave;

  final List<ChatMessage> saved = [];
  final StreamController<List<ChatMessage>> _changes =
      StreamController<List<ChatMessage>>.broadcast();

  @override
  Stream<List<ChatMessage>> watchMessages() async* {
    yield List.of(saved);
    yield* _changes.stream;
  }

  @override
  Future<ChatMessage?> getById(int id) async {
    for (final message in saved) {
      if (message.id == id) return message;
    }
    return null;
  }

  @override
  Future<ChatMessage?> getLatest() async => saved.isEmpty ? null : saved.last;

  @override
  Future<List<ChatMessage>> getAll() async => List.of(saved);

  @override
  Future<int> save(ChatMessage message) async {
    if (failSave) {
      throw StateError('database rusak');
    }
    final id = saved.length + 1;
    saved.add(message.copyWith(id: id));
    _changes.add(List.of(saved));
    return id;
  }

  @override
  Future<bool> update(ChatMessage message) async {
    final index = saved.indexWhere((m) => m.id == message.id);
    if (index == -1) return false;
    saved[index] = message;
    _changes.add(List.of(saved));
    return true;
  }

  @override
  Future<bool> delete(int id) async {
    final length = saved.length;
    saved.removeWhere((m) => m.id == id);
    _changes.add(List.of(saved));
    return saved.length != length;
  }
}

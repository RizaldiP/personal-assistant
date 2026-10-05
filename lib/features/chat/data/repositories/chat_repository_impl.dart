import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/chat_message_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._dao, this._clock);

  final ChatMessageDao _dao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<ChatMessage>> watchMessages() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<ChatMessage?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<ChatMessage?> getLatest() async {
    final row = await _dao.getLatest();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<ChatMessage>> getAll() async =>
      (await _dao.getAll()).map(_toDomain).toList();

  @override
  Future<int> save(ChatMessage message) async {
    final now = _now;
    if (message.id != null) {
      await _dao.updateMessage(message.id!, _companion(message, now));
      return message.id!;
    }
    return _dao.insertMessage(_companion(message, now));
  }

  @override
  Future<bool> update(ChatMessage message) async {
    final id = message.id;
    if (id == null) return false;
    return _dao.updateMessage(id, _companion(message, _now));
  }

  @override
  Future<bool> delete(int id) => _dao.deleteMessage(id);

  static ChatMessage _toDomain(db.ChatMessage row) => ChatMessage(
    id: row.id,
    role: ChatRole.parse(row.role),
    content: row.content,
    intent: row.intent,
    payload: row.payload,
    status: ChatStatus.parse(row.status),
    resolvedAt: _fromEpoch(row.resolvedAt),
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static db.ChatMessagesCompanion _companion(ChatMessage message, int now) {
    final createdAt = _toEpoch(message.createdAt);
    return db.ChatMessagesCompanion(
      role: Value(message.role.storageValue),
      content: Value(message.content),
      intent: Value(message.intent),
      payload: Value(message.payload),
      status: Value(message.status.storageValue),
      resolvedAt: Value(_toEpoch(message.resolvedAt)),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static int? _toEpoch(DateTime? value) =>
      value?.toUtc().millisecondsSinceEpoch;

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ChatRepositoryImpl(database.chatMessageDao, ref.watch(clockProvider));
});

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_dao.dart';

// ignore_for_file: type=lint
mixin _$ChatMessageDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChatMessagesTable get chatMessages => attachedDatabase.chatMessages;
  ChatMessageDaoManager get managers => ChatMessageDaoManager(this);
}

class ChatMessageDaoManager {
  final _$ChatMessageDaoMixin _db;
  ChatMessageDaoManager(this._db);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db.attachedDatabase, _db.chatMessages);
}

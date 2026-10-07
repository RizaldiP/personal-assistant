// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_item_dao.dart';

// ignore_for_file: type=lint
mixin _$InboxItemDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChatMessagesTable get chatMessages => attachedDatabase.chatMessages;
  $InboxItemsTable get inboxItems => attachedDatabase.inboxItems;
  InboxItemDaoManager get managers => InboxItemDaoManager(this);
}

class InboxItemDaoManager {
  final _$InboxItemDaoMixin _db;
  InboxItemDaoManager(this._db);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db.attachedDatabase, _db.chatMessages);
  $$InboxItemsTableTableManager get inboxItems =>
      $$InboxItemsTableTableManager(_db.attachedDatabase, _db.inboxItems);
}

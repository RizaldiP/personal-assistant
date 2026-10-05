import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/chat_message_table.dart';

part 'chat_message_dao.g.dart';

@DriftAccessor(tables: [ChatMessages])
class ChatMessageDao extends DatabaseAccessor<AppDatabase>
    with _$ChatMessageDaoMixin {
  ChatMessageDao(super.db);

  Stream<List<ChatMessage>> watchAll() =>
      (select(chatMessages)..orderBy([
            (c) => OrderingTerm.asc(c.createdAt),
            (c) => OrderingTerm.asc(c.id),
          ]))
          .watch();

  Future<ChatMessage?> getById(int id) =>
      (select(chatMessages)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<ChatMessage?> getLatest() async {
    final rows =
        await (select(chatMessages)
              ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<ChatMessage>> getAll() => select(chatMessages).get();

  Future<int> insertMessage(ChatMessagesCompanion entry) =>
      into(chatMessages).insert(entry);

  Future<bool> updateMessage(int id, ChatMessagesCompanion entry) async {
    final updated = await (update(
      chatMessages,
    )..where((c) => c.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteMessage(int id) async {
    final deleted = await (delete(
      chatMessages,
    )..where((c) => c.id.equals(id))).go();
    return deleted > 0;
  }
}

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/inbox_item_table.dart';

part 'inbox_item_dao.g.dart';

@DriftAccessor(tables: [InboxItems])
class InboxItemDao extends DatabaseAccessor<AppDatabase>
    with _$InboxItemDaoMixin {
  InboxItemDao(super.db);

  /// Item urut terbaru; difilter [resolution] bila diisi.
  Stream<List<InboxItem>> watchAll({String? resolution}) {
    final statement = select(inboxItems)
      ..orderBy([
        (i) => OrderingTerm.desc(i.createdAt),
        (i) => OrderingTerm.desc(i.id),
      ]);
    if (resolution != null) {
      statement.where((i) => i.resolution.equals(resolution));
    }
    return statement.watch();
  }

  Future<InboxItem?> getById(int id) =>
      (select(inboxItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<List<InboxItem>> getOpen() =>
      (select(inboxItems)
            ..where((i) => i.resolution.equals('open'))
            ..orderBy([
              (i) => OrderingTerm.desc(i.createdAt),
              (i) => OrderingTerm.desc(i.id),
            ]))
          .get();

  Future<int> insertItem(InboxItemsCompanion entry) =>
      into(inboxItems).insert(entry);

  Future<bool> updateItem(int id, InboxItemsCompanion entry) async {
    final updated = await (update(
      inboxItems,
    )..where((i) => i.id.equals(id))).write(entry);
    return updated > 0;
  }

  Future<bool> deleteItem(int id) async {
    final deleted = await (delete(
      inboxItems,
    )..where((i) => i.id.equals(id))).go();
    return deleted > 0;
  }
}

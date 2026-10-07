import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/daos/inbox_item_dao.dart';
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';

import '../../domain/entities/inbox_item.dart';
import '../../domain/repositories/inbox_repository.dart';

/// Implementasi [InboxRepository] berbasis drift (PHASE 13).
class InboxRepositoryImpl implements InboxRepository {
  InboxRepositoryImpl(this._dao, this._clock);

  final InboxItemDao _dao;
  final Clock _clock;

  int get _now => _clock.now().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<InboxItem>> watchItems({InboxResolution? resolution}) => _dao
      .watchAll(resolution: resolution?.storageValue)
      .map((rows) => rows.map(_toItem).toList());

  @override
  Future<InboxItem?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toItem(row);
  }

  @override
  Future<int> addOpen({
    int? chatMessageId,
    required String rawText,
    String? suggestion,
  }) {
    return _dao.insertItem(
      db.InboxItemsCompanion.insert(
        chatMessageId: Value(chatMessageId),
        rawText: rawText,
        suggestion: Value(suggestion),
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<bool> markConverted(int id, {String? entityType, int? entityId}) {
    return _dao.updateItem(
      id,
      db.InboxItemsCompanion(
        resolution: Value(InboxResolution.converted.storageValue),
        resolvedEntityType: Value(entityType),
        resolvedEntityId: Value(entityId),
        updatedAt: Value(_now),
      ),
    );
  }

  @override
  Future<bool> markDiscarded(int id) {
    return _dao.updateItem(
      id,
      db.InboxItemsCompanion(
        resolution: Value(InboxResolution.discarded.storageValue),
        updatedAt: Value(_now),
      ),
    );
  }

  @override
  Future<void> resolveByText(String rawText, {String? entityType}) async {
    final target = _normalize(rawText);
    if (target.isEmpty) return;
    final open = await _dao.getOpen();
    for (final item in open) {
      if (_normalize(item.rawText) != target) continue;
      await _dao.updateItem(
        item.id,
        db.InboxItemsCompanion(
          resolution: Value(InboxResolution.converted.storageValue),
          resolvedEntityType: Value(entityType),
          updatedAt: Value(_now),
        ),
      );
    }
  }

  static InboxItem _toItem(db.InboxItem row) => InboxItem(
    id: row.id,
    chatMessageId: row.chatMessageId,
    rawText: row.rawText,
    suggestion: row.suggestion,
    resolution: InboxResolution.parse(row.resolution),
    resolvedEntityType: row.resolvedEntityType,
    resolvedEntityId: row.resolvedEntityId,
    createdAt: _fromEpoch(row.createdAt),
    updatedAt: _fromEpoch(row.updatedAt),
  );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);

  /// Normalisasi untuk pencocokan teks: trim, spasi rapat, lowercase.
  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return InboxRepositoryImpl(database.inboxItemDao, ref.watch(clockProvider));
});

import 'package:drift/drift.dart';

import 'chat_message_table.dart';

/// Item Smart Inbox (PHASE 13): input chat yang belum berhasil dipahami
/// (confidence rendah / unknown / AI tidak tersedia) sehingga user bisa
/// menentukan nasibnya sendiri (docs/04 bagian 3).
@TableIndex(name: 'idx_inbox_items_resolution', columns: {#resolution})
class InboxItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Pesan chat asal; nullable agar item manual tetap memungkinkan.
  IntColumn get chatMessageId => integer().nullable().references(
    ChatMessages,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Teks input user apa adanya.
  TextColumn get rawText => text()();

  /// Intent saran (`create_reminder`, ...) bila AI sempat menebak; null
  /// bila AI tidak tersedia/unknown.
  TextColumn get suggestion => text().nullable()();

  /// `open` / `converted` / `discarded`.
  TextColumn get resolution => text().withDefault(const Constant('open'))();

  TextColumn get resolvedEntityType => text().nullable()();

  IntColumn get resolvedEntityId => integer().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

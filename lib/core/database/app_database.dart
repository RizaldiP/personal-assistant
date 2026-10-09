import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/chat_message_dao.dart';
import 'daos/expense_dao.dart';
import 'daos/idea_dao.dart';
import 'daos/inbox_item_dao.dart';
import 'daos/journal_dao.dart';
import 'daos/note_dao.dart';
import 'daos/reminder_dao.dart';
import 'daos/shopping_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/task_dao.dart';
import 'daos/user_preferences_dao.dart';
import 'tables/chat_message_table.dart';
import 'tables/expense_table.dart';
import 'tables/idea_table.dart';
import 'tables/inbox_item_table.dart';
import 'tables/journal_table.dart';
import 'tables/notes_table.dart';
import 'tables/reminder_table.dart';
import 'tables/shopping_table.dart';
import 'tables/tag_table.dart';
import 'tables/task_table.dart';
import 'tables/user_preference_table.dart';

part 'app_database.g.dart';

/// Database utama aplikasi (SQLite via drift).
///
/// Skema:
/// - versi 1: baseline empat tabel inti (dibuat pada awal PHASE 2)
/// - versi 2: menambah kolom jejak NLP + indeks query
/// - versi 3: menambah tabel daftar belanja (PHASE 7)
/// - versi 4: menambah tabel pengeluaran (PHASE 8)
/// - versi 5: menambah tabel catatan, jurnal, ide, dan tag (PHASE 9)
/// - versi 6: menambah tabel inbox_items — Smart Inbox (PHASE 13)
///
/// File database disimpan di application support directory perangkat.
@DriftDatabase(
  tables: [
    Tasks,
    Reminders,
    ChatMessages,
    UserPreferences,
    ShoppingLists,
    ShoppingItems,
    Expenses,
    Notes,
    JournalEntries,
    Ideas,
    Tags,
    TagLinks,
    InboxItems,
  ],
  daos: [
    TaskDao,
    ReminderDao,
    ChatMessageDao,
    UserPreferencesDao,
    ShoppingDao,
    ExpenseDao,
    NoteDao,
    JournalDao,
    IdeaDao,
    TagDao,
    InboxItemDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _upgradeToV2(m);
      }
      if (from < 3) {
        await _upgradeToV3(m);
      }
      if (from < 4) {
        await _upgradeToV4(m);
      }
      if (from < 5) {
        await _upgradeToV5(m);
      }
      if (from < 6) {
        await _upgradeToV6(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v1 -> v2: kolom jejak NLP pada Task/Reminder/ChatMessage + indeks.
  Future<void> _upgradeToV2(Migrator m) async {
    await m.addColumn(tasks, tasks.source);
    await m.addColumn(tasks, tasks.rawInput);
    await m.addColumn(tasks, tasks.confidence);

    await m.addColumn(reminders, reminders.source);
    await m.addColumn(reminders, reminders.rawInput);
    await m.addColumn(reminders, reminders.confidence);

    await m.addColumn(chatMessages, chatMessages.intent);
    await m.addColumn(chatMessages, chatMessages.payload);
    await m.addColumn(chatMessages, chatMessages.status);
    await m.addColumn(chatMessages, chatMessages.resolvedAt);

    await _createIndexes(this);
  }

  /// v2 -> v3: tabel daftar belanja (SHOPPING LIST, PHASE 7).
  Future<void> _upgradeToV3(Migrator m) async {
    await m.createTable(shoppingLists);
    await m.createTable(shoppingItems);
    // createTable tidak membuat indeks dari @TableIndex; buat manual.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shopping_items_list_id '
      'ON shopping_items (list_id)',
    );
  }

  /// v3 -> v4: tabel pengeluaran (EXPENSE, PHASE 8).
  Future<void> _upgradeToV4(Migrator m) async {
    await m.createTable(expenses);
    // createTable tidak membuat indeks dari @TableIndex; buat manual.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category '
      'ON expenses (category)',
    );
  }

  /// v4 -> v5: tabel catatan, jurnal, ide, dan tag (NOTE/JOURNAL/IDEA,
  /// PHASE 9).
  Future<void> _upgradeToV5(Migrator m) async {
    await m.createTable(notes);
    await m.createTable(journalEntries);
    await m.createTable(ideas);
    await m.createTable(tags);
    await m.createTable(tagLinks);
    // createTable tidak membuat indeks dari @TableIndex; buat manual.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes (created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_date '
      'ON journal_entries (date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas (status)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_name ON tags (name)',
    );
  }

  /// v5 -> v6: tabel inbox_items — Smart Inbox (PHASE 13).
  Future<void> _upgradeToV6(Migrator m) async {
    await m.createTable(inboxItems);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inbox_items_resolution '
      'ON inbox_items (resolution)',
    );
  }

  static Future<void> _createIndexes(DatabaseConnectionUser db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks (due_date)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status)',
      'CREATE INDEX IF NOT EXISTS idx_reminders_next_fire ON reminders (next_fire_at)',
      'CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders (status)',
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages (created_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_preferences_key ON user_preferences (key)',
    ];
    for (final statement in statements) {
      await db.customStatement(statement);
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'personal_offline',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
        // Isolate background widget (home_widget) membuka database yang sama
        // untuk menandai tugas selesai, jadi koneksi harus dibagi antar isolate.
        shareAcrossIsolates: true,
      ),
    );
  }
}

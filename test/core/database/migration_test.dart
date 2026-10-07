import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// DDL skema versi 1: empat tabel inti tanpa kolom jejak NLP dan tanpa indeks.
const List<String> v1Statements = [
  '''
  CREATE TABLE "tasks" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "description" TEXT NULL,
    "due_date" TEXT NULL,
    "due_time" TEXT NULL,
    "priority" TEXT NOT NULL DEFAULT 'normal',
    "category" TEXT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "completed_at" INTEGER NULL,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE "reminders" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "notes" TEXT NULL,
    "date" TEXT NOT NULL,
    "time" TEXT NOT NULL,
    "scheduled_at" INTEGER NOT NULL,
    "priority" TEXT NOT NULL DEFAULT 'normal',
    "status" TEXT NOT NULL DEFAULT 'active',
    "is_recurring" INTEGER NOT NULL DEFAULT 0,
    "recurrence_rule" TEXT NOT NULL DEFAULT 'none',
    "recurrence_anchor" TEXT NULL,
    "next_fire_at" INTEGER NULL,
    "snoozed_until" INTEGER NULL,
    "last_fired_at" INTEGER NULL,
    "completed_at" INTEGER NULL,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE "chat_messages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "role" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE "user_preferences" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
];

void main() {
  late Directory tempDir;
  late String path;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('personal_offline_migration');
    path = '${tempDir.path}${Platform.pathSeparator}personal_offline.db';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'v1 -> v6: data utuh, kolom NLP & tabel belanja/pengeluaran/catatan/jurnal/ide/tag/inbox ditambahkan',
    () async {
      final raw = sqlite.sqlite3.open(path);
      try {
        for (final statement in v1Statements) {
          raw.execute(statement);
        }
        raw.execute('PRAGMA user_version = 1');
        raw.execute(
          "INSERT INTO tasks (title, due_date, status, created_at, updated_at) VALUES ('Tugas lama', '2026-01-01', 'pending', 111, 222)",
        );
        raw.execute(
          "INSERT INTO reminders (title, date, time, scheduled_at, created_at, updated_at) VALUES ('Minum obat', '2026-01-01', '08:00', 555, 111, 222)",
        );
        raw.execute(
          "INSERT INTO chat_messages (role, content, created_at, updated_at) VALUES ('user', 'halo', 111, 222)",
        );
        raw.execute(
          "INSERT INTO user_preferences (key, value, created_at, updated_at) VALUES ('locale', 'id', 111, 222)",
        );
      } finally {
        raw.close();
      }

      final db = AppDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], 6, reason: 'user_version naik ke 6');

      final task = await db.taskDao.getById(1);
      expect(task!.title, 'Tugas lama');
      expect(task.dueDate, '2026-01-01');
      expect(task.createdAt, 111);
      expect(task.updatedAt, 222);
      expect(task.source, isNull, reason: 'kolom baru masih kosong');

      final reminder = await db.reminderDao.getById(1);
      expect(reminder!.title, 'Minum obat');
      expect(reminder.isRecurring, isFalse);
      expect(reminder.recurrenceRule, 'none');
      expect(reminder.source, isNull);

      final chat = await db.chatMessageDao.getById(1);
      expect(chat!.content, 'halo');
      expect(chat.status, 'sent', reason: 'default kolom baru diterapkan');

      final prefs = await db.userPreferencesDao.get('locale');
      expect(prefs, 'id');

      final shoppingTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
            "('shopping_lists', 'shopping_items', 'expenses')",
          )
          .get();
      expect(
        shoppingTables,
        hasLength(3),
        reason: 'tabel belanja & pengeluaran dibuat',
      );

      final listColumns = await db
          .customSelect('PRAGMA table_info(shopping_lists)')
          .get();
      expect(
        listColumns.map((r) => r.data['name'] as String),
        containsAll(['id', 'title', 'status', 'date']),
      );

      final itemColumns = await db
          .customSelect('PRAGMA table_info(shopping_items)')
          .get();
      expect(
        itemColumns.map((r) => r.data['name'] as String),
        containsAll(['list_id', 'name', 'is_checked', 'sort_order']),
      );

      final expenseColumns = await db
          .customSelect('PRAGMA table_info(expenses)')
          .get();
      expect(
        expenseColumns.map((r) => r.data['name'] as String),
        containsAll([
          'id',
          'amount',
          'currency',
          'category',
          'description',
          'date',
          'payment_method',
        ]),
      );
      final fk = await db
          .customSelect(
            'SELECT COUNT(*) AS total FROM pragma_foreign_key_list('
            "'shopping_items') WHERE \"table\" = 'shopping_lists'",
          )
          .getSingle();
      expect(fk.data['total'], greaterThan(0), reason: 'FK cascade ke daftar');

      final taskColumns = await db
          .customSelect('SELECT * FROM tasks')
          .getSingle();
      expect(
        taskColumns.data.keys,
        containsAll(['source', 'raw_input', 'confidence']),
      );

      final reminderColumns = await db
          .customSelect('SELECT * FROM reminders')
          .getSingle();
      expect(
        reminderColumns.data.keys,
        containsAll(['source', 'raw_input', 'confidence']),
      );

      final chatColumns = await db
          .customSelect('SELECT * FROM chat_messages')
          .getSingle();
      expect(
        chatColumns.data.keys,
        containsAll(['intent', 'payload', 'status', 'resolved_at']),
      );

      final indexRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name IS NOT NULL",
          )
          .get();
      final indexNames = indexRows
          .map((row) => row.data['name'])
          .toSet()
          .cast<String>();
      expect(
        indexNames,
        containsAll(<String>[
          'idx_tasks_due_date',
          'idx_tasks_status',
          'idx_reminders_next_fire',
          'idx_reminders_status',
          'idx_chat_messages_created_at',
          'idx_user_preferences_key',
          'idx_shopping_items_list_id',
          'idx_expenses_date',
          'idx_expenses_category',
        ]),
      );

      final newExpenseId = await db.expenseDao.insert(
        ExpensesCompanion.insert(
          amount: 25000,
          category: const Value('makanan'),
          description: 'Ayam',
          date: '2026-10-06',
          createdAt: 444,
          updatedAt: 444,
        ),
      );
      final total = await db.expenseDao.totalBetween(
        '2026-10-01',
        '2026-10-31',
      );
      expect(newExpenseId, isPositive);
      expect(total, 25000, reason: 'pengeluaran dapat diisi setelah migrasi');

      final newTaskId = await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Tugas baru',
          source: const Value('chat'),
          rawInput: const Value('buat tugas baru'),
          confidence: const Value(0.93),
          createdAt: 333,
          updatedAt: 333,
        ),
      );
      final newTask = await db.taskDao.getById(newTaskId);
      expect(newTask!.source, 'chat');
      expect(newTask.rawInput, 'buat tugas baru');
      expect(newTask.confidence, closeTo(0.93, 0.0001));

      final phase9Tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
            "('notes', 'journal_entries', 'ideas', 'tags', 'tag_links')",
          )
          .get();
      expect(
        phase9Tables,
        hasLength(5),
        reason: 'tabel catatan/jurnal/ide/tag dibuat di v5',
      );

      final noteColumns = await db
          .customSelect('PRAGMA table_info(notes)')
          .get();
      expect(
        noteColumns.map((r) => r.data['name'] as String),
        containsAll([
          'id',
          'title',
          'content',
          'source',
          'raw_input',
          'confidence',
          'created_at',
          'updated_at',
        ]),
      );

      final journalColumns = await db
          .customSelect('PRAGMA table_info(journal_entries)')
          .get();
      expect(
        journalColumns.map((r) => r.data['name'] as String),
        containsAll(['id', 'date', 'content', 'mood', 'source']),
      );

      final ideaColumns = await db
          .customSelect('PRAGMA table_info(ideas)')
          .get();
      expect(
        ideaColumns.map((r) => r.data['name'] as String),
        containsAll(['id', 'title', 'content', 'status', 'source']),
      );
      final ideaStatus = await db
          .customSelect('SELECT status FROM ideas')
          .get();
      expect(ideaStatus, isEmpty);

      final linkFk = await db
          .customSelect(
            'SELECT COUNT(*) AS total FROM pragma_foreign_key_list('
            "'tag_links') WHERE \"table\" = 'tags'",
          )
          .getSingle();
      expect(
        linkFk.data['total'],
        greaterThan(0),
        reason: 'tag_links cascade ke tags',
      );

      final phase9Indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name IS NOT NULL",
          )
          .get();
      final phase9IndexNames = phase9Indexes
          .map((row) => row.data['name'])
          .toSet()
          .cast<String>();
      expect(
        phase9IndexNames,
        containsAll(<String>[
          'idx_notes_created_at',
          'idx_journal_entries_date',
          'idx_ideas_status',
          'idx_tags_name',
        ]),
      );

      final newNoteId = await db.noteDao.insert(
        NotesCompanion.insert(
          content: 'Catatan pasca migrasi',
          source: const Value('rule'),
          createdAt: 555,
          updatedAt: 555,
        ),
      );
      expect(await db.noteDao.getById(newNoteId), isNotNull);

      final tagId = await db.tagDao.insertTag(
        TagsCompanion.insert(name: 'kapal', createdAt: 555, updatedAt: 555),
      );
      await db.tagDao.link(tagId, 'note', newNoteId, now: 555);
      final linked = await db.tagDao.tagsForEntity('note', newNoteId);
      expect(linked.single.name, 'kapal', reason: 'tabel tag dapat diisi');

      final inboxTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = "
            "'inbox_items'",
          )
          .get();
      expect(inboxTables, hasLength(1), reason: 'tabel inbox dibuat di v6');

      final inboxColumns = await db
          .customSelect('PRAGMA table_info(inbox_items)')
          .get();
      expect(
        inboxColumns.map((r) => r.data['name'] as String),
        containsAll([
          'id',
          'chat_message_id',
          'raw_text',
          'suggestion',
          'resolution',
          'resolved_entity_type',
          'resolved_entity_id',
          'created_at',
          'updated_at',
        ]),
      );

      final inboxIndexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = "
            "'idx_inbox_items_resolution'",
          )
          .get();
      expect(inboxIndexes, hasLength(1), reason: 'indeks resolution dibuat');

      final chatId = await db.chatMessageDao.insertMessage(
        ChatMessagesCompanion.insert(
          role: 'user',
          content: 'tadi makan ayam',
          createdAt: 666,
          updatedAt: 666,
        ),
      );
      final inboxId = await db.inboxItemDao.insertItem(
        InboxItemsCompanion.insert(
          chatMessageId: Value(chatId),
          rawText: 'tadi makan ayam',
          suggestion: const Value('create_expense'),
          createdAt: 666,
          updatedAt: 666,
        ),
      );
      final inboxItem = await db.inboxItemDao.getById(inboxId);
      expect(inboxItem!.resolution, 'open', reason: 'default resolution');
      expect(inboxItem.suggestion, 'create_expense');
    },
  );

  test(
    'database baru dibuat langsung pada skema v6 lengkap dengan indeks',
    () async {
      final db = AppDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], 6);

      final newTaskId = await db.taskDao.insertTask(
        TasksCompanion.insert(
          title: 'Segar',
          source: const Value('manual'),
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      expect(await db.taskDao.getById(newTaskId), isNotNull);

      final indexRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name IS NOT NULL",
          )
          .get();
      final indexNames = indexRows
          .map((row) => row.data['name'])
          .toSet()
          .cast<String>();
      expect(indexNames, contains('idx_tasks_due_date'));
      expect(indexNames, contains('idx_shopping_items_list_id'));
      expect(indexNames, contains('idx_expenses_date'));
      expect(indexNames, contains('idx_expenses_category'));
      expect(indexNames, contains('idx_notes_created_at'));
      expect(indexNames, contains('idx_journal_entries_date'));
      expect(indexNames, contains('idx_ideas_status'));
      expect(indexNames, contains('idx_tags_name'));
      expect(indexNames, contains('idx_inbox_items_resolution'));
    },
  );
}

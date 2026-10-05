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

  test('v1 -> v2: data utuh, kolom jejak NLP dan indeks ditambahkan', () async {
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
    expect(version.data['user_version'], 2, reason: 'user_version naik ke 2');

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
      ]),
    );

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
  });

  test(
    'database baru dibuat langsung pada skema v2 lengkap dengan indeks',
    () async {
      final db = AppDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], 2);

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
    },
  );
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense.dart';
import 'package:personal_offline/features/ideas/data/repositories/idea_repository_impl.dart';
import 'package:personal_offline/features/ideas/domain/entities/idea.dart';
import 'package:personal_offline/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:personal_offline/features/journal/domain/entities/journal_entry.dart';
import 'package:personal_offline/features/notes/data/repositories/note_repository_impl.dart';
import 'package:personal_offline/features/notes/domain/entities/note.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/reminder/domain/entities/reminder.dart';
import 'package:personal_offline/features/reminder/domain/reminder_schedule.dart';
import 'package:personal_offline/features/search/data/repositories/search_repository_impl.dart';
import 'package:personal_offline/features/search/domain/repositories/search_repository.dart';
import 'package:personal_offline/features/search/domain/search_result.dart';
import 'package:personal_offline/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:personal_offline/features/shopping/domain/entities/shopping_list.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';

void main() {
  late db.AppDatabase database;
  late SearchRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = SearchRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedAll() async {
    await TaskRepositoryImpl(
      database.taskDao,
      clock,
    ).create(const Task(title: 'Servis kapal', dueDate: '2026-10-06'));
    await ReminderRepositoryImpl(database.reminderDao, clock).create(
      Reminder(
        title: 'Cek kapal',
        date: '2026-10-06',
        time: '08:00',
        scheduledAt: reminderToEpochUtc(
          reminderLocalDateTime('2026-10-06', '08:00'),
        ),
      ),
    );
    await NoteRepositoryImpl(
      database.noteDao,
      database.tagDao,
      clock,
    ).create(const Note(content: 'Foto kapal di galangan'));
    await JournalRepositoryImpl(
      database.journalDao,
      database.tagDao,
      clock,
    ).create(const JournalEntry(date: '2026-10-05', content: 'Naik kapal'));
    await IdeaRepositoryImpl(
      database.ideaDao,
      database.tagDao,
      clock,
    ).create(const Idea(title: 'Ide kapal layar'));
    await ShoppingRepositoryImpl(
      database.shoppingDao,
      clock,
    ).createList(const ShoppingList(title: 'Suku cadang kapal'));
    await ExpenseRepositoryImpl(
      database.expenseDao,
      database.userPreferencesDao,
      clock,
    ).create(
      const Expense(
        amount: 50000,
        description: 'Bensin kapal',
        date: '2026-10-05',
      ),
    );
  }

  test('search lintas tipe menemukan teks pada seluruh entitas', () async {
    await seedAll();

    final results = await repository.search(query: 'kapal');

    expect(results.map((r) => r.type).toSet(), {
      SearchTypes.todo,
      SearchTypes.reminder,
      SearchTypes.note,
      SearchTypes.journal,
      SearchTypes.idea,
      SearchTypes.shopping,
      SearchTypes.expense,
    });
    final types = results.map((r) => r.type).toList();
    final indexes = [for (final type in types) SearchTypes.all.indexOf(type)];
    final sorted = [...indexes]..sort();
    expect(indexes, sorted, reason: 'urut sesuai SearchTypes.all');
    expect(
      results.firstWhere((r) => r.type == SearchTypes.todo).title,
      'Servis kapal',
    );
    expect(
      results.firstWhere((r) => r.type == SearchTypes.reminder).subtitle,
      contains('jam 08:00'),
    );
    expect(
      results.firstWhere((r) => r.type == SearchTypes.expense).subtitle,
      contains('Rp'),
    );
  });

  test('type filter hanya mengembalikan tipe itu', () async {
    await seedAll();

    final results = await repository.search(
      query: 'kapal',
      type: SearchTypes.note,
    );

    expect(results, hasLength(1));
    expect(results.single.type, SearchTypes.note);
    expect(results.single.title, 'Foto kapal di galangan');
  });

  test('query kosong atau tidak dikenal mengembalikan kosong', () async {
    await seedAll();

    expect(await repository.search(query: ''), isEmpty);
    expect(await repository.search(query: '   '), isEmpty);
    expect(await repository.search(query: 'zzz-tidak-ada'), isEmpty);
    expect(await repository.search(query: 'kapal', type: 'alien'), isEmpty);
  });

  test('tag filter menelusuri entitas bertaut dengan batasan teks', () async {
    final notes = NoteRepositoryImpl(database.noteDao, database.tagDao, clock);
    await notes.create(const Note(content: 'Resep sup ayam', tags: ['dapur']));
    await notes.create(const Note(content: 'Catatan kapal', tags: ['kapal']));

    final byTag = await repository.search(query: '', tag: 'kapal');
    expect(byTag.single.title, 'Catatan kapal');

    final narrowed = await repository.search(query: 'catatan', tag: 'kapal');
    expect(narrowed.single.title, 'Catatan kapal');

    final mismatch = await repository.search(query: 'resep', tag: 'kapal');
    expect(mismatch, isEmpty);
  });

  test('query yang sama dengan nama tag menampilkan entitas bertaut', () async {
    await NoteRepositoryImpl(
      database.noteDao,
      database.tagDao,
      clock,
    ).create(const Note(content: 'Resep sup ayam', tags: ['dapur']));

    final results = await repository.search(query: 'dapur');

    expect(results.single.type, SearchTypes.note);
    expect(results.single.title, 'Resep sup ayam');
    expect(results.single.tags, ['dapur'], reason: 'tag ikut dilampirkan');
  });

  test('escape LIKE: % dan _ tidak menjadi wildcard', () async {
    final notes = NoteRepositoryImpl(database.noteDao, database.tagDao, clock);
    await notes.create(const Note(content: 'Promo diskon 50%'));
    await notes.create(const Note(content: 'Promo diskon 5000 rupiah'));

    final percent = await repository.search(query: '50%');
    expect(percent.single.title, 'Promo diskon 50%');

    await notes.create(const Note(content: 'Kode a_b spesial'));
    final underscore = await repository.search(query: 'a_b');
    expect(underscore.single.title, 'Kode a_b spesial');
    expect(await repository.search(query: 'axb'), isEmpty);
  });

  test('limitPerType membatasi jumlah hasil tiap tipe', () async {
    final notes = NoteRepositoryImpl(database.noteDao, database.tagDao, clock);
    for (var i = 0; i < 5; i++) {
      await notes.create(Note(content: 'huruf ke-$i'));
    }

    final capped = await repository.search(query: 'huruf', limitPerType: 2);
    expect(
      capped.where((r) => r.type == SearchTypes.note),
      hasLength(2),
      reason: 'dibatasi limitPerType',
    );

    final all = await repository.search(query: 'huruf');
    expect(all.where((r) => r.type == SearchTypes.note), hasLength(5));
  });

  test('search mengurutkan tipe lalu tanggal terbaru', () async {
    final notes = NoteRepositoryImpl(database.noteDao, database.tagDao, clock);
    await notes.create(const Note(content: 'Pantau progres lama'));
    await notes.create(const Note(content: 'Pantau progres baru'));

    final results = await repository.search(query: 'pantau');

    expect(results.map((r) => r.title), [
      'Pantau progres baru',
      'Pantau progres lama',
    ]);
  });

  test('watchTagNames memancarkan nama tag lowercase', () async {
    await NoteRepositoryImpl(
      database.noteDao,
      database.tagDao,
      clock,
    ).create(const Note(content: 'Suku cadang', tags: ['Kapal', 'Dapur']));

    final names = await repository.watchTagNames().first;

    expect(names, ['dapur', 'kapal']);
  });
}

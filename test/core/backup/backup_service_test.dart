import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/backup/backup_document.dart';
import 'package:personal_offline/core/backup/backup_service.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';

void main() {
  late db.AppDatabase database;
  late BackupService service;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);
  final epoch = start.millisecondsSinceEpoch;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    service = BackupService(database, clock);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedTasks({int count = 1}) async {
    for (var i = 0; i < count; i++) {
      await database.taskDao.insertTask(
        db.TasksCompanion.insert(
          title: 'Tugas $i',
          createdAt: epoch + i,
          updatedAt: epoch + i,
        ),
      );
    }
  }

  Future<void> seedShopping() async {
    final listId = await database.shoppingDao.insertList(
      db.ShoppingListsCompanion.insert(
        title: const Value('Belanja'),
        status: const Value('open'),
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
    await database.shoppingDao.insertItem(
      db.ShoppingItemsCompanion.insert(
        listId: listId,
        name: 'Telur',
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
  }

  group('BackupService.exportDocument', () {
    test('membaca seluruh tabel aplikasi beserta isi baris', () async {
      await seedTasks(count: 2);
      await seedShopping();

      final doc = await service.exportDocument();

      expect(
        doc.tables.keys,
        containsAll([
          'tasks',
          'shopping_lists',
          'shopping_items',
          'chat_messages',
          'user_preferences',
          'expenses',
          'notes',
          'journal_entries',
          'ideas',
          'tags',
          'tag_links',
          'inbox_items',
        ]),
      );
      expect(doc.tables['tasks'], hasLength(2));
      expect(doc.tables['tasks']!.first['title'], 'Tugas 0');
      expect(doc.tables['shopping_lists'], hasLength(1));
      expect(doc.tables['shopping_items']!.single['name'], 'Telur');
      expect(doc.schemaVersion, database.schemaVersion);
      expect(doc.totalRows, 4);
    });

    test('tidak menyertakan tabel internal sqlite/drift', () async {
      await seedTasks();

      final doc = await service.exportDocument();

      for (final name in doc.tables.keys) {
        expect(name, isNot(startsWith('sqlite_')));
        expect(name, isNot(startsWith('drift_')));
      }
    });
  });

  group('BackupService.validate', () {
    test('hasil ekspor tervalidasi sebagai berkas sah', () async {
      await seedTasks();
      final doc = await service.exportDocument();

      final result = await service.validate(doc.encode());

      expect(result.isValid, isTrue);
      expect(result.totalRows, doc.totalRows);
      expect(result.document!.tables['tasks'], hasLength(1));
    });

    test('isi bukan JSON → invalid', () async {
      final result = await service.validate('rusak');

      expect(result.isValid, isFalse);
    });
  });

  group('BackupService.restore', () {
    test('replace menghapus data lama lalu mengisi cadangan', () async {
      await seedTasks(count: 1);
      final doc = await service.exportDocument();

      await database.delete(database.tasks).go();
      await seedTasks(count: 2);
      expect(await database.taskDao.getAll(), hasLength(2));

      final result = await service.restore(doc, mode: RestoreMode.replace);

      expect(result.success, isTrue);
      expect(result.inserted, 1);
      final all = await database.taskDao.getAll();
      expect(all, hasLength(1));
      expect(all.single.title, 'Tugas 0');
    });

    test(
      'merge melewati baris yang primary key-nya sudah ada (conflict)',
      () async {
        await seedTasks(count: 1); // id 1, judul 'Tugas 0'
        final doc = await service.exportDocument();

        final task = (await database.taskDao.getAll()).single;
        await database.taskDao.updateTask(
          task.id,
          db.TasksCompanion(title: const Value('Diubah')),
        );

        final result = await service.restore(doc, mode: RestoreMode.merge);

        expect(result.success, isTrue);
        expect(result.skipped, 1);
        expect(result.inserted, 0);
        final all = await database.taskDao.getAll();
        expect(all.single.title, 'Diubah');
      },
    );

    test('replace gagal di tengah dibatalkan penuh, data lama utuh', () async {
      await seedTasks(count: 1);
      final doc = await service.exportDocument();
      final tampered = BackupDocument(
        version: BackupDocument.currentVersion,
        schemaVersion: database.schemaVersion,
        exportedAt: clock.now(),
        tables: {
          ...doc.tables,
          'tasks': [
            ...doc.tables['tasks']!,
            {'id': 1, 'title': 'Duplikat'},
          ],
        },
      );

      final result = await service.restore(tampered, mode: RestoreMode.replace);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      final all = await database.taskDao.getAll();
      expect(all, hasLength(1));
      expect(all.single.title, 'Tugas 0');
    });

    test('insert urut induk sebelum anak (foreign key tetap aman)', () async {
      await seedShopping();
      final doc = await service.exportDocument();

      await database.delete(database.shoppingItems).go();
      await database.delete(database.shoppingLists).go();

      final result = await service.restore(doc, mode: RestoreMode.replace);

      expect(result.success, isTrue);
      expect(await database.shoppingDao.getAllLists(), hasLength(1));
      expect((await database.shoppingDao.getAllItems()).single.name, 'Telur');
    });

    test(
      'baris dihapus ulang saat replace mengikuti urutan anak → induk',
      () async {
        await seedShopping();
        final doc = await service.exportDocument();

        final result = await service.restore(doc, mode: RestoreMode.replace);

        expect(result.success, isTrue);
        expect(await database.shoppingDao.getAllItems(), hasLength(1));
      },
    );

    test('tabel tak dikenal dalam dokumen diabaikan', () async {
      await seedTasks();
      final doc = await service.exportDocument();
      final withUnknown = BackupDocument(
        version: BackupDocument.currentVersion,
        schemaVersion: database.schemaVersion,
        exportedAt: clock.now(),
        tables: {
          ...doc.tables,
          'habits': [
            {'id': 1, 'name': 'Olahraga'},
          ],
        },
      );

      final result = await service.restore(
        withUnknown,
        mode: RestoreMode.replace,
      );

      expect(result.success, isTrue);
      expect(await database.taskDao.getAll(), hasLength(1));
    });

    test('restore menggiring stream drift memuat ulang', () async {
      await seedTasks(count: 1);
      final events = <List<db.Task>>[];
      final subscription = database.taskDao.watchAll().listen(events.add);
      await pumpEventQueue();
      events.clear();

      final doc = await service.exportDocument();
      await database.delete(database.tasks).go();
      final result = await service.restore(doc, mode: RestoreMode.replace);

      await pumpEventQueue();
      expect(result.success, isTrue);
      expect(events, isNotEmpty);
      expect(events.last, hasLength(1));
      expect(events.last.single.title, 'Tugas 0');
      await subscription.cancel();
    });

    test('cadangan versi skema lebih lama memunculkan peringatan', () async {
      await seedTasks();
      final doc = await service.exportDocument();
      final older = BackupDocument(
        version: BackupDocument.currentVersion,
        schemaVersion: database.schemaVersion - 2,
        exportedAt: clock.now(),
        tables: doc.tables,
      );

      final result = await service.restore(older, mode: RestoreMode.replace);

      expect(result.success, isTrue);
      expect(result.warnings.single, contains('versi'));
    });
  });
}

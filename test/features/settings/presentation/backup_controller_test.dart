import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/backup/backup_archive.dart';
import 'package:personal_offline/core/backup/backup_document.dart';
import 'package:personal_offline/core/backup/backup_service.dart';
import 'package:personal_offline/core/backup/backup_storage.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/finance/data/repositories/expense_repository_impl.dart';
import 'package:personal_offline/features/finance/domain/entities/expense.dart';
import 'package:personal_offline/features/finance/domain/entities/expense_category.dart';
import 'package:personal_offline/features/settings/presentation/providers/backup_controller.dart';

import '../../../helpers/fake_backup_storage.dart';

void main() {
  late db.AppDatabase database;
  late FixedClock clock;
  late FakeBackupStorage storage;
  late ProviderContainer container;
  late BackupController controller;

  final start = DateTime(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    storage = FakeBackupStorage();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
        backupStorageProvider.overrideWithValue(storage),
      ],
    );
    controller = container.read(backupControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<BackupDocument> exportDocument() async {
    final service = container.read(backupServiceProvider);
    return service.exportDocument();
  }

  Future<void> seedExpense(String date) async {
    await container
        .read(expenseRepositoryProvider)
        .create(
          Expense(
            amount: 25000,
            category: ExpenseCategory.makanan,
            description: 'Ayam',
            date: date,
          ),
        );
  }

  group('BackupController.exportBackup', () {
    test(
      'JSON tanpa lampiran menulis berkas json lalu membagikannya',
      () async {
        await seedExpense('2026-10-05');

        final path = await controller.exportBackup(BackupFormat.json);

        expect(path, isNotNull);
        expect(storage.sharedPaths, [path]);
        expect(
          storage.backupFiles.keys.single,
          'personal-offline-backup-2026-10-05.json',
        );
        final decoded = jsonDecode(
          utf8.decode(storage.backupFiles.values.single),
        );
        expect(decoded['format'], BackupDocument.formatName);
        expect(decoded['data']['expenses'], hasLength(1));
      },
    );

    test('lampiran memaksa berkas ZIP walau format JSON', () async {
      await seedExpense('2026-10-05');
      storage.attachments['foto.png'] = [1, 2, 3];

      final path = await controller.exportBackup(BackupFormat.json);

      expect(path, isNotNull);
      final name = storage.backupFiles.keys.single;
      expect(name, endsWith('.zip'));
      final content = BackupArchive.decode(storage.backupFiles.values.single);
      expect(content, isNotNull);
      expect(content!.attachments['foto.png'], [1, 2, 3]);
      expect(content.documentJson, contains('"expenses"'));
    });

    test('format ZIP tanpa lampiran tetap menghasilkan ZIP', () async {
      await seedExpense('2026-10-05');

      final path = await controller.exportBackup(BackupFormat.zip);

      expect(path, isNotNull);
      expect(storage.backupFiles.keys.single, endsWith('.zip'));
    });

    test('state sibuk menolak ekspor kedua tanpa menulis apa pun', () async {
      final gate = Completer<void>();
      storage.gate = gate;

      final first = controller.exportBackup(BackupFormat.json);
      await pumpEventQueue();
      expect(container.read(backupControllerProvider), isTrue);

      final second = await controller.exportBackup(BackupFormat.json);
      expect(second, isNull);
      expect(storage.backupFiles, isEmpty);

      gate.complete();
      expect(await first, isNotNull);
      expect(container.read(backupControllerProvider), isFalse);
    });

    test('kegagalan menyimpan mengembalikan null tanpa crash', () async {
      storage.writeError = StateError('disk penuh');

      final path = await controller.exportBackup(BackupFormat.json);

      expect(path, isNull);
      expect(container.read(backupControllerProvider), isFalse);
    });
  });

  group('BackupController.pickAndValidate', () {
    test('picker dibatalkan → status cancelled', () async {
      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.cancelled);
    });

    test('bukan JSON → status invalid', () async {
      storage.pickedFile = FakeBackupStorage.jsonFile(
        'rusak.json',
        'bukan json',
      );

      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.invalid);
      expect(result.error, contains('bukan JSON'));
    });

    test('format bukan cadangan → status invalid', () async {
      storage.pickedFile = FakeBackupStorage.jsonFile(
        'x.json',
        jsonEncode({'format': 'lain', 'version': 1}),
      );

      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.invalid);
      expect(result.error, contains('bukan cadangan'));
    });

    test('JSON hasil ekspor → status ready', () async {
      await seedExpense('2026-10-05');
      final doc = await exportDocument();
      storage.pickedFile = FakeBackupStorage.jsonFile('cad.json', doc.encode());

      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.ready);
      expect(result.document!.totalRows, 1);
      expect(result.attachments, isEmpty);
    });

    test('ZIP hasil ekspor → status ready dengan lampiran', () async {
      await seedExpense('2026-10-05');
      final doc = await exportDocument();
      final bytes = BackupArchive.encode(
        documentJson: doc.encode(),
        attachments: const {
          'foto.png': [7],
        },
      );
      storage.pickedFile = FakeBackupStorage.binaryFile('cad.zip', bytes);

      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.ready);
      expect(result.attachmentCount, 1);
      expect(result.attachments['foto.png'], [7]);
    });

    test('ZIP tanpa backup.json → status invalid', () async {
      storage.pickedFile = FakeBackupStorage.binaryFile('cad.zip', [1, 2, 3]);

      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.invalid);
      expect(result.error, contains('tidak berisi cadangan'));
    });

    test('berkas tidak dapat dibaca → status invalid', () async {
      storage.readError = StateError('izin ditolak');

      final result = await controller.pickAndValidate();

      expect(result.status, BackupPickStatus.invalid);
      expect(result.error, contains('tidak dapat dibaca'));
    });
  });

  group('BackupController.restore', () {
    test('menulis cadangan aman sebelum memulihkan', () async {
      await seedExpense('2026-10-05');
      final doc = await exportDocument();

      final result = await controller.restore(doc, RestoreMode.replace);

      expect(result.success, isTrue);
      final safety = storage.backupFiles.keys.where(
        (name) => name.contains('sebelum-pulihkan'),
      );
      expect(safety, isNotEmpty);
    });

    test('menyimpan lampiran dari berkas ZIP', () async {
      await seedExpense('2026-10-05');
      final doc = await exportDocument();

      final result = await controller.restore(
        doc,
        RestoreMode.replace,
        attachments: const {
          'foto.png': [1, 2],
        },
      );

      expect(result.success, isTrue);
      expect(storage.attachments['foto.png'], [1, 2]);
    });

    test(
      'replace gagal → success false dan state kembali tidak sibuk',
      () async {
        await seedExpense('2026-10-05');
        final doc = await exportDocument();
        final tampered = BackupDocument(
          version: BackupDocument.currentVersion,
          schemaVersion: database.schemaVersion,
          exportedAt: clock.now(),
          tables: {
            ...doc.tables,
            'expenses': [
              ...doc.tables['expenses']!,
              {
                'id': 1,
                'amount': 1,
                'category': 'x',
                'description': 'y',
                'date': 'x',
              },
            ],
          },
        );

        final result = await controller.restore(tampered, RestoreMode.replace);

        expect(result.success, isFalse);
        expect(result.error, contains('dibatalkan'));
        expect(container.read(backupControllerProvider), isFalse);
      },
    );
  });

  group('BackupController.exportMonthlyExpenseReport', () {
    test('menulis PDF bulan berjalan lalu membukanya', () async {
      await seedExpense('2026-10-05');

      final path = await controller.exportMonthlyExpenseReport();

      expect(path, isNotNull);
      expect(path, contains('laporan-pengeluaran'));
      expect(path, endsWith('.pdf'));
      expect(storage.openedPaths, [path]);
      final bytes = storage.backupFiles[storage.backupFiles.keys.single]!;
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('pengalaman gagal menyimpan mengembalikan null tanpa crash', () async {
      storage.writeError = StateError('gagal menulis');

      final path = await controller.exportMonthlyExpenseReport();

      expect(path, isNull);
      expect(container.read(backupControllerProvider), isFalse);
    });
  });
}

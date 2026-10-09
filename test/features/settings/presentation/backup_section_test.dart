import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/backup/backup_document.dart';
import 'package:personal_offline/core/backup/backup_service.dart';
import 'package:personal_offline/core/backup/backup_storage.dart';
import 'package:personal_offline/core/backup/backup_validator.dart';
import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/settings/presentation/widgets/backup_section.dart';

import '../../../helpers/fake_backup_service.dart';
import '../../../helpers/fake_backup_storage.dart';

void main() {
  late db.AppDatabase database;
  late FixedClock clock;
  late FakeBackupStorage storage;
  late FakeBackupService service;

  final start = DateTime(2026, 10, 5, 8, 30);

  BackupDocument document() => BackupDocument(
    version: BackupDocument.currentVersion,
    schemaVersion: 6,
    exportedAt: start,
    tables: {
      'tasks': [
        {
          'id': 1,
          'title': 'Bayar listrik',
          'priority': 'normal',
          'status': 'pending',
        },
      ],
    },
  );

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    storage = FakeBackupStorage();
    service = FakeBackupService(database, clock);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(clock),
          backupStorageProvider.overrideWithValue(storage),
          backupServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: Scaffold(body: BackupSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.widgetWithText(OutlinedButton, label);

  group('BackupSection', () {
    testWidgets('menampilkan deskripsi dan empat aksi', (tester) async {
      await pumpSection(tester);

      expect(find.text('Cadangan & Data'), findsOneWidget);
      expect(find.text('Ekspor JSON'), findsOneWidget);
      expect(find.text('Ekspor ZIP'), findsOneWidget);
      expect(find.text('Pulihkan'), findsOneWidget);
      expect(find.text('Laporan PDF (bulan ini)'), findsOneWidget);
    });

    testWidgets('Ekspor JSON memanggil layanan dan membagikan berkas', (
      tester,
    ) async {
      service.exportResult = document();
      await pumpSection(tester);

      await tester.tap(find.text('Ekspor JSON'));
      await tester.pumpAndSettle();

      expect(service.exportCalls, 1);
      expect(storage.sharedPaths, isNotEmpty);
      expect(find.text('Ekspor cadangan gagal. Coba lagi.'), findsNothing);
    });

    testWidgets('kegagalan ekspor menampilkan SnackBar', (tester) async {
      storage.writeError = StateError('gagal');
      await pumpSection(tester);

      await tester.tap(find.text('Ekspor JSON'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ekspor cadangan gagal. Coba lagi.'), findsOneWidget);
    });

    testWidgets('tombol nonaktif saat ada operasi berjalan', (tester) async {
      service.exportResult = document();
      final gate = Completer<void>();
      storage.gate = gate;
      await pumpSection(tester);

      await tester.tap(find.text('Ekspor JSON'));
      await tester.pump();

      final pulihkan = button('Pulihkan').evaluate().single.widget;
      expect((pulihkan as OutlinedButton).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      final pulihkanSet = button('Pulihkan').evaluate().single.widget;
      expect((pulihkanSet as OutlinedButton).onPressed, isNotNull);
    });

    testWidgets('Pulihkan, picker dibatalkan → tidak ada dialog', (
      tester,
    ) async {
      await pumpSection(tester);

      await tester.tap(button('Pulihkan'));
      await tester.pumpAndSettle();

      expect(find.text('Pulihkan cadangan?'), findsNothing);
    });

    testWidgets('Pulihkan, berkas tidak valid → dialog Gagal', (tester) async {
      storage.pickedFile = FakeBackupStorage.jsonFile(
        'rusak.json',
        'bukan json',
      );
      service.validateResult = const BackupValidationResult.invalid(
        'File bukan JSON yang valid.',
      );
      await pumpSection(tester);

      await tester.tap(button('Pulihkan'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal'), findsOneWidget);
      expect(find.text('File bukan JSON yang valid.'), findsOneWidget);
    });

    testWidgets(
      'Pulihkan menampilkan pratinjau lalu Batal tidak mengubah apa-apa',
      (tester) async {
        final doc = document();
        storage.pickedFile = FakeBackupStorage.jsonFile(
          'cad.json',
          doc.encode(),
        );
        service.validateResult = BackupValidationResult.valid(document: doc);
        await pumpSection(tester);

        await tester.tap(button('Pulihkan'));
        await tester.pumpAndSettle();

        expect(find.text('Pulihkan cadangan?'), findsOneWidget);
        expect(find.textContaining('Tugas: 1'), findsOneWidget);
        expect(find.text('Gabung (lewati duplikat)'), findsOneWidget);
        expect(find.text('Timpa (hapus data lama)'), findsOneWidget);

        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        expect(find.text('Pulihkan cadangan?'), findsNothing);
        expect(service.restoreCalls, 0);
      },
    );

    testWidgets('Pulihkan → Timpa memunculkan ringkasan keberhasilan', (
      tester,
    ) async {
      final doc = document();
      storage.pickedFile = FakeBackupStorage.jsonFile('cad.json', doc.encode());
      service.validateResult = BackupValidationResult.valid(document: doc);
      service.restoreResult = RestoreResult.ok({
        'tasks': const RestoreTableCounts(inserted: 1, skipped: 0),
      });
      await pumpSection(tester);

      await tester.tap(button('Pulihkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timpa (hapus data lama)'));
      await tester.pumpAndSettle();

      expect(service.restoreCalls, 1);
      expect(service.lastRestoreMode, RestoreMode.replace);
      expect(find.text('Pemulihan selesai'), findsOneWidget);
      expect(find.textContaining('Disisipkan: 1'), findsOneWidget);
    });

    testWidgets('Pulihkan → Gabung memakai mode merge', (tester) async {
      final doc = document();
      storage.pickedFile = FakeBackupStorage.jsonFile('cad.json', doc.encode());
      service.validateResult = BackupValidationResult.valid(document: doc);
      service.restoreResult = RestoreResult.ok({
        'tasks': const RestoreTableCounts(inserted: 0, skipped: 1),
      });
      await pumpSection(tester);

      await tester.tap(button('Pulihkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gabung (lewati duplikat)'));
      await tester.pumpAndSettle();

      expect(service.lastRestoreMode, RestoreMode.merge);
      expect(find.textContaining('Dilewati (duplikat): 1'), findsOneWidget);
    });

    testWidgets('pemulihan gagal menampilkan dialog Gagal', (tester) async {
      final doc = document();
      storage.pickedFile = FakeBackupStorage.jsonFile('cad.json', doc.encode());
      service.validateResult = BackupValidationResult.valid(document: doc);
      service.restoreResult = RestoreResult.failed('Pemulihan dibatalkan: x.');
      await pumpSection(tester);

      await tester.tap(button('Pulihkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timpa (hapus data lama)'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal'), findsOneWidget);
      expect(find.textContaining('Pemulihan dibatalkan'), findsOneWidget);
    });
  });
}

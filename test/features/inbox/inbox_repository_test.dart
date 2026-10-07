import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/inbox/data/repositories/inbox_repository_impl.dart';
import 'package:personal_offline/features/inbox/domain/entities/inbox_item.dart';
import 'package:personal_offline/features/inbox/domain/repositories/inbox_repository.dart';

void main() {
  late db.AppDatabase database;
  late InboxRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = InboxRepositoryImpl(database.inboxItemDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('addOpen menyimpan item terbuka dengan timestamp clock', () async {
    final chatMessageId = await database
        .into(database.chatMessages)
        .insert(
          db.ChatMessagesCompanion.insert(
            role: 'user',
            content: 'lusa rapat kapal',
            createdAt: start.millisecondsSinceEpoch,
            updatedAt: start.millisecondsSinceEpoch,
          ),
        );
    final id = await repository.addOpen(
      chatMessageId: chatMessageId,
      rawText: 'lusa rapat kapal',
      suggestion: 'create_reminder',
    );

    final item = await repository.getById(id);
    expect(item, isNotNull);
    expect(item!.chatMessageId, chatMessageId);
    expect(item.rawText, 'lusa rapat kapal');
    expect(item.suggestion, 'create_reminder');
    expect(item.resolution, InboxResolution.open);
    expect(item.resolvedEntityType, isNull);
    expect(item.resolvedEntityId, isNull);
    expect(item.createdAt, start.toUtc());
    expect(item.updatedAt, start.toUtc());
  });

  test('addOpen tanpa chatMessageId dan suggestion tetap tersimpan', () async {
    final id = await repository.addOpen(rawText: '  ');

    final item = await repository.getById(id);
    expect(item!.chatMessageId, isNull);
    expect(item.suggestion, isNull);
    expect(item.rawText, '  ');
  });

  test('watchItems memancarkan urutan terbaru dan terfilter', () async {
    await repository.addOpen(rawText: 'pertama');
    final secondId = await repository.addOpen(rawText: 'kedua');
    final firstId = (await repository.watchItems().first).last.id!;

    final all = await repository.watchItems().first;
    expect(all, hasLength(2));
    expect(all.first.id, secondId, reason: 'terbaru di depan');
    expect(all.last.id, firstId);

    await repository.markDiscarded(secondId);

    final open = await repository
        .watchItems(resolution: InboxResolution.open)
        .first;
    expect(open, hasLength(1));
    expect(open.single.rawText, 'pertama');

    final discarded = await repository
        .watchItems(resolution: InboxResolution.discarded)
        .first;
    expect(discarded.single.id, secondId);
  });

  test('markConverted menyimpan tipe dan id entitas hasil', () async {
    final id = await repository.addOpen(rawText: 'besok jam 8 bayar listrik');

    clock.value = start.add(const Duration(minutes: 5));
    expect(
      await repository.markConverted(id, entityType: 'reminder', entityId: 7),
      isTrue,
    );

    final item = (await repository.getById(id))!;
    expect(item.resolution, InboxResolution.converted);
    expect(item.resolvedEntityType, 'reminder');
    expect(item.resolvedEntityId, 7);
    expect(item.updatedAt, start.add(const Duration(minutes: 5)));
    expect(item.createdAt, start.toUtc());
    expect(await repository.markConverted(999), isFalse);
  });

  test('markDiscarded menyelesaikan item dan id asing false', () async {
    final id = await repository.addOpen(rawText: 'buang ini');

    expect(await repository.markDiscarded(id), isTrue);
    expect(
      (await repository.getById(id))!.resolution,
      InboxResolution.discarded,
    );
    expect(await repository.markDiscarded(999), isFalse);
  });

  test(
    'resolveByText menandai item cocok abaikan spasi dan besar-kecil',
    () async {
      await repository.addOpen(rawText: '  Besok   Jam 8 Bayar Listrik ');
      final otherId = await repository.addOpen(rawText: 'hal lain');

      await repository.resolveByText('besok jam 8 bayar listrik');

      final open = await repository
          .watchItems(resolution: InboxResolution.open)
          .first;
      expect(open.single.id, otherId);

      final converted = await repository
          .watchItems(resolution: InboxResolution.converted)
          .first;
      expect(
        converted.single.rawText,
        '  Besok   Jam 8 Bayar Listrik ',
        reason: 'rawText disimpan apa adanya; normalisasi hanya untuk cocok',
      );
      expect(converted.single.resolvedEntityType, isNull);
    },
  );

  test(
    'resolveByText meneruskan entityType dan mengabaikan teks kosong',
    () async {
      final id = await repository.addOpen(rawText: 'beli beras');

      await repository.resolveByText('   ');
      expect(
        (await repository.getById(id))!.resolution,
        InboxResolution.open,
        reason: 'teks kosong tidak menyelesaikan apa pun',
      );

      await repository.resolveByText('BELI  beras ', entityType: 'shopping');
      final item = (await repository.getById(id))!;
      expect(item.resolution, InboxResolution.converted);
      expect(item.resolvedEntityType, 'shopping');
    },
  );

  test('resolveByText tidak mengubah item yang sudah diselesaikan', () async {
    final id = await repository.addOpen(rawText: 'catatan lama');
    await repository.markConverted(id, entityType: 'note');

    await repository.resolveByText('catatan lama', entityType: 'todo');

    final item = (await repository.getById(id))!;
    expect(item.resolvedEntityType, 'note', reason: 'tetap hasil awal');
  });

  test('getById mengembalikan null untuk id yang tidak ada', () async {
    expect(await repository.getById(123), isNull);
  });
}

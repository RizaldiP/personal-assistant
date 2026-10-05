import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:personal_offline/features/chat/domain/entities/chat_message.dart';
import 'package:personal_offline/features/chat/domain/repositories/chat_repository.dart';

void main() {
  late db.AppDatabase database;
  late ChatRepository repository;
  late FixedClock clock;

  final start = DateTime.utc(2026, 10, 5, 8, 30);

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    clock = FixedClock(start);
    repository = ChatRepositoryImpl(database.chatMessageDao, clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('save pesan baru mengisi id, status dan timestamp clock', () async {
    final id = await repository.save(
      const ChatMessage(
        role: ChatRole.user,
        content: 'buat tugas besok',
        intent: 'create_task',
        payload: '{"title":"besok"}',
        status: ChatStatus.needsConfirmation,
      ),
    );

    final saved = await repository.getById(id);

    expect(saved, isNotNull);
    expect(saved!.role, ChatRole.user);
    expect(saved.content, 'buat tugas besok');
    expect(saved.intent, 'create_task');
    expect(saved.payload, '{"title":"besok"}');
    expect(saved.status, ChatStatus.needsConfirmation);
    expect(saved.createdAt, start.toUtc());
    expect(saved.updatedAt, start.toUtc());
  });

  test('save dengan id memperbarui pesan yang sama', () async {
    final id = await repository.save(
      const ChatMessage(role: ChatRole.user, content: 'awal'),
    );
    final original = await repository.getById(id);

    clock.value = start.add(const Duration(minutes: 1));
    await repository.save(
      original!.copyWith(
        intent: 'create_task',
        status: ChatStatus.sent,
        resolvedAt: start.add(const Duration(minutes: 1)),
      ),
    );

    final rows = await repository.getAll();
    expect(rows, hasLength(1));
    final updated = rows.single;
    expect(updated.id, id);
    expect(updated.content, 'awal');
    expect(updated.intent, 'create_task');
    expect(updated.updatedAt, start.add(const Duration(minutes: 1)));
    expect(updated.resolvedAt, start.add(const Duration(minutes: 1)));
    expect(updated.createdAt, original.createdAt);
  });

  test('update tanpa id mengembalikan false', () async {
    expect(
      await repository.update(
        const ChatMessage(role: ChatRole.user, content: 'tanpa id'),
      ),
      isFalse,
    );
  });

  test('getLatest dan delete', () async {
    await repository.save(
      ChatMessage(
        role: ChatRole.assistant,
        content: 'lama',
        createdAt: start.subtract(const Duration(minutes: 1)),
      ),
    );
    await repository.save(
      ChatMessage(role: ChatRole.user, content: 'baru', createdAt: start),
    );

    expect((await repository.getLatest())!.content, 'baru');
    expect(await repository.watchMessages().first, hasLength(2));

    final first = (await repository.getAll()).first;
    expect(await repository.delete(first.id!), isTrue);
    expect(await repository.getById(first.id!), isNull);
    expect(await repository.delete(first.id!), isFalse);
  });

  test('getLatest pada chat kosong mengembalikan null', () async {
    expect(await repository.getLatest(), isNull);
  });

  test('pesan tanpa data tersimpan mengembalikan null', () async {
    expect(await repository.getById(999), isNull);
  });
}

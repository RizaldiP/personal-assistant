import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/todo/data/repositories/task_repository_impl.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';
import 'package:personal_offline/features/todo/presentation/screens/todo_screen.dart';

import '../../../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repository;
  late FixedClock clock;

  setUp(() {
    repository = FakeTaskRepository();
    clock = FixedClock(DateTime(2026, 10, 5, 8));
  });

  Future<void> pumpTodo(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
          ...overrides,
        ],
        child: const MaterialApp(home: TodoScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tampilan kosong menampilkan empty state', (tester) async {
    await pumpTodo(tester);

    expect(find.text('Tugas'), findsOneWidget);
    expect(find.text('Belum ada tugas'), findsOneWidget);
  });

  testWidgets('mengelompokkan tugas belum selesai dan selesai', (tester) async {
    await repository.create(
      const Task(title: 'Kerjakan laporan', dueDate: '2026-10-06'),
    );
    await repository.create(
      const Task(title: 'Beresin kamar', status: TaskStatus.done),
    );

    await pumpTodo(tester);

    expect(find.text('BELUM SELESAI'), findsOneWidget);
    expect(find.text('SELESAI'), findsOneWidget);
    expect(find.text('Kerjakan laporan'), findsOneWidget);
    expect(find.text('Beresin kamar'), findsOneWidget);
    expect(find.textContaining('6 Oktober 2026'), findsOneWidget);
  });

  testWidgets('menceklis tugas menandainya selesai', (tester) async {
    await repository.create(const Task(title: 'Kirim email'));

    await pumpTodo(tester);
    expect(repository.tasks.single.status, TaskStatus.pending);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(repository.tasks.single.status, TaskStatus.done);
  });

  testWidgets('menghapus tugas melalui dialog konfirmasi', (tester) async {
    await repository.create(const Task(title: 'Buang sampah'));

    await pumpTodo(tester);
    await tester.tap(find.byTooltip('Hapus tugas'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus tugas?'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(repository.tasks, isEmpty);
    expect(find.text('Belum ada tugas'), findsOneWidget);
  });

  testWidgets('menambah tugas lewat form', (tester) async {
    await pumpTodo(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Tugas baru'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Beresin kamar');
    final save = find.text('Tambahkan tugas');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Tugas baru'), findsNothing);
    expect(repository.tasks, hasLength(1));
    expect(repository.tasks.single.title, 'Beresin kamar');
  });

  testWidgets('edit memuat nilai lama lalu menyimpan perubahan', (
    tester,
  ) async {
    await repository.create(
      const Task(title: 'Tugas lama', dueDate: '2026-10-06'),
    );

    await pumpTodo(tester);
    await tester.tap(find.text('Tugas lama'));
    await tester.pumpAndSettle();

    expect(find.text('Edit tugas'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Tugas lama',
    );

    await tester.enterText(find.byType(TextFormField).first, 'Tugas baru');
    final save = find.text('Simpan perubahan');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.tasks.single.title, 'Tugas baru');
    expect(find.text('Edit tugas'), findsNothing);
  });

  testWidgets('judul kosong menampilkan pesan validasi', (tester) async {
    await pumpTodo(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final save = find.text('Tambahkan tugas');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Judul wajib diisi'), findsOneWidget);
    expect(repository.tasks, isEmpty);
  });
}

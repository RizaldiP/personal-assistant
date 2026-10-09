import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/widget/today_tasks_codec.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';

void main() {
  group('encodeTodayTasks', () {
    test('mengubah tugas menjadi JSON ringkas dengan flag selesai', () {
      final json = encodeTodayTasks(const [
        Task(
          id: 1,
          title: 'Masak',
          dueDate: '2026-10-09',
          dueTime: '08:00',
        ),
        Task(
          id: 2,
          title: 'Olahraga',
          dueDate: '2026-10-09',
          status: TaskStatus.done,
        ),
      ]);

      final entries = decodeTodayTasks(json);
      expect(entries, hasLength(2));
      expect(entries[0].id, 1);
      expect(entries[0].title, 'Masak');
      expect(entries[0].time, '08:00');
      expect(entries[0].done, isFalse);
      expect(entries[1].id, 2);
      expect(entries[1].title, 'Olahraga');
      expect(entries[1].time, isNull);
      expect(entries[1].done, isTrue);
    });

    test('melewati tugas tanpa id', () {
      final json = encodeTodayTasks(const [
        Task(title: 'Tanpa id', dueDate: '2026-10-09'),
        Task(id: 5, title: 'Punya id', dueDate: '2026-10-09'),
      ]);

      final entries = decodeTodayTasks(json);
      expect(entries, hasLength(1));
      expect(entries.single.id, 5);
    });
  });

  group('decodeTodayTasks', () {
    test('null / kosong / rusak mengembalikan daftar kosong', () {
      expect(decodeTodayTasks(null), isEmpty);
      expect(decodeTodayTasks(''), isEmpty);
      expect(decodeTodayTasks('bukan json'), isEmpty);
      expect(decodeTodayTasks('{"i":1}'), isEmpty);
    });

    test('mengabaikan entri yang tidak lengkap', () {
      final entries = decodeTodayTasks(
        '[{"i":1,"t":"Valid","d":false},'
        '{"i":"x","t":"id salah"},'
        '{"t":"tanpa id"},'
        '"bukan objek"]',
      );

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Valid');
    });
  });
}

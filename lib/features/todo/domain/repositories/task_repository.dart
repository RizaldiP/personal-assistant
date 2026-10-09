import '../entities/task.dart';

/// Kontrak akses data tugas. Implementasi ada di lapisan data.
abstract interface class TaskRepository {
  Stream<List<Task>> watchTasks();

  Stream<List<Task>> watchTasksOn(String date);

  /// Semua tugas (pending + selesai) pada [date] untuk widget layar utama.
  Stream<List<Task>> watchTasksForWidgetOn(String date);

  Future<Task?> getById(int id);

  Future<List<Task>> getAll();

  Future<List<Task>> search(String query);

  /// Mengembalikan id baris yang dibuat.
  Future<int> create(Task task);

  /// `task.id` wajib terisi.
  Future<bool> update(Task task);

  Future<bool> delete(int id);
}

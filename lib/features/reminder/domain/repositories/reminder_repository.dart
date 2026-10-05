import '../entities/reminder.dart';

/// Kontrak akses data reminder. Implementasi ada di lapisan data.
abstract interface class ReminderRepository {
  Stream<List<Reminder>> watchActive();

  Future<Reminder?> getById(int id);

  Future<List<Reminder>> getAll();

  /// Reminder aktif yang jatuh tempo pada [moment].
  Future<List<Reminder>> dueAt(DateTime moment);

  Future<List<Reminder>> search(String query);

  Future<int> create(Reminder reminder);

  Future<bool> update(Reminder reminder);

  Future<bool> delete(int id);
}

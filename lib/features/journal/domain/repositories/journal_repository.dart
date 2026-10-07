import 'package:personal_offline/features/journal/domain/entities/journal_entry.dart';

/// Repositori jurnal harian.
abstract interface class JournalRepository {
  /// Daftar entri urut tanggal terbaru; difilter [query] bila terisi.
  Stream<List<JournalEntry>> watchEntries({String? query});

  Future<List<JournalEntry>> getAll({String? query});

  Future<JournalEntry?> getById(int id);

  /// Menyimpan entri baru; mengembalikan id.
  Future<int> create(JournalEntry entry);

  Future<bool> update(JournalEntry entry);

  Future<bool> deleteById(int id);
}

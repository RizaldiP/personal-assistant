import 'package:personal_offline/features/notes/domain/entities/note.dart';

/// Repositori catatan bebas.
abstract interface class NoteRepository {
  /// Daftar catatan urut terbaru; difilter [query] bila terisi.
  Stream<List<Note>> watchNotes({String? query});

  Future<List<Note>> getAll({String? query});

  Future<Note?> getById(int id);

  /// Menyimpan catatan baru; mengembalikan id.
  Future<int> create(Note note);

  Future<bool> update(Note note);

  Future<bool> deleteById(int id);
}

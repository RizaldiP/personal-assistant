import 'package:personal_offline/features/ideas/domain/entities/idea.dart';

/// Repositori ide.
abstract interface class IdeaRepository {
  /// Daftar ide urut terbaru; difilter [query] bila terisi.
  Stream<List<Idea>> watchIdeas({String? query});

  Future<List<Idea>> getAll({String? query});

  Future<Idea?> getById(int id);

  /// Menyimpan ide baru; mengembalikan id.
  Future<int> create(Idea idea);

  Future<bool> update(Idea idea);

  Future<bool> deleteById(int id);
}

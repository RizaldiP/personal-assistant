import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/note_repository_impl.dart';
import '../../domain/entities/note.dart';

/// Daftar catatan urut terbaru; [query] kosong = semua catatan.
final notesProvider = StreamProvider.autoDispose.family<List<Note>, String>((
  ref,
  query,
) {
  final trimmed = query.trim();
  return ref
      .watch(noteRepositoryProvider)
      .watchNotes(query: trimmed.isEmpty ? null : trimmed);
});

class NoteController extends Notifier<void> {
  @override
  void build() {}

  /// Menyimpan catatan baru (tag opsional, dipakai apa adanya).
  Future<int> create({
    required String content,
    String? title,
    List<String> tags = const [],
    String? source,
    String? rawInput,
    double? confidence,
  }) {
    return ref
        .read(noteRepositoryProvider)
        .create(
          Note(
            title: title,
            content: content,
            tags: tags,
            source: source,
            rawInput: rawInput,
            confidence: confidence,
          ),
        );
  }

  Future<bool> update(Note note) =>
      ref.read(noteRepositoryProvider).update(note);

  Future<bool> delete(int id) =>
      ref.read(noteRepositoryProvider).deleteById(id);
}

final noteControllerProvider = NotifierProvider<NoteController, void>(
  NoteController.new,
);

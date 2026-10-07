import 'dart:async';

import 'package:personal_offline/features/notes/domain/entities/note.dart';
import 'package:personal_offline/features/notes/domain/repositories/note_repository.dart';

/// Fake [NoteRepository] untuk test controller, layar, dan alur chat.
///
/// Data disimpan dalam memori; setiap `watchNotes` mengembalikan stream yang
/// langsung memancarkan snapshot lalu mengikuti perubahan berikutnya — tiap
/// pendengar (mis. provider dengan query berbeda) mendapat replay sendiri.
class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({List<Note> seed = const []}) {
    _notes.addAll(seed);
    if (seed.isNotEmpty) {
      _nextId =
          seed.map((note) => note.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  final List<Note> _notes = [];
  final StreamController<List<Note>> _changes = StreamController.broadcast(
    sync: true,
  );

  int _nextId = 1;

  List<Note> get notes => List.unmodifiable(_notes);

  void _emit() => _changes.add(_snapshot());

  List<Note> _snapshot() => List.of(_notes);

  Stream<List<Note>> _watch(List<Note> Function(List<Note> notes) pick) {
    late StreamController<List<Note>> controller;
    StreamSubscription<List<Note>>? pipe;
    controller = StreamController<List<Note>>.broadcast(
      sync: true,
      onListen: () {
        controller.add(pick(_snapshot()));
        pipe = _changes.stream.listen((_) => controller.add(pick(_snapshot())));
      },
      onCancel: () {
        pipe?.cancel();
        pipe = null;
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<Note>> watchNotes({String? query}) {
    final trimmed = query?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return _watch((notes) => notes);
    return _watch(
      (notes) => notes
          .where(
            (note) =>
                note.content.toLowerCase().contains(trimmed) ||
                (note.title?.toLowerCase().contains(trimmed) ?? false),
          )
          .toList(),
    );
  }

  @override
  Future<List<Note>> getAll({String? query}) async =>
      watchNotes(query: query).first;

  @override
  Future<Note?> getById(int id) async {
    for (final note in _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<int> create(Note note) async {
    final id = _nextId++;
    _notes.add(note.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<bool> update(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return false;
    _notes[index] = note;
    _emit();
    return true;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = _notes.length;
    _notes.removeWhere((n) => n.id == id);
    _emit();
    return _notes.length != before;
  }
}

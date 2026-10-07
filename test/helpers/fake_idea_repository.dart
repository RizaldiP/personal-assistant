import 'dart:async';

import 'package:personal_offline/features/ideas/domain/entities/idea.dart';
import 'package:personal_offline/features/ideas/domain/repositories/idea_repository.dart';

/// Fake [IdeaRepository] untuk test controller, layar, dan alur chat.
///
/// Data disimpan dalam memori; setiap `watchIdeas` mengembalikan stream yang
/// langsung memancarkan snapshot lalu mengikuti perubahan berikutnya — tiap
/// pendengar (mis. provider dengan query berbeda) mendapat replay sendiri.
class FakeIdeaRepository implements IdeaRepository {
  FakeIdeaRepository({List<Idea> seed = const []}) {
    _ideas.addAll(seed);
    if (seed.isNotEmpty) {
      _nextId =
          seed.map((idea) => idea.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  final List<Idea> _ideas = [];
  final StreamController<List<Idea>> _changes = StreamController.broadcast(
    sync: true,
  );

  int _nextId = 1;

  List<Idea> get ideas => List.unmodifiable(_ideas);

  void _emit() => _changes.add(_snapshot());

  List<Idea> _snapshot() => List.of(_ideas);

  Stream<List<Idea>> _watch(List<Idea> Function(List<Idea> ideas) pick) {
    late StreamController<List<Idea>> controller;
    StreamSubscription<List<Idea>>? pipe;
    controller = StreamController<List<Idea>>.broadcast(
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
  Stream<List<Idea>> watchIdeas({String? query}) {
    final trimmed = query?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return _watch((ideas) => ideas);
    return _watch(
      (ideas) => ideas
          .where(
            (idea) =>
                idea.title.toLowerCase().contains(trimmed) ||
                (idea.content?.toLowerCase().contains(trimmed) ?? false),
          )
          .toList(),
    );
  }

  @override
  Future<List<Idea>> getAll({String? query}) async =>
      watchIdeas(query: query).first;

  @override
  Future<Idea?> getById(int id) async {
    for (final idea in _ideas) {
      if (idea.id == id) return idea;
    }
    return null;
  }

  @override
  Future<int> create(Idea idea) async {
    final id = _nextId++;
    _ideas.add(idea.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<bool> update(Idea idea) async {
    final index = _ideas.indexWhere((i) => i.id == idea.id);
    if (index == -1) return false;
    _ideas[index] = idea;
    _emit();
    return true;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = _ideas.length;
    _ideas.removeWhere((i) => i.id == id);
    _emit();
    return _ideas.length != before;
  }
}

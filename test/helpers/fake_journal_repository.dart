import 'dart:async';

import 'package:personal_offline/features/journal/domain/entities/journal_entry.dart';
import 'package:personal_offline/features/journal/domain/repositories/journal_repository.dart';

/// Fake [JournalRepository] untuk test controller, layar, dan alur chat.
///
/// Data disimpan dalam memori; setiap `watchEntries` mengembalikan stream
/// yang langsung memancarkan snapshot lalu mengikuti perubahan berikutnya —
/// tiap pendengar (mis. provider dengan query berbeda) mendapat replay
/// sendiri.
class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository({List<JournalEntry> seed = const []}) {
    _entries.addAll(seed);
    if (seed.isNotEmpty) {
      _nextId =
          seed.map((entry) => entry.id ?? 0).reduce((a, b) => a > b ? a : b) +
          1;
    }
  }

  final List<JournalEntry> _entries = [];
  final StreamController<List<JournalEntry>> _changes =
      StreamController.broadcast(sync: true);

  int _nextId = 1;

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  void _emit() => _changes.add(_snapshot());

  List<JournalEntry> _snapshot() => List.of(_entries);

  Stream<List<JournalEntry>> _watch(
    List<JournalEntry> Function(List<JournalEntry> entries) pick,
  ) {
    late StreamController<List<JournalEntry>> controller;
    StreamSubscription<List<JournalEntry>>? pipe;
    controller = StreamController<List<JournalEntry>>.broadcast(
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
  Stream<List<JournalEntry>> watchEntries({String? query}) {
    final trimmed = query?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return _watch((entries) => entries);
    return _watch(
      (entries) => entries
          .where(
            (entry) =>
                entry.content.toLowerCase().contains(trimmed) ||
                (entry.title?.toLowerCase().contains(trimmed) ?? false) ||
                (entry.mood?.toLowerCase().contains(trimmed) ?? false),
          )
          .toList(),
    );
  }

  @override
  Future<List<JournalEntry>> getAll({String? query}) async =>
      watchEntries(query: query).first;

  @override
  Future<JournalEntry?> getById(int id) async {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<int> create(JournalEntry entry) async {
    final id = _nextId++;
    _entries.add(entry.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<bool> update(JournalEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) return false;
    _entries[index] = entry;
    _emit();
    return true;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    _emit();
    return _entries.length != before;
  }
}

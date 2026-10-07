import 'dart:async';

import 'package:personal_offline/features/inbox/domain/entities/inbox_item.dart';
import 'package:personal_offline/features/inbox/domain/repositories/inbox_repository.dart';

/// Fake [InboxRepository] untuk test chat, layar inbox, dan auto-resolve.
class FakeInboxRepository implements InboxRepository {
  FakeInboxRepository({List<InboxItem> seed = const []}) {
    _items.addAll(seed);
    if (seed.isNotEmpty) {
      _nextId =
          seed.map((item) => item.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  final List<InboxItem> _items = [];
  final StreamController<List<InboxItem>> _changes = StreamController.broadcast(
    sync: true,
  );

  int _nextId = 1;

  /// Bila true, [addOpen] melempar galat (menguji ketahanan chat).
  bool failAdd = false;

  List<InboxItem> get items => List.unmodifiable(_items);

  List<InboxItem> _snapshot({InboxResolution? resolution}) => [
    for (final item in _items)
      if (resolution == null || item.resolution == resolution) item,
  ];

  void _emit() => _changes.add(_snapshot());

  Stream<List<InboxItem>> _watch({InboxResolution? resolution}) {
    late StreamController<List<InboxItem>> controller;
    StreamSubscription<List<InboxItem>>? pipe;
    controller = StreamController<List<InboxItem>>.broadcast(
      sync: true,
      onListen: () {
        controller.add(_snapshot(resolution: resolution));
        pipe = _changes.stream.listen(
          (_) => controller.add(_snapshot(resolution: resolution)),
        );
      },
      onCancel: () {
        pipe?.cancel();
        pipe = null;
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<InboxItem>> watchItems({InboxResolution? resolution}) =>
      _watch(resolution: resolution);

  @override
  Future<InboxItem?> getById(int id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<int> addOpen({
    int? chatMessageId,
    required String rawText,
    String? suggestion,
  }) async {
    if (failAdd) throw StateError('inbox offline');
    final id = _nextId++;
    _items.add(
      InboxItem(
        id: id,
        chatMessageId: chatMessageId,
        rawText: rawText,
        suggestion: suggestion,
        createdAt: DateTime.utc(2026, 10, 5, 9),
        updatedAt: DateTime.utc(2026, 10, 5, 9),
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<bool> markConverted(
    int id, {
    String? entityType,
    int? entityId,
  }) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return false;
    _items[index] = _items[index].copyWith(
      resolution: InboxResolution.converted,
      resolvedEntityType: entityType,
      resolvedEntityId: entityId,
      updatedAt: DateTime.utc(2026, 10, 5, 10),
    );
    _emit();
    return true;
  }

  @override
  Future<bool> markDiscarded(int id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return false;
    _items[index] = _items[index].copyWith(
      resolution: InboxResolution.discarded,
      updatedAt: DateTime.utc(2026, 10, 5, 10),
    );
    _emit();
    return true;
  }

  @override
  Future<void> resolveByText(String rawText, {String? entityType}) async {
    final target = _normalize(rawText);
    if (target.isEmpty) return;
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.resolution != InboxResolution.open) continue;
      if (_normalize(item.rawText) != target) continue;
      _items[i] = item.copyWith(
        resolution: InboxResolution.converted,
        resolvedEntityType: entityType,
        updatedAt: DateTime.utc(2026, 10, 5, 10),
      );
      changed = true;
    }
    if (changed) _emit();
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

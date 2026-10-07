import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_offline/core/database/app_database.dart' as db;
import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/shared/formatters/currency_formats.dart';
import 'package:personal_offline/shared/formatters/date_formats.dart';

import '../../domain/repositories/search_repository.dart';
import '../../domain/search_result.dart';

/// Implementasi [SearchRepository] berbasis drift: `LIKE :q` pada kolom
/// judul/konten tiap tabel + temuan lewat nama tag (docs/04 bagian 7).
///
/// Hasil dibatasi [limitPerType] per tipe agar pencarian tetap cepat.
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._database);

  final db.AppDatabase _database;

  @override
  Future<List<SearchResult>> search({
    required String query,
    String? type,
    String? tag,
    int limitPerType = 30,
  }) async {
    final trimmed = query.trim();
    final hasQuery = trimmed.isNotEmpty;
    if (!hasQuery && tag == null) return const [];

    final types = type == null
        ? SearchTypes.all
        : SearchTypes.all.contains(type)
        ? [type]
        : const <String>[];
    if (types.isEmpty) return const [];

    final results = <SearchResult>[];
    if (tag != null) {
      results.addAll(await _searchByTag(tag, trimmed, types, limitPerType));
    } else {
      for (final entityType in types) {
        results.addAll(await _textHits(entityType, trimmed, limitPerType));
      }
      results.addAll(
        await _taggedByNames(trimmed, types, results, limitPerType),
      );
    }

    _sort(results);
    final capped = _capPerType(results, limitPerType);
    await _attachTags(capped);
    return capped;
  }

  @override
  Stream<List<String>> watchTagNames() => _database.tagDao.watchAll().map(
    (rows) => rows.map((row) => row.name).toList(),
  );

  /// Entitas yang tertaut ke [tag]; bila [query] juga terisi, batasi ke yang
  /// teksnya cocok — kecuali query-nya sendiri cocok dengan nama tag.
  Future<List<SearchResult>> _searchByTag(
    String tag,
    String query,
    List<String> types,
    int limitPerType,
  ) async {
    final links = await _database.tagDao.linksForTag(tag);
    final idsByType = <String, Set<int>>{};
    for (final link in links) {
      (idsByType[link.entityType] ??= <int>{}).add(link.entityId);
    }

    final includeAll =
        query.isEmpty ||
        (await _database.tagDao.matchingNames(
          _likePattern(query),
        )).contains(tag);

    final results = <SearchResult>[];
    for (final entityType in types) {
      final ids = idsByType[entityType] ?? const <int>{};
      if (ids.isEmpty) continue;
      if (includeAll) {
        results.addAll(await _byIds(entityType, ids, limitPerType));
      } else {
        final hits = await _textHits(entityType, query, limitPerType);
        results.addAll(hits.where((hit) => ids.contains(hit.id)));
      }
    }
    return results;
  }

  /// Hasil tambahan dari entitas yang namanya cocok lewat tag-nya (hanya
  /// saat tidak ada filter tag; [existing] dihindari dari ganda).
  Future<List<SearchResult>> _taggedByNames(
    String query,
    List<String> types,
    List<SearchResult> existing,
    int limitPerType,
  ) async {
    if (query.isEmpty) return const [];
    final seen = {for (final hit in existing) '${hit.type}:${hit.id}'};
    final links = await _database.tagDao.matchingLinks(_likePattern(query));
    final extra = <SearchResult>[];
    for (final link in links) {
      if (!types.contains(link.entityType)) continue;
      final key = '${link.entityType}:${link.entityId}';
      if (seen.contains(key)) continue;
      if (extra.where((hit) => hit.type == link.entityType).length >=
          limitPerType) {
        continue;
      }
      seen.add(key);
      extra.addAll(await _byIds(link.entityType, {link.entityId}, 1));
    }
    return extra;
  }

  Future<List<SearchResult>> _textHits(
    String entityType,
    String query,
    int limitPerType,
  ) async {
    switch (entityType) {
      case SearchTypes.todo:
        final rows = await _database.taskDao.search(query);
        return rows.take(limitPerType).map(_todoResult).toList();
      case SearchTypes.reminder:
        final rows = await _database.reminderDao.search(query);
        return rows.take(limitPerType).map(_reminderResult).toList();
      case SearchTypes.note:
        final rows = await _database.noteDao.getAll(query: query);
        return rows.take(limitPerType).map(_noteResult).toList();
      case SearchTypes.journal:
        final rows = await _database.journalDao.getAll(query: query);
        return rows.take(limitPerType).map(_journalResult).toList();
      case SearchTypes.idea:
        final rows = await _database.ideaDao.getAll(query: query);
        return rows.take(limitPerType).map(_ideaResult).toList();
      case SearchTypes.expense:
        final rows = await _database.expenseDao.search(
          query,
          limit: limitPerType,
        );
        return rows.map(_expenseResult).toList();
      case SearchTypes.shopping:
        final lists = await _database.shoppingDao.searchLists(
          query,
          limit: limitPerType,
        );
        if (lists.isEmpty) return const [];
        return _shoppingResults(lists, await _allItems());
      default:
        return const [];
    }
  }

  Future<List<SearchResult>> _byIds(
    String entityType,
    Set<int> ids,
    int limitPerType,
  ) async {
    switch (entityType) {
      case SearchTypes.todo:
        final rows = await _database.taskDao.getAll();
        return rows
            .where((task) => ids.contains(task.id))
            .take(limitPerType)
            .map(_todoResult)
            .toList();
      case SearchTypes.reminder:
        final rows = await _database.reminderDao.getAll();
        return rows
            .where((reminder) => ids.contains(reminder.id))
            .take(limitPerType)
            .map(_reminderResult)
            .toList();
      case SearchTypes.note:
        final rows = await _database.noteDao.getAll();
        return rows
            .where((note) => ids.contains(note.id))
            .take(limitPerType)
            .map(_noteResult)
            .toList();
      case SearchTypes.journal:
        final rows = await _database.journalDao.getAll();
        return rows
            .where((entry) => ids.contains(entry.id))
            .take(limitPerType)
            .map(_journalResult)
            .toList();
      case SearchTypes.idea:
        final rows = await _database.ideaDao.getAll();
        return rows
            .where((idea) => ids.contains(idea.id))
            .take(limitPerType)
            .map(_ideaResult)
            .toList();
      case SearchTypes.expense:
        final rows = await _database.expenseDao.getAll();
        return rows
            .where((expense) => ids.contains(expense.id))
            .take(limitPerType)
            .map(_expenseResult)
            .toList();
      case SearchTypes.shopping:
        final lists = (await _database.shoppingDao.getAllLists())
            .where((list) => ids.contains(list.id))
            .take(limitPerType)
            .toList();
        if (lists.isEmpty) return const [];
        return _shoppingResults(lists, await _allItems());
      default:
        return const [];
    }
  }

  Future<List<db.ShoppingItem>> _allItems() =>
      _database.shoppingDao.getAllItems();

  static SearchResult _todoResult(db.Task task) => SearchResult(
    type: SearchTypes.todo,
    id: task.id,
    title: task.title,
    subtitle: _joinParts([
      if (task.dueDate != null) DateFormats.longIndonesia(task.dueDate),
      if (task.dueTime != null) 'jam ${task.dueTime}',
      if (task.status == 'done') 'selesai',
    ]),
    date: task.dueDate,
  );

  static SearchResult _reminderResult(db.Reminder reminder) => SearchResult(
    type: SearchTypes.reminder,
    id: reminder.id,
    title: reminder.title,
    subtitle: _joinParts([
      DateFormats.longIndonesia(reminder.date),
      'jam ${reminder.time}',
      if (reminder.status != 'active') 'selesai',
    ]),
    date: reminder.date,
  );

  static SearchResult _noteResult(db.Note note) {
    final hasTitle = note.title?.trim().isNotEmpty ?? false;
    return SearchResult(
      type: SearchTypes.note,
      id: note.id,
      title: hasTitle ? note.title! : _snippet(note.content),
      subtitle: hasTitle ? _snippet(note.content) : '',
    );
  }

  static SearchResult _journalResult(db.JournalEntry entry) => SearchResult(
    type: SearchTypes.journal,
    id: entry.id,
    title: _snippet(entry.content),
    subtitle: _joinParts([
      DateFormats.longIndonesia(entry.date),
      if ((entry.mood ?? '').isNotEmpty) 'mood ${entry.mood}',
    ]),
    date: entry.date,
  );

  static SearchResult _ideaResult(db.Idea idea) => SearchResult(
    type: SearchTypes.idea,
    id: idea.id,
    title: idea.title,
    subtitle: _snippet(idea.content ?? ''),
  );

  static SearchResult _expenseResult(db.Expense expense) => SearchResult(
    type: SearchTypes.expense,
    id: expense.id,
    title: expense.description,
    subtitle:
        '${CurrencyFormats.idr(expense.amount)} · '
        '${_categoryLabel(expense.category)}',
    date: expense.date,
  );

  static List<SearchResult> _shoppingResults(
    List<db.ShoppingList> lists,
    List<db.ShoppingItem> items,
  ) => [
    for (final list in lists)
      SearchResult(
        type: SearchTypes.shopping,
        id: list.id,
        title: list.title,
        subtitle: _joinParts([
          if (list.date != null) DateFormats.longIndonesia(list.date),
          '${items.where((item) => item.listId == list.id).length} barang',
        ]),
        date: list.date,
      ),
  ];

  /// Menambahkan tag tiap hasil lewat satu query per tipe.
  Future<void> _attachTags(List<SearchResult> results) async {
    if (results.isEmpty) return;
    final idsByType = <String, List<int>>{};
    for (final result in results) {
      (idsByType[result.type] ??= []).add(result.id);
    }
    var updated = [...results];
    for (final entry in idsByType.entries) {
      final rows = await _database.tagDao.tagsForEntities(
        entry.key,
        entry.value,
      );
      if (rows.isEmpty) continue;
      final grouped = <int, List<String>>{};
      for (final row in rows) {
        (grouped[row.entityId] ??= []).add(row.name);
      }
      updated = [
        for (final result in updated)
          result.type == entry.key && grouped.containsKey(result.id)
              ? result.copyWith(tags: grouped[result.id]!)
              : result,
      ];
    }
    results
      ..clear()
      ..addAll(updated);
  }

  static void _sort(List<SearchResult> results) {
    results.sort((a, b) {
      final byType = SearchTypes.all
          .indexOf(a.type)
          .compareTo(SearchTypes.all.indexOf(b.type));
      if (byType != 0) return byType;
      final byDate = (b.date ?? '').compareTo(a.date ?? '');
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
  }

  static List<SearchResult> _capPerType(
    List<SearchResult> results,
    int limitPerType,
  ) {
    final counts = <String, int>{};
    final capped = <SearchResult>[];
    for (final result in results) {
      final count = counts.update(
        result.type,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (count <= limitPerType) capped.add(result);
    }
    return capped;
  }

  static String _joinParts(List<String> parts) =>
      parts.where((part) => part.trim().isNotEmpty).join(' · ');

  static String _snippet(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }

  static String _categoryLabel(String category) => switch (category) {
    'makanan' => 'Makanan',
    'transport' => 'Transport',
    'tagihan' => 'Tagihan',
    'belanja' => 'Belanja',
    'kesehatan' => 'Kesehatan',
    'hiburan' => 'Hiburan',
    _ => 'Lainnya',
  };

  static String _likePattern(String value) => '%${_escapeLike(value)}%';

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (match) => '\\${match[0]}');
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(ref.watch(appDatabaseProvider));
});

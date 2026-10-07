import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/search_repository_impl.dart';
import '../../domain/search_result.dart';

/// Kunci pencarian (teks + filter) — `==`/`hashCode` wajib agar
/// `FutureProvider.family` tidak memanggil repository untuk query identik.
class SearchQuery {
  const SearchQuery({required this.text, this.type, this.tag});

  final String text;

  /// Tipe entitas (`SearchTypes.*`) atau null = semua.
  final String? type;

  final String? tag;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.type == type &&
      other.tag == tag;

  @override
  int get hashCode => Object.hash(text, type, tag);
}

/// Hasil pencarian global (PHASE 13).
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<SearchResult>, SearchQuery>((ref, query) {
      return ref
          .read(searchRepositoryProvider)
          .search(query: query.text, type: query.type, tag: query.tag);
    });

/// Nama tag untuk chip filter (live).
final searchTagNamesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(searchRepositoryProvider).watchTagNames(),
);

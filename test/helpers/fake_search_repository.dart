import 'package:personal_offline/features/search/domain/repositories/search_repository.dart';
import 'package:personal_offline/features/search/domain/search_result.dart';

/// Fake [SearchRepository] untuk menguji intent `search` tanpa database.
class FakeSearchRepository implements SearchRepository {
  FakeSearchRepository({List<SearchResult>? results})
    : _results = results ?? <SearchResult>[];

  List<SearchResult> _results;

  /// Hasil yang dikembalikan [search].
  set results(List<SearchResult> value) => _results = value;

  /// Query terakhir yang diterima (untuk asersi).
  String? lastQuery;

  /// Filter tipe terakhir yang diterima.
  String? lastType;

  /// Filter tag terakhir yang diterima.
  String? lastTag;

  /// limitPerType terakhir yang diterima.
  int? lastLimitPerType;

  /// Nama tag untuk chip filter.
  List<String> tagNames = const [];

  int searchCalls = 0;

  @override
  Future<List<SearchResult>> search({
    required String query,
    String? type,
    String? tag,
    int limitPerType = 30,
  }) async {
    searchCalls++;
    lastQuery = query;
    lastType = type;
    lastTag = tag;
    lastLimitPerType = limitPerType;
    return _results.take(limitPerType).toList();
  }

  @override
  Stream<List<String>> watchTagNames() => Stream.value(tagNames);
}

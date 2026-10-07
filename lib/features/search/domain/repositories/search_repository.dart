import '../search_result.dart';

/// Kontrak pencarian global lintas entitas (PHASE 13).
abstract interface class SearchRepository {
  /// Pencarian `LIKE` lintas tipe; maks [limitPerType] hasil per tipe.
  ///
  /// [query] boleh kosong selama [tag] terisi (menelusuri entitas ber-tag).
  /// [type] membatasi satu tipe saja (lihat [SearchTypes.all]).
  Future<List<SearchResult>> search({
    required String query,
    String? type,
    String? tag,
    int limitPerType = 30,
  });

  /// Semua nama tag — dipakai baris filter tag di layar pencarian.
  Stream<List<String>> watchTagNames();
}

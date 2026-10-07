import '../entities/inbox_item.dart';

/// Kontrak akses item Smart Inbox (PHASE 13).
abstract interface class InboxRepository {
  /// Item urut terbaru; difilter [resolution] bila diisi.
  Stream<List<InboxItem>> watchItems({InboxResolution? resolution});

  Future<InboxItem?> getById(int id);

  /// Menambahkan item terbuka dari hasil pemrosesan chat yang belum
  /// berhasil dipahami.
  Future<int> addOpen({
    int? chatMessageId,
    required String rawText,
    String? suggestion,
  });

  Future<bool> markConverted(int id, {String? entityType, int? entityId});

  Future<bool> markDiscarded(int id);

  /// Menandai semua item terbuka yang teksnya sama dengan [rawText]
  /// (abaikan besar-kecil huruf/spasi) sebagai converted — dipanggil saat
  /// teks yang sama akhirnya berhasil dieksekusi lewat chat.
  Future<void> resolveByText(String rawText, {String? entityType});
}

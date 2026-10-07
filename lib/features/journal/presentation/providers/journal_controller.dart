import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/repositories/journal_repository_impl.dart';
import '../../domain/entities/journal_entry.dart';

/// Daftar entri jurnal urut terbaru; [query] kosong = semua entri.
final journalEntriesProvider = StreamProvider.autoDispose
    .family<List<JournalEntry>, String>((ref, query) {
      final trimmed = query.trim();
      return ref
          .watch(journalRepositoryProvider)
          .watchEntries(query: trimmed.isEmpty ? null : trimmed);
    });

class JournalController extends Notifier<void> {
  @override
  void build() {}

  /// Menyimpan entri baru; [date] default hari ini (dari clock).
  Future<int> create({
    required String content,
    String? title,
    String? mood,
    String? date,
    List<String> tags = const [],
    String? source,
    String? rawInput,
    double? confidence,
  }) {
    final entry = JournalEntry(
      date: date ?? _isoDate(ref.read(clockProvider).now()),
      title: title,
      content: content,
      mood: mood,
      tags: tags,
      source: source,
      rawInput: rawInput,
      confidence: confidence,
    );
    return ref.read(journalRepositoryProvider).create(entry);
  }

  Future<bool> update(JournalEntry entry) =>
      ref.read(journalRepositoryProvider).update(entry);

  Future<bool> delete(int id) =>
      ref.read(journalRepositoryProvider).deleteById(id);

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final journalControllerProvider = NotifierProvider<JournalController, void>(
  JournalController.new,
);

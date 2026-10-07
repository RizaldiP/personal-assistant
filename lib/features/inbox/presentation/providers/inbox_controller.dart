import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/providers/pending_confirmation.dart';
import '../../../notes/data/repositories/note_repository_impl.dart';
import '../../../notes/domain/entities/note.dart';
import '../../data/repositories/inbox_repository_impl.dart';
import '../../domain/entities/inbox_item.dart';

/// Filter status chip di layar Inbox.
enum InboxStatusFilter {
  open('Terbuka'),
  done('Selesai'),
  all('Semua');

  const InboxStatusFilter(this.label);

  final String label;
}

/// State UI layar Inbox: filter status yang dipilih user.
class InboxUiState {
  const InboxUiState({this.filter = InboxStatusFilter.open});

  final InboxStatusFilter filter;
}

class InboxUiController extends Notifier<InboxUiState> {
  @override
  InboxUiState build() => const InboxUiState();

  void setFilter(InboxStatusFilter filter) {
    state = InboxUiState(filter: filter);
  }
}

final inboxUiProvider = NotifierProvider<InboxUiController, InboxUiState>(
  InboxUiController.new,
);

/// Semua item inbox (urut terbaru) — filtering status dilakukan di layar.
final inboxItemsProvider = StreamProvider<List<InboxItem>>(
  (ref) => ref.watch(inboxRepositoryProvider).watchItems(),
);

/// Menyimpan item inbox sebagai catatan (PHASE 13, aksi bottom sheet).
Future<void> saveInboxAsNote(WidgetRef ref, InboxItem item) async {
  final id = item.id;
  if (id == null) return;
  final noteId = await ref
      .read(noteRepositoryProvider)
      .create(Note(content: item.rawText));
  await ref
      .read(inboxRepositoryProvider)
      .markConverted(id, entityType: 'note', entityId: noteId);
}

/// Membuang item inbox tanpa konversi.
Future<void> discardInboxItem(WidgetRef ref, InboxItem item) async {
  final id = item.id;
  if (id == null) return;
  await ref.read(inboxRepositoryProvider).markDiscarded(id);
}

/// Mengirim teks item ke input chat lalu membuka layar chat; item tetap
/// terbuka dan baru ditandai selesai otomatis bila teksnya berhasil
/// dieksekusi (auto-resolve, PHASE 13).
void prepareInboxChatDraft(WidgetRef ref, InboxItem item) {
  ref.read(chatDraftProvider.notifier).set(item.rawText);
}

/// Label saran intent untuk subtitle daftar inbox.
String inboxSuggestionLabel(String? suggestion) => switch (suggestion) {
  'create_todo' => 'Saran: todo',
  'create_reminder' => 'Saran: reminder',
  'create_note' => 'Saran: catatan',
  'create_journal' => 'Saran: jurnal',
  'create_idea' => 'Saran: ide',
  'create_expense' => 'Saran: pengeluaran',
  'create_shopping' => 'Saran: belanja',
  _ => '',
};

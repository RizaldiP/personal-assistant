import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/idea_repository_impl.dart';
import '../../domain/entities/idea.dart';

/// Daftar ide urut terbaru; [query] kosong = semua ide.
final ideasProvider = StreamProvider.autoDispose.family<List<Idea>, String>((
  ref,
  query,
) {
  final trimmed = query.trim();
  return ref
      .watch(ideaRepositoryProvider)
      .watchIdeas(query: trimmed.isEmpty ? null : trimmed);
});

class IdeaController extends Notifier<void> {
  @override
  void build() {}

  /// Menyimpan ide baru (status default `inbox`).
  Future<int> create({
    required String title,
    String? content,
    IdeaStatus status = IdeaStatus.inbox,
    List<String> tags = const [],
    String? source,
    String? rawInput,
    double? confidence,
  }) {
    return ref
        .read(ideaRepositoryProvider)
        .create(
          Idea(
            title: title,
            content: content,
            status: status,
            tags: tags,
            source: source,
            rawInput: rawInput,
            confidence: confidence,
          ),
        );
  }

  Future<bool> update(Idea idea) =>
      ref.read(ideaRepositoryProvider).update(idea);

  Future<bool> delete(int id) =>
      ref.read(ideaRepositoryProvider).deleteById(id);

  /// Mengubah status ide (mis. dari Inbox ke Working).
  Future<bool> setStatus(Idea idea, IdeaStatus status) =>
      ref.read(ideaRepositoryProvider).update(idea.copyWith(status: status));
}

final ideaControllerProvider = NotifierProvider<IdeaController, void>(
  IdeaController.new,
);

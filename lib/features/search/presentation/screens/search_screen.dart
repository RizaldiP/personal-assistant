import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/tag_chips.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../ideas/presentation/screens/ideas_screen.dart';
import '../../../journal/presentation/screens/journal_screen.dart';
import '../../../notes/presentation/screens/notes_screen.dart';
import '../../../shopping/presentation/screens/shopping_screen.dart';
import '../../../todo/presentation/screens/todo_screen.dart';
import '../../domain/search_result.dart';
import '../providers/search_providers.dart';

/// Layar pencarian global (PHASE 13): teks bebas difilter per tipe dan
/// per tag; ketikan di-debounce 250 ms agar pencarian tetap cepat.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  /// Teks hasil debounce (yang dipakai mencari).
  String _text = '';

  String _type = 'all';
  String? _tag;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _text = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = SearchQuery(
      text: _text.trim(),
      type: _type == 'all' ? null : _type,
      tag: _tag,
    );
    final showResults = query.text.isNotEmpty || query.tag != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Pencarian')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              key: const Key('search-input'),
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Cari tugas, catatan, jurnal, ...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          _FilterChips(
            selectedType: _type,
            selectedTag: _tag,
            onType: (type) => setState(() => _type = type),
            onTag: (tag) => setState(() => _tag = tag),
          ),
          Expanded(
            child: !showResults
                ? const EmptyState(
                    icon: Icons.search,
                    title: 'Mulai mencari',
                    message:
                        'Ketik kata kunci untuk menemukan tugas, reminder, '
                        'catatan, jurnal, ide, belanja, dan pengeluaran.',
                  )
                : ref
                      .watch(searchResultsProvider(query))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => const EmptyState(
                          icon: Icons.error_outline,
                          title: 'Gagal mencari',
                          message: 'Coba lagi sebentar lagi.',
                        ),
                        data: (results) => results.isEmpty
                            ? const EmptyState(
                                icon: Icons.search_off,
                                title: 'Tidak ada hasil',
                                message:
                                    'Coba kata kunci lain atau hapus filter.',
                              )
                            : _ResultList(results: results),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Chip filter tipe + tag (baris scroll horizontal).
class _FilterChips extends ConsumerWidget {
  const _FilterChips({
    required this.selectedType,
    required this.selectedTag,
    required this.onType,
    required this.onTag,
  });

  final String selectedType;
  final String? selectedTag;
  final ValueChanged<String> onType;
  final ValueChanged<String?> onTag;

  static const Map<String, String> _labels = {
    'all': 'Semua',
    SearchTypes.todo: 'Tugas',
    SearchTypes.reminder: 'Reminder',
    SearchTypes.note: 'Catatan',
    SearchTypes.journal: 'Jurnal',
    SearchTypes.idea: 'Ide',
    SearchTypes.shopping: 'Belanja',
    SearchTypes.expense: 'Keuangan',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(searchTagNamesProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final entry in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                key: Key('search-filter-${entry.key}'),
                label: Text(entry.value),
                selected: selectedType == entry.key,
                onSelected: (_) => onType(entry.key),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          ...tagsAsync.maybeWhen(
            data: (names) => [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  key: const Key('search-filter-tag-all'),
                  label: const Text('Semua tag'),
                  selected: selectedTag == null,
                  onSelected: (_) => onTag(null),
                ),
              ),
              for (final name in names)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    key: Key('search-tag-$name'),
                    label: Text('#$name'),
                    selected: selectedTag == name,
                    onSelected: (_) => onTag(name),
                  ),
                ),
            ],
            orElse: () => const [],
          ),
        ],
      ),
    );
  }
}

/// Hasil dikelompokkan per tipe sesuai urutan [SearchTypes.all].
class _ResultList extends StatelessWidget {
  const _ResultList({required this.results});

  final List<SearchResult> results;

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<SearchResult>>{};
    for (final result in results) {
      (sections[result.type] ??= []).add(result);
    }
    final orderedTypes = SearchTypes.all.where(
      (type) => sections.containsKey(type),
    );

    final children = <Widget>[];
    for (final type in orderedTypes) {
      final items = sections[type]!;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            _sectionLabel(type),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (final result in items) {
        children.add(_ResultTile(type: type, result: result));
      }
    }
    return ListView(children: children);
  }

  static String _sectionLabel(String type) => switch (type) {
    SearchTypes.todo => 'Tugas',
    SearchTypes.reminder => 'Reminder',
    SearchTypes.note => 'Catatan',
    SearchTypes.journal => 'Jurnal',
    SearchTypes.idea => 'Ide',
    SearchTypes.shopping => 'Belanja',
    SearchTypes.expense => 'Keuangan',
    _ => type,
  };
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.type, required this.result});

  final String type;
  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('search-result-$type-${result.id}'),
      leading: Icon(_iconFor(type)),
      title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.subtitle.isNotEmpty)
            Text(result.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (result.tags.isNotEmpty) TagChips(tags: result.tags),
        ],
      ),
      onTap: _routeFor(context, type),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    SearchTypes.todo => Icons.check_circle_outline,
    SearchTypes.reminder => Icons.alarm,
    SearchTypes.note => Icons.notes,
    SearchTypes.journal => Icons.menu_book_outlined,
    SearchTypes.idea => Icons.lightbulb_outline,
    SearchTypes.shopping => Icons.shopping_basket_outlined,
    SearchTypes.expense => Icons.account_balance_wallet_outlined,
    _ => Icons.description_outlined,
  };

  /// Reminder belum punya layar sendiri — hasilnya tampil tanpa navigasi.
  VoidCallback? _routeFor(BuildContext context, String type) => switch (type) {
    SearchTypes.todo => () => _push(context, const TodoScreen()),
    SearchTypes.note => () => _push(context, const NotesScreen()),
    SearchTypes.journal => () => _push(context, const JournalScreen()),
    SearchTypes.idea => () => _push(context, const IdeasScreen()),
    SearchTypes.shopping => () => _push(context, const ShoppingScreen()),
    SearchTypes.expense => () => _push(context, const FinanceScreen()),
    _ => null,
  };

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
  }
}

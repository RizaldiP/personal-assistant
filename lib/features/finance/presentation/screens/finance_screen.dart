import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/formatters/currency_formats.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../providers/finance_controller.dart';

/// Layar keuangan: budget, ringkasan harian/bulanan, dan daftar pengeluaran.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Keuangan')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah pengeluaran',
        onPressed: () => _promptAddExpense(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ErrorState(
            title: 'Keuangan gagal dimuat',
            onRetry: () => ref.invalidate(expensesProvider),
          ),
          data: (expenses) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryCard(expenses: expenses),
              Expanded(
                child: expenses.isEmpty
                    ? const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Belum ada pengeluaran',
                        message:
                            'Ketuk tombol + untuk mencatat, atau ketik di '
                            'percakapan seperti "tadi makan ayam 25 ribu".',
                      )
                    : _ExpenseList(expenses: expenses),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _promptAddExpense(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final description = TextEditingController();
    var category = ExpenseCategory.makanan;
    var date = ref.read(clockProvider).now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Tambah pengeluaran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal',
                    hintText: 'Misal: 25000',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    hintText: 'Misal: makan ayam geprek',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: ExpenseCategory.values.map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => category = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => date = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormats.longIndonesia(_isoYmd(date))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final value = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final name = description.text.trim();
    if (value == null || value <= 0 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal dan keterangan wajib diisi.')),
      );
      return;
    }
    try {
      await ref
          .read(financeControllerProvider.notifier)
          .addExpense(
            amount: value,
            category: category,
            description: name,
            date: _isoYmd(date),
          );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    }
  }

  static String _isoYmd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Kartu budget + ringkasan pengeluaran hari ini dan bulan ini.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = ref.watch(clockProvider).now();
    final today = _isoYmd(now);
    final monthPrefix = today.substring(0, 7);

    final todayTotal = expenses
        .where((e) => e.date == today)
        .fold<int>(0, (sum, e) => sum + e.amount);
    final monthTotal = expenses
        .where((e) => e.date.startsWith(monthPrefix))
        .fold<int>(0, (sum, e) => sum + e.amount);

    final budgetAsync = ref.watch(financeBudgetProvider);
    final budget = budgetAsync.asData?.value;

    final remaining = budget == null ? null : budget - monthTotal;

    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget == null
                      ? 'Belum ada budget bulan ini'
                      : 'Budget bulan ini · ${CurrencyFormats.idr(budget)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Atur budget',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _promptBudget(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (remaining != null)
            Text(
              remaining < 0
                  ? 'Melebihi budget ${CurrencyFormats.idr(remaining.abs())}'
                  : 'Sisa ${CurrencyFormats.idr(remaining)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: remaining < 0 ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _SummaryTile(label: 'Hari ini', amount: todayTotal),
              const SizedBox(width: AppSpacing.md),
              _SummaryTile(label: 'Bulan ini', amount: monthTotal),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptBudget(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: (ref.read(financeBudgetProvider).asData?.value ?? 0).toString(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Budget bulan ini'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal',
            prefixText: 'Rp ',
            hintText: 'Kosongkan untuk menghapus budget',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final value = int.tryParse(
      controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    try {
      await ref
          .read(financeControllerProvider.notifier)
          .setBudget(value == null || value <= 0 ? null : value);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    }
  }

  static String _isoYmd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CurrencyFormats.idr(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseList extends ConsumerWidget {
  const _ExpenseList({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    final today = _isoYmd(now);
    final yesterday = _isoYmd(now.subtract(const Duration(days: 1)));

    final grouped = <String, List<Expense>>{};
    for (final expense in expenses) {
      grouped.putIfAbsent(expense.date, () => []).add(expense);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        _SectionLabel('PENGELUARAN'),
        ...grouped.entries.map((entry) {
          final label = entry.key == today
              ? 'Hari ini'
              : entry.key == yesterday
              ? 'Kemarin'
              : DateFormats.longIndonesia(entry.key);
          return _DateGroup(label: label, expenses: entry.value);
        }),
      ],
    );
  }

  static String _isoYmd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({required this.label, required this.expenses});

  final String label;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...expenses.map((expense) => _ExpenseRow(expense: expense)),
      ],
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(_categoryIcon(expense.category), size: 20),
        ),
        title: Text(
          expense.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(expense.category.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-${CurrencyFormats.idr(expense.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            IconButton(
              tooltip: 'Hapus pengeluaran',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _remove(ref, context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(WidgetRef ref, BuildContext context) async {
    final id = expense.id;
    if (id == null) return;
    try {
      await ref.read(financeControllerProvider.notifier).removeExpense(id);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus. Coba lagi.')),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.sectionLabel(
          theme.textTheme,
        )?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

IconData _categoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.makanan => Icons.restaurant_outlined,
  ExpenseCategory.transport => Icons.directions_bus_outlined,
  ExpenseCategory.tagihan => Icons.receipt_long_outlined,
  ExpenseCategory.belanja => Icons.shopping_basket_outlined,
  ExpenseCategory.kesehatan => Icons.medical_services_outlined,
  ExpenseCategory.hiburan => Icons.sports_esports_outlined,
  ExpenseCategory.lainnya => Icons.category_outlined,
};

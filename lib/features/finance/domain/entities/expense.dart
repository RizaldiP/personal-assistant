import 'expense_category.dart';

/// Entitas pengeluaran milik domain — tidak bergantung pada drift maupun UI.
class Expense {
  const Expense({
    this.id,
    required this.amount,
    this.currency = 'IDR',
    this.category = ExpenseCategory.lainnya,
    required this.description,
    required this.date,
    this.paymentMethod,
    this.source,
    this.rawInput,
    this.confidence,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Nominal dalam integer (IDR tanpa desimal).
  final int amount;
  final String currency;
  final ExpenseCategory category;

  /// Deskripsi singkat (bukan teks mentah perintah).
  final String description;

  /// Tanggal kejadian `YYYY-MM-DD`.
  final String date;
  final String? paymentMethod;
  final String? source;
  final String? rawInput;
  final double? confidence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Expense copyWith({
    int? id,
    int? amount,
    String? currency,
    ExpenseCategory? category,
    String? description,
    String? date,
    String? paymentMethod,
    String? source,
    String? rawInput,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

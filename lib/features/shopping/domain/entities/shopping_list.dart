import 'shopping_item.dart';

enum ShoppingListStatus {
  open,
  done;

  static ShoppingListStatus parse(String? value) =>
      value == 'done' ? ShoppingListStatus.done : ShoppingListStatus.open;

  String get storageValue => name;
}

/// Entitas daftar belanja berikut item-itemnya (milik domain).
class ShoppingList {
  const ShoppingList({
    this.id,
    required this.title,
    this.status = ShoppingListStatus.open,
    this.date,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  final int? id;
  final String title;
  final ShoppingListStatus status;

  /// Rencana tanggal belanja `YYYY-MM-DD`, nullable.
  final String? date;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ShoppingItem> items;

  bool get isDone => status == ShoppingListStatus.done;

  ShoppingList copyWith({
    int? id,
    String? title,
    ShoppingListStatus? status,
    String? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ShoppingItem>? items,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

/// Entitas item belanja milik domain — tidak bergantung pada drift maupun UI.
class ShoppingItem {
  const ShoppingItem({
    this.id,
    required this.listId,
    required this.name,
    this.quantity,
    this.unit,
    this.isChecked = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int listId;
  final String name;

  /// Jumlah banyaknya (misal 2 untuk "2 kg").
  final double? quantity;

  /// Satuan (misal `kg`, `liter`, `pcs`).
  final String? unit;
  final bool isChecked;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShoppingItem copyWith({
    int? id,
    int? listId,
    String? name,
    double? quantity,
    String? unit,
    bool? isChecked,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

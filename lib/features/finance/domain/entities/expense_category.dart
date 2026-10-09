/// Kategori pengeluaran. Nilai penyimpanan memakai snake_case/lowercase.
enum ExpenseCategory {
  makanan('makanan'),
  transport('transport'),
  tagihan('tagihan'),
  belanja('belanja'),
  kesehatan('kesehatan'),
  hiburan('hiburan'),
  lainnya('lainnya');

  const ExpenseCategory(this.storageValue);

  final String storageValue;

  /// Label tampilan Bahasa Indonesia.
  String get label => switch (this) {
    ExpenseCategory.makanan => 'Makanan',
    ExpenseCategory.transport => 'Transport',
    ExpenseCategory.tagihan => 'Tagihan',
    ExpenseCategory.belanja => 'Belanja',
    ExpenseCategory.kesehatan => 'Kesehatan',
    ExpenseCategory.hiburan => 'Hiburan',
    ExpenseCategory.lainnya => 'Lainnya',
  };

  static ExpenseCategory parse(String? value) => values.firstWhere(
    (category) => category.storageValue == value,
    orElse: () => ExpenseCategory.lainnya,
  );
}

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

  static ExpenseCategory parse(String? value) => values.firstWhere(
    (category) => category.storageValue == value,
    orElse: () => ExpenseCategory.lainnya,
  );
}

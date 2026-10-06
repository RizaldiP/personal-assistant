/// Intent aplikasi. Nilai JSON memakai snake_case (lihat [storageValue]).
enum AppIntent {
  createReminder('create_reminder'),
  createTodo('create_todo'),
  createShopping('create_shopping'),
  createExpense('create_expense'),
  createNote('create_note'),
  createJournal('create_journal'),
  createIdea('create_idea'),
  updateItem('update_item'),
  deleteItem('delete_item'),
  completeItem('complete_item'),
  search('search'),
  unknown('unknown');

  const AppIntent(this.storageValue);

  final String storageValue;

  static AppIntent fromStorage(String? value) => values.firstWhere(
    (intent) => intent.storageValue == value,
    orElse: () => AppIntent.unknown,
  );
}

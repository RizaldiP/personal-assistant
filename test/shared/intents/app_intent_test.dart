import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

void main() {
  group('AppIntent.storageValue', () {
    test('known intents memakai snake_case', () {
      expect(AppIntent.createReminder.storageValue, 'create_reminder');
      expect(AppIntent.createTodo.storageValue, 'create_todo');
      expect(AppIntent.createShopping.storageValue, 'create_shopping');
      expect(AppIntent.createExpense.storageValue, 'create_expense');
      expect(AppIntent.createNote.storageValue, 'create_note');
      expect(AppIntent.createJournal.storageValue, 'create_journal');
      expect(AppIntent.createIdea.storageValue, 'create_idea');
      expect(AppIntent.unknown.storageValue, 'unknown');
    });
  });

  group('AppIntent.fromStorage', () {
    test('nilai yang dikenali dipetakan', () {
      expect(
        AppIntent.fromStorage('create_reminder'),
        AppIntent.createReminder,
      );
      expect(AppIntent.fromStorage('create_expense'), AppIntent.createExpense);
    });

    test('nilai asing jatuh ke unknown', () {
      expect(AppIntent.fromStorage('bukan_intent'), AppIntent.unknown);
      expect(AppIntent.fromStorage(null), AppIntent.unknown);
    });
  });
}

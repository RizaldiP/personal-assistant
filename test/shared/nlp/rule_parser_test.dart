import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';
import 'package:personal_offline/shared/nlp/rule_parser.dart';

void main() {
  final today = DateTime(2026, 10, 6);

  group('RuleParser.deteksi intent wajib', () {
    test('"besok jam 8 bayar listrik" -> create_reminder', () {
      final result = RuleParser(now: today).parse('besok jam 8 bayar listrik');

      expect(result.intent, AppIntent.createReminder);
      expect(result.isKnown, true);
      expect(result.confidence, 0.9);
      expect(result.needsConfirmation, false);
      expect(result.entities['title'], 'Bayar listrik');
      expect(result.entities['date'], '2026-10-07');
      expect(result.entities['time'], '08:00');
      expect(result.entities['priority'], 'normal');
    });

    test('"besok beli telur susu" -> create_shopping', () {
      final result = RuleParser(now: today).parse('besok beli telur susu');

      expect(result.intent, AppIntent.createShopping);
      expect(result.entities['items'], ['Telur', 'Susu']);
    });

    test('"tadi makan 25 ribu" -> create_expense', () {
      final result = RuleParser(now: today).parse('tadi makan 25 ribu');

      expect(result.intent, AppIntent.createExpense);
      expect(result.entities['amount'], 25000);
      expect(result.entities['currency'], 'IDR');
      expect(result.entities['category'], 'makanan');
      expect(result.entities['description'], 'Makan');
      expect(result.entities['date'], '2026-10-06');
    });

    test('"kemarin makan ayam 20 ribu" -> create_expense kemarin', () {
      final result = RuleParser(now: today).parse('kemarin makan ayam 20 ribu');

      expect(result.intent, AppIntent.createExpense);
      expect(result.entities['amount'], 20000);
      expect(result.entities['category'], 'makanan');
      expect(result.entities['description'], 'Ayam');
      expect(result.entities['date'], '2026-10-05');
    });

    test('"hari ini kerjakan laporan" -> create_todo', () {
      final result = RuleParser(now: today).parse('hari ini kerjakan laporan');

      expect(result.intent, AppIntent.createTodo);
      expect(result.entities['title'], 'Kerjakan laporan');
      expect(result.entities['due_date'], '2026-10-06');
      expect(result.entities['priority'], 'normal');
    });

    test('"3 hari lagi servis motor" -> create_todo', () {
      final result = RuleParser(now: today).parse('3 hari lagi servis motor');

      expect(result.intent, AppIntent.createTodo);
      expect(result.entities['title'], 'Servis motor');
      expect(result.entities['due_date'], '2026-10-09');
    });
  });

  group('RuleParser.intent tambahan', () {
    test('pengeluaran memakai prefiks Rp', () {
      final result = RuleParser(now: today).parse('beli bensin Rp50.000');

      expect(result.intent, AppIntent.createExpense);
      expect(result.entities['amount'], 50000);
      expect(result.entities['category'], 'transport');
      expect(result.entities['description'], 'Bensin');
    });

    test('tagihan listrik masuk kategori tagihan', () {
      final result = RuleParser(now: today).parse('bayar listrik 350 ribu');

      expect(result.intent, AppIntent.createExpense);
      expect(result.entities['amount'], 350000);
      expect(result.entities['category'], 'tagihan');
      expect(result.entities['description'], 'Listrik');
    });

    test('belanja tanpa nominal', () {
      final result = RuleParser(now: today).parse('belanja sayur bayam');

      expect(result.intent, AppIntent.createShopping);
    });

    test('pengingat lewat kata "jangan lupa"', () {
      final result = RuleParser(now: today).parse('jangan lupa bayar listrik');

      expect(result.intent, AppIntent.createReminder);
      expect(result.entities['title'], 'Bayar listrik');
      expect(result.entities['date'], '2026-10-06');
    });

    test('tugas dengan jam tidak menimpa pencarian teratur', () {
      final result = RuleParser(
        now: today,
      ).parse('jam 9 selesaikan presentasi');

      expect(result.intent, AppIntent.createReminder);
      expect(result.entities['time'], '09:00');
      expect(result.entities['title'], 'Selesaikan presentasi');
    });

    test('jurnal deteksi suasana hati', () {
      final result = RuleParser(now: today).parse('hari ini capek banget');

      expect(result.intent, AppIntent.createJournal);
      expect(result.entities['mood'], 'capek');
      expect(result.entities['content'], 'Capek banget');
    });

    test('ide via awalan "ide:"', () {
      final result = RuleParser(
        now: today,
      ).parse('ide: aplikasi pemantau utang');

      expect(result.intent, AppIntent.createIdea);
      expect(result.entities['content'], 'Aplikasi pemantau utang');
    });

    test('catatan via awalan "catat:"', () {
      final result = RuleParser(now: today).parse('catat: resep rendang');

      expect(result.intent, AppIntent.createNote);
      expect(result.entities['content'], 'Resep rendang');
    });

    test('kata pertama "ide" membuat idea', () {
      final result = RuleParser(now: today).parse('ide skema cicilan');

      expect(result.intent, AppIntent.createIdea);
      expect(result.entities['content'], 'Skema cicilan');
    });

    test('belanja jam dengan berpengaruh nominal jadi pengeluaran', () {
      final result = RuleParser(now: today).parse('beli kopi 20 ribu');

      expect(result.intent, AppIntent.createExpense);
      expect(result.entities['category'], 'makanan');
      expect(result.entities['description'], 'Kopi');
    });
  });

  group('RuleParser.tidak dikenal', () {
    test('teks acak -> unknown + butuh konfirmasi', () {
      final result = RuleParser(now: today).parse('qwerty asdf');

      expect(result.intent, AppIntent.unknown);
      expect(result.isKnown, false);
      expect(result.needsConfirmation, true);
    });
  });
}

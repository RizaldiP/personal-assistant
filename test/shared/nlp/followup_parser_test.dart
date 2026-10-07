import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';
import 'package:personal_offline/shared/nlp/followup_parser.dart';

void main() {
  // Referensi tetap: Senin, 5 Oktober 2026 → besok = 6 Oktober 2026.
  FollowUpParser parser() => FollowUpParser(now: DateTime(2026, 10, 5, 9));

  group('ubah / ganti / jadikan', () {
    test('ubah jadi jam 10 → updateItem dengan time', () {
      final result = parser().parse('ubah jadi jam 10');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities['time'], '10:00');
      expect(result.entities.containsKey('date'), isFalse);
      expect(result.entities.containsKey('title'), isFalse);
      expect(result.entities.containsKey('snooze'), isFalse);
      expect(result.confidence, 0.95);
    });

    test('ubah jam jadi 14:30 → updateItem dengan time HH:mm', () {
      final result = parser().parse('ubah jam jadi 14:30');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities['time'], '14:30');
    });

    test('jadikan besok → updateItem dengan date', () {
      final result = parser().parse('jadikan besok');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities['date'], '2026-10-06');
      expect(result.entities.containsKey('time'), isFalse);
    });

    test('ganti jadi beli susu → updateItem dengan judul baru', () {
      final result = parser().parse('ganti jadi beli susu');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities['title'], 'Beli susu');
      expect(result.entities.containsKey('date'), isFalse);
    });

    test('tolong di depan tetap dikenali', () {
      final result = parser().parse('tolong ubah jadi jam 7');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities['time'], '07:00');
    });

    test('ubah tanpa rincian → updateItem tanpa entity', () {
      final result = parser().parse('ubah');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities, isEmpty);
    });
  });

  group('tunda (snooze)', () {
    test('tunda 2 jam → snooze_minutes 120', () {
      final result = parser().parse('tunda 2 jam');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.updateItem);
      expect(result.entities['snooze'], isTrue);
      expect(result.entities['snooze_minutes'], 120);
    });

    test('tunda 30 menit → snooze_minutes 30', () {
      final result = parser().parse('tunda 30 menit');

      expect(result, isNotNull);
      expect(result!.entities['snooze_minutes'], 30);
    });

    test('tunda besok → snooze dengan date, tanpa durasi', () {
      final result = parser().parse('tunda besok');

      expect(result, isNotNull);
      expect(result!.entities['snooze'], isTrue);
      expect(result.entities['date'], '2026-10-06');
      expect(result.entities.containsKey('snooze_minutes'), isFalse);
    });

    test('tunda jam 10 → snooze dengan time, tanpa durasi', () {
      final result = parser().parse('tunda jam 10');

      expect(result, isNotNull);
      expect(result!.entities['snooze'], isTrue);
      expect(result.entities['time'], '10:00');
    });

    test('tunda tanpa durasi → snooze tanpa entity', () {
      final result = parser().parse('tunda');

      expect(result, isNotNull);
      expect(result!.entities['snooze'], isTrue);
      expect(result.entities, hasLength(1));
    });
  });

  group('selesaikan / hapus', () {
    test('selesaikan → completeItem', () {
      final result = parser().parse('selesaikan');

      expect(result, isNotNull);
      expect(result!.intent, AppIntent.completeItem);
      expect(result.entities, isEmpty);
    });

    test('done dan centang → completeItem', () {
      expect(parser().parse('done')?.intent, AppIntent.completeItem);
      expect(parser().parse('centang')?.intent, AppIntent.completeItem);
      expect(parser().parse('tandai selesai')?.intent, AppIntent.completeItem);
    });

    test('hapus / buang / tolong hapus → deleteItem', () {
      expect(parser().parse('hapus')?.intent, AppIntent.deleteItem);
      expect(parser().parse('buang')?.intent, AppIntent.deleteItem);
      expect(parser().parse('tolong hapus')?.intent, AppIntent.deleteItem);
    });
  });

  group('bukan perintah lanjutan → null', () {
    test('kalimat pembuatan tetap milik Rule Parser', () {
      expect(parser().parse('besok jam 8 bayar listrik'), isNull);
      expect(parser().parse('besok beli beras minyak telur'), isNull);
      expect(parser().parse('catatan: nomor penting 1234'), isNull);
      expect(parser().parse('tadi makan ayam 25 ribu'), isNull);
      expect(parser().parse('hari ini capek banget'), isNull);
      expect(parser().parse('ide: aplikasi inventory kapal'), isNull);
    });

    test('kata kerja di tengah kalimat tidak memicu follow-up', () {
      expect(parser().parse('besok selesaikan laporan kapal'), isNull);
      expect(parser().parse('jangan lupa bayar listrik'), isNull);
      expect(parser().parse('sudah selesai deh'), isNull);
    });

    test('teks kosong dan huruf kapital/spasi berlebih aman', () {
      expect(parser().parse(''), isNull);
      expect(parser().parse('   '), isNull);
      expect(parser().parse('  UBah JADI jam 10 ')?.entities['time'], '10:00');
    });
  });
}

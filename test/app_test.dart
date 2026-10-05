import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_offline/app.dart';
import 'package:personal_offline/features/home/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: PersonalOfflineApp()));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Home', () {
    testWidgets('menampilkan sapaan, tanggal, section hari ini, dan input', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.textContaining('Selamat'), findsOneWidget);
      expect(find.text('HARI INI'), findsOneWidget);
      expect(find.text('Belum ada tugas hari ini'), findsOneWidget);
      expect(find.text('Apa yang ingin kamu lakukan?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('format tanggal memakai Bahasa Indonesia', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeScreen(today: DateTime(2026, 10, 5))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Senin, 5 Oktober 2026'), findsOneWidget);
    });

    testWidgets('input menampilkan pesan bahwa chat belum tersedia', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Fitur chat belum tersedia.'), findsOneWidget);
    });
  });

  group('Navigasi', () {
    testWidgets('bottom navigation berpindah antar lima layar', (tester) async {
      await _pumpApp(tester);
      expect(find.text('HARI INI'), findsOneWidget);

      await tester.tap(_navDestination('Kalender'));
      await tester.pumpAndSettle();
      expect(find.text('Kalender kosong'), findsOneWidget);

      await tester.tap(_navDestination('Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Inbox kosong'), findsOneWidget);

      await tester.tap(_navDestination('Insight'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada data'), findsOneWidget);

      await tester.tap(_navDestination('Pengaturan'));
      await tester.pumpAndSettle();
      expect(find.text('Mode tema'), findsOneWidget);

      await tester.tap(_navDestination('Beranda'));
      await tester.pumpAndSettle();
      expect(find.text('HARI INI'), findsOneWidget);
    });
  });

  group('Tema', () {
    testWidgets('bisa berpindah light, dark, dan sistem', (tester) async {
      await _pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(app.themeMode, ThemeMode.system);

      await tester.tap(_navDestination('Pengaturan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terang'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });

    testWidgets('pilihan tema tersimpan ke preferensi lokal', (tester) async {
      await _pumpApp(tester);

      await tester.tap(_navDestination('Pengaturan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), 'dark');
    });

    testWidgets('mode tersimpan dipakai ulang saat aplikasi dibuka', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});

      await _pumpApp(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}

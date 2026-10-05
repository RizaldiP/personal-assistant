import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/settings/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController', () {
    test('default sistem ketika belum ada preferensi', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(sharedPreferencesProvider.future);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('membaca preferensi yang tersimpan', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'light'});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(sharedPreferencesProvider.future);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setMode memperbarui state dan menyimpan ke preferensi', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(sharedPreferencesProvider.future);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), 'dark');
    });

    test('nilai tidak dikenal jatuh ke sistem', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'neon'});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(sharedPreferencesProvider.future);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });
}

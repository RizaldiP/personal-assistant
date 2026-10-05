import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan preferensi aplikasi berbasis SharedPreferences.
///
/// Ini cache preferensi UI saja. Sumber kebenaran data utama aplikasi tetap
/// database lokal (PHASE 2).
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

const String _themeModeKey = 'themeMode';

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = switch (ref.watch(sharedPreferencesProvider)) {
      AsyncData<SharedPreferences>(:final value) => value,
      _ => null,
    };
    if (prefs == null) return ThemeMode.system;
    return decode(prefs.getString(_themeModeKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = switch (ref.read(sharedPreferencesProvider)) {
      AsyncData<SharedPreferences>(:final value) => value,
      _ => null,
    };
    if (prefs == null) return;
    await prefs.setString(_themeModeKey, encode(mode));
  }

  static String encode(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };

  static ThemeMode decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

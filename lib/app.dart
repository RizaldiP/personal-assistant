import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_shell.dart';
import 'core/settings/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widget/widget_sync_scope.dart';

class PersonalOfflineApp extends ConsumerWidget {
  const PersonalOfflineApp({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return WidgetSyncScope(
      navigatorKey: _navigatorKey,
      child: MaterialApp(
        title: 'Personal Offline',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const AppShell(),
      ),
    );
  }
}

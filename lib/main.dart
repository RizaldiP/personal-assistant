import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/notification_scheduler.dart';
import 'core/widget/home_widget_service.dart';

/// Titik masuk aplikasi.
///
/// [overrides] hanya dipakai pengujian (integration test) untuk menyuntikkan
/// database in-memory, jam tetap, dan scheduler notifikasi palsu; aplikasi
/// asli tidak mengirim overrides apa pun. Scheduler dibaca dari container
/// agar pengujian tidak memunculkan dialog izin sistem nyata.
Future<void> main({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');

  final container = ProviderContainer(overrides: overrides);
  final scheduler = container.read(notificationSchedulerProvider);
  await scheduler.initialize();
  await scheduler.requestPermissions();

  final homeWidgetService = container.read(homeWidgetServiceProvider);
  await homeWidgetService.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PersonalOfflineApp(),
    ),
  );
}

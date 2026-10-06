import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');

  final scheduler = FlutterLocalNotificationsScheduler();
  await scheduler.initialize();
  await scheduler.requestPermissions();

  runApp(const ProviderScope(child: PersonalOfflineApp()));
}

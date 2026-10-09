import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/todo/data/repositories/task_repository_impl.dart';
import '../../features/todo/domain/entities/task.dart';
import '../../features/todo/presentation/providers/task_controller.dart';
import '../database/database_provider.dart';
import 'widget_keys.dart';
import 'widget_sync.dart';

/// Callback yang dijalankan di isolate background saat pengguna menekan ikon
/// centang pada widget.
///
/// `@pragma('vm:entry-point')` wajib agar tidak di-tree-shake pada rilis.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != WidgetKeys.toggleHost) return;
  final id = int.tryParse(uri.queryParameters[WidgetKeys.toggleIdParam] ?? '');
  if (id == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  // Daftarkan plugin (path_provider) untuk isolate background agar drift dapat
  // membuka file database yang sama (shareAcrossIsolates).
  DartPluginRegistrant.ensureInitialized();

  final container = ProviderContainer();
  try {
    final repository = container.read(taskRepositoryProvider);
    final task = await repository.getById(id);
    if (task == null) return;

    await container
        .read(todoControllerProvider.notifier)
        .setCompleted(task, task.status != TaskStatus.done);

    final now = container.read(clockProvider).now();
    final tasks = await repository.watchTasksForWidgetOn(_isoDate(now)).first;
    await pushTodayTasksToWidget(tasks);
  } finally {
    container.dispose();
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

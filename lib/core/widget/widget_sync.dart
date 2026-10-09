import 'package:home_widget/home_widget.dart';

import '../../features/todo/domain/entities/task.dart';
import 'today_tasks_codec.dart';
import 'widget_keys.dart';

/// Menyimpan snapshot [tasks] ke penyimpanan widget dan meminta redraw.
///
/// Dipakai dari isolate UI ([HomeWidgetServiceImpl]) maupun dari isolate
/// background (callback interaktif widget).
Future<void> pushTodayTasksToWidget(List<Task> tasks) async {
  await HomeWidget.saveWidgetData<String>(
    WidgetKeys.todayTasksJsonKey,
    encodeTodayTasks(tasks),
  );
  await HomeWidget.saveWidgetData<String>(
    WidgetKeys.todayTasksUpdatedAtKey,
    DateTime.now().toUtc().toIso8601String(),
  );
  await HomeWidget.updateWidget(
    qualifiedAndroidName: WidgetKeys.providerQualifiedName,
  );
}

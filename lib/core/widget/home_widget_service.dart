import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/todo/domain/entities/task.dart';
import 'widget_callbacks.dart';
import 'widget_keys.dart';
import 'widget_sync.dart';

/// Abstraksi komunikasi dengan widget layar utama.
///
/// Memisahkan paket `home_widget` dari domain agar UI dapat diuji tanpa plugin
/// platform (lihat `FakeHomeWidgetService`).
abstract interface class HomeWidgetService {
  /// Mendaftarkan callback Dart yang dipanggil dari widget (interaktivitas).
  Future<void> initialize();

  /// Menyimpan snapshot tugas hari ini dan meminta widget menggambar ulang.
  Future<void> syncTodayTasks(List<Task> tasks);

  /// URI bila app ini baru diluncurkan dari widget (sekali), selain itu null.
  Future<Uri?> initiallyLaunchedUri();

  /// Stream URI saat app yang sudah berjalan diklik dari widget.
  Stream<Uri?> widgetClicked();

  /// Apakah launcher mendukung pin widget (Android API 26+).
  Future<bool> isPinSupported();

  /// Meminta launcher menyematkan widget ke layar utama.
  Future<void> requestPin();
}

/// Implementasi asli memakai paket `home_widget`.
class HomeWidgetServiceImpl implements HomeWidgetService {
  const HomeWidgetServiceImpl();

  @override
  Future<void> initialize() =>
      HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);

  @override
  Future<void> syncTodayTasks(List<Task> tasks) => pushTodayTasksToWidget(tasks);

  @override
  Future<Uri?> initiallyLaunchedUri() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> widgetClicked() => HomeWidget.widgetClicked;

  @override
  Future<bool> isPinSupported() async =>
      (await HomeWidget.isRequestPinWidgetSupported()) ?? false;

  @override
  Future<void> requestPin() => HomeWidget.requestPinWidget(
    qualifiedAndroidName: WidgetKeys.providerQualifiedName,
  );
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => const HomeWidgetServiceImpl(),
);

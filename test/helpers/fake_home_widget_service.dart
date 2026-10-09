import 'dart:async';

import 'package:personal_offline/core/widget/home_widget_service.dart';
import 'package:personal_offline/features/todo/domain/entities/task.dart';

/// Fake [HomeWidgetService] untuk test tanpa plugin platform.
class FakeHomeWidgetService implements HomeWidgetService {
  final StreamController<Uri?> _clicks = StreamController<Uri?>.broadcast();

  /// Setiap snapshot tugas yang dikirim ke widget (urut waktu pemanggilan).
  final List<List<Task>> synced = [];

  /// URI yang dikembalikan [initiallyLaunchedUri] (default null).
  Uri? initialUri;

  /// Hasil [isPinSupported].
  bool pinSupported = true;

  /// Jumlah pemanggilan [requestPin].
  int pinRequests = 0;

  /// Apakah [initialize] sudah dipanggil.
  bool initialized = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> syncTodayTasks(List<Task> tasks) async {
    synced.add(List.of(tasks));
  }

  @override
  Future<Uri?> initiallyLaunchedUri() async => initialUri;

  @override
  Stream<Uri?> widgetClicked() => _clicks.stream;

  @override
  Future<bool> isPinSupported() async => pinSupported;

  @override
  Future<void> requestPin() async {
    pinRequests++;
  }

  /// Memancarkan klik widget (simulasi).
  void emitClick(Uri uri) => _clicks.add(uri);

  Future<void> dispose() => _clicks.close();
}

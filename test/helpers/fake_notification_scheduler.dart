import 'package:personal_offline/core/services/notification_scheduler.dart';

/// Fake [NotificationScheduler] yang mencatat jadwal & pembatalan di memori.
class FakeNotificationScheduler implements NotificationScheduler {
  bool initializeCalled = false;
  bool permissionGranted = true;
  int scheduleCalls = 0;

  /// id → waktu lokal jadwal yang tersimpan.
  final Map<int, DateTime> scheduled = {};

  /// id yang pernah dibatalkan (urut pemanggilan).
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    scheduleCalls++;
    scheduled[id] = at;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

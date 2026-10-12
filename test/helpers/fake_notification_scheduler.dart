import 'package:personal_offline/core/services/notification_scheduler.dart';

/// Fake [NotificationScheduler] yang mencatat jadwal & pembatalan di memori.
class FakeNotificationScheduler implements NotificationScheduler {
  bool initializeCalled = false;
  bool permissionGranted = true;
  int scheduleCalls = 0;

  /// Status izin yang dilaporkan ke UI.
  bool notificationsEnabledValue = true;
  bool exactAlarmsEnabledValue = false;

  /// Jumlah pemanggilan notifikasi uji.
  int testNotificationCount = 0;

  /// id → waktu lokal jadwal yang tersimpan.
  final Map<int, DateTime> scheduled = {};

  /// id → jadwal harian berulang (jam, menit).
  final Map<int, ({int hour, int minute})> dailyScheduled = {};

  /// id → isi (judul, body) notifikasi harian terakhir.
  final Map<int, ({String title, String body})> dailyContent = {};

  /// id yang pernah dibatalkan (urut pemanggilan).
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<bool> notificationsEnabled() async => notificationsEnabledValue;

  @override
  Future<bool> canScheduleExactNotifications() async => exactAlarmsEnabledValue;

  @override
  Future<void> showTestNotification() async {
    testNotificationCount++;
  }

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
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    scheduleCalls++;
    dailyScheduled[id] = (hour: hour, minute: minute);
    dailyContent[id] = (title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    dailyScheduled.remove(id);
    dailyContent.remove(id);
  }
}

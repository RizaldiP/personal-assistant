import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Penjadwal notifikasi lokal.
///
/// Diuji lewat implementasi palsu; implementasi asli [FlutterLocal
/// NotificationsScheduler] berkomunikasi dengan OS (Android/iOS) sehingga
/// notifikasi tetap tampil meski aplikasi ditutup, layar terkunci, atau
/// offline (dijadwalkan oleh OS, bukan saat runtime).
abstract interface class NotificationScheduler {
  /// Menyiapkan plugin, zona waktu lokal, dan kanal notifikasi.
  Future<void> initialize();

  /// Meminta izin notifikasi + alarm presisi (Android 13+/12+).
  /// Mengembalikan `true` bila izin notifikasi diberikan.
  Future<bool> requestPermissions();

  /// Menjadwalkan [at] (waktu lokal) satu kali. Dijadwalkan hanya bila masih
  /// di masa depan.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancel(int id);
}

class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  FlutterLocalNotificationsScheduler();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'reminders',
    'Reminder',
    description: 'Notifikasi pengingat pribadi',
    importance: Importance.high,
  );

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      // Bila plugin zona waktu tidak tersedia, `tz.local` tetap dipakai.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    await android.requestExactAlarmsPermission();
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!at.isAfter(DateTime.now())) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Android 14+ tidak memberikan SCHEDULE_EXACT_ALARM secara otomatis.
    // Bila belum diizinkan, jadwalkan "inexact" agar notifikasi tetap tampil
    // (hanya mungkin tidak presisi ke detik), alih-alih gagal sama sekali.
    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      if (await android?.canScheduleExactNotifications() ?? false) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    } on Object {
      // Gagal mengecek izin → pakai jalur aman (inexact).
    }

    final scheduledDate = tz.TZDateTime.from(at, tz.local);
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Reminder',
        channelDescription: 'Notifikasi pengingat pribadi',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: mode,
      );
    } on Object {
      // Exact ditolak saat eksekusi → ulangi dengan mode inexact.
      if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

/// Scheduler default aplikasi. Test meng-override dengan implementasi palsu
/// agar tidak menyentuh platform channel.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => FlutterLocalNotificationsScheduler(),
);

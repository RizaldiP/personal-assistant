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

  /// Apakah notifikasi aplikasi sedang diizinkan (Android 13+).
  Future<bool> notificationsEnabled();

  /// Apakah OS mengizinkan alarm presisi (Android 12+).
  Future<bool> canScheduleExactNotifications();

  /// Menampilkan notifikasi uji untuk memverifikasi kanal & izin.
  Future<void> showTestNotification();

  /// Menjadwalkan [at] (waktu lokal) satu kali. Dijadwalkan hanya bila masih
  /// di masa depan.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Menjadwalkan notifikasi berulang **setiap hari** pada jam [hour]:[minute]
  /// (waktu lokal). `cancel` dengan id yang sama menghentikannya.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
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

  /// Zona waktu default bila deteksi perangkat gagal. Aplikasi ditargetkan
  /// untuk pengguna Indonesia (WIB), dan ini mencegah notifikasi dinding-jam
  /// (digest 08.00) memakai UTC secara diam-diam.
  static const String _fallbackZone = 'Asia/Jakarta';

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(await _resolveLocalZone());

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

  /// Menentukan lokasi zona waktu: pakai zona perangkat bila tersedia,
  /// selain itu [fallbackZone] (mis. WIB) agar waktu dinding tetap benar.
  Future<tz.Location> _resolveLocalZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(info.identifier);
    } on Object {
      // Lanjut ke fallback.
    }
    try {
      return tz.getLocation(_fallbackZone);
    } on Object {
      return tz.UTC;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    // Minta izin notifikasi lebih dulu agar dialog runtime tampil sebelum
    // halaman Setelan "Alarm & pengingat" dibuka (bisa menutupi dialog).
    final granted = await android.requestNotificationsPermission() ?? false;
    try {
      await android.requestExactAlarmsPermission();
    } on Object {
      // Diabaikan: bila ditolak, penjadwalan jatuh ke mode inexact.
    }
    return granted;
  }

  @override
  Future<bool> notificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    try {
      return await android.areNotificationsEnabled() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> canScheduleExactNotifications() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> showTestNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Reminder',
        channelDescription: 'Notifikasi pengingat pribadi',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: 900099,
      title: 'Uji notifikasi',
      body: 'Jika kamu melihat ini, notifikasi Personal Offline berfungsi.',
      notificationDetails: details,
    );
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!at.isAfter(DateTime.now())) return;
    await _zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
    );
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
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
        matchDateTimeComponents: matchDateTimeComponents,
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
        matchDateTimeComponents: matchDateTimeComponents,
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

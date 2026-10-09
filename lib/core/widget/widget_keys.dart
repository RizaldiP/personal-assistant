/// Konstanta bersama untuk widget layar utama Android.
///
/// Dipakai oleh lapisan Dart ([home_widget]) dan harus sama dengan nilai yang
/// dipakai `TodayTasksWidgetProvider.kt` serta `AndroidManifest.xml`.
abstract final class WidgetKeys {
  /// Nama class `AppWidgetProvider` native (fully qualified) — dipakai saat
  /// meminta update / pin lewat `home_widget`.
  static const String providerQualifiedName =
      'com.personaloffline.personal_offline.TodayTasksWidgetProvider';

  /// Kunci SharedPreferences tempat snapshot JSON tugas hari ini.
  static const String todayTasksJsonKey = 'today_tasks_json';

  /// Kunci waktu sinkronisasi terakhir (ISO 8601, UTC) — untuk diagnosa.
  static const String todayTasksUpdatedAtKey = 'today_tasks_updated_at';

  /// Skema URI deep-link dari widget.
  static const String scheme = 'personaloffline';

  /// Host URI untuk membuka layar Percakapan.
  static const String chatHost = 'chat';

  /// Host URI untuk menandai tugas selesai/belum dari widget.
  static const String toggleHost = 'toggle';

  /// Nama parameter id tugas pada URI toggle.
  static const String toggleIdParam = 'id';

  /// Uri deep-link ke layar Percakapan.
  static Uri get chatUri => Uri.parse('$scheme://$chatHost');

  /// Uri toggle untuk tugas [id].
  static Uri toggleUri(int id) =>
      Uri.parse('$scheme://$toggleHost?$toggleIdParam=$id');
}

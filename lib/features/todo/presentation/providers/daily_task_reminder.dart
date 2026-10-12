import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_scheduler.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';

/// Id notifikasi tetap untuk digest tugas harian. Reminder biasa memakai id
/// barisnya (kecil), sehingga id tinggi ini tidak bertabrakan.
const int dailyTasksNotificationId = 900001;

/// Jam notifikasi digest tugas harian.
const int dailyTasksHour = 8;
const int dailyTasksMinute = 0;

/// Mengelola satu notifikasi harian pukul 08.00 yang mengingatkan semua tugas
/// yang belum selesai. Tugas yang belum dicentang otomatis ikut diingatkan
/// hari-hari berikutnya sampai selesai (carry-over).
///
/// Isi notifikasi berulang ini disusun ulang setiap kali daftar tugas berubah
/// atau aplikasi dibuka, sehingga tetap relevan.
class DailyTaskReminderController extends Notifier<void> {
  @override
  void build() {}

  /// Menjadwalkan ulang digest: jadwalkan bila ada tugas pending, batalkan
  /// bila tidak ada. Semua galat ditelan agar tidak menjatuhkan aplikasi/chat.
  Future<void> reconcile() async {
    try {
      final tasks = await ref.read(taskRepositoryProvider).getAll();
      final pending = tasks
          .where((task) => task.status == TaskStatus.pending)
          .toList();
      final scheduler = ref.read(notificationSchedulerProvider);

      if (pending.isEmpty) {
        await scheduler.cancel(dailyTasksNotificationId);
        return;
      }

      await scheduler.scheduleDaily(
        id: dailyTasksNotificationId,
        title: 'Tugas belum selesai',
        body: _body(pending),
        hour: dailyTasksHour,
        minute: dailyTasksMinute,
      );
    } on Object {
      // Sinkronisasi digest tidak boleh menggagalkan aksi lain.
    }
  }

  /// Isi notifikasi: jumlah tugas + daftar judul (maksimal lima).
  static String _body(List<Task> pending) {
    const maxTitles = 5;
    final titles = pending.map((task) => task.title.trim()).toList();
    final shown = titles.take(maxTitles).join(', ');
    final remaining = titles.length - maxTitles;
    final suffix = remaining > 0 ? ', dan $remaining lainnya' : '';
    return '${pending.length} tugas belum selesai: $shown$suffix';
  }
}

final dailyTaskReminderProvider =
    NotifierProvider<DailyTaskReminderController, void>(
      DailyTaskReminderController.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/recurrence_calculator.dart';
import '../../domain/reminder_schedule.dart';

/// Reminder aktif untuk layar/tampilan (sumber kebenaran database).
final activeRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchActive();
});

/// Mengatur siklus hidup reminder: jadwal, batalkan, tunda (snooze), selesai,
/// dan lanjutkan pengulangan saat notifikasi berbunyi.
class ReminderController extends Notifier<void> {
  @override
  void build() {}

  /// Menyimpan [reminder] lalu menjadwalkan notifikasinya (bila masih di masa
  /// depan). Mengembalikan id baru.
  Future<int> create(Reminder reminder) async {
    final id = await ref.read(reminderRepositoryProvider).create(reminder);
    final at = _fireTime(reminder);
    if (at != null) await _schedule(id, reminder.title, at);
    return id;
  }

  /// Membatalkan notifikasi dan menandai reminder [id] sebagai `dismissed`.
  Future<bool> cancel(int id) async {
    final reminder = await _getActive(id);
    if (reminder == null) return false;
    await ref.read(notificationSchedulerProvider).cancel(id);
    return _save(reminder.copyWith(status: ReminderStatus.dismissed));
  }

  /// Menghapus reminder [id] sekaligus membatalkan notifikasinya.
  Future<bool> delete(int id) async {
    await ref.read(notificationSchedulerProvider).cancel(id);
    return ref.read(reminderRepositoryProvider).delete(id);
  }

  /// Menyimpan perubahan [reminder] dan menjadwalkan ulang notifikasinya
  /// (dipakai perintah "ubah"/"tunda" di chat, PHASE 12).
  Future<bool> update(Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return false;
    await ref.read(notificationSchedulerProvider).cancel(id);
    final saved = await _save(reminder);
    if (saved) {
      final at = _fireTime(reminder);
      if (at != null) await _schedule(id, reminder.title, at);
    }
    return saved;
  }

  /// Menunda reminder [id] selama [duration] dari waktu sekarang; notifikasi
  /// dijadwalkan ulang ke `snoozed_until` / `next_fire_at`.
  Future<bool> snooze(int id, Duration duration) async {
    final reminder = await _getActive(id);
    if (reminder == null) return false;
    final until = ref.read(clockProvider).now().add(duration);
    final epoch = reminderToEpochUtc(until);
    final saved = await _save(
      reminder.copyWith(nextFireAt: epoch, snoozedUntil: epoch),
    );
    if (saved) await _schedule(id, reminder.title, until);
    return saved;
  }

  /// Menyelesaikan reminder [id]: notifikasi dibatalkan, status `completed`.
  Future<bool> complete(int id) async {
    await ref.read(notificationSchedulerProvider).cancel(id);
    final reminder = await ref.read(reminderRepositoryProvider).getById(id);
    if (reminder == null || reminder.status != ReminderStatus.active) {
      return false;
    }
    final now = ref.read(clockProvider).now();
    return _save(
      reminder.copyWith(
        status: ReminderStatus.completed,
        completedAt: reminderToEpochUtc(now),
      ),
    );
  }

  /// Dipanggil saat notifikasi reminder benar-benar berbunyi (callback plugin
  /// / test). Mencatat `lastFiredAt` dan, bila berulang, menghitung serta
  /// menjadwalkan kemunculan berikutnya.
  Future<void> handleFired(int id) async {
    final reminder = await _getActive(id);
    if (reminder == null) return;
    final now = ref.read(clockProvider).now();
    final nowEpoch = reminderToEpochUtc(now);

    if (!reminder.isRecurring) {
      await _save(reminder.copyWith(lastFiredAt: nowEpoch));
      return;
    }

    final next = RecurrenceCalculator.nextOccurrence(
      rule: reminder.recurrenceRule,
      anchor: reminderLocalDateTime(reminder.date, reminder.time),
      now: now,
    );
    if (next == null) {
      await _save(
        reminder.copyWith(
          status: ReminderStatus.completed,
          lastFiredAt: nowEpoch,
          completedAt: nowEpoch,
        ),
      );
      return;
    }
    final saved = await _save(
      reminder.copyWith(
        nextFireAt: reminderToEpochUtc(next),
        lastFiredAt: nowEpoch,
      ),
    );
    if (saved) await _schedule(id, reminder.title, next);
  }

  Future<Reminder?> _getActive(int id) async {
    final reminder = await ref.read(reminderRepositoryProvider).getById(id);
    if (reminder == null || reminder.status != ReminderStatus.active) {
      return null;
    }
    return reminder;
  }

  Future<bool> _save(Reminder reminder) =>
      ref.read(reminderRepositoryProvider).update(reminder);

  Future<void> _schedule(int id, String title, DateTime at) {
    return ref
        .read(notificationSchedulerProvider)
        .schedule(
          id: id,
          title: title,
          body: 'Kamu punya pengingat: $title',
          at: at,
        );
  }

  DateTime? _fireTime(Reminder reminder) {
    final at = reminderFromEpochUtc(
      reminder.nextFireAt ?? reminder.scheduledAt,
    );
    return at.isAfter(ref.read(clockProvider).now()) ? at : null;
  }
}

final reminderControllerProvider = NotifierProvider<ReminderController, void>(
  ReminderController.new,
);

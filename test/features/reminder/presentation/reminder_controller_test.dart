import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_offline/core/database/database_provider.dart';
import 'package:personal_offline/core/services/notification_scheduler.dart';
import 'package:personal_offline/core/utils/clock.dart';
import 'package:personal_offline/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:personal_offline/features/reminder/domain/entities/reminder.dart';
import 'package:personal_offline/features/reminder/domain/reminder_schedule.dart';
import 'package:personal_offline/features/reminder/presentation/providers/reminder_controller.dart';

import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository repository;
  late FakeNotificationScheduler scheduler;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    repository = FakeReminderRepository();
    scheduler = FakeNotificationScheduler();
    clock = FixedClock(DateTime(2026, 10, 5, 9));
    container = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  });

  ReminderController controller() =>
      container.read(reminderControllerProvider.notifier);

  Reminder reminder({
    String date = '2026-10-06',
    String time = '08:00',
    bool isRecurring = false,
    String recurrenceRule = 'none',
  }) {
    return Reminder(
      title: 'Bayar listrik',
      date: date,
      time: time,
      scheduledAt: reminderToEpochUtc(reminderLocalDateTime(date, time)),
      isRecurring: isRecurring,
      recurrenceRule: recurrenceRule,
      recurrenceAnchor: date,
    );
  }

  test('create menyimpan reminder dan menjadwalkan notifikasi', () async {
    final id = await controller().create(reminder());

    expect(id, 1);
    expect(repository.reminders, hasLength(1));
    expect(repository.reminders.single.title, 'Bayar listrik');
    expect(scheduler.scheduled[id], DateTime(2026, 10, 6, 8));
  });

  test('create dengan waktu di masa lampau tidak menjadwalkan', () async {
    await controller().create(reminder(date: '2026-10-05'));

    expect(repository.reminders, hasLength(1));
    expect(scheduler.scheduled, isEmpty);
  });

  test(
    'create reminder berulang tetap menjadwalkan jadwal pertamanya',
    () async {
      final id = await controller().create(
        reminder(isRecurring: true, recurrenceRule: 'daily'),
      );

      expect(scheduler.scheduled[id], DateTime(2026, 10, 6, 8));
    },
  );

  test('cancel membatalkan notifikasi dan menandai dismissed', () async {
    final id = await controller().create(reminder());

    final result = await controller().cancel(id);

    expect(result, isTrue);
    expect(repository.reminders.single.status, ReminderStatus.dismissed);
    expect(scheduler.cancelled, contains(id));
    expect(scheduler.scheduled, isEmpty);
  });

  test('delete menghapus reminder dan membatalkan notifikasi', () async {
    final id = await controller().create(reminder());

    final result = await controller().delete(id);

    expect(result, isTrue);
    expect(repository.reminders, isEmpty);
    expect(scheduler.cancelled, contains(id));
  });

  test('snooze menunda ke now + durasi dan menjadwal ulang', () async {
    final id = await controller().create(reminder());

    final result = await controller().snooze(id, const Duration(minutes: 10));

    expect(result, isTrue);
    final saved = repository.reminders.single;
    final expected = reminderToEpochUtc(DateTime(2026, 10, 5, 9, 10));
    expect(saved.nextFireAt, expected);
    expect(saved.snoozedUntil, expected);
    expect(scheduler.scheduled[id], DateTime(2026, 10, 5, 9, 10));
  });

  test('complete menyelesaikan reminder dan membatalkan notifikasi', () async {
    final id = await controller().create(reminder());

    final result = await controller().complete(id);

    expect(result, isTrue);
    final saved = repository.reminders.single;
    expect(saved.status, ReminderStatus.completed);
    expect(saved.completedAt, reminderToEpochUtc(DateTime(2026, 10, 5, 9)));
    expect(scheduler.cancelled, contains(id));
  });

  test(
    'handleFired non-recurring mencatat lastFiredAt tanpa menjadwal ulang',
    () async {
      final id = await controller().create(reminder());
      scheduler.scheduled.clear();
      clock.value = DateTime(2026, 10, 6, 8);

      await controller().handleFired(id);

      final saved = repository.reminders.single;
      final expected = reminderToEpochUtc(DateTime(2026, 10, 6, 8));
      expect(saved.lastFiredAt, expected);
      expect(saved.status, ReminderStatus.active);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.scheduleCalls, 1);
    },
  );

  test(
    'handleFired recurring daily menjadwalkan kemunculan berikutnya',
    () async {
      final id = await controller().create(
        reminder(isRecurring: true, recurrenceRule: 'daily'),
      );
      clock.value = DateTime(2026, 10, 6, 8);

      await controller().handleFired(id);

      final saved = repository.reminders.single;
      expect(saved.nextFireAt, reminderToEpochUtc(DateTime(2026, 10, 7, 8)));
      expect(saved.lastFiredAt, reminderToEpochUtc(DateTime(2026, 10, 6, 8)));
      expect(scheduler.scheduled[id], DateTime(2026, 10, 7, 8));
    },
  );

  test('handleFired recurring interval:5d melompat kelipatan 5 hari', () async {
    final id = await controller().create(
      reminder(isRecurring: true, recurrenceRule: 'interval:5d'),
    );
    clock.value = DateTime(2026, 10, 16, 9);

    await controller().handleFired(id);

    final saved = repository.reminders.single;
    // anchor 6 Okt 08:00 → 11 Okt (lampau) → 16 Okt 08:00 (lampau dari 16 Okt 09:00) → 21 Okt.
    expect(saved.nextFireAt, reminderToEpochUtc(DateTime(2026, 10, 21, 8)));
    expect(scheduler.scheduled[id], DateTime(2026, 10, 21, 8));
  });

  test('handleFired non-aktif diabaikan', () async {
    final id = await controller().create(reminder());
    await controller().cancel(id);

    await controller().handleFired(id);

    expect(scheduler.scheduleCalls, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/services/notification_scheduler.dart';
import 'package:personal_offline/features/settings/presentation/widgets/notification_permission_card.dart';

import '../../../helpers/fake_notification_scheduler.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeNotificationScheduler scheduler,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
      child: const MaterialApp(
        home: Scaffold(body: NotificationPermissionCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan status aktif saat izin & alarm presisi aktif', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()
      ..notificationsEnabledValue = true
      ..exactAlarmsEnabledValue = true;

    await _pump(tester, scheduler);

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(
      find.text('Notifikasi dan alarm presisi aktif.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan peringatan saat alarm presisi belum aktif', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()
      ..notificationsEnabledValue = true
      ..exactAlarmsEnabledValue = false;

    await _pump(tester, scheduler);

    expect(
      find.textContaining('alarm presisi belum diizinkan'),
      findsOneWidget,
    );
  });

  testWidgets('menekan "Uji notifikasi" memanggil scheduler', (tester) async {
    final scheduler = FakeNotificationScheduler();

    await _pump(tester, scheduler);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Uji notifikasi'));
    await tester.pumpAndSettle();

    expect(scheduler.testNotificationCount, 1);
    expect(find.text('Notifikasi uji dikirim.'), findsOneWidget);
  });

  testWidgets('menekan "Izinkan notifikasi" meminta izin lalu menyegarkan', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler()
      ..notificationsEnabledValue = false
      ..exactAlarmsEnabledValue = false;

    await _pump(tester, scheduler);
    expect(find.textContaining('Notifikasi belum diizinkan'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Izinkan notifikasi'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permintaan izin notifikasi diproses.'), findsOneWidget);
  });
}

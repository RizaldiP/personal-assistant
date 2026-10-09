import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/todo/domain/entities/task.dart';
import '../../features/todo/presentation/providers/task_controller.dart';
import 'home_widget_service.dart';
import 'widget_keys.dart';

/// Menjembatani state aplikasi dengan widget layar utama Android:
///
/// - menyinkronkan tugas hari ini setiap kali berubah, dan
/// - membuka layar Percakapan saat widget diklik.
///
/// Dibungkus mengelilingi `MaterialApp` agar `ref.listen` bekerja dan
/// `navigatorKey` tersedia untuk navigasi.
class WidgetSyncScope extends ConsumerStatefulWidget {
  const WidgetSyncScope({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<WidgetSyncScope> createState() => _WidgetSyncScopeState();
}

class _WidgetSyncScopeState extends ConsumerState<WidgetSyncScope> {
  StreamSubscription<Uri?>? _clickSubscription;

  @override
  void initState() {
    super.initState();
    final service = ref.read(homeWidgetServiceProvider);
    _clickSubscription = service.widgetClicked().listen(
      _handleUri,
      onError: (Object _) {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      service.initiallyLaunchedUri().then(_handleUri, onError: (Object _) {});
    });
  }

  @override
  void dispose() {
    _clickSubscription?.cancel();
    super.dispose();
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.host != WidgetKeys.chatHost) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Task>>>(todayTasksForWidgetProvider, (
      previous,
      next,
    ) {
      next.whenData((tasks) {
        ref
            .read(homeWidgetServiceProvider)
            .syncTodayTasks(tasks)
            .catchError((Object _) {});
      });
    });
    return widget.child;
  }
}

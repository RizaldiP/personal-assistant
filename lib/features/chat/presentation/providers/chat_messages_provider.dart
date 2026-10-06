import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';

/// Riwayat seluruh pesan chat, urut dari yang paling lama.
final chatMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>(
  (ref) => ref.watch(chatRepositoryProvider).watchMessages(),
);

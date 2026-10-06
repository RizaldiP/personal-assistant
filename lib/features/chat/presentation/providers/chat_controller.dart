import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/formatters/currency_formats.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../../../shared/intents/ai_intent_result.dart';
import '../../../../shared/intents/app_intent.dart';
import '../../../../shared/nlp/rule_parser.dart';
import '../../../finance/data/repositories/expense_repository_impl.dart';
import '../../../finance/domain/entities/expense.dart';
import '../../../finance/domain/entities/expense_category.dart';
import '../../../reminder/domain/entities/reminder.dart';
import '../../../reminder/domain/reminder_schedule.dart';
import '../../../reminder/presentation/providers/reminder_controller.dart';
import '../../../shopping/presentation/providers/shopping_controller.dart';
import '../../../todo/data/repositories/task_repository_impl.dart';
import '../../../todo/domain/entities/task.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';

/// Aksi chat: menyimpan pesan user lalu mengeksekusi intent sederhana.
///
/// Alur:
/// 1. Simpan pesan user (dengan `intent` + `payload` hasil Rule Parser).
/// 2. `create_todo` membuat tugas lewat repository dan balas konfirmasi.
/// 3. `create_reminder` membuat reminder, menjadwalkan notifikasi, dan balas.
/// 4. `create_shopping` menambah item ke daftar belanja dan balas konfirmasi.
/// 5. `create_expense` mencatat pengeluaran dan balas konfirmasi.
///
/// Riwayat pesan tidak dipegang di sini; sumber kebenaran tetap
/// [chatMessagesProvider] yang membaca database.
class ChatController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Menyimpan [rawText] sebagai pesan user dan memproses intentnya.
  ///
  /// Melempar error bila penyimpanan gagal; state ikut menjadi [AsyncError].
  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isLoading) return;

    state = const AsyncLoading();
    try {
      final repository = ref.read(chatRepositoryProvider);
      final parsed = _parse(text);

      var message = ChatMessage(role: ChatRole.user, content: text);
      if (parsed != null) {
        message = message.copyWith(
          intent: parsed.intent.storageValue,
          payload: jsonEncode(parsed.toJson()),
        );
      }
      await repository.save(message);

      if (parsed != null && parsed.intent == AppIntent.createTodo) {
        await _createTodo(text, parsed);
        await repository.save(
          ChatMessage(role: ChatRole.assistant, content: _todoReply(parsed)),
        );
      } else if (parsed != null && parsed.intent == AppIntent.createReminder) {
        await _createReminder(text, parsed);
        await repository.save(
          ChatMessage(
            role: ChatRole.assistant,
            content: _reminderReply(parsed),
          ),
        );
      } else if (parsed != null && parsed.intent == AppIntent.createShopping) {
        final reply = await _createShopping(text, parsed);
        await repository.save(
          ChatMessage(role: ChatRole.assistant, content: reply),
        );
      } else if (parsed != null && parsed.intent == AppIntent.createExpense) {
        final reply = await _createExpense(text, parsed);
        await repository.save(
          ChatMessage(role: ChatRole.assistant, content: reply),
        );
      }
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  AiIntentResult? _parse(String text) {
    try {
      final now = ref.read(clockProvider).now();
      return RuleParser(now: now).parse(text);
    } on Object {
      return null;
    }
  }

  Future<void> _createTodo(String rawText, AiIntentResult parsed) async {
    final task = Task(
      title: parsed.entities['title'] as String? ?? rawText,
      dueDate: parsed.entities['due_date'] as String?,
      priority: TaskPriority.parse(parsed.entities['priority'] as String?),
      source: 'rule',
      rawInput: rawText,
      confidence: parsed.confidence,
    );
    await ref.read(taskRepositoryProvider).create(task);
  }

  static String _todoReply(AiIntentResult parsed) {
    final title = parsed.entities['title'] as String? ?? '';
    final date = DateFormats.longIndonesia(
      parsed.entities['due_date'] as String?,
    );
    final base = 'Todo dibuat: $title';
    return date.isEmpty ? base : '$base · $date';
  }

  Future<void> _createReminder(String rawText, AiIntentResult parsed) async {
    final date = parsed.entities['date'] as String? ?? '';
    final time = parsed.entities['time'] as String? ?? '00:00';
    final reminder = Reminder(
      title: parsed.entities['title'] as String? ?? rawText,
      date: date,
      time: time,
      scheduledAt: reminderToEpochUtc(reminderLocalDateTime(date, time)),
      source: 'rule',
      rawInput: rawText,
      confidence: parsed.confidence,
    );
    await ref.read(reminderControllerProvider.notifier).create(reminder);
  }

  static String _reminderReply(AiIntentResult parsed) {
    final title = parsed.entities['title'] as String? ?? '';
    final date = DateFormats.longIndonesia(parsed.entities['date'] as String?);
    final time = parsed.entities['time'] as String? ?? '';
    final base = 'Reminder dijadwalkan: $title';
    final parts = <String>[
      if (date.isNotEmpty) date,
      if (time.isNotEmpty) time,
    ];
    return parts.isEmpty ? base : '$base · ${parts.join(' jam ')}';
  }

  Future<String> _createShopping(String rawText, AiIntentResult parsed) async {
    final items = (parsed.entities['items'] as List? ?? const <String>[])
        .map((item) => item.toString())
        .toList();
    await ref.read(shoppingControllerProvider.notifier).addItems(items);
    return items.isEmpty
        ? 'Belanja dicatat.'
        : 'Belanja dicatat: ${items.join(', ')}';
  }

  Future<String> _createExpense(String rawText, AiIntentResult parsed) async {
    final amount = (parsed.entities['amount'] as num?)?.toInt() ?? 0;
    final description = parsed.entities['description'] as String? ?? '';
    if (amount <= 0 || description.isEmpty) {
      return 'Pengeluaran tidak dikenali. Tulis nominal dan keterangan.';
    }
    final date =
        parsed.entities['date'] as String? ??
        _isoDate(ref.read(clockProvider).now());
    await ref
        .read(expenseRepositoryProvider)
        .create(
          Expense(
            amount: amount,
            category: ExpenseCategory.parse(
              parsed.entities['category'] as String?,
            ),
            description: description,
            date: date,
            source: 'rule',
            rawInput: rawText,
            confidence: parsed.confidence,
          ),
        );
    final categoryLabel = _expenseCategoryLabel(
      ExpenseCategory.parse(parsed.entities['category'] as String?),
    );
    return 'Pengeluaran dicatat: ${CurrencyFormats.idr(amount)} · '
        '$categoryLabel · $description';
  }

  static String _expenseCategoryLabel(ExpenseCategory category) =>
      switch (category) {
        ExpenseCategory.makanan => 'Makanan',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.tagihan => 'Tagihan',
        ExpenseCategory.belanja => 'Belanja',
        ExpenseCategory.kesehatan => 'Kesehatan',
        ExpenseCategory.hiburan => 'Hiburan',
        ExpenseCategory.lainnya => 'Lainnya',
      };

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final chatControllerProvider =
    NotifierProvider<ChatController, AsyncValue<void>>(ChatController.new);

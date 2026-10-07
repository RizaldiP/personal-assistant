import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/intents/last_item_context.dart';
import '../../../../shared/formatters/currency_formats.dart';
import '../../../../shared/formatters/date_formats.dart';
import '../../../../shared/intents/ai_intent_result.dart';
import '../../../../shared/intents/app_intent.dart';
import '../../../finance/data/repositories/expense_repository_impl.dart';
import '../../../finance/domain/entities/expense.dart';
import '../../../finance/domain/entities/expense_category.dart';
import '../../../ideas/data/repositories/idea_repository_impl.dart';
import '../../../ideas/domain/entities/idea.dart';
import '../../../journal/data/repositories/journal_repository_impl.dart';
import '../../../journal/domain/entities/journal_entry.dart';
import '../../../notes/data/repositories/note_repository_impl.dart';
import '../../../notes/domain/entities/note.dart';
import '../../../reminder/data/repositories/reminder_repository_impl.dart';
import '../../../reminder/domain/entities/reminder.dart';
import '../../../reminder/domain/reminder_schedule.dart';
import '../../../reminder/presentation/providers/reminder_controller.dart';
import '../../../search/data/repositories/search_repository_impl.dart';
import '../../../shopping/presentation/providers/shopping_controller.dart';
import '../../../todo/data/repositories/task_repository_impl.dart';
import '../../../todo/domain/entities/task.dart';

/// Menjalankan [AiIntentResult] yang sudah dikonfirmasi ke repository
/// aplikasi dan mengembalikan balasan chat untuk user.
///
/// `source` diteruskan ke tiap entitas (`rule` / `ai`) supaya asal data
/// tetap terlacak. Intent `search` (PHASE 13) membalas dengan cuplikan
/// hasil pencarian global.
///
/// Setiap pembuatan/penyimpanan menulis `LastItemContext` sehingga perintah
/// lanjutan berikutnya (`ubah`, `hapus`, `selesaikan`, `tunda`) tahu targetnya
/// (PHASE 12); intent kontekstual datang sudah berisi `target_*` dari
/// `IntentProcessor`.
class IntentExecutor {
  IntentExecutor(this._ref);

  final Ref _ref;

  Future<String> execute(
    AiIntentResult result, {
    required String rawText,
    required String source,
  }) async {
    return switch (result.intent) {
      AppIntent.createTodo => _createTodo(rawText, result, source),
      AppIntent.createReminder => _createReminder(rawText, result, source),
      AppIntent.createShopping => _createShopping(result),
      AppIntent.createExpense => _createExpense(rawText, result, source),
      AppIntent.createNote => _createNote(rawText, result, source),
      AppIntent.createJournal => _createJournal(rawText, result, source),
      AppIntent.createIdea => _createIdea(rawText, result, source),
      AppIntent.updateItem => _updateItem(result),
      AppIntent.deleteItem => _deleteItem(result),
      AppIntent.completeItem => _completeItem(result),
      AppIntent.search => _search(rawText, result),
      AppIntent.unknown => Future.value(
        'Aku belum bisa memahami itu, jadi tidak ada yang disimpan.',
      ),
    };
  }

  Future<String> _createTodo(
    String rawText,
    AiIntentResult parsed,
    String source,
  ) async {
    final task = Task(
      title: parsed.entities['title'] as String? ?? rawText,
      dueDate: parsed.entities['due_date'] as String?,
      priority: TaskPriority.parse(parsed.entities['priority'] as String?),
      source: source,
      rawInput: rawText,
      confidence: parsed.confidence,
    );
    final id = await _ref.read(taskRepositoryProvider).create(task);
    await _remember(
      'todo',
      id,
      task.title,
      date: task.dueDate,
      time: task.dueTime,
    );
    return _todoReply(parsed);
  }

  static String _todoReply(AiIntentResult parsed) {
    final title = parsed.entities['title'] as String? ?? '';
    final date = DateFormats.longIndonesia(
      parsed.entities['due_date'] as String?,
    );
    final base = 'Todo dibuat: $title';
    return date.isEmpty ? base : '$base · $date';
  }

  Future<String> _createReminder(
    String rawText,
    AiIntentResult parsed,
    String source,
  ) async {
    final date = parsed.entities['date'] as String? ?? '';
    final time = parsed.entities['time'] as String? ?? '00:00';
    final reminder = Reminder(
      title: parsed.entities['title'] as String? ?? rawText,
      date: date,
      time: time,
      scheduledAt: reminderToEpochUtc(reminderLocalDateTime(date, time)),
      source: source,
      rawInput: rawText,
      confidence: parsed.confidence,
    );
    final id = await _ref
        .read(reminderControllerProvider.notifier)
        .create(reminder);
    await _remember(
      'reminder',
      id,
      reminder.title,
      date: reminder.date,
      time: reminder.time,
    );
    return _reminderReply(parsed);
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

  Future<String> _createShopping(AiIntentResult parsed) async {
    final items = (parsed.entities['items'] as List? ?? const <String>[])
        .map((item) => item.toString())
        .toList();
    await _ref.read(shoppingControllerProvider.notifier).addItems(items);
    await _remember('shopping', null, items.join(', '));
    return items.isEmpty
        ? 'Belanja dicatat.'
        : 'Belanja dicatat: ${items.join(', ')}';
  }

  Future<String> _createExpense(
    String rawText,
    AiIntentResult parsed,
    String source,
  ) async {
    final amount = (parsed.entities['amount'] as num?)?.toInt() ?? 0;
    final description = parsed.entities['description'] as String? ?? '';
    if (amount <= 0 || description.isEmpty) {
      return 'Pengeluaran tidak dikenali. Tulis nominal dan keterangan.';
    }
    final date =
        parsed.entities['date'] as String? ??
        _isoDate(_ref.read(clockProvider).now());
    final id = await _ref
        .read(expenseRepositoryProvider)
        .create(
          Expense(
            amount: amount,
            category: ExpenseCategory.parse(
              parsed.entities['category'] as String?,
            ),
            description: description,
            date: date,
            source: source,
            rawInput: rawText,
            confidence: parsed.confidence,
          ),
        );
    await _remember('expense', id, description, date: date);
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

  Future<String> _createNote(
    String rawText,
    AiIntentResult parsed,
    String source,
  ) async {
    final content = parsed.entities['content'] as String? ?? rawText;
    final id = await _ref
        .read(noteRepositoryProvider)
        .create(
          Note(
            content: content,
            source: source,
            rawInput: rawText,
            confidence: parsed.confidence,
          ),
        );
    await _remember('note', id, content);
    return 'Catatan disimpan: $content';
  }

  Future<String> _createJournal(
    String rawText,
    AiIntentResult parsed,
    String source,
  ) async {
    final content = parsed.entities['content'] as String? ?? rawText;
    final mood = parsed.entities['mood'] as String?;
    final date = _isoDate(_ref.read(clockProvider).now());
    final id = await _ref
        .read(journalRepositoryProvider)
        .create(
          JournalEntry(
            date: date,
            content: content,
            mood: mood,
            source: source,
            rawInput: rawText,
            confidence: parsed.confidence,
          ),
        );
    await _remember('journal', id, content, date: date);
    return 'Jurnal ditulis: $content';
  }

  Future<String> _createIdea(
    String rawText,
    AiIntentResult parsed,
    String source,
  ) async {
    final content = parsed.entities['content'] as String? ?? rawText;
    final id = await _ref
        .read(ideaRepositoryProvider)
        .create(
          Idea(
            title: content,
            source: source,
            rawInput: rawText,
            confidence: parsed.confidence,
          ),
        );
    await _remember('idea', id, content);
    return 'Ide disimpan: $content';
  }

  /// Intent `search` (PHASE 13): tiga hasil teratas di chat; daftar lengkap
  /// tersedia di layar Pencarian.
  Future<String> _search(String rawText, AiIntentResult parsed) async {
    var query = _entityText(parsed, 'query');
    if (query.isEmpty) query = rawText;
    final results = await _ref
        .read(searchRepositoryProvider)
        .search(query: query, limitPerType: 5);
    if (results.isEmpty) {
      return 'Tidak ada hasil untuk "$query". Coba kata lain, misalnya '
          '"catatan liburan".';
    }
    final top = results.take(3).map((result) => '- ${result.title}').join('\n');
    return 'Menemukan ${results.length} hasil untuk "$query":\n$top\n'
        'Buka Pencarian di beranda untuk melihat semua.';
  }

  /// Perintah lanjutan `ubah` / `tunda` (PHASE 12): target datang dari
  /// `IntentProcessor` lewat entity `target_*` (item terakhir percakapan).
  Future<String> _updateItem(AiIntentResult parsed) async {
    final type = _targetType(parsed);
    final id = _targetId(parsed);
    if (id == null || type.isEmpty) return _gone(_targetLabel(parsed));

    final isSnooze = parsed.entities['snooze'] == true;
    final minutes = (parsed.entities['snooze_minutes'] as num?)?.toInt();

    if (type == 'reminder') {
      return _updateReminder(parsed, id, isSnooze: isSnooze, minutes: minutes);
    }
    if (type == 'todo') {
      if (isSnooze || minutes != null) {
        return 'Perintah tunda hanya berlaku untuk reminder.';
      }
      return _updateTodo(parsed, id);
    }
    return 'Item "${_targetLabel(parsed)}" belum didukung untuk diubah.';
  }

  Future<String> _updateReminder(
    AiIntentResult parsed,
    int id, {
    required bool isSnooze,
    required int? minutes,
  }) async {
    final repository = _ref.read(reminderRepositoryProvider);
    final controller = _ref.read(reminderControllerProvider.notifier);
    final reminder = await repository.getById(id);
    if (reminder == null) return _gone(_targetLabel(parsed));

    if (isSnooze) {
      return _snoozeReminder(parsed, reminder, controller, minutes: minutes);
    }

    final dateEntity = _entityText(parsed, 'date');
    final timeEntity = _entityText(parsed, 'time');
    final titleEntity = _entityText(parsed, 'title');
    final date = dateEntity.isEmpty ? reminder.date : dateEntity;
    final time = timeEntity.isEmpty ? reminder.time : timeEntity;
    final title = titleEntity.isEmpty ? reminder.title : titleEntity;

    if (title == reminder.title &&
        date == reminder.date &&
        time == reminder.time) {
      return 'Tidak ada perubahan pada reminder: ${reminder.title}. '
          'Coba "ubah jadi jam 10" atau "jadikan besok".';
    }

    final updated = reminder.copyWith(
      title: title,
      date: date,
      time: time,
      scheduledAt: reminderToEpochUtc(reminderLocalDateTime(date, time)),
    );
    if (!await controller.update(updated)) return _gone(_targetLabel(parsed));
    await _remember('reminder', id, title, date: date, time: time);
    return 'Reminder diubah: $title · ${DateFormats.longIndonesia(date)} '
        'jam $time';
  }

  Future<String> _snoozeReminder(
    AiIntentResult parsed,
    Reminder reminder,
    ReminderController controller, {
    required int? minutes,
  }) async {
    final id = reminder.id!;
    final now = _ref.read(clockProvider).now();
    final dateEntity = _entityText(parsed, 'date');
    final timeEntity = _entityText(parsed, 'time');

    if (minutes == null && dateEntity.isEmpty && timeEntity.isEmpty) {
      return 'Mau ditunda berapa lama? Contoh: "tunda 1 jam", '
          '"tunda besok", atau "tunda jam 10".';
    }

    Duration duration;
    DateTime target;
    if (minutes != null) {
      if (minutes <= 0) {
        return 'Durasi tunda tidak valid. Contoh: "tunda 1 jam".';
      }
      duration = Duration(minutes: minutes);
      target = now.add(duration);
    } else {
      final date = dateEntity.isEmpty ? reminder.date : dateEntity;
      final time = timeEntity.isEmpty ? reminder.time : timeEntity;
      target = reminderLocalDateTime(date, time);
      if (dateEntity.isEmpty && !target.isAfter(now)) {
        // "tunda jam 10" yang sudah lewat hari ini → besok pagi.
        target = target.add(const Duration(days: 1));
      }
      duration = target.difference(now);
      if (duration <= Duration.zero) {
        return 'Waktu tunda sudah lewat. Coba "tunda besok" atau '
            '"tunda 1 jam".';
      }
    }

    if (!await controller.snooze(id, duration)) {
      return _gone(_targetLabel(parsed));
    }
    return 'Reminder ditunda: ${reminder.title} · '
        '${DateFormats.longIndonesia(_isoDate(target))} jam ${_hhMm(target)}';
  }

  Future<String> _updateTodo(AiIntentResult parsed, int id) async {
    final repository = _ref.read(taskRepositoryProvider);
    final task = await repository.getById(id);
    if (task == null) return _gone(_targetLabel(parsed));

    final dateEntity = _entityText(parsed, 'date', fallbackKey: 'due_date');
    final timeEntity = _entityText(parsed, 'time');
    final titleEntity = _entityText(parsed, 'title');
    final date = dateEntity.isEmpty ? task.dueDate ?? '' : dateEntity;
    final time = timeEntity.isEmpty ? task.dueTime ?? '' : timeEntity;
    final title = titleEntity.isEmpty ? task.title : titleEntity;
    final dueDate = date.isEmpty ? null : date;
    final dueTime = time.isEmpty ? null : time;

    if (title == task.title &&
        dueDate == task.dueDate &&
        dueTime == task.dueTime) {
      return 'Tidak ada perubahan pada todo: ${task.title}. '
          'Coba "ubah jadi besok" atau "ubah jadi jam 10".';
    }

    final updated = task.copyWith(
      title: title,
      dueDate: dueDate,
      dueTime: dueTime,
    );
    if (!await repository.update(updated)) return _gone(_targetLabel(parsed));
    await _remember('todo', id, title, date: dueDate, time: dueTime);
    final details = <String>[
      if (dueDate != null) DateFormats.longIndonesia(dueDate),
      if (dueTime != null) 'jam $dueTime',
    ];
    final suffix = details.isEmpty ? '' : ' · ${details.join(' ')}';
    return 'Todo diubah: $title$suffix';
  }

  /// Perintah lanjutan `hapus`: selalu lewat kartu konfirmasi lebih dulu
  /// (destruktif); konteks dibersihkan setelah berhasil.
  Future<String> _deleteItem(AiIntentResult parsed) async {
    final type = _targetType(parsed);
    final id = _targetId(parsed);
    final label = _targetLabel(parsed);
    if (id == null || type.isEmpty) return _gone(label);

    final bool saved;
    if (type == 'reminder') {
      saved = await _ref.read(reminderControllerProvider.notifier).delete(id);
    } else if (type == 'todo') {
      saved = await _ref.read(taskRepositoryProvider).delete(id);
    } else {
      return 'Item "$label" belum didukung untuk dihapus.';
    }
    if (!saved) return _gone(label);

    await _ref.read(lastItemContextProvider).clear();
    return '${type == 'reminder' ? 'Reminder' : 'Todo'} dihapus: $label';
  }

  /// Perintah lanjutan `selesaikan` (todo maupun reminder).
  Future<String> _completeItem(AiIntentResult parsed) async {
    final type = _targetType(parsed);
    final id = _targetId(parsed);
    final label = _targetLabel(parsed);
    if (id == null || type.isEmpty) return _gone(label);

    if (type == 'todo') {
      final repository = _ref.read(taskRepositoryProvider);
      final task = await repository.getById(id);
      if (task == null) return _gone(label);
      if (task.status == TaskStatus.done) {
        return 'Todo sudah selesai: ${task.title}.';
      }
      final saved = await repository.update(
        task.copyWith(
          status: TaskStatus.done,
          completedAt: _ref.read(clockProvider).now(),
        ),
      );
      return saved ? 'Todo diselesaikan: ${task.title}' : _gone(label);
    }

    if (type == 'reminder') {
      final saved = await _ref
          .read(reminderControllerProvider.notifier)
          .complete(id);
      return saved
          ? 'Reminder diselesaikan: $label'
          : 'Reminder tidak aktif: $label';
    }
    return 'Item "$label" belum didukung untuk diselesaikan.';
  }

  /// Menyimpan item terakhir ke konteks percakapan (gagal ≠ error chat).
  Future<void> _remember(
    String type,
    int? id,
    String label, {
    String? date,
    String? time,
  }) => _ref
      .read(lastItemContextProvider)
      .write(
        LastItemContext(
          type: type,
          id: id,
          label: label,
          date: date,
          time: time,
        ),
      );

  String _targetType(AiIntentResult parsed) =>
      _entityText(parsed, 'target_type');

  int? _targetId(AiIntentResult parsed) =>
      (parsed.entities['target_id'] as num?)?.toInt();

  String _targetLabel(AiIntentResult parsed) =>
      _entityText(parsed, 'target_label');

  String _entityText(AiIntentResult parsed, String key, {String? fallbackKey}) {
    final value = parsed.entities[key];
    final text = value == null ? '' : value.toString().trim();
    if (text.isNotEmpty || fallbackKey == null) return text;
    final fallback = parsed.entities[fallbackKey];
    return fallback == null ? '' : fallback.toString().trim();
  }

  String _gone(String label) => label.isEmpty
      ? 'Item sudah tidak ada. Buat dulu, misalnya "besok jam 8 bayar '
            'listrik".'
      : '"$label" sudah tidak ada. Buat dulu, misalnya "besok jam 8 bayar '
            'listrik".';

  static String _hhMm(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final intentExecutorProvider = Provider<IntentExecutor>((ref) {
  return IntentExecutor(ref);
});

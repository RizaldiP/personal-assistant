/// Label Bahasa Indonesia untuk tabel database (cadangan & pratinjau).
abstract final class BackupTableLabels {
  static const Map<String, String> _labels = {
    'tasks': 'Tugas',
    'reminders': 'Pengingat',
    'chat_messages': 'Percakapan',
    'user_preferences': 'Preferensi',
    'shopping_lists': 'Daftar belanja',
    'shopping_items': 'Item belanja',
    'expenses': 'Pengeluaran',
    'notes': 'Catatan',
    'journal_entries': 'Jurnal',
    'ideas': 'Ide',
    'tags': 'Tag',
    'tag_links': 'Relasi tag',
    'inbox_items': 'Inbox',
  };

  static String of(String table) => _labels[table] ?? table;
}

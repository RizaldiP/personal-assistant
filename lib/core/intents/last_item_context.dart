import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/preferences_repository.dart';

/// Item terakhir yang dibuat/diubah lewat chat — target perintah lanjutan
/// (`ubah`, `hapus`, `selesaikan`, `tunda`) pada PHASE 12.
class LastItemContext {
  const LastItemContext({
    required this.type,
    required this.id,
    required this.label,
    this.date,
    this.time,
  });

  /// Jenis item: `todo`, `reminder`, `shopping`, `expense`, `note`,
  /// `journal`, `idea`.
  final String type;

  /// Id item; null bila repository tidak mengembalikan id (mis. belanja).
  final int? id;

  /// Judul/konten untuk disebut di balasan chat.
  final String label;

  /// Tanggal/waktu item bila diketahui (`YYYY-MM-DD` / `HH:mm`).
  final String? date;
  final String? time;

  static const Set<String> followUpTypes = {'todo', 'reminder'};

  bool get supportsFollowUp => followUpTypes.contains(type);

  Map<String, dynamic> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    'label': label,
    if (date != null) 'date': date,
    if (time != null) 'time': time,
  };

  factory LastItemContext.fromJson(Map<String, dynamic> json) =>
      LastItemContext(
        type: json['type'] as String? ?? '',
        id: (json['id'] as num?)?.toInt(),
        label: json['label'] as String? ?? '',
        date: json['date'] as String?,
        time: json['time'] as String?,
      );
}

/// Menyimpan/membaca [LastItemContext] di preferensi pengguna agar konteks
/// percakapan bertahan setelah aplikasi dibuka ulang.
///
/// Semua operasi menangkap kegalahan: konteks yang hilang tidak boleh
/// menjatuhkan chat — perintah lanjutan cukup membalas "belum ada item".
class LastItemContextStore {
  LastItemContextStore(this._preferences);

  static const String prefKey = 'chat_last_item';

  final PreferencesRepository _preferences;

  Future<LastItemContext?> read() async {
    try {
      final raw = await _preferences.get(prefKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return LastItemContext.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> write(LastItemContext context) async {
    try {
      await _preferences.set(prefKey, jsonEncode(context.toJson()));
    } on Object {
      // Konteks gagal disimpan tidak menggagalkan pesan user.
    }
  }

  Future<void> clear() async {
    try {
      await _preferences.remove(prefKey);
    } on Object {
      // Diabaikan; lihat [read].
    }
  }
}

final lastItemContextProvider = Provider<LastItemContextStore>((ref) {
  return LastItemContextStore(ref.watch(preferencesRepositoryProvider));
});

import 'package:drift/drift.dart';

/// Tabel pesan chat.
///
/// Pesan disimpan apa adanya. Hasil ekstraksi (`intent`, `payload`) disimpan
/// di kolom terpisah sehingga history tidak pernah tertimpa.
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get role => text()();

  TextColumn get content => text()();

  TextColumn get intent => text().nullable()();

  /// JSON structured intent, nullable.
  TextColumn get payload => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('sent'))();

  /// Epoch ms; diisi ketika pesan sudah diproses menjadi entitas.
  IntColumn get resolvedAt => integer().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/clock.dart';
import 'app_database.dart';

/// Instance database aplikasi.
///
/// Satu instance untuk satu Isolate aplikasi; ditutup otomatis saat provider
/// dibuang. Test meng-override provider ini dengan database in-memory.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Sumber waktu aplikasi. Test dapat menggantinya dengan [FixedClock].
final clockProvider = Provider<Clock>((ref) => const SystemClock());

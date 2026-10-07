import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_model_manager.dart';
import 'llamadart_local_ai_engine.dart';
import 'local_ai_engine.dart';

/// Pasangan engine + model manager yang dibuat dari satu backend.
///
/// Dipisah dari provider engine agar lapisan UI/controller bekerja terhadap
/// interface ([LocalAiEngine], [AiModelManager]) dan bisa diuji memakai fake
/// tanpa menyentuh library native.
class LocalAiRuntime {
  const LocalAiRuntime({required this.engine, required this.modelManager});

  final LocalAiEngine engine;
  final AiModelManager modelManager;
}

/// Satu-satunya tempat engine AI lokal dibuat (docs/05 bagian 3).
///
/// Engine dibuat lazily saat pertama kali dibaca — membuka aplikasi tanpa
/// membuka pengaturan AI tidak memuat library native apa pun.
final localAiRuntimeProvider = Provider<LocalAiRuntime>((ref) {
  final engine = LlamadartLocalAiEngine();
  ref.onDispose(() => engine.dispose());
  return LocalAiRuntime(engine: engine, modelManager: engine.modelManager);
});

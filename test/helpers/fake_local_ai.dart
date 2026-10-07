import 'package:personal_offline/core/ai/ai_model_manager.dart';
import 'package:personal_offline/core/ai/local_ai_engine.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';
import 'package:personal_offline/shared/intents/ai_intent_result.dart';

/// Fake [AiModelManager] in-memory untuk test UI/controller PHASE 10.
class FakeAiModelManager implements AiModelManager {
  FakeAiModelManager({this.cached = false});

  bool cached;
  bool loaded = false;

  /// Hasil yang dikembalikan [downloadModel] / apakah [loadModel] berhasil.
  bool downloadResult = true;
  bool loadResult = true;

  /// Bila di-set, operasi terkait melempar exception ini.
  Object? downloadError;
  Object? loadError;
  Object? cachedCheckError;

  int downloadCalls = 0;
  int loadCalls = 0;
  int unloadCalls = 0;
  int cachedCheckCalls = 0;
  final List<double> progress = [];

  @override
  Future<bool> downloadModel({void Function(double progress)? onProgress}) {
    downloadCalls++;
    if (downloadError != null) {
      return Future<bool>.error(downloadError!);
    }
    for (final step in const [0.4, 1.0]) {
      onProgress?.call(step);
      progress.add(step);
    }
    if (downloadResult) {
      cached = true;
    }
    return Future<bool>.value(downloadResult);
  }

  @override
  Future<bool> loadModel() {
    loadCalls++;
    if (loadError != null) {
      return Future<bool>.error(loadError!);
    }
    if (loadResult) {
      loaded = true;
    }
    return Future<bool>.value(loadResult);
  }

  @override
  Future<void> unloadModel() async {
    unloadCalls++;
    loaded = false;
  }

  @override
  Future<bool> isModelCached() {
    cachedCheckCalls++;
    if (cachedCheckError != null) {
      return Future<bool>.error(cachedCheckError!);
    }
    return Future<bool>.value(cached);
  }

  @override
  bool get isLoaded => loaded;

  @override
  String get modelName => 'Fake Model Test';

  @override
  int get sizeBytes => 1024 * 1024;
}

/// Fake [LocalAiEngine] tanpa inference nyata.
class FakeLocalAiEngine implements LocalAiEngine {
  FakeLocalAiEngine({this.canLoad = true});

  /// Apakah [initialize] berhasil membuat engine siap.
  bool canLoad;

  bool ready = false;
  Object? initializeError;

  /// Hasil yang dikembalikan [understand]; null = perilaku default.
  AiIntentResult? understandResult;

  /// Bila di-set, [understand] melempar exception ini.
  Object? understandError;

  int initializeCalls = 0;
  int disposeCalls = 0;
  int understandCalls = 0;
  final List<String> texts = [];

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (initializeError != null) {
      throw initializeError!;
    }
    ready = canLoad;
  }

  @override
  Future<bool> isAvailable() async => ready;

  @override
  Future<AiIntentResult> understand(String text) async {
    understandCalls++;
    texts.add(text);
    if (!ready) {
      throw const LocalAiUnavailableException();
    }
    if (understandError != null) {
      throw understandError!;
    }
    final result = understandResult;
    if (result != null) {
      return result;
    }
    throw const LocalAiInferenceException('fake tidak melakukan inference');
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    ready = false;
  }
}

/// Pasangan fake siap pakai untuk override [localAiRuntimeProvider].
LocalAiRuntime buildFakeRuntime({
  FakeAiModelManager? manager,
  FakeLocalAiEngine? engine,
}) {
  final fakeManager = manager ?? FakeAiModelManager();
  final fakeEngine = engine ?? FakeLocalAiEngine();
  return LocalAiRuntime(engine: fakeEngine, modelManager: fakeManager);
}

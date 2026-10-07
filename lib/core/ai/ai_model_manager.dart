import 'package:llamadart/llamadart.dart';

import 'ai_config.dart';

/// Manajer model AI lokal (docs/05 bagian 3).
abstract class AiModelManager {
  /// Mengunduh model — HANYA dipanggil setelah consent user (opsional).
  Future<bool> downloadModel({void Function(double progress)? onProgress});

  /// Memuat model dari cache. Tidak boleh menyentuh jaringan (offline).
  Future<bool> loadModel();

  Future<void> unloadModel();

  /// true bila file model sudah ada di cache (belum tentu dimuat ke RAM).
  Future<bool> isModelCached();

  bool get isLoaded;

  String get modelName;

  int get sizeBytes;
}

/// Implementasi berbasis llamadart: cache dan unduhan memakai
/// [LlamaEngine.modelDownloadManager] yang sama sehingga lokasi cache
/// konsisten.
class LlamadartModelManager implements AiModelManager {
  LlamadartModelManager(this._engine, [this._config = const AiConfig()]);

  final LlamaEngine _engine;
  final AiConfig _config;

  ModelSource get _source => ModelSource.parse(_config.modelSource);

  ModelLoadOptions get _loadOptions => ModelLoadOptions(
    cachePolicy: ModelCachePolicy.preferCached,
    cacheDirectory: _config.cacheDirectory,
  );

  @override
  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _engine.modelDownloadManager.ensureModel(
        _source,
        options: _loadOptions,
        onProgress: onProgress == null
            ? null
            : (progress) {
                final fraction = progress.fraction;
                if (fraction != null) {
                  onProgress(fraction);
                }
              },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> loadModel() async {
    try {
      await _engine.loadModelSource(
        _source,
        modelParams: ModelParams(
          contextSize: _config.contextSize,
          gpuLayers: _config.gpuLayers,
          preferredBackend: GpuBackend.cpu,
        ),
        options: ModelLoadOptions(
          cachePolicy: ModelCachePolicy.cacheOnly,
          cacheDirectory: _config.cacheDirectory,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isModelCached() async {
    try {
      // cacheOnly: melempar bila file belum ada — tidak pernah mengunduh.
      await _engine.modelDownloadManager.ensureModel(
        _source,
        options: ModelLoadOptions(
          cachePolicy: ModelCachePolicy.cacheOnly,
          cacheDirectory: _config.cacheDirectory,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> unloadModel() async {
    if (_engine.isReady) {
      await _engine.unloadModel();
    }
  }

  @override
  bool get isLoaded => _engine.isReady;

  @override
  String get modelName => _config.modelName;

  @override
  int get sizeBytes => _config.modelSizeBytes;
}

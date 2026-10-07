import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_model_manager.dart';
import 'local_ai_engine.dart';
import 'local_ai_runtime.dart';

/// Status model AI lokal di perangkat.
///
/// Semua operasi bersifat non-blocking bagi UI: operasi yang gagal selalu
/// jatuh ke [errorMessage] — tidak pernah melempar, tidak pernah crash
/// (DoD PHASE 10: "AI tidak crash app").
class AiModelState {
  const AiModelState({
    this.isCached = false,
    this.isLoaded = false,
    this.isBusy = false,
    this.downloadProgress,
    this.errorMessage,
  });

  /// File model sudah ada di cache (hasil unduhan sebelumnya).
  final bool isCached;

  /// Model sudah dimuat ke RAM dan siap untuk inference.
  final bool isLoaded;

  /// Sedang mengunduh/memuat — tombol nonaktif saat true.
  final bool isBusy;

  /// Progres unduhan 0.0–1.0; null saat tidak mengunduh.
  final double? downloadProgress;

  /// Pesan gagal terakhir (Bahasa Indonesia); null bila tidak ada.
  final String? errorMessage;

  bool get isDownloading => isBusy && downloadProgress != null;

  AiModelState copyWith({
    bool? isCached,
    bool? isLoaded,
    bool? isBusy,
    double? downloadProgress,
    String? errorMessage,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return AiModelState(
      isCached: isCached ?? this.isCached,
      isLoaded: isLoaded ?? this.isLoaded,
      isBusy: isBusy ?? this.isBusy,
      downloadProgress: clearProgress
          ? null
          : downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final aiModelControllerProvider =
    NotifierProvider<AiModelController, AiModelState>(AiModelController.new);

/// Orkestrasi unduh/muat/lepas model AI lokal dari sisi aplikasi.
///
/// Engine hanya boleh dipakai `understand()` oleh IntentProcessor (phase 11);
/// controller ini hanya mengelola siklus hidup model (docs/05 bagian 3).
class AiModelController extends Notifier<AiModelState> {
  bool _initialized = false;

  @override
  AiModelState build() => const AiModelState();

  AiModelManager get _manager => ref.read(localAiRuntimeProvider).modelManager;

  LocalAiEngine get _engine => ref.read(localAiRuntimeProvider).engine;

  /// Membaca status cache/muat saat pertama kali layar pengaturan dibuka.
  ///
  /// Aman dipanggil berulang: hanya membaca status, tidak pernah mengunduh.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  /// Menyegarkan status dari engine; mengabaikan bila sedang sibuk.
  Future<void> refresh() async {
    if (state.isBusy) return;
    try {
      final isCached = await _manager.isModelCached();
      final isLoaded = await _engine.isAvailable();
      state = AiModelState(isCached: isCached, isLoaded: isLoaded);
    } catch (_) {
      state = state.copyWith(
        clearError: false,
        errorMessage: 'Gagal membaca status model AI.',
      );
    }
  }

  /// Mengunduh model (hanya setelah consent user) dengan progres.
  Future<void> download() async {
    if (state.isBusy) return;
    state = state.copyWith(
      isBusy: true,
      downloadProgress: 0,
      clearError: true,
      clearProgress: false,
    );
    try {
      final ok = await _manager.downloadModel(
        onProgress: (progress) =>
            state = state.copyWith(downloadProgress: progress.clamp(0.0, 1.0)),
      );
      if (!ok) {
        state = AiModelState(
          isCached: state.isCached,
          errorMessage: 'Unduhan model gagal. Periksa koneksi lalu coba lagi.',
        );
        return;
      }
      state = AiModelState(isCached: true, isLoaded: state.isLoaded);
    } catch (_) {
      state = AiModelState(
        isCached: state.isCached,
        errorMessage: 'Unduhan model gagal. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Memuat model dari cache ke RAM.
  Future<void> load() async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, clearError: true, clearProgress: true);
    try {
      await _engine.initialize();
      final isLoaded = await _engine.isAvailable();
      state = AiModelState(isCached: true, isLoaded: isLoaded);
      if (!isLoaded) {
        state = state.copyWith(
          errorMessage:
              'Model gagal dimuat. '
              'Aplikasi tetap berfungsi penuh tanpa AI.',
        );
      }
    } catch (_) {
      state = AiModelState(
        isCached: state.isCached,
        errorMessage:
            'Model gagal dimuat. '
            'Aplikasi tetap berfungsi penuh tanpa AI.',
      );
    }
  }

  /// Melepas model dari RAM; file cache tetap ada.
  Future<void> unload() async {
    if (state.isBusy) return;
    try {
      await _manager.unloadModel();
      state = state.copyWith(isLoaded: false, clearError: true);
    } catch (_) {
      state = state.copyWith(
        clearError: false,
        errorMessage: 'Model gagal dilepas.',
      );
    }
  }
}

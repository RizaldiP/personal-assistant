import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/ai/ai_model_controller.dart';
import 'package:personal_offline/core/ai/local_ai_runtime.dart';

import '../../helpers/fake_local_ai.dart';

void main() {
  late FakeAiModelManager manager;
  late FakeLocalAiEngine engine;
  late ProviderContainer container;

  AiModelState state() => container.read(aiModelControllerProvider);
  AiModelController controller() =>
      container.read(aiModelControllerProvider.notifier);

  setUp(() {
    manager = FakeAiModelManager();
    engine = FakeLocalAiEngine();
    container = ProviderContainer(
      overrides: [
        localAiRuntimeProvider.overrideWithValue(
          buildFakeRuntime(manager: manager, engine: engine),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('status awal & pembacaan status', () {
    test('awal: belum diunduh, belum dimuat, tidak sibuk', () {
      expect(state().isCached, false);
      expect(state().isLoaded, false);
      expect(state().isBusy, false);
      expect(state().downloadProgress, isNull);
      expect(state().errorMessage, isNull);
    });

    test(
      'ensureInitialized membaca cache dan status muat dari runtime',
      () async {
        manager.cached = true;
        engine.ready = true;

        await controller().ensureInitialized();

        expect(manager.cachedCheckCalls, 1);
        expect(state().isCached, true);
        expect(state().isLoaded, true);
      },
    );

    test('ensureInitialized hanya membaca status satu kali', () async {
      await controller().ensureInitialized();
      await controller().ensureInitialized();

      expect(manager.cachedCheckCalls, 1);
      expect(manager.downloadCalls, 0);
    });

    test('kegagalan membaca status jadi error, bukan exception', () async {
      manager.cachedCheckError = StateError('io rusak');

      await controller().ensureInitialized();

      expect(state().errorMessage, 'Gagal membaca status model AI.');
      expect(state().isBusy, false);
    });
  });

  group('download', () {
    test('sukses: progres dilaporkan lalu status jadi terunduh', () async {
      await controller().download();

      expect(manager.downloadCalls, 1);
      expect(manager.progress, [0.4, 1]);
      expect(state().isCached, true);
      expect(state().isBusy, false);
      expect(state().downloadProgress, isNull);
      expect(state().errorMessage, isNull);
    });

    test('hasil false: error ditampilkan dan status tetap', () async {
      manager.downloadResult = false;

      await controller().download();

      expect(state().isCached, false);
      expect(state().isBusy, false);
      expect(
        state().errorMessage,
        'Unduhan model gagal. Periksa koneksi lalu coba lagi.',
      );
    });

    test('exception dari runtime ditangkap (tidak crash)', () async {
      manager.downloadError = Exception('jaringan putus');

      await controller().download();

      expect(state().isBusy, false);
      expect(state().errorMessage, contains('Unduhan model gagal'));
    });
  });

  group('load / unload', () {
    test('load sukses membuat model siap', () async {
      manager.cached = true;

      await controller().load();

      expect(engine.initializeCalls, 1);
      expect(state().isLoaded, true);
      expect(state().isCached, true);
      expect(state().errorMessage, isNull);
    });

    test('load gagal: pesan ramah dan aplikasi tetap jalan', () async {
      manager.cached = true;
      engine.canLoad = false;

      await controller().load();

      expect(state().isLoaded, false);
      expect(state().errorMessage, contains('Aplikasi tetap berfungsi'));
      expect(state().isBusy, false);
    });

    test('exception backend saat load ditangkap', () async {
      engine.initializeError = Exception('native lib hilang');

      await controller().load();

      expect(state().isLoaded, false);
      expect(state().errorMessage, contains('Model gagal dimuat'));
    });

    test('unload melepas model tanpa menghapus status cache', () async {
      manager.cached = true;
      await controller().load();
      expect(state().isLoaded, true);

      await controller().unload();

      expect(manager.unloadCalls, 1);
      expect(state().isLoaded, false);
      expect(state().isCached, true);
    });
  });

  group('perlindungan saat sibuk', () {
    test('operasi kedua diabaikan selama masih sibuk', () async {
      final first = controller().download();
      final second = controller().download();
      await Future.wait([first, second]);

      expect(manager.downloadCalls, 1);
    });
  });
}

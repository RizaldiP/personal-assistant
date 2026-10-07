// Benchmark sengaja mencetak laporan ke stdout test.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_offline/core/ai/intent_validator.dart';
import 'package:personal_offline/core/ai/llamadart_local_ai_engine.dart';
import 'package:personal_offline/core/ai/local_ai_engine.dart';
import 'package:personal_offline/shared/intents/app_intent.dart';

class _Case {
  const _Case(this.text, this.expected);

  final String text;
  final AppIntent expected;
}

const _cases = <_Case>[
  _Case('Bayar listrik besok jam 8 malam', AppIntent.createReminder),
  _Case('Ingatkan saya rapat tim jam 10 pagi', AppIntent.createReminder),
  _Case('ingt kan sya byar plng listrk bsk mlm', AppIntent.createReminder),
  _Case('Beli beras, telur, dan minyak goreng', AppIntent.createShopping),
  _Case('mw bli susu sm roti ya', AppIntent.createShopping),
  _Case('blai sbru d indomaret', AppIntent.createShopping),
  _Case('Habis makan siang lima puluh ribu', AppIntent.createExpense),
  _Case('bayar ojek 25 ribu', AppIntent.createExpense),
  _Case(
    'Belanja mingguan di supermarket empat ratus lima puluh ribu',
    AppIntent.createExpense,
  ),
  _Case(
    'Aku merasa senang hari ini karena tugas selesai',
    AppIntent.createJournal,
  ),
  _Case('capek bgt hari ini, banyak banget kerjaan', AppIntent.createJournal),
  _Case(
    'Hari ini saya merasa sedih karena hujan terus',
    AppIntent.createJournal,
  ),
  _Case('Catat nomor wifi kantor gardatamu123', AppIntent.createNote),
  _Case(
    'catet ya alamat kantor baru di jalan melati nomor 10',
    AppIntent.createNote,
  ),
  _Case(
    'Ide aplikasi untuk mencatat keuangan secara otomatis',
    AppIntent.createIdea,
  ),
  _Case(
    'gmn kalau bikin usaha laundry kiloan dekat kampus',
    AppIntent.createIdea,
  ),
  _Case('Buat tugas lapor ke atasan hari Jumat', AppIntent.createTodo),
  _Case('Tugas minggu ini beresin laporan keuangan', AppIntent.createTodo),
  _Case('cari catatan tentang rencana liburan ke jogja', AppIntent.search),
  _Case('pantun jaka sembung digantung', AppIntent.unknown),
];

void main() {
  final enabled = Platform.environment['PA_AI_BENCHMARK'] == '1';
  const validator = DefaultIntentValidator();

  // flutter test di Windows: flutter_tester.exe ada di folder engine dan
  // `package:` URI tidak resolve di DynamicLibrary.open, jadi resolver
  // moduleDir llamadart tidak menemukan DLL backend. Arahkan resolver ke
  // folder native assets yang sama dengan yang dibaca VM untuk primary
  // library (via env — di-set in-process karena Platform.environment hidup).
  void ensureBackendModuleDir() {
    if (!Platform.isWindows) {
      return;
    }
    final buildDir =
        '${Directory.current.path}\\build\\native_assets'
        '\\windows';
    if (!File('$buildDir\\ggml-cpu.dll').existsSync()) {
      fail(
        'native assets belum dibangun: jalankan build hook llamadart '
        '(mis. flutter test sekali) agar DLL backend tersedia',
      );
    }
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final setEnv = kernel32
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)
        >('SetEnvironmentVariableW');
    final name = 'LLAMADART_NATIVE_LIB_DIR'.toNativeUtf16();
    final dir = buildDir.toNativeUtf16();
    final ok = setEnv(name, dir);
    malloc.free(name);
    malloc.free(dir);
    if (ok == 0) {
      fail('SetEnvironmentVariableW gagal');
    }
  }

  group(
    'Inference lokal nyata + benchmark (PHASE 10)',
    () {
      late LlamadartLocalAiEngine engine;

      setUpAll(() async {
        ensureBackendModuleDir();
        engine = LlamadartLocalAiEngine();
        final downloaded = await engine.modelManager.downloadModel(
          onProgress: (fraction) {
            final percent = (fraction * 100).floor();
            if (percent % 10 == 0) {
              print('unduhan model: $percent%');
            }
          },
        );
        expect(downloaded, true, reason: 'unduhan model gagal');
        await engine.initialize();
      });

      tearDownAll(() async {
        await engine.dispose();
      });

      test(
        'model dapat diunduh dan dimuat',
        () async {
          expect(await engine.isAvailable(), true);
          expect(engine.modelManager.isLoaded, true);
          expect(engine.modelManager.modelName, contains('Qwen2.5-0.5B'));
          expect(engine.modelManager.sizeBytes, 491400032);
        },
        timeout: const Timeout(Duration(minutes: 15)),
      );

      test(
        'understand menghasilkan JSON valid dan intent benar (smoke)',
        () async {
          const samples = [
            ('besok jam 8 bayar listrik', AppIntent.createReminder),
            ('mw beli telur sama susu', AppIntent.createShopping),
            ('tadi habis makan 25 ribu', AppIntent.createExpense),
          ];

          for (final (text, expected) in samples) {
            final result = await engine.understand(text);
            final validated = validator.validate(result);

            print(
              'smoke "$text" -> ${result.intent.name} '
              'conf=${result.confidence} '
              'needsConfirmation=${validated.result!.needsConfirmation}',
            );
            expect(
              validated.isValid,
              true,
              reason: 'hasil harus lolos validator',
            );
            expect(validated.result!.intent, expected, reason: 'input: $text');
            expect(result.rawJson, isNotNull);
          }
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );

      test(
        'benchmark 20 kalimat campuran (rapi/informal/typo)',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          var peakRss = rssBefore;
          final sampler = Timer.periodic(const Duration(milliseconds: 100), (
            _,
          ) {
            final rss = ProcessInfo.currentRss;
            if (rss > peakRss) {
              peakRss = rss;
            }
          });

          var validJson = 0;
          var correctIntent = 0;
          final latencies = <int>[];
          final failures = <String>[];
          final crashes = <String>[];

          try {
            for (final testCase in _cases) {
              final stopwatch = Stopwatch()..start();
              try {
                final result = await engine.understand(testCase.text);
                stopwatch.stop();
                final validated = validator.validate(result);
                if (validated.isValid) {
                  validJson += 1;
                } else {
                  failures.add(
                    'tolak(${validated.errorCode}) '
                    '${testCase.text}',
                  );
                }
                if (validated.result!.intent == testCase.expected) {
                  correctIntent += 1;
                } else {
                  failures.add(
                    '${testCase.text} '
                    '-> ${result.intent.name} (harusnya '
                    '${testCase.expected.name})',
                  );
                }
              } on LocalAiException catch (error) {
                stopwatch.stop();
                crashes.add(
                  '${testCase.text} -> ${error.runtimeType}: '
                  '${error.message}',
                );
              } catch (error) {
                stopwatch.stop();
                crashes.add(
                  '${testCase.text} -> ${error.runtimeType}: '
                  '$error',
                );
              }
              latencies.add(stopwatch.elapsedMilliseconds);
              final rss = ProcessInfo.currentRss;
              if (rss > peakRss) {
                peakRss = rss;
              }
            }
          } finally {
            sampler.cancel();
          }

          latencies.sort();
          final total = latencies.fold<int>(0, (sum, value) => sum + value);
          final avg = (total / latencies.length).round();
          final maxRss = ProcessInfo.maxRss;

          print('');
          print('=== BENCHMARK PHASE 10 ===');
          print(
            'model: ${engine.modelManager.modelName} '
            '(${engine.modelManager.sizeBytes} byte)',
          );
          print('jumlah kalimat: ${_cases.length}');
          print('JSON valid: $validJson/${_cases.length}');
          print('intent benar: $correctIntent/${_cases.length}');
          print(
            'latency ms — rerata: $avg, '
            'median: ${latencies[latencies.length ~/ 2]}, '
            'min: ${latencies.first}, max: ${latencies.last}',
          );
          print(
            'RSS sebelum: ${rssBefore ~/ (1024 * 1024)} MB, '
            'puncak: ${peakRss ~/ (1024 * 1024)} MB, '
            'maxRss OS: ${maxRss ~/ (1024 * 1024)} MB',
          );
          if (failures.isNotEmpty) {
            print('detail salah:');
            for (final failure in failures) {
              print('  - $failure');
            }
          }
          if (crashes.isNotEmpty) {
            print('detail crash:');
            for (final crash in crashes) {
              print('  - $crash');
            }
          }
          print('==========================');

          expect(crashes, isEmpty, reason: 'AI tidak boleh crash per kalimat');
          expect(
            validJson,
            _cases.length,
            reason: 'structured output wajib selalu JSON valid',
          );
          expect(
            correctIntent,
            greaterThanOrEqualTo(10),
            reason: 'akurasi intent di bawah lantai wajar untuk 0.5B',
          );
        },
        timeout: const Timeout(Duration(minutes: 20)),
      );
    },
    skip: enabled ? false : 'Set PA_AI_BENCHMARK=1 untuk menjalankan.',
  );
}

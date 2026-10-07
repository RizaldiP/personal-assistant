/// SATU-SATUNYA tempat nama model, sumber file, dan parameter AI disimpan.
///
/// Tidak ada hard-code nama model di tempat lain (lihat docs/05 bagian 2).
/// Nilai default mengikuti keputusan PHASE 10; ambang batas confidence
/// disini adalah default preferensi — phase berikutnya boleh menimpanya dari
/// preferensi pengguna tanpa menyebar konstanta baru.
class AiConfig {
  const AiConfig({
    this.modelSource = defaultModelSource,
    this.modelName = defaultModelName,
    this.modelSizeBytes = defaultModelSizeBytes,
    this.contextSize = 4096,
    this.maxOutputTokens = 256,
    this.temperature = 0.0,
    this.topP = 0.9,
    this.seed = 42,
    this.gpuLayers = 0,
    this.cacheDirectory,
    this.acceptThreshold = 0.85,
    this.uncertainThreshold = 0.50,
    this.systemPrompt = defaultSystemPrompt,
  });

  /// Sumber model (`hf://` Hugging Face). Lisensi Apache-2.0.
  static const String defaultModelSource =
      'hf://Qwen/Qwen2.5-0.5B-Instruct-GGUF/'
      'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  static const String defaultModelName = 'Qwen2.5-0.5B-Instruct GGUF Q4_K_M';

  /// Ukuran file model di Hugging Face (byte) — untuk estimasi unduhan.
  static const int defaultModelSizeBytes = 491400032;

  static const String modelLicense = 'Apache-2.0';

  /// Kunci preferensi ambang confidence (docs/05 bagian 6).
  ///
  /// Nilai disimpan sebagai string di tabel `user_preferences`; bila tidak
  /// ada atau tidak valid, dipakai [acceptThreshold]/[uncertainThreshold].
  static const String prefKeyConfidenceAccept = 'ai_confidence_accept';
  static const String prefKeyConfidenceUncertain = 'ai_confidence_uncertain';

  /// Instruksi system prompt: hanya menghasilkan intent terstruktur.
  ///
  /// Aturan prioritas nomor 1-9 sengaja meniru urutan dispatch
  /// `RuleParser.parse` supaya fallback AI dan parser aturan sepakat pada
  /// kalimat ambigu (lihat docs/05 bagian 6). Prompt sengaja ringkas —
  /// model 0.5B kehilangan akurasi saat instruksi terlalu panjang; contoh
  /// penanganan kasus sulit ada di [fewShotExamples].
  static const String defaultSystemPrompt =
      'You are an intent parser for an offline personal assistant app. '
      'User messages are in Bahasa Indonesia (formal, informal, or typos). '
      'Respond with ONLY one JSON object and nothing else. '
      '"intent" must be one of: '
      'create_reminder, create_todo, create_shopping, create_expense, '
      'create_note, create_journal, create_idea, update_item, delete_item, '
      'complete_item, search, unknown. '
      '"confidence" is a number from 0.0 to 1.0. '
      '"needs_confirmation" is true when you are unsure or a required '
      'entity is missing. '
      '"entities" may use only these keys: '
      'title, content, description, category, currency, amount, date, time, '
      'due_date, priority, query, mood, items (array of strings). '
      'Dates are "YYYY-MM-DD" and times "HH:MM" (24-hour). Compute dates ONLY '
      'from the "Today is" line of the CURRENT user message, never from the '
      'examples below. '
      'Decide in this order: '
      '1. Starts with "ide:", "trik:", "inspirasi:", or proposes a new '
      'project/idea (usaha, aplikasi, usaha kiloan) -> create_idea with '
      'content. '
      '2. Starts with "catat:", "catatan:", "note:", "catet:", or the first '
      'word is "catat", "catatan", or "catet" -> create_note with content: '
      '"catet ya alamat kantor baru" -> content "Alamat kantor baru". '
      '3. create_expense ONLY when a money amount is present: digits '
      '("25000"), "rp", or quantity words ("ribu", "juta", "lima puluh '
      'ribu") together with a spend word (beli, bayar, makan, belanja, '
      'jajan, ngopi). Convert words to numbers: "lima puluh ribu" = 50000. '
      'Set currency "IDR" plus description and category. The amount '
      'decides, even when the verb is "beli" or "belanja": '
      '"beli beras lima puluh ribu" -> expense with amount 50000. '
      'A spend word alone, with no amount, is NEVER an expense. '
      '4. Goods to buy with NO amount at all -> create_shopping with items: '
      '"mw beli telur sama susu" -> items ["Telur","Susu"]. '
      'Do not invent an amount. '
      '5. A clock time ("jam 8", "pukul 10", "07:30") or reminder words '
      '(ingatkan, alarm, jangan lupa) -> create_reminder with title, date, '
      'time. "besok jam 8 bayar listrik" is a reminder titled "Bayar '
      'listrik", NOT an expense, because no amount was given. '
      '6. Task action words (kerjakan, beresin, selesaikan, buat, kirim, '
      'servis, jemput) -> create_todo with title and due_date. '
      '7. Feeling or mood words (capek, sedih, senang, galau, ...) -> '
      'create_journal with content and mood, even when the sentence also '
      'mentions tasks or work: "Aku merasa senang hari ini karena tugas '
      'selesai" -> create_journal, mood "senang". '
      '8. Starts with "cari" -> search with query. '
      '9. Otherwise -> unknown with confidence no higher than 0.4. '
      'Required entities: create_expense needs amount; create_shopping needs '
      'a non-empty items array; create_reminder and create_todo need title; '
      'create_note, create_journal and create_idea need content; search needs '
      'query. '
      'Never invent commands outside the intent list.';

  /// Contoh beberapa langkah (few-shot) untuk mengunci perilaku model 0.5B
  /// pada kasus ambigu: nominal vs belanja, jam vs pengeluaran, mood vs
  /// tugas, typo, dan kalimat tak dikenal.
  ///
  /// Setiap entri memakai format pesan yang sama dengan pesan user sungguhan
  /// ([userMessage]) sehingga model tidak kebingungan.
  static const List<({String user, String assistant})> fewShotExamples = [
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: besok jam 8 bayar listrik',
      assistant:
          '{"intent":"create_reminder","confidence":0.95,'
          '"entities":{"title":"Bayar listrik","date":"2026-10-07",'
          '"time":"08:00","priority":"normal"},"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: ingt kan sya byar plng listrk bsk mlm',
      assistant:
          '{"intent":"create_reminder","confidence":0.7,'
          '"entities":{"title":"Bayar listrik","date":"2026-10-07",'
          '"time":"20:00","priority":"normal"},"needs_confirmation":true}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: bayar ojek 25 ribu',
      assistant:
          '{"intent":"create_expense","confidence":0.95,'
          '"entities":{"amount":25000,"currency":"IDR",'
          '"description":"Ojek","category":"transport",'
          '"date":"2026-10-06"},"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: Habis makan siang lima puluh ribu',
      assistant:
          '{"intent":"create_expense","confidence":0.9,'
          '"entities":{"amount":50000,"currency":"IDR",'
          '"description":"Makan siang","category":"makanan",'
          '"date":"2026-10-06"},"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: Belanja mingguan di supermarket empat ratus lima '
          'puluh ribu',
      assistant:
          '{"intent":"create_expense","confidence":0.9,'
          '"entities":{"amount":450000,"currency":"IDR",'
          '"description":"Belanja mingguan di supermarket",'
          '"category":"belanja","date":"2026-10-06"},'
          '"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: mw bli susu sm roti ya',
      assistant:
          '{"intent":"create_shopping","confidence":0.9,'
          '"entities":{"items":["Susu","Roti"]},'
          '"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: blai sbru d indomaret',
      assistant:
          '{"intent":"create_shopping","confidence":0.6,'
          '"entities":{"items":["Sabun"]},"needs_confirmation":true}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: mau beli sabun sama sampo',
      assistant:
          '{"intent":"create_shopping","confidence":0.9,'
          '"entities":{"items":["Sabun","Sampo"]},'
          '"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: capek bgt hari ini, banyak banget kerjaan',
      assistant:
          '{"intent":"create_journal","confidence":0.85,'
          '"entities":{"content":"Capek bgt hari ini, banyak banget '
          'kerjaan","mood":"capek"},"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: Hari ini saya merasa sedih karena hujan terus',
      assistant:
          '{"intent":"create_journal","confidence":0.9,'
          '"entities":{"content":"Saya merasa sedih karena hujan terus",'
          '"mood":"sedih"},"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: Catat nomor wifi kantor gardatamu123',
      assistant:
          '{"intent":"create_note","confidence":0.9,'
          '"entities":{"content":"Nomor wifi kantor gardatamu123"},'
          '"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: gmn kalau bikin usaha laundry kiloan dekat kampus',
      assistant:
          '{"intent":"create_idea","confidence":0.75,'
          '"entities":{"content":"Bikin usaha laundry kiloan dekat kampus"},'
          '"needs_confirmation":true}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: Buat tugas lapor ke atasan hari Jumat',
      assistant:
          '{"intent":"create_todo","confidence":0.9,'
          '"entities":{"title":"Lapor ke atasan","due_date":"2026-10-09",'
          '"priority":"normal"},"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: cari catatan tentang rencana liburan ke jogja',
      assistant:
          '{"intent":"search","confidence":0.9,'
          '"entities":{"query":"catatan tentang rencana liburan ke jogja"},'
          '"needs_confirmation":false}',
    ),
    (
      user:
          'Today is 2026-10-06.\n'
          'User message: pantun jaka sembung digantung',
      assistant:
          '{"intent":"unknown","confidence":0.1,'
          '"entities":{},"needs_confirmation":true}',
    ),
  ];

  final String modelSource;
  final String modelName;
  final int modelSizeBytes;

  /// System prompt + few-shot ±1,5 ribu token; 4096 memberi ruang untuk
  /// pesan panjang pengguna tanpa memotong keluaran JSON.
  final int contextSize;
  final int maxOutputTokens;
  final double temperature;
  final double topP;
  final int seed;

  /// 0 = CPU penuh (default aman lintas perangkat; GPU bisa disetel nanti).
  final int gpuLayers;

  /// Override direktori cache model; null = cache bawaan platform.
  final String? cacheDirectory;

  /// Confidence ≥ ini → tampil kartu langsung (docs/05 bagian 6).
  final double acceptThreshold;

  /// Confidence < ini → jangan menebak, tawarkan Smart Inbox.
  final double uncertainThreshold;

  final String systemPrompt;

  /// Pesan user: konteks hari ini + kalimat mentah dari pengguna.
  String userMessage({required DateTime now, required String text}) {
    final date = now.toIso8601String().split('T').first;
    return 'Today is $date.\nUser message: $text';
  }

  /// JSON Schema ketat untuk structured output (grammar-constrained decoding).
  static const Map<String, dynamic> intentSchema = {
    'type': 'object',
    'properties': {
      'intent': {
        'type': 'string',
        'enum': [
          'create_reminder',
          'create_todo',
          'create_shopping',
          'create_expense',
          'create_note',
          'create_journal',
          'create_idea',
          'update_item',
          'delete_item',
          'complete_item',
          'search',
          'unknown',
        ],
      },
      'confidence': {'type': 'number'},
      'entities': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
          'description': {'type': 'string'},
          'category': {'type': 'string'},
          'currency': {'type': 'string'},
          'mood': {'type': 'string'},
          'priority': {'type': 'string'},
          'date': {'type': 'string'},
          'time': {'type': 'string'},
          'due_date': {'type': 'string'},
          'query': {'type': 'string'},
          'amount': {'type': 'number'},
          'items': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'additionalProperties': false,
      },
      'needs_confirmation': {'type': 'boolean'},
    },
    'required': ['intent', 'confidence', 'entities', 'needs_confirmation'],
    'additionalProperties': false,
  };
}

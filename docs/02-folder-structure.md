# 02 — Folder Structure

## 1. Root project

Proyek Flutter dibuat di root repository (folder ini) pada PHASE 1.

```
personal-assistant/
├── PROJECT.md                 # spesifikasi & aturan phase (sumber utama)
├── README.md                  # cara menjalankan aplikasi
├── analysis_options.yaml      # lint rules
├── pubspec.yaml
├── docs/                      # dokumentasi perencanaan
│   ├── 00-index.md
│   ├── 01-architecture.md
│   ├── 02-folder-structure.md
│   ├── 03-dependencies.md
│   ├── 04-database-planning.md
│   ├── 05-ai-abstraction.md
│   ├── 06-coding-conventions.md
│   └── 07-roadmap.md
├── android/                   # generated oleh flutter create
├── lib/
├── test/
├── integration_test/
├── tool/                      # script util (codegen, backup test data)
└── assets/
    ├── images/
    ├── fonts/
    └── models/                # file model AI (phase 10, opsional)
```

Identitas aplikasi:

| Item | Nilai |
|------|-------|
| App name | Personal Offline |
| Package / app id | `com.personaloffline.app` |
| Dart package | `personal_offline` |
| Organisasi | `com.personaloffline` |
| Min SDK Android | sesuai default Flutter stable, naikkan bila plugin minta |
| Target | Android only pada phase awal |

## 2. Struktur `lib/`

Feature-first: setiap fitur punya folder sendiri, layer di dalamnya.

```
lib/
├── main.dart                      # entry point, bootstrap minimal
├── app.dart                       # MaterialApp, theme, router
│
├── core/
│   ├── config/                    # konstanta app, fitur flag
│   ├── theme/                     # colors, typography, theme mode
│   ├── navigation/                # router, bottom nav definition
│   ├── utils/                     # clock, result<T>, extensions
│   ├── error/                     # failure types, error mapping
│   └── database/                  # drift: tables, daos, migrations
│       ├── app_database.dart
│       ├── tables/
│       ├── daos/
│       └── migrations/
│
├── features/
│   ├── home/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   ├── domain/                # (mulai phase 5+ bila perlu)
│   │   └── data/
│   │
│   ├── chat/
│   ├── todo/
│   ├── reminder/
│   ├── shopping/
│   ├── finance/
│   ├── journal/
│   ├── notes/
│   ├── ideas/
│   ├── calendar/
│   ├── inbox/
│   ├── insights/
│   ├── search/
│   └── settings/
│
└── shared/
    ├── intents/                   # AiIntentResult, intent enum, validator
    ├── nlp/                       # normalizer, rule parser, amount parser
    └── widgets/                   # reusable lintas fitur (app scaffold, dsb.)
```

Catatan layer per fitur:

```
features/<name>/
├── domain/
│   ├── entities/
│   ├── repositories/             # abstract
│   └── usecases/
├── data/
│   ├── models/                   # model drift/serialization
│   ├── datasources/
│   └── repositories/             # implementasi
└── presentation/
    ├── screens/
    ├── widgets/
    └── providers/
```

Fitur awal yang masih sederhana (phase 1) boleh hanya punya
`presentation/`. Folder `domain/` dan `data/` ditambahkan saat fitur itu
mulai punya aturan bisnis (lihat `07-roadmap.md`).

## 3. Struktur `test/`

Ikuti struktur `lib/`:

```
test/
├── core/
│   ├── database/
│   └── theme/
├── features/
│   ├── todo/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   └── finance/
├── shared/
│   ├── intents/
│   └── nlp/
└── helpers/                      # fakes, fixtures, in-memory db
```

Naming file test: `<nama_file>_test.dart`.

## 4. Struktur `integration_test/`

```
integration_test/
├── app_smoke_test.dart           # app run, navigasi, theme
├── chat_persistence_test.dart    # history bertahan setelah restart
├── reminder_flow_test.dart       # phase 6
├── backup_restore_test.dart      # phase 14
└── offline_test.dart             # phase 17
```

## 5. Konvensi penamaan folder

| Item | Konvensi | Contoh |
|------|----------|--------|
| Folder fitur | snake_case, singular | `shopping`, `reminder` |
| Folder layer | snake_case | `presentation`, `datasources` |
| File Dart | snake_case | `todo_repository.dart` |
| File test | snake_case + `_test` | `todo_repository_test.dart` |
| Kelas | PascalCase | `TodoRepositoryImpl` |
| Variabel/function | lowerCamelCase | `createReminder()` |
| Konstanta | lowerCamelCase | `defaultPriority` |
| Table Drift | PascalCase | `class Todos extends Table` |
| Provider | suffix `Provider` | `todoListProvider` |
| Abstract di domain | nama polos | `TodoRepository` |
| Impl di data | suffix `Impl` | `TodoRepositoryImpl` |

## 6. Aturan letak file (penting)

1. Satu file hanya memuat satu top-level class utama.
2. File domain tidak boleh import package Flutter kecuali `meta`.
3. File data tidak boleh import widget.
4. Jangan membuat folder `utils/` raksasa di root — taruh di `core/utils`
   atau di fitur yang memakainya.
5. Jangan membuat folder `models/` di root `lib/`. Model milik fiturnya
   masing-masing, kecuali yang dipakai lintas fitur → `shared/intents/`.
6. Naming public API mengikuti `06-coding-conventions.md`.

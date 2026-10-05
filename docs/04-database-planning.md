# 04 — Database Planning

Engine: **Drift (SQLite)**. Lokasi kode: `lib/core/database/`.
Implementasi dimulai di PHASE 2.

## 1. Aturan umum

1. Setiap entity punya `id`, `created_at`, `updated_at`.
2. `id` bertipe `INTEGER PRIMARY KEY AUTOINCREMENT` (rowid) — sederhana,
   cukup unik untuk device tunggal. ID tidak pernah dipakai sebagai identitas
   lintas perangkat (itu urusan backup, bukan database).
3. `created_at` / `updated_at` disimpan sebagai **epoch millisecond UTC**
   (`INTEGER`). Tampilan jam ditentukan UI.
4. Tanggal murni (tanggal kejadian, tanpa jam) disimpan sebagai text
   ISO-8601 `YYYY-MM-DD` agar mudah dibandingkan dan dibaca.
5. Jam disimpan sebagai text `HH:mm`.
6. Uang disimpan **integer** (IDR tanpa desimal). Kolom `currency` default `IDR`.
7. Enum disimpan sebagai text (readable) + dibatasi di domain layer.
8. Soft delete tidak dipakai pada phase awal; hapus = hapus. Undo ditangani
   di level aksi (simpan salinan sementara di memori), bukan kolom tersembunyi.
9. Foreign key: selalu `ON DELETE CASCADE` untuk relasi child.
10. Kolom tambahan untuk NLP (`source`, `raw_input`, `confidence`) wajib ada
    agar riwayat asal-usul entitas dapat ditelusuri.

## 2. Tabel inti

### 2.1 Task (Todo)

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| title | TEXT NOT NULL | |
| description | TEXT | |
| due_date | TEXT | `YYYY-MM-DD`, nullable |
| due_time | TEXT | `HH:mm`, nullable |
| priority | TEXT NOT NULL | `low` / `normal` / `high` / `urgent`, default `normal` |
| category | TEXT | |
| status | TEXT NOT NULL | `pending` / `done`, default `pending` |
| completed_at | INTEGER | epoch ms, nullable |
| source | TEXT | `chat` / `manual` / `inbox` |
| raw_input | TEXT | teks asli pengguna |
| confidence | REAL | 0.0–1.0, nullable |
| created_at | INTEGER NOT NULL | |
| updated_at | INTEGER NOT NULL | |

Index: `due_date`, `status`, `priority`.

### 2.2 Reminder

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| title | TEXT NOT NULL | |
| notes | TEXT | |
| date | TEXT | `YYYY-MM-DD` |
| time | TEXT | `HH:mm` |
| scheduled_at | INTEGER | epoch ms UTC hasil resolve date+time (untuk scheduler) |
| priority | TEXT NOT NULL | default `normal` |
| status | TEXT NOT NULL | `active` / `completed` / `dismissed` |
| is_recurring | INTEGER | 0/1 |
| recurrence_rule | TEXT | mis. `daily`, `weekly:MON`, `monthly:10`, `interval:3d`, `none` |
| recurrence_anchor | TEXT | `YYYY-MM-DD` acuan hitung ulang |
| next_fire_at | INTEGER | epoch ms UTC, nullable |
| snoozed_until | INTEGER | epoch ms UTC, nullable |
| last_fired_at | INTEGER | nullable |
| completed_at | INTEGER | nullable |
| source / raw_input / confidence | TEXT / TEXT / REAL | |
| created_at / updated_at | INTEGER NOT NULL | |

Index: `status` + `next_fire_at` (query: reminder aktif yang harus ditembak).

### 2.3 ShoppingList

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| title | TEXT NOT NULL | default "Belanja" |
| status | TEXT NOT NULL | `open` / `done` |
| date | TEXT | rencana tanggal belanja, nullable |
| created_at / updated_at | INTEGER NOT NULL | |

### 2.4 ShoppingItem

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| list_id | INTEGER NOT NULL FK → ShoppingList | CASCADE |
| name | TEXT NOT NULL | |
| quantity | REAL | nullable |
| unit | TEXT | nullable (`kg`, `liter`, `pcs`) |
| is_checked | INTEGER NOT NULL | 0/1 default 0 |
| sort_order | INTEGER NOT NULL | default 0 |
| created_at / updated_at | INTEGER NOT NULL | |

Index: `list_id`.

### 2.5 Expense

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| amount | INTEGER NOT NULL | IDR, integer |
| currency | TEXT NOT NULL | default `IDR` |
| category | TEXT NOT NULL | `makanan`, `transport`, `tagihan`, `belanja`, `kesehatan`, `hiburan`, `lainnya` |
| description | TEXT NOT NULL | |
| date | TEXT NOT NULL | `YYYY-MM-DD` |
| payment_method | TEXT | nullable |
| source / raw_input / confidence | TEXT / TEXT / REAL | |
| created_at / updated_at | INTEGER NOT NULL | |

Index: `date`, `category`.

### 2.6 JournalEntry

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| date | TEXT NOT NULL | `YYYY-MM-DD` |
| title | TEXT | |
| content | TEXT NOT NULL | |
| mood | TEXT | nullable, mis. `senang`/`netral`/`capek`/`sedih`/`stres` |
| created_at / updated_at | INTEGER NOT NULL | |

Index: `date`.

### 2.7 Idea

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| title | TEXT NOT NULL | |
| content | TEXT | |
| status | TEXT NOT NULL | `inbox` / `thinking` / `working` / `completed` / `archived`, default `inbox` |
| created_at / updated_at | INTEGER NOT NULL | |

### 2.8 Note

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| title | TEXT | nullable |
| content | TEXT NOT NULL | |
| source / raw_input | TEXT | |
| created_at / updated_at | INTEGER NOT NULL | |

### 2.9 Habit & HabitLog

Habit (dirancang sekarang, diimplementasikan setelah phase roadmap menyebutnya):

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| name | TEXT NOT NULL | |
| recurrence_rule | TEXT | format sama dengan Reminder |
| target | REAL | nullable |
| unit | TEXT | nullable |
| is_active | INTEGER NOT NULL | default 1 |
| color | TEXT | nullable |
| created_at / updated_at | INTEGER NOT NULL | |

HabitLog:

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| habit_id | INTEGER NOT NULL FK → Habit | CASCADE |
| date | TEXT NOT NULL | `YYYY-MM-DD` |
| value | REAL | nullable |
| is_completed | INTEGER NOT NULL | 0/1 |
| note | TEXT | |
| created_at / updated_at | INTEGER NOT NULL | |

Unique index: (`habit_id`, `date`).

### 2.10 ChatMessage

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| role | TEXT NOT NULL | `user` / `assistant` |
| content | TEXT NOT NULL | teks apa adanya |
| intent | TEXT | nullable, hasil deteksi |
| payload | TEXT | JSON hasil structured intent, nullable |
| status | TEXT | `sent` / `processing` / `failed` / `needs_confirmation` |
| resolved_at | INTEGER | nullable → untuk Smart Inbox |
| created_at / updated_at | INTEGER NOT NULL | |

Index: `created_at` (desc), `intent`.

### 2.11 Attachment

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| entity_type | TEXT NOT NULL | `note` / `journal` / `idea` / `chat` |
| entity_id | INTEGER NOT NULL | |
| file_path | TEXT NOT NULL | path relatif app sandbox |
| mime_type | TEXT | |
| size_bytes | INTEGER | |
| created_at / updated_at | INTEGER NOT NULL | |

Index: (`entity_type`, `entity_id`).

### 2.12 Tag & TagLink

Tag:

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| name | TEXT NOT NULL UNIQUE | lowercase |
| color | TEXT | nullable |
| created_at / updated_at | INTEGER NOT NULL | |

TagLink (junction, tanpa `id` karena kombinasi sudah unik):

| Kolom | Tipe | Note |
|-------|------|------|
| tag_id | INTEGER NOT NULL FK | CASCADE |
| entity_type | TEXT NOT NULL | |
| entity_id | INTEGER NOT NULL | |
| created_at / updated_at | INTEGER NOT NULL | |

Unique index: (`tag_id`, `entity_type`, `entity_id`).

### 2.13 UserPreferences

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| key | TEXT NOT NULL UNIQUE | |
| value | TEXT NOT NULL | serialisasi JSON/string |
| created_at / updated_at | INTEGER NOT NULL | |

Dipakai untuk: tema (`light`/`dark`/`system`), bahasa, jam 12/24,
status onboarding, konfirmasi terakhir, dsb.
Sumber kebenaran untuk state jangka panjang; Riverpod hanya cache.

## 3. Entity tambahan (di luar daftar minimal)

### InboxItem (PHASE 13)

Daftar input yang confidence-nya rendah / unresolved.

| Kolom | Tipe | Note |
|-------|------|------|
| id | INTEGER PK | |
| chat_message_id | INTEGER FK → ChatMessage | CASCADE |
| raw_text | TEXT NOT NULL | |
| suggestion | TEXT | intent yang disarankan |
| resolution | TEXT | `open` / `converted` / `discarded` |
| resolved_entity_type | TEXT | nullable |
| resolved_entity_id | INTEGER | nullable |
| created_at / updated_at | INTEGER NOT NULL | |

Alasan menambah: entitas minimal di spec tidak punya tempat untuk state
"belum yakin", dan Smart Inbox adalah fitur phase 13. Alternatif (menumpuk di
Note) dianggap kurang jelas karena butuh kolom status khusus yang tidak relevan
dengan Note biasa.

## 4. ER ringkas

```
ShoppingList 1 ──── ∞ ShoppingItem
Habit        1 ──── ∞ HabitLog
Note/Journal/Idea/Task/Reminder/Chat 1 ──── ∞ Attachment
Tag ∞ ──── ∞ (Note|Journal|Idea|Task|Reminder|Expense)  via TagLink
ChatMessage 1 ──── ∞ InboxItem
```

## 5. Migrasi

Strategi: **drift schema versioning**, tidak pernah `DROP` kolom yang berisi
data pengguna.

```
lib/core/database/
├── app_database.dart        # schemaVersion, migrations
├── tables/                  # definisi Table classes
├── daos/                    # query per domain
└── migrations/
    ├── migration_1_2.dart
    └── ...
```

Aturan migrasi:

1. `schemaVersion` naik 1 per perubahan schema.
2. Perubahan backward-compatible (tambah kolom/tabel/index) → step migrasi.
3. Perubahan breaking (rename/tipe) → buat kolom baru, salin data, jangan
   hapus kolom lama pada versi yang sama.
4. Selalu ada fallback `onUpgrade` yang mencatat ke log lokal bila gagal.
5. Migrasi wajib punya test: bangun DB versi lama → upgrade → assert data
   tetap utuh.
6. Sebelum migrasi berisiko: wajib jalankan backup export otomatis (fitur
   phase 14; sampai saat itu, migrasi harus dianggap non-destruktif).

## 6. Test database (PHASE 2)

- Gunakan drift `NativeDatabase.memory()` untuk unit test (cepat, tanpa file).
- Test CRUD per DAO.
- Test relasi cascade.
- Test migrasi.
- Test query search lintas entity (phase 9/13).
- Selalu buka database in-memory di `setUp`, tutup di `tearDown`.

## 7. Query penting yang harus didukung

| Kebutuhan | Query |
|-----------|-------|
| Todo hari ini | `status='pending' AND due_date = :today` |
| Reminder aktif berikutnya | `status='active' AND next_fire_at <= :now` |
| Total bulanan | `SUM(amount) FROM expense WHERE date BETWEEN :from AND :to` |
| Total harian per kategori | `GROUP BY category, date` |
| Search global | `LIKE :q` pada kolom judul/konten tiap tabel |
| Checklist belum selesai | `list_id=:id AND is_checked=0` |

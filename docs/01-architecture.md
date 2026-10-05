# 01 — Architecture

## 1. Bentuk umum

Aplikasi berarsitektur **layered + feature-first**.
Layer menentukan arah dependensi; fitur menentukan lokasi file.

```
┌─────────────────────────────────────────────┐
│ PRESENTATION  (Flutter widgets, providers) │
├─────────────────────────────────────────────┤
│ APPLICATION / DOMAIN (use case, intent)     │
├─────────────────────────────────────────────┤
│ DATA (repository, datasource, model lokal)  │
├─────────────────────────────────────────────┤
│ INFRASTRUCTURE (notification, AI, backup,   │
│                 PDF, security)              │
└─────────────────────────────────────────────┘
```

Aturan dependensi:

- Presentation → boleh memanggil Domain dan Application.
- Domain → TIDAK tahu Widget, TIDAK tahu Drift, TIDAK tahu plugin.
- Data → mengimplementasi interface Domain.
- Infrastructure → dipanggil lewat interface milik Domain/Application.
- **Arah bawah ke atas dilarang.** Domain tidak pernah import presentation.

## 2. Presentation

Berisi UI dan state.

```
presentation/
├── screens/     satu layar utama per fitur
├── widgets/     widget reusable dalam satu fitur
└── providers/   Riverpod providers (state + aksi)
```

Responsibilitas:

- Merender state.
- Mengirim event ke use case / repository.
- Menampilkan hasil, loading, error, empty state.
- **Tidak** mengandung aturan bisnis (misal parsing tanggal, kategori, total).

## 3. Application / Domain

Berisi aturan bisnis dan orkestrasi.

```
domain/
├── entities/        model murni (Todo, Reminder, Expense...)
├── repositories/    interface abstract class
└── usecases/        satu kelas = satu aksi bisnis
```

Komponen utama:

| Komponen | Tugas |
|----------|-------|
| Intent Processor | memilih jalur: Rule Parser → Local AI → Validator |
| Task Manager | CRUD todo, prioritas, due date, completion |
| Reminder Manager | jadwal, recurring, snooze, cancel |
| Finance Manager | kategori, nominal, daily/monthly total, budget |
| Search Manager | pencarian lokal lintas entity |
| Notification Manager | kontrak schedule/cancel/snooze ke infra |

Aturan emas domain:

- Semua fungsi murni dan bisa diuji tanpa Flutter widget.
- Tidak ada `BuildContext`, tidak ada `DateTime.now()` yang tidak bisa disuntik
  (gunakan clock interface agar test bisa mengatur waktu).

## 4. Data

```
data/
├── datasources/     akses Drift / file / SharedPreferences
├── models/          model data + mapper entity ↔ row
└── repositories/    implementasi interface domain
```

Responsibilitas:

- Membaca dan menulis SQLite (Drift).
- Migrasi schema.
- Mapping error database ke error domain.

Repository hanya mengeksekusi. Ia tidak memutuskan intent dan tidak
mengirim notifikasi; itu urusan domain/application.

## 5. Infrastructure

Bungkus semua plugin platform di belakang interface:

```
infrastructure/
├── notification/    local notification
├── ai/              LocalAiEngine implementation
├── backup/          export/import JSON + ZIP
├── pdf/             PDF generator
└── security/        keystore, PIN, biometric
```

Setiap modul punya interface di domain dan implementasi di sini, agar bisa
di-mock saat test dan bisa ditukar tanpa menyentuh UI.

## 6. Alur data utama

### 6.1 Input teks → aksi (alur inti aplikasi)

```
USER INPUT
   ↓
NORMALIZER   (trim, lowercase untuk deteksi, unicode clean)
   ↓
RULE PARSER  (deteksi tanggal, jam, nominal, intent)
   ↓
confidence tinggi?
   ├── YES → STRUCTURED INTENT
   └── NO  → LOCAL AI (offline) → STRUCTURED INTENT
                     ↓
                VALIDATOR  (schema check + business rule)
                     ↓
                CONFIRMATION (berdasarkan confidence)
                     ↓
                ACTION (repository + notification)
                     ↓
                UNDO TOKEN (opsional, untuk snackbar Undo)
```

Poin penting:

- Rule Parser bekerja lebih dulu. AI hanya dipanggil jika confidence rendah.
- AI menghasilkan JSON, bukan aksi. Validator memutuskan apakah JSON layak
  dipakai.
- Aksi selalu lewat repository aplikasi. AI tidak pernah menyentuh Drift.

### 6.2 Notification

```
Reminder Manager → NotificationScheduler (interface)
                        ↓
              flutter_local_notifications (Android)
```

Harus tetap jalan saat aplikasi tertutup, layar terkunci, internet mati.

### 6.3 Chat sebagai pusat

```
ChatScreen → ChatController → ChatRepository → SQLite
                    ↓
             IntentProcessor (pada phase AI/parser aktif)
                    ↓
             domain managers (todo/reminder/shopping/expense...)
```

Pesan chat disimpan apa adanya. Hasil ekstraksi juga disimpan sebagai
entitas terpisah (bukan menimpa pesan), agar history tetap utuh.

## 7. State management

Pilihan: **Riverpod**.

Alasan:

- Testable tanpa `BuildContext`.
- Scope provider per fitur, tidak global mutable.
- Mendukung `AsyncValue` (loading/error/data) secara konsisten.

Pembagian:

| Tipe | Contoh | Lifetime |
|------|--------|----------|
| Provider | theme, locale, settings | app-wide, long |
| Provider | `todoListProvider` | auto-dispose |
| Notifier | `chatControllerProvider` | hold aksi |

State yang sifatnya data (todo, expense) tetap di database. Riverpod hanya
cache hasil query, bukan sumber kebenaran.

## 8. Layer permission & plugin

Setiap plugin platform wajib di balik interface di domain:

| Interface | Implementasi | Fase |
|-----------|--------------|------|
| `NotificationScheduler` | `flutter_local_notifications` | 6 |
| `LocalAiEngine` | model runtime pilihan | 10 |
| `BackupService` | file + JSON + ZIP | 14 |
| `PdfService` | `pdf` package | 14 |
| `SecureStorage` | Android Keystore | 15 |

Dengan pola ini phase berikutnya tidak merusak phase sebelumnya.

## 9. Non-goal arsitektur

Arsitektur ini sengaja TIDAK memuat:

- Backend / API server / cloud sync.
- Authentication multi-user.
- Analytics online.
- Dependency injection framework berat (cukup Riverpod provider manual).
- BLoC/event bus global.

## 10. Checklist arsitektur

- [x] Layer Presentasi / Domain / Data / Infrastructure
- [x] Arah dependensi one-way
- [x] Semua plugin dibungkus interface
- [x] Alur intent: Normalizer → Rule Parser → AI → Validator → Action
- [x] Notification terpisah dari domain logic
- [x] Chat sebagai input utama, data tidak ditimpa

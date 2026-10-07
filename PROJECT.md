Personal Offline Assistant

Project Specification & Phased Development Plan

«PENTING UNTUK OPENCODE

Proyek ini WAJIB dikerjakan secara bertahap.

JANGAN mengerjakan seluruh proyek sekaligus.

Pada setiap sesi, OpenCode hanya boleh mengerjakan PHASE yang sedang aktif.

Setelah PHASE selesai dan seluruh Definition of Done terpenuhi, STOP.

Jangan melanjutkan ke PHASE berikutnya tanpa instruksi eksplisit dari pengguna.»

---

1. PROJECT OVERVIEW

Buat aplikasi Android bernama sementara:

Personal Offline

Konsep utama:

«Pengguna cukup mengetik seperti sedang berbicara, dan aplikasi memahami apa yang harus dilakukan.»

Contoh:

"besok jam 8 ingetin aku bayar listrik"

menjadi:

🔔 Reminder

Bayar listrik
Besok · 08:00

Contoh:

"besok beli telur, susu sama minyak"

menjadi:

🛒 Shopping List

☐ Telur
☐ Susu
☐ Minyak

Contoh:

"tadi makan ayam 25 ribu"

menjadi:

💰 Pengeluaran

Makan ayam
Rp25.000
Kategori: Makanan

Contoh:

"hari ini capek banget kerja"

menjadi:

📔 Journal

Hari ini capek banget kerja.

Tujuan akhirnya:

«Ketik apa saja. Aplikasi memahami maksudnya dan mengubahnya menjadi sesuatu yang berguna.»

---

2. CORE PRINCIPLES

Aplikasi harus mengikuti prinsip berikut:

1. Offline-first.
2. Privacy-first.
3. Chat-first.
4. Bahasa utama Bahasa Indonesia.
5. Tidak membutuhkan akun.
6. Tidak membutuhkan internet untuk fitur utama.
7. Data utama disimpan di perangkat.
8. Local notification.
9. Local AI jika AI digunakan.
10. AI tidak boleh mempunyai akses langsung ke database.
11. AI hanya menghasilkan structured intent.
12. Business logic tetap dikontrol aplikasi.
13. UI sederhana.
14. Jangan membuat terlalu banyak menu.
15. Jangan membuat fitur hanya karena terlihat keren.
16. Prioritaskan reliability.
17. Setiap phase harus bisa diuji secara mandiri.

---

3. DEVELOPMENT RULE — SANGAT PENTING

OPEN CODE HARUS MENGIKUTI PHASE

Sistem pengerjaan:

PHASE 0
   ↓
PHASE 1
   ↓
PHASE 2
   ↓
PHASE 3
   ↓
...
   ↓
PHASE FINAL

Tetapi OpenCode tidak boleh otomatis berpindah phase.

Pada awal setiap sesi:

1. Baca file "PROJECT.md".
2. Cari bagian "CURRENT ACTIVE PHASE".
3. Kerjakan hanya phase tersebut.
4. Jangan mengimplementasikan fitur phase berikutnya.
5. Jalankan test.
6. Perbaiki error yang berkaitan dengan phase aktif.
7. Perbarui status progress.
8. Tampilkan laporan.
9. STOP.

---

4. CURRENT ACTIVE PHASE

Pada awal proyek:

CURRENT ACTIVE PHASE: PHASE 13
STATUS: DONE

Pengguna akan mengubah bagian ini secara manual.

Contoh:

CURRENT ACTIVE PHASE: PHASE 1
STATUS: IN PROGRESS

Jika OpenCode menemukan:

CURRENT ACTIVE PHASE: PHASE 4

maka hanya PHASE 4 yang boleh dikerjakan.

---

5. HARD STOP RULE

OpenCode DILARANG:

- mengerjakan phase berikutnya
- membuat fitur yang belum diminta phase aktif
- melakukan refactor besar yang tidak diperlukan
- menambahkan AI sebelum phase AI
- membuat backend/cloud
- membuat API server
- menambahkan authentication
- menambahkan fitur subscription
- menambahkan analytics online
- menambahkan cloud sync

Jika phase aktif sudah selesai:

«STOP.»

Jangan berkata:

«"Sekalian saya lanjut membuat..."»

Tidak.

Harus berhenti.

---

6. DEVELOPMENT CYCLE

Setiap phase menggunakan:

READ
 ↓
PLAN
 ↓
IMPLEMENT
 ↓
TEST
 ↓
FIX
 ↓
VERIFY
 ↓
REPORT
 ↓
STOP

Sebelum coding, OpenCode harus memberikan rencana singkat.

Contoh:

PHASE 3 PLAN

1. Membuat ChatMessage model.
2. Membuat ChatRepository.
3. Membuat ChatScreen.
4. Membuat input field.
5. Menyimpan pesan lokal.
6. Menampilkan history.
7. Menjalankan test.

Setelah selesai:

PHASE 3 RESULT

Completed:
- Chat UI
- Local chat storage
- Send message
- History

Tests:
PASS

Status:
DONE

STOP.

---

7. TECHNOLOGY

Gunakan:

- Flutter
- Dart
- Android
- SQLite / Drift
- Local Notification
- Local storage
- PDF generator
- Android Keystore / secure storage jika diperlukan

AI dibuat modular.

Jangan mengikat seluruh aplikasi pada satu model AI.

Gunakan abstraction:

abstract class LocalAiEngine {
  Future<void> initialize();

  Future<AiIntentResult> understand(String text);

  Future<bool> isAvailable();

  Future<void> dispose();
}

---

8. FINAL APPLICATION ARCHITECTURE

Target architecture:

Presentation
│
├── Home
├── Chat
├── Todo
├── Reminder
├── Shopping
├── Finance
├── Journal
├── Ideas
├── Calendar
├── Search
└── Settings
        │
        ▼
Application / Domain
        │
├── Intent Processor
├── Task Manager
├── Reminder Manager
├── Finance Manager
├── Search Manager
└── Notification Manager
        │
        ▼
Data
│
├── SQLite
├── Local Files
└── Preferences
        │
        ▼
Infrastructure
│
├── Notification
├── Local AI
├── Backup
├── PDF
└── Security

---

9. MAIN USER EXPERIENCE

Home harus langsung berfokus pada input.

Contoh:

┌──────────────────────────────────┐
│                                  │
│ Selamat pagi 👋                  │
│ Senin, 5 Oktober 2026            │
│                                  │
├──────────────────────────────────┤
│                                  │
│ HARI INI                         │
│                                  │
│ ☐ Bayar listrik          08:00   │
│ ☐ Kirim laporan          10:00   │
│ ☐ Beli oli               17:00   │
│                                  │
├──────────────────────────────────┤
│                                  │
│ Apa yang ingin kamu lakukan?     │
│                                  │
│ [ Ketik di sini...           ➤ ] │
│                                  │
└──────────────────────────────────┘

User tidak perlu memilih jenis input terlebih dahulu.

---

10. CORE INTENTS

Aplikasi akhirnya harus mampu memahami:

create_reminder
create_todo
create_shopping
create_expense
create_note
create_journal
create_idea

update_item
delete_item
complete_item
search

unknown

---

11. REMINDER

Contoh:

besok jam 8 bayar listrik

Output:

{
  "intent": "create_reminder",
  "title": "Bayar listrik",
  "date": "YYYY-MM-DD",
  "time": "08:00",
  "priority": "normal"
}

Harus mendukung:

- hari ini
- besok
- lusa
- minggu depan
- bulan depan
- Senin
- Selasa
- Rabu
- Kamis
- Jumat
- Sabtu
- Minggu
- tanggal tertentu
- 3 hari lagi
- 2 minggu lagi
- pagi
- siang
- sore
- malam
- jam 8
- jam 20:00

---

12. TODO

Contoh:

besok selesaikan laporan kapal

Output:

{
  "intent": "create_todo",
  "title": "Selesaikan laporan kapal",
  "due_date": "YYYY-MM-DD",
  "priority": "normal"
}

Todo memiliki:

- title
- description
- due date
- due time
- priority
- category
- tags
- status
- created_at
- completed_at

---

13. SHOPPING

Contoh:

besok beli telur, susu dan minyak

Output:

{
  "intent": "create_shopping",
  "items": [
    "Telur",
    "Susu",
    "Minyak"
  ]
}

---

14. FINANCE

Contoh:

tadi beli bensin 50 ribu

Output:

{
  "intent": "create_expense",
  "amount": 50000,
  "currency": "IDR",
  "category": "transport",
  "description": "Bensin"
}

Harus memahami:

10 ribu
10rb
10k
10.000
1 juta
1jt
Rp50.000
50 ribu rupiah

---

15. JOURNAL

Contoh:

hari ini capek banget kerja

→ Journal.

Data:

date
title
content
mood
tags

---

16. IDEAS

Contoh:

ide: aplikasi inventory kapal offline

→ Idea.

Status:

Inbox
Thinking
Working
Completed
Archived

---

17. NOTES

Jika sistem tidak yakin:

unknown

jangan memaksakan klasifikasi.

Simpan sebagai Note atau Inbox.

Contoh:

nomor sparepart pompa 12345

→ Note.

---

18. LOCAL NOTIFICATION

Reminder harus menggunakan local notification.

Harus bekerja ketika:

- aplikasi ditutup
- internet mati
- user tidak membuka aplikasi

Notification:

🔔 Reminder

Bayar listrik

08:00

Action:

Selesai
Tunda 10 menit
Tunda 1 jam
Besok

---

19. RECURRING REMINDER

Dukung:

setiap hari
setiap Senin
setiap minggu
setiap bulan
setiap tanggal 10
setiap 3 hari

Contoh:

setiap Senin jam 7 ingatkan olahraga

---

20. AI ARCHITECTURE

AI tidak dibuat pada awal proyek.

AI akan masuk pada phase khusus.

Sistem final:

USER INPUT
    ↓
NORMALIZER
    ↓
RULE PARSER
    ↓
Confidence tinggi?
    │
    ├── YES → STRUCTURED INTENT
    │
    └── NO
          ↓
       LOCAL AI
          ↓
    STRUCTURED INTENT
          ↓
       VALIDATOR
          ↓
     CONFIRMATION
          ↓
       ACTION

---

21. RULE PARSER

Kalimat sederhana harus ditangani tanpa AI.

Contoh:

besok jam 8 bayar listrik

Tidak perlu memanggil AI.

Rule parser harus mampu:

- mendeteksi tanggal
- mendeteksi jam
- mendeteksi nominal
- mendeteksi kata reminder
- mendeteksi kata todo
- mendeteksi shopping
- mendeteksi expense
- mendeteksi journal
- mendeteksi idea

---

22. LOCAL AI

AI hanya digunakan untuk kalimat yang:

- ambigu
- kompleks
- informal
- typo
- tidak cocok dengan rule parser

AI harus:

- offline
- on-device
- tidak membutuhkan API key
- tidak membutuhkan API quota
- tidak mengirim data ke cloud

Model harus dipilih berdasarkan:

- ukuran
- RAM
- performa Android
- Bahasa Indonesia
- structured output
- lisensi komersial

Jangan hard-code model.

---

23. AI OUTPUT

AI wajib menghasilkan structured JSON.

Contoh:

{
  "intent": "create_reminder",
  "confidence": 0.96,
  "entities": {
    "title": "Bayar listrik",
    "date": "2026-10-06",
    "time": "08:00"
  },
  "needs_confirmation": false
}

AI tidak boleh mengakses database secara langsung.

AI tidak boleh:

execute_shell
delete_database
send_network_request

---

24. CONFIRMATION

Confidence tinggi:

✓ Reminder

Bayar listrik
Besok · 08:00

[Simpan]

Confidence sedang:

Saya memahami ini sebagai:

🔔 Reminder
"Servis motor"

Benar?

[Ya] [Ubah]

Confidence rendah:

Aku belum yakin.

Kamu ingin menjadikannya:

[Reminder]
[Todo]
[Catatan]

---

25. CONTEXT

Aplikasi harus memahami konteks pendek.

Contoh:

User:
besok jam 8 bayar listrik

Assistant:
Reminder dibuat.

User:
ubah jadi jam 10

→ update reminder terakhir.

Dukung:

ubah
hapus
tunda
selesaikan
jangan ingatkan lagi
jadikan besok
ubah jam

---

26. DATABASE

Minimal entity:

Task
Reminder
ShoppingList
ShoppingItem
Expense
JournalEntry
Idea
Note
Habit
HabitLog
ChatMessage
Attachment
Tag
UserPreferences

Semua entity memiliki:

id
created_at
updated_at

Gunakan database migration.

---

27. SEARCH

Global search:

todo
reminder
shopping
expense
journal
idea
note

Contoh:

listrik

dapat menemukan:

Reminder:
Bayar listrik

Expense:
Bayar listrik Rp350.000

Note:
Nomor pelanggan listrik

Semua pencarian lokal.

---

28. CALENDAR

Calendar menampilkan:

- Todo
- Reminder
- Journal
- Recurring reminder

Gunakan indikator pada tanggal.

---

29. BACKUP

Wajib tersedia.

Export:

personal-offline-backup-YYYY-MM-DD.json

Jika attachment:

ZIP

Import harus:

1. validasi
2. preview
3. konfirmasi
4. restore
5. tidak merusak database jika gagal

---

30. SECURITY

Tambahkan optional:

- PIN
- biometric
- secure storage
- Android Keystore

Jangan menyimpan PIN plaintext.

---

31. DARK / LIGHT MODE

Harus mendukung:

Light
Dark
System

Desain:

- modern
- minimal
- rounded
- clean
- whitespace cukup
- typography jelas
- tidak terlalu banyak warna

---

32. BOTTOM NAVIGATION

Target:

Home
Calendar
Inbox
Insights
Settings

Home tetap menjadi pusat aplikasi.

---

33. SMART INBOX

Input yang tidak yakin masuk Inbox.

Contoh:

kayaknya besok harus beli sesuatu buat rumah

→ Inbox.

User dapat memilih:

Reminder
Todo
Shopping
Note

---

34. UNDO

Setelah aksi:

✓ Reminder dibuat

[Undo]

Undo harus benar-benar membatalkan action.

---

35. PHASE ROADMAP

---

PHASE 0 — PROJECT PLANNING

Tujuan

Menyiapkan arsitektur dan struktur project tanpa membuat fitur kompleks.

Kerjakan

- tentukan architecture
- tentukan folder structure
- tentukan dependency
- buat dokumentasi
- buat coding conventions
- buat database planning
- buat AI abstraction planning

Jangan

- membuat AI
- membuat notification
- membuat finance
- membuat parser lengkap

Definition of Done

- [ ] architecture terdokumentasi
- [ ] folder structure ditentukan
- [ ] dependency ditentukan
- [ ] database entity dirancang
- [ ] AI interface dirancang
- [ ] roadmap dipahami

STOP.

---

PHASE 1 — FLUTTER FOUNDATION

Tujuan

Membuat project Flutter yang dapat berjalan.

Kerjakan

- Flutter project
- Android setup
- theme
- navigation
- Home
- Settings
- Calendar placeholder
- Inbox placeholder
- Insights placeholder

Jangan

- database
- AI
- notification
- finance logic

Definition of Done

- [ ] aplikasi run
- [ ] Home tampil
- [ ] navigation bekerja
- [ ] dark mode
- [ ] light mode
- [ ] tidak ada compile error

STOP.

---

PHASE 2 — LOCAL DATABASE

Tujuan

Membangun storage lokal.

Kerjakan

Database untuk:

- Task
- Reminder
- ChatMessage
- UserPreferences

Buat:

- repository
- migration
- CRUD
- tests

Jangan

- AI
- notification
- finance

Definition of Done

- [ ] database dibuat
- [ ] insert
- [ ] update
- [ ] delete
- [ ] query
- [ ] migration
- [ ] tests PASS

STOP.

---

PHASE 3 — CHAT UI

Tujuan

Membuat chat sebagai pusat aplikasi.

Kerjakan

- Chat screen
- message bubble
- input
- send
- history
- local storage
- empty state
- loading state

Input:

besok bayar listrik

sementara cukup disimpan sebagai pesan.

Jangan

- AI
- parser kompleks
- notification

Definition of Done

- [ ] user bisa mengetik
- [ ] user bisa send
- [ ] message muncul
- [ ] history tersimpan
- [ ] app restart tidak menghilangkan history

STOP.

---

PHASE 4 — RULE-BASED NLP

Tujuan

Memahami kalimat sederhana tanpa AI.

Kerjakan

Parser:

- reminder
- todo
- shopping
- expense
- date
- time
- amount

Test wajib

besok jam 8 bayar listrik
besok beli telur susu
tadi makan 25 ribu
hari ini kerjakan laporan
3 hari lagi servis motor

Definition of Done

- [ ] parser bekerja
- [ ] date parser
- [ ] time parser
- [ ] amount parser
- [ ] intent detection
- [ ] unit tests PASS

STOP.

---

PHASE 5 — TODO

Tujuan

Input natural language dapat membuat Todo.

Contoh:

besok selesaikan laporan kapal

→ Todo.

Kerjakan

- Todo entity
- Todo repository
- Todo UI
- create
- edit
- complete
- delete
- priority
- due date

Definition of Done

- [ ] create
- [ ] edit
- [ ] complete
- [ ] delete
- [ ] natural language create
- [ ] tests PASS

STOP.

---

PHASE 6 — REMINDER + NOTIFICATION

Tujuan

Membuat reminder benar-benar menghasilkan notification.

Kerjakan

- Reminder entity
- Notification service
- schedule
- cancel
- snooze
- complete
- recurring reminder dasar

Test

Pastikan notification tetap muncul ketika:

- aplikasi ditutup
- layar terkunci
- internet mati

Definition of Done

- [x] notification bekerja
- [x] schedule bekerja
- [x] cancel bekerja
- [x] snooze bekerja
- [x] recurring bekerja
- [x] permission Android ditangani

STOP.

---

PHASE 7 — SHOPPING LIST

Kerjakan

- Shopping List
- Shopping Item
- checklist
- add/remove
- natural language parser

Test:

besok beli beras minyak telur

Definition of Done

- [x] shopping list
- [x] item checklist
- [x] natural language
- [x] persistent storage

STOP.

---

PHASE 8 — FINANCE

Kerjakan

- Expense
- kategori
- nominal
- tanggal
- summary
- monthly total
- simple budget

Test:

tadi makan ayam 25 ribu
beli bensin 50rb
bayar listrik 350 ribu

Definition of Done

- [x] expense
- [x] category
- [x] amount parser
- [x] daily total
- [x] monthly total
- [x] tests

STOP.

---

PHASE 9 — NOTE / JOURNAL / IDEA

Kerjakan

- Notes
- Journal
- Ideas
- mood
- tags

Input:

catatan: nomor sparepart 12345

hari ini capek banget

ide: aplikasi inventory kapal

Definition of Done

- [x] note
- [x] journal
- [x] idea
- [x] tag
- [x] search

STOP.

---

PHASE 10 — LOCAL AI

Tujuan

Menambahkan AI on-device.

PENTING

Jangan mengganti Rule Parser.

Arsitektur:

Rule Parser
    ↓
confidence tinggi?
    ↓
YES → parser
NO → Local AI

Kerjakan

- LocalAiEngine
- model manager
- model initialization
- inference
- structured JSON
- validator
- error handling

Model harus dipilih berdasarkan:

- offline
- commercial-compatible license
- mobile performance
- Bahasa Indonesia
- structured output
- reasonable RAM/storage

Jangan

- cloud API
- API key
- backend AI

Definition of Done

- [x] model lokal dapat load
- [x] inference bekerja
- [x] JSON valid
- [x] app tetap bekerja tanpa model
- [x] AI tidak crash app
- [x] benchmark sederhana

STOP.

---

PHASE 11 — HYBRID INTELLIGENCE

Tujuan

Menggabungkan parser + AI.

Contoh:

besok jam 8 bayar listrik

→ Rule Parser.

Sedangkan:

kayaknya minggu depan gue harus ngurus pajak motor

→ Local AI.

Definition of Done

- [x] routing parser/AI
- [x] confidence
- [x] fallback
- [x] validation
- [x] confirmation
- [x] ambiguous handling

STOP.

---

PHASE 12 — CONTEXTUAL CHAT

Tujuan

Memahami perintah lanjutan.

Contoh:

besok jam 8 bayar listrik

kemudian:

ubah jadi jam 10

→ reminder menjadi 10:00.

Dukung:

ubah
hapus
selesaikan
tunda
jadikan besok
ubah jam

Definition of Done

- [x] last item context
- [x] update
- [x] delete
- [x] complete
- [x] snooze
- [x] tests

STOP.

---

PHASE 13 — SEARCH + CALENDAR + SMART INBOX

Kerjakan

- global search
- calendar
- Inbox
- unresolved intent
- filters
- tags

Definition of Done

- [x] search cepat
- [x] calendar
- [x] inbox
- [x] unresolved items
- [x] filtering

STOP.

---

PHASE 14 — BACKUP / RESTORE / PDF

Kerjakan

- JSON backup
- restore
- ZIP attachment
- PDF export
- validation
- conflict handling

Definition of Done

- [ ] export
- [ ] import
- [ ] failed restore aman
- [ ] attachment
- [ ] PDF

STOP.

---

PHASE 15 — SECURITY

Kerjakan

- app lock
- PIN
- biometric
- secure storage
- Android Keystore
- sensitive data handling

Definition of Done

- [ ] PIN
- [ ] biometric
- [ ] secure storage
- [ ] no plaintext secrets

STOP.

---

PHASE 16 — UI/UX POLISH

Kerjakan

- animations ringan
- transitions
- empty states
- loading states
- error states
- accessibility
- responsive layout
- typography
- spacing
- dark mode refinement

Jangan menambahkan fitur baru.

Definition of Done

- [ ] UI konsisten
- [ ] tidak ada overflow
- [ ] dark mode bagus
- [ ] light mode bagus
- [ ] accessibility dasar
- [ ] loading/error state

STOP.

---

PHASE 17 — TESTING & RELEASE

Kerjakan

Full test:

Reminder

besok jam 8 bayar listrik

Todo

besok selesaikan laporan

Shopping

besok beli telur susu minyak

Finance

tadi makan 25 ribu

Journal

hari ini capek banget

AI

kayaknya minggu depan aku harus servis motor

Context

ubah jadi jam 10

Test:

- offline
- notification
- restart
- database
- backup
- restore
- dark mode
- low memory
- AI unavailable
- permission denied

Definition of Done

- [ ] unit tests PASS
- [ ] widget tests PASS
- [ ] integration tests PASS
- [ ] release build berhasil
- [ ] offline test PASS
- [ ] notification PASS
- [ ] backup PASS
- [ ] AI fallback PASS

STOP.

---

36. FINAL QUALITY RULES

Jangan mengorbankan:

Reliability
Privacy
Offline functionality
Data integrity
User control

demi:

AI
Animation
Feature count
Visual gimmick

---

37. FINAL PRODUCT VISION

Aplikasi harus terasa seperti:

«"Aku cukup mengetik apa yang kupikirkan. Aplikasi ini yang mengurus sisanya."»

Bukan:

«"Aku harus mencari menu apa yang harus dipakai."»

Contoh ideal:

User:
besok pagi jangan lupa bayar listrik

App:
🔔 Saya memahami:

Bayar listrik
Besok · 08:00

[Simpan]

User:

tadi beli bensin 50 ribu

App:

💰 Pengeluaran dicatat

Bensin
Transportasi
Rp50.000

User:

kayaknya minggu depan harus servis motor

App:

🔔 Saya kurang yakin dengan waktunya.

Mau dijadwalkan:

Senin depan · 08:00

[Ya] [Ubah]

---

38. FINAL RULE FOR OPENCODE

READ THIS BEFORE EVERY TASK.

1. Read PROJECT.md.
2. Find CURRENT ACTIVE PHASE.
3. Work ONLY on CURRENT ACTIVE PHASE.
4. Do NOT implement future phases.
5. Do NOT add unrelated features.
6. Plan first.
7. Implement.
8. Test.
9. Fix errors related to current phase.
10. Verify Definition of Done.
11. Report result.
12. STOP.

Jika current phase selesai:

«DO NOT CONTINUE TO THE NEXT PHASE.»

Tunggu instruksi pengguna.

---

39. CURRENT ACTIVE PHASE

CURRENT ACTIVE PHASE: PHASE 13
STATUS: DONE

User akan mengubah nilai ini untuk memulai phase berikutnya.

END OF PROJECT SPECIFICATION
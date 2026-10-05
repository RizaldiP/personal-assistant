# Dokumentasi Proyek — Personal Offline

Indeks dokumen perencanaan (PHASE 0).

Aturan kerja proyek ada di `PROJECT.md`. Dokumen ini TIDAK menggantikan `PROJECT.md`.

| # | Dokumen | Isi |
|---|---------|-----|
| 00 | `00-index.md` | Indeks dan cara pakai |
| 01 | `01-architecture.md` | Arsitektur layer dan alur data |
| 02 | `02-folder-structure.md` | Struktur folder source code |
| 03 | `03-dependencies.md` | Daftar dependency + versi + phase pemakaian |
| 04 | `04-database-planning.md` | Perancangan entity database + migration |
| 05 | `05-ai-abstraction.md` | Interface AI dan kontrak structured intent |
| 06 | `06-coding-conventions.md` | Coding conventions & testing strategy |
| 07 | `07-roadmap.md` | Roadmap phase + status progress |

## Urutan baca

1. `PROJECT.md` (wajib, setiap sesi)
2. `07-roadmap.md` → cari phase aktif
3. Dokumen terkait phase tersebut
4. Kerjakan phase → test → report → STOP

## Prinsip yang tidak boleh dilanggar

1. Offline-first, privacy-first, chat-first.
2. Data utama di perangkat. Tanpa akun, tanpa internet untuk fitur utama.
3. AI tidak pernah mengakses database. AI hanya menghasilkan structured intent.
4. Business logic dikontrol aplikasi, bukan model AI.
5. Reliability > jumlah fitur.

## Status dokumen

Dibuat pada PHASE 0. Setiap perubahan besar arsitektur harus mengubah dokumen ini
di phase yang memperbaikinya, lalu dicatat di `07-roadmap.md`.

# Repo Handover ke GitLab Implementation Plan

> **Arsip historis.** Dokumen ini merekam rencana/temuan pada tanggal asal; checklist tidak membuktikan seluruh pekerjaan sudah selesai. Acuan terbaru: [status proyek](../../project-status.md) dan kontrak resmi SICABOR. Jangan menjalankan instruksi historis tanpa meninjau kode serta kebutuhan terbaru.

> **Digantikan:** rencana ini keliru menyebut kontrak SICABOR sebagai draft. Gunakan [rencana handover yang dikoreksi](../../handover.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyiapkan repository aplikasi KOK KONI Garut agar rapi, terdokumentasi, dapat direproduksi, dan dipindahkan hanya dengan branch `main` ke repository GitLab KONI.

**Architecture:** Pertahankan source code dan riwayat Git yang ada. Lakukan cleanup ringan pada dokumentasi dan handover information tanpa menulis ulang 145 commit lama. Setelah baseline diverifikasi, tambahkan remote GitLab dan push hanya `main`; remote GitHub dipertahankan sementara sebagai backup.

**Tech Stack:** Flutter 3.44.4, Dart 3.12.2, Riverpod, GoRouter, Dio, Freezed/JSON serialization, Git, GitLab.

**Spec:** Permintaan handover repository dari percakapan ini dan audit repository lokal pada 2026-09-19.

## Global Constraints

- Jangan mengubah atau menulis ulang riwayat 145 commit `main`.
- Jangan memindahkan branch lain ke GitLab; hanya `main` yang dipush.
- Jangan menghapus dokumentasi secara massal; pindahkan atau tandai sebagai arsip jika masih berguna.
- Jangan mengklaim aplikasi sudah terintegrasi SICABOR; endpoint dan kontrak resmi masih belum tersedia.
- Jangan memasukkan secret produksi, token nyata, atau kredensial KONI nyata ke repository.
- File generated dan local tooling (`.dart_tool`, `build`, `.worktrees`, `.task-appdata`, `.superpowers`) tetap diabaikan oleh Git.

---

### Task 1: Tetapkan baseline kerja dan status handover

**Files:**
- Inspect: `README.md`
- Inspect: `pubspec.yaml`, `pubspec.lock`, `.gitignore`
- Inspect: `docs/api/`, `docs/audit/`, `docs/superpowers/`
- Create: `docs/project-status.md`

**Interfaces:**
- Consumes: status source code, hasil pengujian, dokumentasi API, dan audit saat ini.
- Produces: satu dokumen status yang menjadi titik awal handover dan menyatakan dengan jelas bahwa aplikasi masih menggunakan data demo lokal.

- [ ] **Step 1: Catat kondisi awal repository**

Run:

```powershell
git status --short --branch
git log -1 --oneline
git rev-list --count main
```

Expected: working tree dan file untracked teridentifikasi; `main` memiliki 145 commit sebelum cleanup.

- [ ] **Step 2: Putuskan isi file untracked**

Review `docs/api/` dan `docs/architecture/authentication-current.md`. Pertahankan jika merupakan dokumentasi handover; jangan membiarkannya untracked secara tidak sengaja.

- [ ] **Step 3: Tulis `docs/project-status.md`**

Dokumen harus memuat status demo lokal, batas integrasi SICABOR, fitur yang sudah tersedia, pekerjaan lanjutan, risiko/gap, dan perintah verifikasi.

- [ ] **Step 4: Commit baseline documentation**

```powershell
git add docs/project-status.md docs/API docs/architecture/authentication-current.md
git commit -m "docs: tambahkan status handover proyek KOK"
```

### Task 2: Netralisasi dan indeks struktur dokumentasi

**Files:**
- Create: `docs/README.md`
- Move: `docs/superpowers/plans/*` → `docs/plans/*`
- Move: `docs/superpowers/specs/*` → `docs/specifications/*`
- Move: `docs/api/api-kok-sicabor.md` → `docs/api/sicabor-contract-draft.md`
- Move: `docs/architecture/authentication-current.md` → `docs/architecture/authentication-current.md`
- Move: `docs/design/wireframe-kok.pdf` → `docs/design/wireframe-kok.pdf`

**Interfaces:**
- Consumes: 19 plan, 17 specification, API draft, audit, dan wireframe yang sudah ada.
- Produces: struktur dokumentasi yang tidak bergantung pada nama tool dan mudah dinavigasi oleh tim IT KONI.

- [ ] **Step 1: Buat folder tujuan**

```powershell
New-Item -ItemType Directory -Force docs/api, docs/architecture, docs/design, docs/plans, docs/specifications | Out-Null
```

- [ ] **Step 2: Pindahkan file dengan `git mv`**

Gunakan `git mv` agar Git dapat mengenali perpindahan file. Jangan menghapus isi dokumen pada tahap ini.

- [ ] **Step 3: Tambahkan indeks `docs/README.md`**

Indeks harus menjelaskan fungsi folder `api`, `architecture`, `design`, `audit`, `plans`, dan `specifications`, serta menunjuk ke `docs/project-status.md` sebagai dokumen awal handover.

- [ ] **Step 4: Tandai API sebagai draft**

Tambahkan peringatan di awal `docs/api/sicabor-contract-draft.md` bahwa isinya adalah rancangan/hipotesis integrasi sampai kontrak resmi SICABOR diberikan oleh KONI.

- [ ] **Step 5: Commit reorganisasi dokumentasi**

```powershell
git add -A docs
git commit -m "docs: rapikan struktur dokumentasi proyek"
```

### Task 3: Perbarui README untuk handover

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: `docs/README.md` dan `docs/project-status.md`.
- Produces: halaman awal yang dapat dipahami oleh developer KONI tanpa membaca seluruh dokumentasi historis.

- [ ] **Step 1: Pertahankan instruksi setup yang sudah benar**

Pertahankan perintah Flutter, daftar fitur, struktur kode, dan perintah verifikasi yang masih berlaku.

- [ ] **Step 2: Tambahkan bagian handover singkat**

Jelaskan bahwa aplikasi belum terhubung ke API SICABOR, data olahraga masih demo, adapter remote masih menunggu kontrak resmi, dan server harus menjadi sumber otorisasi serta scope kecamatan.

- [ ] **Step 3: Tambahkan tautan ke dokumentasi utama**

README harus menunjuk ke `docs/README.md`, `docs/project-status.md`, dokumentasi arsitektur autentikasi, dan draft API.

- [ ] **Step 4: Audit kredensial demo**

Pastikan semua akun/password pada README dan test benar-benar akun demo lokal, tidak dipakai di server, dan diberi label non-produksi. Jika ada kredensial nyata, hapus dan rotasi sebelum push.

- [ ] **Step 5: Commit README**

```powershell
git add README.md
git commit -m "docs: lengkapi README untuk handover KONI"
```

### Task 4: Verifikasi kualitas dan kebersihan repository

**Files:**
- Inspect: `.gitignore`
- Inspect: tracked generated files and local artifacts
- Test: Flutter analyzer, unit/widget tests, web build

**Interfaces:**
- Consumes: source tree setelah cleanup dokumentasi.
- Produces: baseline yang dapat direproduksi sebelum dipush ke GitLab.

- [ ] **Step 1: Pastikan working tree bersih**

```powershell
git status --short
```

Expected: tidak ada file yang tertinggal tanpa keputusan; hanya perubahan yang memang akan dikirim yang sudah di-commit.

- [ ] **Step 2: Jalankan analyzer dan test**

```powershell
flutter analyze
flutter test
```

Expected: kedua perintah selesai tanpa error.

- [ ] **Step 3: Validasi build web**

```powershell
flutter build web
```

Expected: build selesai dan output build tetap diabaikan oleh `.gitignore`.

- [ ] **Step 4: Pastikan tidak ada secret produksi**

Periksa source, dokumentasi, test, dan konfigurasi untuk API key, token nyata, private key, password server, atau URL internal yang seharusnya rahasia.

- [ ] **Step 5: Catat hasil verifikasi**

Tambahkan tanggal dan perintah yang berhasil ke `docs/project-status.md` atau `docs/audit/evidence/` tanpa memasukkan output yang berisi credential.

### Task 5: Pindahkan `main` ke GitLab

**Files:**
- Modify: local Git remote configuration only
- Remote target: `https://gitlab.com/konigarut/apps-kok.git`

**Interfaces:**
- Consumes: branch `main` yang sudah bersih dan terverifikasi.
- Produces: GitLab repository dengan history dan tree yang sama, hanya branch `main` yang dikirim.

- [ ] **Step 1: Simpan GitHub sebagai remote backup**

```powershell
git remote rename origin github
git remote add gitlab https://gitlab.com/konigarut/apps-kok.git
```

- [ ] **Step 2: Push hanya `main`**

```powershell
git push -u gitlab main
```

Jangan gunakan `git push --mirror` dan jangan gunakan `git push --all`.

- [ ] **Step 3: Verifikasi hash dan branch GitLab**

```powershell
git rev-parse main
git ls-remote gitlab refs/heads/main
git branch -r
```

Expected: hash `main` lokal sama dengan hash `main` GitLab dan tidak ada branch lain yang dipush.

- [ ] **Step 4: Atur GitLab untuk handover**

Di GitLab, pastikan `main` menjadi default branch, nonaktifkan force push pada `main`, dan tambahkan anggota tim KONI sesuai kebutuhan.

- [ ] **Step 5: Jadikan GitHub backup/read-only sementara**

Jangan menghapus repository GitHub sampai GitLab berhasil diverifikasi dan pihak KONI menyatakan GitLab menjadi source of truth.

### Task 6: Penutupan branch lama secara opsional

**Files:**
- Local branches: `feat/auth-hardening-patch-2`, `codex/patch-3-1-auth-audit`
- Remote GitHub branch: `feat/auth-hardening-patch-2`

**Interfaces:**
- Consumes: GitLab `main` yang sudah diverifikasi dan worktree yang sudah tidak diperlukan.
- Produces: repository lokal/backup yang tidak memiliki branch kerja lama yang membingungkan.

- [ ] **Step 1: Pastikan tidak ada PR, deployment, atau pekerjaan yang masih bergantung pada branch lama**

- [ ] **Step 2: Hapus branch lokal yang sudah merged dengan `git branch -d`**

Jangan gunakan `git branch -D`.

- [ ] **Step 3: Lepas worktree `codex/patch-3-1-auth-audit` sebelum menghapus branch terkait**

Pastikan direktori worktree memang tidak lagi diperlukan dan bersih.

- [ ] **Step 4: Hapus remote branch hanya setelah persetujuan handover**

Branch yang sudah merged tidak menghapus commit yang sudah berada di `main`, tetapi remote branch tetap jangan dihapus sebelum GitLab tervalidasi.

## Definition of Done

- [ ] `main` menjadi source of truth di GitLab.
- [ ] Hanya `main` yang dipush ke GitLab.
- [ ] GitHub masih tersedia sebagai backup sementara.
- [ ] README dan `docs/README.md` cukup untuk onboarding developer baru.
- [ ] Status “belum terintegrasi API SICABOR” tertulis jelas.
- [ ] Draft API tidak disajikan sebagai kontrak resmi.
- [ ] Tidak ada file untracked yang tidak disengaja.
- [ ] `flutter analyze`, `flutter test`, dan `flutter build web` berhasil.
- [ ] Tidak ada secret produksi di history terbaru atau tree yang dipindahkan.
- [ ] Riwayat commit lama tidak ditulis ulang.

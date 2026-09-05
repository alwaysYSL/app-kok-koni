# Pemolesan UI Halaman Perlu Perhatian Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles antarmuka Halaman Perlu Perhatian (`/attention`) agar presisi sesuai acuan desain Figma `ui-screenshot-figma/perlu-perhatian.png`, mengekstrak implementasi menjadi fitur mandiri di `lib/features/attention_page.dart`, menambahkan counter dinamis pada filter chip dan header, serta menggunakan kartu ber-`DashedDivider` dengan highlight isu merah.

**Architecture:** Mengekstrak `AttentionPage` ke berkas mandiri `lib/features/attention_page.dart`, membuat komponen `AttentionCard` dengan `DashedDivider`, menghubungkan rute di `lib/app.dart`, membersihkan `lib/features/detail_pages.dart`, dan mengintegrasikan golden preview screenshot ke `previews/perlu-perhatian.png`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Flutter Riverpod, GoRouter, Plus Jakarta Sans (`KokSans`), Custom Canvas/DashedDivider.

## Global Constraints

- Sesuai spesifikasi `docs/superpowers/specs/2026-09-05-attention-page-ui-polish-design.md`.
- Menggunakan tipografi global Plus Jakarta Sans (`KokSans`).
- Header menampilkan judul dinamis `Perlu Perhatian ($count)`.
- Tombol info sudut melengkung 10px di kanan atas membuka modal bottom sheet penjelasan kriteria kualitas data.
- 3 filter chips: `Semua ${totalCount}`, `Berkas Atlet ${docCount}`, `Lisensi ${licenseCount}`. Chip aktif berlatar solid biru `Color(0xFF1B4F9E)` dengan teks putih.
- Kartu perhatian `AttentionCard` memiliki avatar, nama tebal, subjudul klub & cabor, chevron kanan, `DashedDivider`, serta teks isu merah + ikon `Icons.error_outline` merah.
- Bagian bawah memuat teks arahan koordinasi pengurus klub.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Implementasi Fitur Mandiri `lib/features/attention_page.dart` & Unit/Widget Test

**Files:**
- Create: `lib/features/attention_page.dart`
- Create: `test/attention_page_test.dart`

**Interfaces:**
- Produces: `class AttentionPage extends StatefulWidget`, `class AttentionCard extends StatelessWidget`.
- Consumes: `KokSnapshot`, `SportPerson`, `Club` dari `lib/data/models.dart`; `DashedDivider` dari `lib/shared/widgets.dart`; `KokColors` dari `lib/core/theme.dart`.

- [ ] **Step 1: Tulis tes widget yang gagal di `test/attention_page_test.dart`**
  - Menguji render `AttentionPage`: AppBar judul dinamis, tombol info, filter chips (`Semua 13`, `Berkas Atlet 8`, `Lisensi 5`), dan daftar kartu `AttentionCard`.
  - Menguji perpindahan tab filter (misal memilih `Berkas Atlet 8` memperbarui daftar kartu dan judul menjadi `Perlu Perhatian (8)`).

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan awal**
  - Jalankan `flutter test test/attention_page_test.dart`.

- [ ] **Step 3: Implementasikan `lib/features/attention_page.dart`**
  - Implementasikan `AttentionCard`:
    - Permukaan putih *rounded* 16px dengan soft shadow.
    - Baris atas: Lingkaran avatar (inisial/foto), nama tebal navy `Color(0xFF0C2464)`, subjudul `${club.name} · ${club.sport} ${person.group}`, dan `Icons.chevron_right`.
    - Tap handler navigasi ke `/person/${person.id}`.
    - Pemisah `DashedDivider(color: Color(0xFFE5E7EB))`.
    - Baris bawah: Teks merah `${person.missingDocuments.join(' & ')} kurang` atau `Lisensi kedaluwarsa` + `Icons.error_outline` merah di sisi kanan.
  - Implementasikan `AttentionPage`:
    - State `type` yang diinisialisasi dari `widget.type` (`'all'`, `'documents'`, `'license'`).
    - Filter counts: `docCount` (atlet dengan berkas kurang), `licenseCount` (pelatih dengan expiredLicense), `totalCount` (semua).
    - AppBar dengan tombol info yang menampilkan bottom sheet penjelasan.
    - Baris filter chips horizontal (Solid biru saat aktif, bordered saat inaktif).
    - Subheader: `"Temuan kualitas data untuk koordinasi"`.
    - List view berisi `AttentionCard` dan footer text *"Tindak lanjuti temuan di atas dengan menghubungi ketua pengurus klub bersangkutan."*

- [ ] **Step 4: Jalankan tes dan pastikan lulus**
  - Jalankan `flutter test test/attention_page_test.dart`.
  - Pastikan seluruh tes lulus.

- [ ] **Step 5: Jalankan `flutter analyze`**
  - Pastikan 0 issues.

- [ ] **Step 6: Commit perubahan**
  - Commit: `feat(attention): buat fitur mandiri halaman perlu perhatian sesuai acuan figma`

---

### Task 2: Integrasi Rute `lib/app.dart`, Pembersihan `lib/features/detail_pages.dart`, & Regresi `test/app_test.dart`

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/features/detail_pages.dart`
- Modify: `test/app_test.dart`

**Interfaces:**
- Consumes: `AttentionPage` dari `package:kok_app/features/attention_page.dart`.

- [ ] **Step 1: Perbarui rute di `lib/app.dart`**
  - Ubah import rute `/attention` agar mengarah ke `package:kok_app/features/attention_page.dart`.

- [ ] **Step 2: Bersihkan `lib/features/detail_pages.dart`**
  - Hapus class `AttentionPage` dan `_AttentionPageState` yang lama dari `lib/features/detail_pages.dart`.

- [ ] **Step 3: Perbarui tes integrasi di `test/app_test.dart`**
  - Periksa ekspektasi tes untuk rute `/attention`.
  - Pastikan tes mencakup verifikasi teks filter baru (`Semua 13`, `Berkas Atlet 8`, `Lisensi 5`) dan klik kartu menuju detail personil.

- [ ] **Step 4: Jalankan seluruh test suite**
  - Jalankan `flutter test`.
  - Pastikan seluruh tes lulus.

- [ ] **Step 5: Jalankan `flutter analyze`**
  - Pastikan 0 issues.

- [ ] **Step 6: Commit perubahan**
  - Commit: `refactor(attention): integrasikan rute mandiri dan bersihkan detail_pages`

---

### Task 3: Pembaruan Golden Preview Screenshot & Verifikasi Akhir

**Files:**
- Modify: `test/preview_test.dart`
- Create/Update: `previews/perlu-perhatian.png`

- [ ] **Step 1: Tambahkan rute `/attention` ke `test/preview_test.dart`**
  - Tambahkan `'perlu-perhatian': '/attention'` ke daftar preview routes.

- [ ] **Step 2: Generate golden screenshot**
  - Jalankan `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`.
  - Pastikan berkas `previews/perlu-perhatian.png` terbentuk dan hanya berkas tersebut yang diperbarui (revert timestamp diff pada preview lain jika ada).

- [ ] **Step 3: Jalankan verifikasi total**
  - Jalankan `flutter test` dan `flutter analyze`.

- [ ] **Step 4: Commit pengujian dan golden visual**
  - Commit: `test: tambahkan pengujian dan golden preview untuk halaman perlu perhatian`

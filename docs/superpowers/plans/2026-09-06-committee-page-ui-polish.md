# Pemolesan UI Menu Anggota (Kepengurusan KOK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles antarmuka Menu Anggota (Kepengurusan KOK) (`/committee`) agar presisi, mewah, dan konsisten dengan sistem desain aplikasi: judul AppBar ber-counter dinamis, tombol sortir konsisten dengan Menu Klub, search bar modern, filter chips divisi, kartu pengurus (`CommitteeMemberCard`), dan modal bottom sheet detail profil ID Card pengurus.

**Architecture:** Memperbarui `lib/features/committee_page.dart` dengan komponen terstruktur (`CommitteeMemberCard`, `CommitteeSortOption`, filter/sort state, modal detail pengurus), menambahkan pengujian komprehensif di `test/committee_page_test.dart`, serta memperbarui golden screenshot di `previews/anggota.png`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Flutter Riverpod, GoRouter, Plus Jakarta Sans (`KokSans`), Material 3.

## Global Constraints

- Sesuai spesifikasi `docs/superpowers/specs/2026-09-06-committee-page-ui-polish-design.md`.
- Menggunakan tipografi global Plus Jakarta Sans (`KokSans`).
- Header AppBar menampilkan judul dinamis `Anggota KOK ($count)`.
- Tombol sortir sudut melengkung 10px di kanan atas membuka modal bottom sheet 4 opsi sortir (`defaultStructure`, `nameAsc`, `nameDesc`, `divisionAsc`).
- Search bar rounded 14px dengan placeholder *"Cari nama atau jabatan..."*.
- Filter chips dinamis berdasarkan divisi pengurus (`Semua $total`, `Pengurus inti`, dll.).
- Kartu pengurus `CommitteeMemberCard` memiliki avatar inisial lingkaran, nama tebal navy `Color(0xFF0C2464)`, teks jabatan biru `Color(0xFF1B4F9E)`, subteks bidang/periode, dan chevron kanan.
- Mengetuk kartu membuka modal bottom sheet detail pengurus ("Digital ID Card").
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Enum Sortir, Pemolesan Komprehensif `lib/features/committee_page.dart`, & Unit/Widget Test

**Files:**
- Modify: `lib/features/committee_page.dart`
- Create: `test/committee_page_test.dart`

**Interfaces:**
- Produces: `enum CommitteeSortOption`, `class CommitteePage extends StatefulWidget`, `class CommitteeMemberCard extends StatelessWidget`.
- Consumes: `CommitteeMember` dari `lib/data/models.dart`; `KokColors` dari `lib/core/theme.dart`; `DataView` dari `lib/shared/widgets.dart`.

- [ ] **Step 1: Tulis tes widget di `test/committee_page_test.dart`**
  - Menguji render AppBar judul dinamis dan tombol sortir.
  - Menguji fungsi pencarian teks (nama/jabatan).
  - Menguji modal sortir dan perubahan urutan pengurus (misal Nama A-Z vs Z-A).
  - Menguji filter chip divisi (Semua vs Pengurus Inti).
  - Menguji pembukaan modal detail profil pengurus saat kartu diklik.

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan atau status awal**
  - Jalankan `flutter test test/committee_page_test.dart`.

- [ ] **Step 3: Implementasikan pembaruan di `lib/features/committee_page.dart`**
  - Definisikan `enum CommitteeSortOption { defaultStructure, nameAsc, nameDesc, divisionAsc }`.
  - Tambahkan fungsi helper filtering dan sorting pengurus.
  - Bangun `_showSortModal` yang menampilkan 4 opsi urutan dengan centang aktif.
  - Bangun `_showMemberDetailModal` yang menampilkan bottom sheet "Digital ID Card" pengurus (avatar besar, nama lengkap, badge jabatan, rincian bidang/periode/wilayah, dan tombol tutup).
  - Bangun kartu wilayah `Surface` rounded 20px dengan badge `KEPENGURUSAN KOK`, judul `Kecamatan Garut Kota`, dan subteks jumlah pengurus & periode.
  - Bangun search bar rounded 14px dengan ikon pencarian.
  - Bangun baris filter chips dinamis untuk divisi.
  - Bangun `CommitteeMemberCard`: kontainer putih rounded 16px, soft shadow, avatar inisial `#E8F0FE` / `#0C2464`, nama tebal, jabatan biru, bidang/periode abu-abu, dan chevron kanan.

- [ ] **Step 4: Jalankan tes dan pastikan lulus**
  - Jalankan `flutter test test/committee_page_test.dart`.
  - Pastikan seluruh tes lulus.

- [ ] **Step 5: Jalankan `flutter analyze`**
  - Pastikan 0 issues.

- [ ] **Step 6: Commit perubahan**
  - Commit: `feat(committee): poles UI menu anggota kepengurusan KOK sesuai standar desain`

---

### Task 2: Integrasi Pengujian `test/app_test.dart`, Golden Previews, & Verifikasi Akhir

**Files:**
- Modify: `test/app_test.dart`
- Update: `previews/anggota.png`

- [ ] **Step 1: Periksa dan perbarui ekspektasi di `test/app_test.dart`**
  - Pastikan asersi pengujian yang mengunjungi rute `/committee` berjalan lancar dengan UI baru.

- [ ] **Step 2: Generate golden preview screenshot**
  - Jalankan `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`.
  - Periksa `git status` dan pastikan hanya `previews/anggota.png` yang diperbarui (revert file preview lain jika terkena timestamp diff).

- [ ] **Step 3: Jalankan verifikasi total**
  - Jalankan `flutter test` dan `flutter analyze`.

- [ ] **Step 4: Commit pengujian dan golden visual**
  - Commit: `test: perbarui pengujian dan golden preview menu anggota kepengurusan KOK`

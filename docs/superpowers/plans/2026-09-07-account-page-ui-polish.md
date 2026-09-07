# Pemolesan UI Halaman Akun Koordinator KOK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles antarmuka Halaman Akun (`/profile`) menjadi pusat profil dan utilitas operasional Koordinator KOK Kecamatan Garut Kota, mencakup kartu profil beraksen garis lengkung lingkaran minimalis, seksi sinkronisasi data SICABOR, seksi utilitas koordinator (rekap data kecamatan & helpdesk KONI), seksi pengaturan & aplikasi, serta custom floating dialog konfirmasi keluar (*anti-template*).

**Architecture:** Memperbarui `lib/features/profile_page.dart` dengan komponen terstruktur modular, menambahkan widget tests komprehensif di `test/profile_page_test.dart`, memperbarui pengujian integrasi di `test/app_test.dart`, dan meregenerasi golden preview di `previews/profil.png`.

**Tech Stack:** Flutter 3.x, Flutter Riverpod (`snapshotProvider`, `sessionProvider`, `preferencesProvider`), Plus Jakarta Sans (`KokSans`), DashedDivider, CustomPainter.

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-07-account-page-ui-polish-design.md`.
- Menggunakan tipografi global Plus Jakarta Sans (`KokSans`).
- Aksen dekoratif kartu profil hanya menggunakan garis lingkaran konsentris putih tipis (`AccountProfileCardPainter`) tanpa dot matrix agar tetap bersih dan eksekutif.
- Tombol Keluar memicu custom dialog konfirmasi modern ber-radius 24px (bukan `AlertDialog` bawaan Flutter).
- Seluruh aksi utilitas (salin rekapitulasi data, refresh sinkronisasi, hubungi helpdesk) memiliki umpan balik visual yang jelas.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Pemolesan Komprehensif `lib/features/profile_page.dart` & Unit/Widget Test

**Files:**
- Modify: `lib/features/profile_page.dart`
- Create: `test/profile_page_test.dart`

**Interfaces:**
- Produces: `class ProfilePage extends ConsumerWidget`, `class AccountProfileCardPainter extends CustomPainter`.
- Consumes: `snapshotProvider` dari `lib/data/repository.dart`; `sessionProvider`, `preferencesProvider` dari `lib/core/session.dart`; `KokColors` dari `lib/core/theme.dart`; `DashedDivider`, `DataView` dari `lib/shared/widgets.dart`.

- [ ] **Step 1: Tulis widget tests di `test/profile_page_test.dart`**
  - Menguji render AppBar dengan judul "Akun".
  - Menguji render kartu profil Pak Asep dengan inisial PA, jabatan, dan badge status emas "AKSES READ-ONLY".
  - Menguji render seksi Sinkronisasi Data SICABOR dengan waktu sinkronisasi nyata dan tombol refresh.
  - Menguji interaksi tombol refresh memicu invalidate provider dan menampilkan snackbar.
  - Menguji seksi Utilitas Koordinator:
    - Mengetuk "Rekap Data Kecamatan" membuka bottom sheet ringkasan rekapitulasi data (Total Cabor, Klub, Atlet, Pelatih) dan tombol salin.
    - Mengetuk "Helpdesk KONI Kabupaten" membuka bottom sheet rincian kontak sekretariat KONI Garut.
  - Menguji seksi Pengaturan & Aplikasi:
    - Mengetuk "Pengaturan Aplikasi" membuka modal preferensi nomor SK.
    - Mengetuk "Tentang Aplikasi" membuka modal informasi versi dan legalitas.
  - Menguji interaksi tombol "Keluar dari Akun":
    - Mengetuk tombol memunculkan Custom Confirmation Dialog (ikon merah, judul "Keluar dari Akun?", tombol Batal & Ya Keluar).
    - Mengetuk tombol "Batal" menutup dialog tanpa keluar sesi.
    - Mengetuk tombol "Ya, Keluar" memicu `signOut()`.

- [ ] **Step 2: Jalankan `flutter test test/profile_page_test.dart` untuk memastikan kegagalan awal**

- [ ] **Step 3: Implementasikan `lib/features/profile_page.dart`**
  - Buat `AccountProfileCardPainter` (2 busur lingkaran konsentris putih dengan opacity 0.08 dan 0.05).
  - Implementasikan Kartu Profil Koordinator (gradasi royal navy, border radius 24px, avatar inisial, teks nama, subteks wilayah, badge status emas).
  - Implementasikan Seksi Sinkronisasi SICABOR (indikator status hijau, waktu sinkron terakhir dari `data.loadedAt`, tombol refresh).
  - Implementasikan Seksi Utilitas Koordinator (menu Rekap Data Kecamatan dengan bottom sheet rekapitulasi angka & salin teks; menu Helpdesk KONI dengan bottom sheet kontak).
  - Implementasikan Seksi Pengaturan & Aplikasi (menu Pengaturan dengan aksi hapus SK; menu Tentang Aplikasi dengan info versi & kerja sama).
  - Implementasikan Tombol Keluar & Custom Confirmation Dialog ber-radius 24px non-template.
  - Implementasikan Footer note informasi data kabupaten.

- [ ] **Step 4: Jalankan `flutter test test/profile_page_test.dart` dan pastikan 100% lulus**
- [ ] **Step 5: Jalankan `flutter analyze` dan pastikan 0 issues**
- [ ] **Step 6: Commit perubahan Task 1**
  `feat(profile): poles UI halaman akun menjadi pusat profil dan utilitas koordinator KOK`

---

### Task 2: Pengujian Integrasi `test/app_test.dart`, Golden Previews, & Verifikasi Akhir

**Files:**
- Modify: `test/app_test.dart`
- Regenerate: `previews/profil.png`

- [ ] **Step 1: Perbarui asersi pengujian integrasi di `test/app_test.dart`**
  - Pastikan pengujian yang berinteraksi dengan profil/logout (misal baris 330-333 pada app_test.dart) disesuaikan dengan alur dialog konfirmasi custom (mengetuk tombol keluar -> mengetuk 'Ya, Keluar' pada dialog).
  - Verifikasi seluruh skenario pengujian di `app_test.dart` lulus 100%.

- [ ] **Step 2: Regenerasi golden preview untuk halaman profil**
  - Jalankan `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`.
  - Revert file preview selain `previews/profil.png` jika ada diff timestamp sepele.

- [ ] **Step 3: Jalankan verifikasi menyeluruh proyek**
  - `flutter test` (seluruh pengujian lulus 100%).
  - `flutter analyze` (0 issues / linter errors).

- [ ] **Step 4: Commit perubahan Task 2**
  `test: perbarui pengujian integrasi dan golden preview halaman akun`

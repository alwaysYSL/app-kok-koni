# Pemolesan UI Detail Atlet (Warna Dinamis Klub & Layout v2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles antarmuka Halaman Detail Atlet / Personil (`/person/:id`) agar presisi sesuai acuan desain Figma `ui-screenshot-figma/detail-atlet-binamuda-v2.png`, mengekstrak fitur ke modul terisolasi di `lib/features/athlete_detail/athlete_detail_page.dart`, mengintegrasikan sistem pewarnaan dinamis klub via `ClubBrandPaletteResolver`, serta menyajikan kartu profil melayang, checklist berkas dengan progress bar dinamis, riwayat capaian, dan tombol hubungi pengurus klub.

**Architecture:** Membangun modul mandiri `lib/features/athlete_detail/athlete_detail_page.dart` yang mengonsumsi `ClubBrandPaletteResolver.resolve(club)`, menghubungkan rute `/person/:id` di `lib/app.dart`, membersihkan `lib/features/detail_pages.dart`, menambahkan pengujian komprehensif di `test/athlete_detail_test.dart`, dan memperbarui golden previews visual.

**Tech Stack:** Flutter 3.x, Dart 3.x, Flutter Riverpod, GoRouter, Plus Jakarta Sans (`KokSans`), ClubBrandPaletteResolver, DashedDivider.

## Global Constraints

- Sesuai spesifikasi `docs/superpowers/specs/2026-09-07-athlete-detail-ui-polish-design.md`.
- Menggunakan tipografi global Plus Jakarta Sans (`KokSans`).
- Warna tema dinamis mengikuti klub terkait via `ClubBrandPaletteResolver.resolve(club)`:
  - Header gradient (`headerStart` ke `headerEnd`).
  - Latar tombol utama "Hubungi pengurus klub" dan progress bar dokumen.
  - Aksen lembut lingkaran ikon detail (`softAccent`) dan avatar fallback (`fallbackAvatar`).
- Warna status tetap independen dari warna klub: hijau (`#D1FAE5` / `#059669`) untuk lengkap/terverifikasi, merah (`#FEE2E2` / `#DC2626`) untuk berkas kurang/kedaluwarsa.
- Kartu profil melayang menimpa header (-40px offset) dengan avatar lingkaran ber-border putih tebal (diameter ~88px).
- Baris detail profil memiliki ikon beraksen klub dan pemisah vertikal halus.
- Seksi kelengkapan berkas menampilkan progress bar dan status `✓ ada` / `belum`.
- Seksi riwayat capaian dengan bullet timeline berwarna klub.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Fitur Mandiri `lib/features/athlete_detail/athlete_detail_page.dart` & Unit/Widget Test

**Files:**
- Create: `lib/features/athlete_detail/athlete_detail_page.dart`
- Create: `test/athlete_detail_test.dart`

**Interfaces:**
- Produces: `class AthleteDetailPage extends StatelessWidget`, alias `PersonDetailPage`.
- Consumes: `SportPerson`, `Club`, `KokSnapshot` dari `lib/data/models.dart`; `ClubBrandPaletteResolver`, `ClubBrandPalette` dari `lib/features/club_detail/club_brand_palette.dart`; `DashedDivider`, `DataView` dari `lib/shared/widgets.dart`; `MissingPage` dari `lib/features/detail_pages.dart`.

- [ ] **Step 1: Tulis tes widget di `test/athlete_detail_test.dart`**
  - Menguji render halaman detail atlet untuk atlet Voli Bina Muda (memverifikasi warna dinamis klub amber/gold pada header dan tombol).
  - Menguji render halaman detail atlet Garuda Muda (memverifikasi warna dinamis slate/navy).
  - Menguji avatar melayang, nama tebal, status berkas independen (hijau terverifikasi vs merah berkas kurang).
  - Menguji checklist kelengkapan berkas dan progress bar.
  - Menguji seksi riwayat timeline.
  - Menguji interaksi tombol "Hubungi pengurus klub" memunculkan modal kontak.
  - Menguji penanganan atlet tidak ditemukan (menampilkan `MissingPage`).

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan atau status awal**
  - Jalankan `flutter test test/athlete_detail_test.dart`.

- [ ] **Step 3: Implementasikan `lib/features/athlete_detail/athlete_detail_page.dart`**
  - Ambil `SportPerson` berdasarkan `id` dan `Club` berdasarkan `person.clubId`.
  - Resolve palette via `final palette = ClubBrandPaletteResolver.resolve(club)`.
  - Bangun Header: Container gradient `palette.headerStart` $\rightarrow$ `palette.headerEnd`, tombol kembali `<` beraksi `pop() / go('/home')`, judul `Detail Atlet` (atau `Detail ${person.role}`), tombol share di kanan atas.
  - Bangun Kartu Profil Melayang:
    - Lingkaran avatar besar diameter ~88px dengan border putih 3.5px dan soft shadow, menampilkan foto atau inisial berlatar `palette.fallbackAvatar`.
    - Nama tebal navy `Color(0xFF0C2464)`, teks ID `ID SICABOR · ATL-${person.id}`.
    - Status badge kapsul independen: `terverifikasi` (hijau) atau `berkas kurang` (merah).
    - `DashedDivider(color: Color(0xFFE5E7EB))`.
    - Baris informasi (Klub, Cabor, Kelompok, Lahir/Usia, Alamat, Pelatih) dengan ikon berlatar `palette.softAccent`, label abu-abu, divider vertikal halus, dan nilai tebal navy.
  - Bangun Seksi `KELENGKAPAN BERKAS`:
    - Header rekap: `Kelengkapan dokumen` | `${completeCount} dari ${docs.length}`.
    - Progress bar ber-indikator `palette.headerStart` (atau `palette.selectedTab`).
    - Checklist items (KTP/KIA, Kartu Keluarga, Akta kelahiran, Surat sehat) dengan badge `✓ ada` atau `belum`.
    - Penanganan khusus jika personil adalah Pelatih (menampilkan status lisensi kepelatihan).
  - Bangun Seksi `RIWAYAT`:
    - Timeline milestones dengan bullet dot berwarna `palette.headerStart`.
  - Bangun Sticky Bottom Bar:
    - Tombol `FilledButton.icon` `"Hubungi pengurus klub"` dengan warna primer klub `palette.headerStart`, membuka bottom sheet kontak sekretariat klub.

- [ ] **Step 4: Jalankan tes dan pastikan lulus**
  - Jalankan `flutter test test/athlete_detail_test.dart`.
  - Pastikan seluruh tes lulus.

- [ ] **Step 5: Jalankan `flutter analyze`**
  - Pastikan 0 issues.

- [ ] **Step 6: Commit perubahan**
  - Commit: `feat(athlete-detail): buat modul mandiri detail atlet dengan warna dinamis klub dan layout v2`

---

### Task 2: Integrasi Rute `lib/app.dart`, Pembersihan `lib/features/detail_pages.dart`, & Regresi `test/app_test.dart`

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/features/detail_pages.dart`
- Modify: `test/app_test.dart`

**Interfaces:**
- Consumes: `AthleteDetailPage` dari `package:kok_app/features/athlete_detail/athlete_detail_page.dart`.

- [ ] **Step 1: Perbarui rute di `lib/app.dart`**
  - Arahkan rute `/person/:id` untuk mengimpor dan menggunakan `AthleteDetailPage(id: s.pathParameters['id']!)`.

- [ ] **Step 2: Bersihkan `lib/features/detail_pages.dart`**
  - Hapus class `PersonDetailPage` lama dari `lib/features/detail_pages.dart` (ekspor atau sisakan `MissingPage`).

- [ ] **Step 3: Perbarui pengujian di `test/app_test.dart`**
  - Pastikan seluruh pengujian integrasi alur yang mengunjungi `/person/:id` lulus dan mengecek komponen baru (misal teks `'KELENGKAPAN BERKAS'`, tombol `'Hubungi pengurus klub'`).

- [ ] **Step 4: Jalankan seluruh test suite**
  - Jalankan `flutter test`.
  - Pastikan seluruh tes lulus.

- [ ] **Step 5: Jalankan `flutter analyze`**
  - Pastikan 0 issues.

- [ ] **Step 6: Commit perubahan**
  - Commit: `refactor(athlete-detail): integrasikan rute mandiri dan bersihkan detail_pages`

---

### Task 3: Pembaruan Golden Preview Screenshot & Verifikasi Akhir

**Files:**
- Modify: `test/preview_test.dart`
- Create/Update: `previews/detail-atlet.png`

- [ ] **Step 1: Tambahkan/perbarui rute di `test/preview_test.dart`**
  - Tambahkan `'detail-atlet': '/person/voli-atlet-0'` (atau personil Voli Bina Muda) untuk menguji golden rendering sesuai desain acuan `detail-atlet-binamuda-v2.png`.

- [ ] **Step 2: Generate golden preview screenshot**
  - Jalankan `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`.
  - Periksa `git status` dan pastikan hanya `previews/detail-atlet.png` (dan test files) yang berubah.

- [ ] **Step 3: Jalankan verifikasi total**
  - Jalankan `flutter test` dan `flutter analyze`.

- [ ] **Step 4: Commit pengujian dan golden visual**
  - Commit: `test: perbarui pengujian dan golden preview untuk detail atlet v2`

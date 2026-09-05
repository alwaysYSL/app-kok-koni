# Club List UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles antarmuka Daftar Klub (`ClubsPage`) agar presisi sesuai acuan Figma `ui-screenshot-figma/daftar-klub.png`, dengan header counter klub, tombol sortir kotak rounded yang membuka 4 opsi sortir lengkap, search bar rounded 14px, filter chips modern (kapsul "Semua" solid dan dropdown chips), baris ringkasan data bersih tanpa teks "A → Z", serta kartu klub dengan dashed divider dan avatar tematik cabor.

**Architecture:** Memperkaya fungsionalitas sortir di `lib/data/repository.dart` dengan enum `ClubSortOption`. Menghadirkan widget reusable `DashedDivider` dan menyempurnakan `SportAvatar` dengan bentuk rounded square 12px dan palet tematik. Merestrukturisasi `clubs_page.dart` dan menyinkronkan test suite serta golden preview `previews/klub.png`.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Flutter Riverpod, GoRouter, Material 3 with Custom Canvas Painting.

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-05-club-list-ui-polish-design.md`.
- Menggunakan font Plus Jakarta Sans (`KokSans`).
- Teks `"A → Z"` di baris ringkasan **dihapus**.
- Tombol sortir di header membuka menu/sheet dengan 4 opsi: Nama (A → Z), Nama (Z → A), Jumlah Atlet Terbanyak, Status (Aktif Terlebih Dahulu).
- Kartu klub menggunakan garis putus-putus (*dashed divider*) pemisah dan badge berkas merah lembut jika ada dokumen yang kurang.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Opsi Sortir & Fungsi Filter di `lib/data/repository.dart`

**Files:**
- Modify: `lib/data/repository.dart`
- Modify: `test/repository_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum ClubSortOption {
    nameAsc,
    nameDesc,
    athletesDesc,
    statusActiveFirst,
  }
  ```
  - Perbarui signature `filterClubs` untuk menerima `ClubSortOption sortOption` (dengan backward-compatibility default atau parameter eksplisit) dan snapshot data untuk menghitung jumlah atlet jika opsi `athletesDesc` dipilih.

- [ ] **Step 1: Tulis unit test untuk 4 opsi sortir pada `test/repository_test.dart`**

Tambahkan pengujian:
- Sortir nama A-Z dan Z-A.
- Sortir jumlah atlet terbanyak.
- Sortir status aktif terlebih dahulu.

- [ ] **Step 2: Jalankan unit test untuk memastikan kegagalan (fitur baru belum ada)**

Run: `flutter test test/repository_test.dart`  
Expected: FAIL / Compilation error

- [ ] **Step 3: Implementasikan `ClubSortOption` dan pembaruan `filterClubs` di `lib/data/repository.dart`**

- [ ] **Step 4: Jalankan unit test kembali untuk memverifikasi kelulusan**

Run: `flutter test test/repository_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit perubahan repository**

```bash
git add lib/data/repository.dart test/repository_test.dart
git commit -m "feat(clubs): tambahkan opsi sortir lengkap pada filterClubs"
```

---

### Task 2: Komponen Dashed Divider & Pembaruan Avatar Cabor

**Files:**
- Modify: `lib/shared/widgets.dart`
- Test: `test/dashboard_decorations_test.dart` atau unit test widget

**Interfaces:**
- Produces:
  - `class DashedDivider extends StatelessWidget`: Widget pembagi garis putus-putus horizontal rapi.
  - Perbarui `SportAvatar` agar mendukung proporsi kotak rounded 12px (`BoxShape.rectangle` dengan `BorderRadius.circular(12)`) dan skema warna latar tematik cabor (misal: Sepak Bola biru, Bulu Tangkis indigo, Silat deep orange, Renang teal, Voli amber).

- [ ] **Step 1: Tulis widget test untuk `DashedDivider`**

- [ ] **Step 2: Implementasikan `DashedDivider` dan opsi styling `SportAvatar` di `lib/shared/widgets.dart`**

- [ ] **Step 3: Jalankan widget test untuk memverifikasi kelulusan**

Run: `flutter test`  
Expected: PASS

- [ ] **Step 4: Commit komponen visual pendukung**

```bash
git add lib/shared/widgets.dart
git commit -m "feat(clubs): buat komponen dashed divider dan pembaruan avatar cabor"
```

---

### Task 3: Pemolesan Komprehensif Halaman Klub (`lib/features/clubs_page.dart`)

**Files:**
- Modify: `lib/features/clubs_page.dart`
- Consumes: `ClubSortOption` dari `lib/data/repository.dart`, `DashedDivider` dan `SportAvatar` dari `lib/shared/widgets.dart`
- Test: `test/app_test.dart`

- [ ] **Step 1: Rancang ulang `ClubsPage` dan `ClubTile` sesuai acuan Figma**

Poin pembaruan:
1. **Header AppBar**:
   - Judul: `"Klub (${clubs.length})"` (atau `"${widget.sport} (${clubs.length})"`).
   - Tombol sortir di kanan atas: Kontainer rounded 10px ber-border halus dengan `Icons.swap_vert`.
   - Menampilkan menu modal pemilihan 4 opsi sortir saat ditekan dengan indikator opsi aktif.
2. **Search Bar**:
   - Kolom teks dengan radius 14px, prefix `Icons.search_rounded`, hint `"Cari nama klub..."`, dan tombol clear.
3. **Filter Chips**:
   - Chip pertama `"Semua"`: Kapsul biru solid (`#1B4F9E`) dengan teks putih ketika default/reset.
   - Chip dropdown `"Cabor"`, `"Status"`, dan `"Kelurahan"` dengan ikon panah dropdown di kanan teks.
4. **Baris Ringkasan Data**:
   - Menampilkan `"${clubs.length} klub · ${caborCount} cabor"`.
   - Menghapus teks `"A → Z"`.
5. **Kartu Klub (`ClubTile`)**:
   - `BorderRadius.circular(18)`, background putih berbayangan halus.
   - Bagian atas: Avatar cabor rounded square 12px, nama klub tebal, subteks cabor & kelurahan, badge kapsul "Aktif" (biru muda) / "Pasif" (abu-abu).
   - Garis pemisah: `DashedDivider`.
   - Bagian bawah: Rekap personel `"${atlet} atlet · ${pelatih} pelatih · ${official} official"` di kiri, dan badge merah lembut `"${missing} berkas"` di kanan jika ada berkas bermasalah.

- [ ] **Step 2: Jalankan linter analyzer untuk memastikan kode bersih**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 3: Commit pembaruan `clubs_page.dart`**

```bash
git add lib/features/clubs_page.dart
git commit -m "feat(clubs): poles UI halaman daftar klub sesuai acuan figma"
```

---

### Task 4: Pembaruan Test Suite, Golden Previews, & Verifikasi Akhir

**Files:**
- Modify: `test/app_test.dart`
- Modify: `previews/klub.png`

- [ ] **Step 1: Sesuaikan asersi teks di `test/app_test.dart`**

Pastikan navigasi dan pencarian tetap terverifikasi dengan benar tanpa asersi pada teks `"A → Z"` yang telah dihapus.

- [ ] **Step 2: Jalankan pengujian penuh**

Run: `flutter test`  
Expected: All tests passed!

- [ ] **Step 3: Perbarui golden preview screenshot `previews/klub.png`**

Run: `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`  
Expected: All tests passed! (`previews/klub.png` updated)

- [ ] **Step 4: Jalankan analisis linter akhir**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 5: Commit pembaruan test & preview**

```bash
git add test/app_test.dart previews/klub.png
git commit -m "test: perbarui pengujian dan preview visual daftar klub"
```

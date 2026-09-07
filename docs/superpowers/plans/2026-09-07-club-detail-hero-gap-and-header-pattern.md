# Pembenahan Jarak Hero Detail Klub & Aksen Dekoratif Background Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memperbaiki jarak vertikal antara 3 angka statistik di hero Detail Klub ke kartu putih di bawahnya (~24px presisi sesuai Figma), serta menambahkan ornamen dekoratif background header (garis lingkaran konsentris & dot matrix putih halus) pada Header Detail Klub dan Header Detail Atlet.

**Architecture:** Membuat painter reusable `BrandHeaderPatternPainter` di `lib/features/dashboard_decorations.dart`, mengintegrasikannya ke `ClubDetailHeader` dan `AthleteDetailPage`, menyesuaikan `expandedHeight` (420) dan `titleOpacity` di `ClubDetailPage`, menguji seluruh skenario layout, dan memperbarui golden screenshots.

**Tech Stack:** Flutter 3.x, CustomPainter, SliverAppBar, NestedScrollView, Plus Jakarta Sans (`KokSans`), ClubBrandPaletteResolver.

## Global Constraints

- Sesuai spesifikasi `docs/superpowers/specs/2026-09-07-club-detail-hero-gap-and-header-pattern-design.md`.
- Menggunakan tipografi global Plus Jakarta Sans (`KokSans`).
- Aksen garis lingkaran dan dot matrix menggunakan warna putih ber-opacity terkalibrasi (`0.12` dan `0.07`), bukan warna statis cabor, agar menyatu harmonis dengan warna klub apa pun.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: `BrandHeaderPatternPainter` di `lib/features/dashboard_decorations.dart` & Unit Test

**Files:**
- Modify: `lib/features/dashboard_decorations.dart`
- Modify: `test/dashboard_decorations_test.dart`

**Interfaces:**
- Produces: `class BrandHeaderPatternPainter extends CustomPainter`.
- Consumes: Flutter `CustomPainter`, `Canvas`, `Paint`, `Path`.

- [ ] **Step 1: Tulis unit test di `test/dashboard_decorations_test.dart`**
  - Menguji render `BrandHeaderPatternPainter` dalam `CustomPaint` dengan ukuran tertentu (misal 360x200).
  - Menguji `shouldRepaint` mengembalikan `false`.
- [ ] **Step 2: Jalankan unit test untuk memastikan kegagalan atau status awal**
- [ ] **Step 3: Implementasikan `BrandHeaderPatternPainter` di `lib/features/dashboard_decorations.dart`**
  - Gambar dot matrix putih (opacity 0.12, radius 1.8, spacing 14.0, 6x7 dots) di kanan atas.
  - Gambar busur kurva lingkaran konsentris halus di kiri/tengah atas (strokeWidth 1.5 & 1.2, opacity 0.12 & 0.07).
- [ ] **Step 4: Jalankan `flutter test test/dashboard_decorations_test.dart` dan `flutter analyze`**
- [ ] **Step 5: Commit perubahan Task 1**

---

### Task 2: Pembenahan Jarak Hero & Pasang Dekorasi Header di Detail Klub

**Files:**
- Modify: `lib/features/club_detail/club_detail_header.dart`
- Modify: `lib/features/club_detail/club_detail_page.dart`
- Modify: `test/club_detail_widgets_test.dart`

- [ ] **Step 1: Update `lib/features/club_detail/club_detail_header.dart`**
  - Pasang `CustomPaint(painter: const BrandHeaderPatternPainter())` di dalam `DecoratedBox` latar belakang.
  - Ubah padding dari `padding: const EdgeInsets.fromLTRB(24, 0, 24, 100)` menjadi `padding: const EdgeInsets.fromLTRB(24, 0, 24, 20)`.
- [ ] **Step 2: Update `lib/features/club_detail/club_detail_page.dart`**
  - Ubah `expandedHeight: 500` menjadi `expandedHeight: 420`.
  - Ubah formula `titleOpacity`:
    `final titleOpacity = ((420 - constraints.biggest.height) / 200).clamp(0.0, 1.0);`.
- [ ] **Step 3: Uji widget & regresi**
  - Jalankan `flutter test test/club_detail_widgets_test.dart` dan `flutter test test/app_test.dart`.
  - Pastikan uji scroll collapse, text scale 1.3, dan layar 320px lulus tanpa overflow.
- [ ] **Step 4: Jalankan `flutter analyze`**
- [ ] **Step 5: Commit perubahan Task 2**

---

### Task 3: Pasang Dekorasi Header di Detail Atlet

**Files:**
- Modify: `lib/features/athlete_detail/athlete_detail_page.dart`
- Modify: `test/athlete_detail_test.dart`

- [ ] **Step 1: Update `lib/features/athlete_detail/athlete_detail_page.dart`**
  - Impor `BrandHeaderPatternPainter` dari `package:kok_app/features/dashboard_decorations.dart`.
  - Pasang `CustomPaint(painter: const BrandHeaderPatternPainter())` di dalam container gradasi header setinggi 170px.
- [ ] **Step 2: Uji widget & regresi**
  - Jalankan `flutter test test/athlete_detail_test.dart`.
  - Verifikasi seluruh 7 test detail atlet lulus 100%.
- [ ] **Step 3: Jalankan `flutter analyze`**
- [ ] **Step 4: Commit perubahan Task 3**

---

### Task 4: Pembaruan Golden Preview Screenshot & Verifikasi Akhir

**Files:**
- Modify: `test/preview_test.dart`
- Regenerate: `previews/detail-klub.png`, `previews/detail-klub-pb.png`, `previews/detail-klub-voli.png`, `previews/detail-atlet.png`

- [ ] **Step 1: Regenerasi golden previews**
  - Jalankan `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`.
  - Revert file preview selain yang relevan jika ada diff timestamp acak.
- [ ] **Step 2: Jalankan `flutter test` dan `flutter analyze` untuk seluruh test suite**
- [ ] **Step 3: Commit perubahan Task 4**

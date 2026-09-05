# Dashboard UI Polish & Plus Jakarta Sans Font Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memigrasikan font global aplikasi ke Plus Jakarta Sans dan memoles tampilan Dashboard (Beranda) agar presisi mengikuti desain Figma `ui-screenshot-figma/beranda-varian-2-belum-sinkron.png`, khususnya pada header biru bergradasi, floating card statistik yang menimpa header dengan siluet atlet (bukan maskot), serta kartu peringatan dan daftar klub.

**Architecture:** Memperbarui konfigurasi tema dan font family di `pubspec.yaml` dan `theme.dart`. Membuat widget modular dekorasi dan grafik siluet pelari (`dashboard_decorations.dart`). Merestrukturisasi `home_page.dart` dengan floating card statistik, menyelaraskan teks dan badge status, serta memperbarui test suite dan golden preview `previews/home.png`.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Flutter Riverpod, GoRouter, Custom Canvas Painting, Plus Jakarta Sans OFL Font.

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-05-dashboard-ui-polish-design.md`.
- Menggunakan font Plus Jakarta Sans (`assets/fonts/PlusJakartaSans.ttf`).
- Sisi kanan floating card statistik menggunakan **siluet atlet/pelari**, BUKAN maskot.
- Card statistik harus mengapung (*floating / overlapping*) menimpa bagian bawah header biru.
- Pertahankan seluruh logika pemuatan data dari Riverpod `snapshotProvider` dan refresh data.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Konfigurasi Font Plus Jakarta Sans & Pembaruan Tema Global

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/theme.dart`
- Modify: `test/preview_test.dart`

- [ ] **Step 1: Daftarkan Plus Jakarta Sans pada `pubspec.yaml`**

Tambahkan konfigurasi font `KokSans` atau perbarui asetnya:
```yaml
  fonts:
    - family: KokSans
      fonts:
        - asset: assets/fonts/PlusJakartaSans.ttf
```

- [ ] **Step 2: Perbarui pemuatan font di `test/preview_test.dart`**

Sesuaikan `preview_test.dart` agar memuat `PlusJakartaSans.ttf` untuk `KokSans`:
```dart
final font = FontLoader('KokSans')
  ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
await font.load();
```

- [ ] **Step 3: Jalankan analyzer dan test untuk memastikan konfigurasi font valid**

Run: `flutter test test/login_decorations_test.dart`  
Expected: PASS

- [ ] **Step 4: Commit konfigurasi font**

```bash
git add pubspec.yaml lib/core/theme.dart test/preview_test.dart
git commit -m "feat(theme): migrasikan font global ke Plus Jakarta Sans"
```

---

### Task 2: Komponen Siluet Atlet & Header Dekoratif Dashboard

**Files:**
- Create: `lib/features/dashboard_decorations.dart`
- Create: `test/dashboard_decorations_test.dart`

**Interfaces:**
- Produces:
  - `class DashboardHeaderDecoration extends StatelessWidget`: Latar belakang header biru bergradasi dengan aksen kurva lengkung emas/cyan dan dot matrix.
  - `class AthletesSilhouetteGraphic extends StatelessWidget`: Komponen grafis siluet pelari/atlet dinamis artistik berbasis Flutter Canvas (`CustomPainter`) bernuansa biru/navy lembut.

- [ ] **Step 1: Tulis unit test untuk `AthletesSilhouetteGraphic` dan `DashboardHeaderDecoration`**

```dart
// test/dashboard_decorations_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/dashboard_decorations.dart';

void main() {
  testWidgets('AthletesSilhouetteGraphic and DashboardHeaderDecoration render successfully', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DashboardHeaderDecoration(child: Text('Header')),
              AthletesSilhouetteGraphic(width: 140, height: 100),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Header'), findsOneWidget);
    expect(find.byType(AthletesSilhouetteGraphic), findsOneWidget);
  });
}
```

- [ ] **Step 2: Implementasikan `lib/features/dashboard_decorations.dart`**

Implementasikan dekorasi header dan siluet pelari/atlet dengan garis kurva tubuh pelari atletis (kepala, torso, kaki melangkah cepat, tangan mengayun) menggunakan path canvas yang rapi dan elegan.

- [ ] **Step 3: Jalankan test untuk memverifikasi kelulusan**

Run: `flutter test test/dashboard_decorations_test.dart`  
Expected: PASS

- [ ] **Step 4: Commit perubahan dekorasi**

```bash
git add lib/features/dashboard_decorations.dart test/dashboard_decorations_test.dart
git commit -m "feat(dashboard): buat komponen siluet atlet dan dekorasi header dashboard"
```

---

### Task 3: Implementasi Floating Card & Pemolesan Halaman Beranda (`lib/features/home_page.dart`)

**Files:**
- Modify: `lib/features/home_page.dart`
- Consumes: `DashboardHeaderDecoration` dan `AthletesSilhouetteGraphic` dari `lib/features/dashboard_decorations.dart`
- Test: `test/app_test.dart`

- [ ] **Step 1: Rancang ulang `HomePage` sesuai acuan Figma**

Poin pembaruan:
1. **Header Biru**:
   - Background `DashboardHeaderDecoration`.
   - Baris atas: Logo KONI di dalam `CircleAvatar(backgroundColor: Colors.white, ...)`.
   - Teks `"KOORDINATOR ORGANISASI KECAMATAN"`, `"Kec. Garut Kota"`, `"Pak Asep · Koordinator"`.
   - Kanan: Avatar inisial `"PA"` dalam lingkaran navy berborder tipis.
2. **Floating Card Statistik**:
   - Dibuat mengapung menimpa header (`Stack` atau negative top margin `Transform.translate(offset: Offset(0, -35))` atau overlap container).
   - Container putih dengan `BorderRadius.circular(24)`, padding 20px, soft shadow.
   - Baris status: Indikator titik + `"Terakhir Tersinkron SICABOR · <Waktu>"` dan tombol icon refresh.
   - Highlight Atlet: Angka besar (misal 125) berdampingan dengan label `"ATLET"`, badge kapsul `"117 terverifikasi 94%"`, dan `AthletesSilhouetteGraphic` di sebelah kanan (BUKAN maskot).
   - Divider halus 1px.
   - 3 Kolom Metrik bawah:
     - PELATIH: angka tebal, label `"PELATIH"`, keterangan lisensi (misal `"10 berlisensi"`).
     - KLUB: angka tebal, label `"KLUB"`, keterangan status (misal `"4 aktif · 1 pasif"`).
     - OFFICIAL: angka tebal, label `"OFFICIAL"`, keterangan cabor (misal `"5 cabor"`).
3. **Seksi "Perlu Perhatian"**:
   - Header seksi dengan teks `"lihat semua >"` biru yang dapat diklik ke `/attention`.
   - Card ber-badge merah bernomor `(8)` untuk `"Atlet berkas kurang"` dan `(5)` untuk `"Lisensi pelatih kedaluwarsa"` dengan panah chevron.
4. **Seksi "Klub di kecamatan"**:
   - Header seksi dengan teks `"lihat semua >"` biru yang dapat diklik ke `/clubs`.
   - Card klub dengan ikon cabor rounded, nama klub tebal, detail cabor & jumlah atlet, serta panah chevron.

- [ ] **Step 2: Jalankan analyzer untuk memastikan kode bersih**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 3: Commit perubahan beranda**

```bash
git add lib/features/home_page.dart
git commit -m "feat(dashboard): poles UI beranda dengan floating card statistik sesuai acuan figma"
```

---

### Task 4: Pembaruan Test Suite, Golden Previews, & Verifikasi Akhir

**Files:**
- Modify: `test/app_test.dart`
- Modify: `previews/home.png`

- [ ] **Step 1: Sesuaikan asersi teks di `test/app_test.dart` bila diperlukan**

Pastikan seluruh pencarian elemen pada beranda cocok dengan teks terbaru ("lihat semua >", dsb.).

- [ ] **Step 2: Jalankan pengujian penuh**

Run: `flutter test`  
Expected: All tests passed!

- [ ] **Step 3: Perbarui golden preview screenshot `previews/home.png`**

Run: `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`  
Expected: All tests passed! (previews/home.png updated)

- [ ] **Step 4: Jalankan analisis linter akhir**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 5: Commit pembaruan test & preview**

```bash
git add test/app_test.dart previews/home.png
git commit -m "test: perbarui ekspektasi tes dan preview visual beranda"
```

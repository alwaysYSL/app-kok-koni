# Redesain Halaman Induk Cabor & Pembuatan Detail Cabor Mandiri Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memodernisasi Halaman Induk Cabor (`SportsPage`) dengan visualisasi sebaran atlet kecamatan menggunakan `fl_chart`, serta membangun modul mandiri Halaman Detail Cabor (`SportDetailPage`) dengan tema dinamis warna cabor, kartu statistik, analitik dwimode (Kelompok Usia vs Kualitas Berkas), dan 3 tab navigasi terpadu (Klub, Atlet, Pelatih).

**Architecture:** Memanfaatkan `fl_chart` untuk grafik interaktif, resolver palet warna mandiri `SportBrandPaletteResolver` untuk gradasi header dan aksen visual tiap cabor, serta pemisahan modul mandiri `SportDetailPage` dengan `TabBar` terisolasi untuk data klub, atlet lintas-klub, dan pelatih pembina.

**Tech Stack:** Flutter 3, Dart, Riverpod 3, GoRouter 17, `fl_chart: ^1.2.0`, `BrandHeaderPatternPainter`.

## Global Constraints

- Sesuai spesifikasi `docs/superpowers/specs/2026-09-07-sports-hub-and-sport-detail-redesign-design.md`.
- Menggunakan warna judul kartu utama `KokColors.cardTitle` (`#141414`) dan palet terpusat di `lib/core/theme.dart`.
- Tombol kembali menggunakan ikon `Icons.chevron_left` dengan `size: 28`.
- Mempertahankan struktur 5 tab navigasi bawah (`Beranda`, `Cabor`, `Klub`, `Anggota`, `Akun`).
- Read-only data access (tidak ada aksi mutasi database/CRUD; hanya filter, cari, salin/bagikan).
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Dependensi `fl_chart: ^1.2.0` & `SportBrandPaletteResolver`

**Files:**
- Modify: `pubspec.yaml:10-16`
- Create: `lib/features/sport_detail/sport_brand_palette.dart`
- Create: `test/sport_brand_palette_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class SportBrandPalette {
    final Color headerStart;
    final Color headerEnd;
    final Color softAccent;
    final Color badgeBackground;
    final Color chartColor;
  }
  class SportBrandPaletteResolver {
    static SportBrandPalette resolve(String sport);
  }
  ```

- [ ] **Step 1: Write the failing test for SportBrandPaletteResolver**

Create `test/sport_brand_palette_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/sport_detail/sport_brand_palette.dart';

void main() {
  group('SportBrandPaletteResolver', () {
    test('resolves distinct palettes for known sports', () {
      final silat = SportBrandPaletteResolver.resolve('Pencak Silat');
      final badminton = SportBrandPaletteResolver.resolve('Bulu Tangkis');
      final football = SportBrandPaletteResolver.resolve('Sepak Bola');
      final volleyball = SportBrandPaletteResolver.resolve('Bola Voli');
      final swimming = SportBrandPaletteResolver.resolve('Renang');

      expect(silat.headerStart, const Color(0xFFC2410C));
      expect(badminton.headerStart, const Color(0xFF6D28D9));
      expect(football.headerStart, const Color(0xFF1D4ED8));
      expect(volleyball.headerStart, const Color(0xFF0284C7));
      expect(swimming.headerStart, const Color(0xFF0F766E));
    });

    test('resolves fallback palette for unknown sport', () {
      final unknown = SportBrandPaletteResolver.resolve('Olahraga Lain');
      expect(unknown.headerStart, const Color(0xFF1B4FA0));
      expect(unknown.headerEnd, const Color(0xFF123A75));
    });
  });
}
```

- [ ] **Step 2: Add `fl_chart: ^1.2.0` to `pubspec.yaml` and run `flutter pub get`**

Add `fl_chart: ^1.2.0` to `pubspec.yaml` under `dependencies` and run `flutter pub get`.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/sport_brand_palette_test.dart`  
Expected: FAIL (file or class not found).

- [ ] **Step 4: Implement `SportBrandPaletteResolver`**

Create `lib/features/sport_detail/sport_brand_palette.dart`:
```dart
import 'package:flutter/material.dart';

class SportBrandPalette {
  const SportBrandPalette({
    required this.headerStart,
    required this.headerEnd,
    required this.softAccent,
    required this.badgeBackground,
    required this.chartColor,
  });

  final Color headerStart;
  final Color headerEnd;
  final Color softAccent;
  final Color badgeBackground;
  final Color chartColor;
}

class SportBrandPaletteResolver {
  static const _silat = SportBrandPalette(
    headerStart: Color(0xFFC2410C),
    headerEnd: Color(0xFF9A3412),
    softAccent: Color(0xFFFFEDD5),
    badgeBackground: Color(0xFFFFF7ED),
    chartColor: Color(0xFFEA580C),
  );

  static const _badminton = SportBrandPalette(
    headerStart: Color(0xFF6D28D9),
    headerEnd: Color(0xFF4C1D95),
    softAccent: Color(0xFFDDD6FE),
    badgeBackground: Color(0xFFF5F3FF),
    chartColor: Color(0xFF7C3AED),
  );

  static const _football = SportBrandPalette(
    headerStart: Color(0xFF1D4ED8),
    headerEnd: Color(0xFF1E3A8A),
    softAccent: Color(0xFFDBEAFE),
    badgeBackground: Color(0xFFEFF6FF),
    chartColor: Color(0xFF2563EB),
  );

  static const _volleyball = SportBrandPalette(
    headerStart: Color(0xFF0284C7),
    headerEnd: Color(0xFF0369A1),
    softAccent: Color(0xFFE0F2FE),
    badgeBackground: Color(0xFFF0F9FF),
    chartColor: Color(0xFF0284C7),
  );

  static const _swimming = SportBrandPalette(
    headerStart: Color(0xFF0F766E),
    headerEnd: Color(0xFF115E59),
    softAccent: Color(0xFFCCFBF1),
    badgeBackground: Color(0xFFF0FDFA),
    chartColor: Color(0xFF0D9488),
  );

  static const _fallback = SportBrandPalette(
    headerStart: Color(0xFF1B4FA0),
    headerEnd: Color(0xFF123A75),
    softAccent: Color(0xFFE9F0FB),
    badgeBackground: Color(0xFFF0F4FA),
    chartColor: Color(0xFF1B4FA0),
  );

  static SportBrandPalette resolve(String sport) {
    final lower = sport.toLowerCase();
    if (lower.contains('silat')) return _silat;
    if (lower.contains('tangkis') || lower.contains('badminton')) return _badminton;
    if (lower.contains('sepak') || lower.contains('bola') && !lower.contains('voli')) return _football;
    if (lower.contains('voli')) return _volleyball;
    if (lower.contains('renang')) return _swimming;
    return _fallback;
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/sport_brand_palette_test.dart`  
Expected: PASS (2 tests passed).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/sport_detail/sport_brand_palette.dart test/sport_brand_palette_test.dart
git commit -m "feat(cabor): tambahkan dependensi fl_chart dan resolver tema palet cabor dinamis"
```

---

### Task 2: Pembaruan Halaman Induk Cabor (`lib/features/sports_page.dart`) dengan Grafik Sebaran Atlet `fl_chart`

**Files:**
- Modify: `lib/features/sports_page.dart`
- Create: `test/sports_page_test.dart`

**Interfaces:**
- Consumes:
  - `SportBrandPaletteResolver.resolve(sport)`
  - `BrandHeaderPatternPainter`
  - `fl_chart` (`BarChart`, `BarChartData`, dll)

- [ ] **Step 1: Write failing widget test in `test/sports_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/sports_page.dart';

void main() {
  group('SportsPage Widget Tests', () {
    Widget buildSubject({GoRouter? router}) {
      return ProviderScope(
        overrides: [
          snapshotProvider.overrideWith((ref) => DemoKokRepository().fetch()),
        ],
        child: MaterialApp.router(
          routerConfig: router ??
              GoRouter(
                initialLocation: '/sports',
                routes: [
                  GoRoute(
                    path: '/sports',
                    builder: (_, _) => const SportsPage(),
                  ),
                  GoRoute(
                    path: '/sport/:name',
                    builder: (_, s) => Scaffold(
                      body: Text('Detail: ${s.pathParameters['name']}'),
                    ),
                  ),
                ],
              ),
        ),
      );
    }

    testWidgets('renders executive header, chart, and sport cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('5 Cabang Olahraga Aktif'), findsOneWidget);
      expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Pencak Silat'), findsWidgets);
      expect(find.text('Sepak Bola'), findsWidgets);
    });

    testWidgets('filters sports list using search field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bulu');
      await tester.pumpAndSettle();

      expect(find.text('Bulu Tangkis'), findsOneWidget);
      expect(find.text('Renang'), findsNothing);
    });

    testWidgets('tapping sport card navigates to /sport/:name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bulu Tangkis').first);
      await tester.pumpAndSettle();

      expect(find.text('Detail: Bulu Tangkis'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sports_page_test.dart`  
Expected: FAIL (missing header text / BarChart).

- [ ] **Step 3: Implement new `SportsPage` in `lib/features/sports_page.dart`**

Update `lib/features/sports_page.dart`:
- Header navy dengan `BrandHeaderPatternPainter` dan teks *"DIREKTORI CABANG OLAHRAGA"*, *"5 Cabang Olahraga Aktif"*, dan subteks Garut Kota.
- Kartu analitik sebaran atlet `SEBARAN ATLET PER CABANG OLAHRAGA` dengan horizontal `BarChart` `fl_chart` mewarnai tiap cabor dengan warna dari `SportBrandPaletteResolver.resolve(s).chartColor`.
- Search input dengan border radius 12, placeholder *"Cari cabang olahraga..."*, prefix icon search, dan clear button.
- Daftar kartu cabor: avatar dengan soft background, nama cabor tebal (`KokColors.cardTitle`, 16sp), baris chips `X Klub`, `Y Atlet`, `Z Pelatih`, mini verification progress bar, chevron kanan, dan `onTap: () => context.push('/sport/${Uri.encodeComponent(sport)}')`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/sports_page_test.dart`  
Expected: PASS (all 3 tests pass).

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/sports_page.dart test/sports_page_test.dart
git commit -m "feat(cabor): perbarui halaman direktori cabor dengan grafik sebaran atlet fl_chart"
```

---

### Task 3: Pembuatan Modul Mandiri `SportDetailPage` di `lib/features/sport_detail/sport_detail_page.dart` & Unit Test

**Files:**
- Create: `lib/features/sport_detail/sport_detail_page.dart`
- Create: `test/sport_detail_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class SportDetailPage extends ConsumerStatefulWidget {
    const SportDetailPage({super.key, required this.sport});
    final String sport;
  }
  ```

- [ ] **Step 1: Write failing widget tests in `test/sport_detail_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/sport_detail/sport_detail_page.dart';

void main() {
  group('SportDetailPage Widget Tests', () {
    Widget buildSubject({String sport = 'Sepak Bola', GoRouter? router}) {
      return ProviderScope(
        overrides: [
          snapshotProvider.overrideWith((ref) => DemoKokRepository().fetch()),
        ],
        child: MaterialApp.router(
          routerConfig: router ??
              GoRouter(
                initialLocation: '/sport/$sport',
                routes: [
                  GoRoute(
                    path: '/sport/:name',
                    builder: (_, s) => SportDetailPage(
                      sport: s.pathParameters['name'] ?? sport,
                    ),
                  ),
                  GoRoute(
                    path: '/club/:id',
                    builder: (_, s) => Scaffold(
                      body: Text('Club: ${s.pathParameters['id']}'),
                    ),
                  ),
                  GoRoute(
                    path: '/person/:id',
                    builder: (_, s) => Scaffold(
                      body: Text('Person: ${s.pathParameters['id']}'),
                    ),
                  ),
                ],
              ),
        ),
      );
    }

    testWidgets('renders sport dynamic header, floating stats card, and tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      expect(find.text('Sepak Bola'), findsWidgets);
      expect(find.text('Kecamatan Garut Kota'), findsWidgets);
      expect(find.text('Klub'), findsWidgets);
      expect(find.text('Atlet'), findsWidgets);
      expect(find.text('Pelatih'), findsWidgets);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('renders analytic fl_chart and toggles between age groups and document status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      expect(find.text('Kelompok Usia'), findsOneWidget);
      expect(find.text('Status Berkas'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);

      await tester.tap(find.text('Status Berkas'));
      await tester.pumpAndSettle();

      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('switches to Atlet tab, filters age group, and taps athlete to open detail', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Atlet').first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Semua'), findsWidgets);

      await tester.tap(find.text('U-16'));
      await tester.pumpAndSettle();

      final firstPerson = find.textContaining('Atlet').first;
      await tester.tap(firstPerson);
      await tester.pumpAndSettle();

      expect(find.textContaining('Person:'), findsOneWidget);
    });

    testWidgets('switches to Pelatih tab and taps coach to open detail', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pelatih').first);
      await tester.pumpAndSettle();

      final coachFinder = find.textContaining('Pelatih').first;
      await tester.tap(coachFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Person:'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sport_detail_test.dart`  
Expected: FAIL (file or class not found).

- [ ] **Step 3: Implement `SportDetailPage` in `lib/features/sport_detail/sport_detail_page.dart`**

Implement:
- `SportDetailPage extends ConsumerStatefulWidget`
- Header dinamis: `palette = SportBrandPaletteResolver.resolve(widget.sport)`, gradient `[palette.headerStart, palette.headerEnd]`, `BrandHeaderPatternPainter`, `Icons.chevron_left` (`size: 28`), `Icons.share_outlined`, avatar cabor 48px ber-border putih, nama cabor putih.
- Floating stats card (-32px): 4 kolom (Klub, Atlet, Pelatih, Berkas Lengkap).
- Kartu analitik `fl_chart` dengan dwimode toggle (`_analyticMode == AnalyticMode.ageGroup` ? `BarChart` : `PieChart`).
- 3 Tab View (`TabBar` & `TabBarView`):
  * Tab Klub: Daftar klub di cabor ini, kelurahan, total atlet, badge berkas, tap -> `context.push('/club/${c.id}')`.
  * Tab Atlet: Filter search + filter chip kelompok usia (Semua, U-14, U-16, U-18, Senior), daftar kartu atlet berpalet klub, badge status berkas, tap -> `context.push('/person/${p.id}')`.
  * Tab Pelatih: Daftar pelatih & official cabor dengan info lisensi & masa berlaku, tap -> `context.push('/person/${p.id}')`.
- Sticky bottom action bar: Tombol *"Salin Rekapitulasi Cabor"* (menyalin ringkasan data cabor ke Clipboard dan menampilkan SnackBar).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/sport_detail_test.dart`  
Expected: PASS (all 4 tests pass).

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/sport_detail/sport_detail_page.dart test/sport_detail_test.dart
git commit -m "feat(sport-detail): buat modul mandiri SportDetailPage dengan analitik dwimode fl_chart dan tab klub/atlet/pelatih"
```

---

### Task 4: Integrasi Router di `lib/app.dart`, Pengujian Integrasi `test/app_test.dart`, & Golden Previews

**Files:**
- Modify: `lib/app.dart:66-70`
- Modify: `test/app_test.dart`
- Modify: `test/preview_test.dart`
- Update: `previews/cabor.png`, `previews/detail-cabor.png`

- [ ] **Step 1: Update route `/sport/:name` in `lib/app.dart`**

Replace:
```dart
      GoRoute(
        path: '/sport/:name',
        builder: (_, s) => ClubsPage(sport: s.pathParameters['name']!),
      ),
```
With:
```dart
      GoRoute(
        path: '/sport/:name',
        builder: (_, s) => SportDetailPage(sport: s.pathParameters['name']!),
      ),
```
Add import: `import 'features/sport_detail/sport_detail_page.dart';`.

- [ ] **Step 2: Update integration tests in `test/app_test.dart`**

Update the sport navigation tests in `test/app_test.dart` to verify navigating to `SportDetailPage`:
- From Sports tab -> tap a sport -> verify `SportDetailPage` renders with its dynamic header and tabs.
- Switch to tab Atlet -> tap an athlete -> verify `AthleteDetailPage` opens -> tap back -> back to `SportDetailPage` -> tap back -> back to `/sports`.
- Ensure all existing integration test flows continue to pass 100%.

- [ ] **Step 3: Update golden previews in `test/preview_test.dart`**

Run:
`flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`  
Check `git status`. Revert any preview files that only have accidental diffs, keeping only `previews/cabor.png` and `previews/detail-cabor.png`.

- [ ] **Step 4: Run full test suite & analyze**

Run: `flutter test`  
Expected: 100% passed.  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart test/app_test.dart test/preview_test.dart previews/cabor.png previews/detail-cabor.png
git commit -m "feat(app): integrasikan rute SportDetailPage, perbarui tes integrasi dan golden preview cabor"
```

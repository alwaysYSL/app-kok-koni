# Pemolesan Halaman Induk Cabor (SportsPage Clean Redesign) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles tampilan Halaman Induk Cabor (`SportsPage`) menjadi bersih, lega, dan mudah dibaca dengan menghapus hero banner biru dan search bar, menerapkan grafik sebaran atlet horizontal (Format A) tanpa tumpukan kartu, memastikan seluruh teks berukuran $\ge 12\text{px}$, serta memperbarui kartu direktori cabor dengan chip metrik dan sinyal peringatan berkas kurang yang terarah (Opsi 2).

**Architecture:** Merestrukturisasi `lib/features/sports_page.dart` menggunakan header ringkas, kartu sebaran horizontal custom berbasis `SportBrandPaletteResolver` dengan logika ekspansi Top 5, serta kartu cabor ramping tanpa progress bar horizontal repetitif.

**Tech Stack:** Flutter 3, Dart, Riverpod 3, GoRouter 17, `SportBrandPaletteResolver`.

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-07-sports-hub-ui-polish-design.md`.
- Tidak ada teks yang berukuran font di bawah 12px (semua teks $\ge 12\text{px}$).
- Warna teks utama judul kartu `KokColors.cardTitle` (`#141414`) dan palet terpusat di `lib/core/theme.dart`.
- Tidak mengubah struktur 5 tab navigasi bawah.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Pembaruan Halaman Induk Cabor (`lib/features/sports_page.dart`) & Unit Test Suite

**Files:**
- Modify: `lib/features/sports_page.dart`
- Modify: `test/sports_page_test.dart`

**Interfaces:**
- Consumes:
  - `SportBrandPaletteResolver.resolve(sport)`
  - `KokColors`
- Produces:
  - Clean `SportsPage` with compact header, horizontal athlete bars, and warning-focused sport cards.

- [ ] **Step 1: Write the failing widget tests in `test/sports_page_test.dart`**

Update `test/sports_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

    testWidgets('renders compact header with cabor count badge and no hero banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Cabang Olahraga Aktif'), findsOneWidget);
      expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
      expect(find.textContaining('5 Cabor'), findsOneWidget);
      expect(find.text('DIREKTORI CABANG OLAHRAGA'), findsNothing);
    });

    testWidgets('renders horizontal athlete distribution bars with full names and no search bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify no search field exists
      expect(find.byType(TextField), findsNothing);

      // Verify distribution chart header
      expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsOneWidget);

      // Verify full sport names are rendered in the distribution card
      expect(find.text('Pencak Silat'), findsWidgets);
      expect(find.text('Sepak Bola'), findsWidgets);
      expect(find.text('Bulu Tangkis'), findsWidgets);
      expect(find.text('Bola Voli'), findsWidgets);
      expect(find.text('Renang'), findsWidgets);

      // Verify athlete count labels
      expect(find.text('44 atlet'), findsOneWidget);
      expect(find.text('34 atlet'), findsOneWidget);
    });

    testWidgets('displays sport cards with metric chips and warning badge only on missing documents', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify metric chips
      expect(find.textContaining('Klub'), findsWidgets);
      expect(find.textContaining('Atlet'), findsWidgets);
      expect(find.textContaining('Pelatih'), findsWidgets);

      // Verify warning only on Sepak Bola (cabor with 8 missing documents)
      expect(find.text('8 atlet berkas kurang'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Verify progress bar is removed
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('tapping sport card or horizontal bar navigates to /sport/:name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
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
Expected: FAIL (search field still found or header text differs).

- [ ] **Step 3: Implement clean `SportsPage` in `lib/features/sports_page.dart`**

Implement:
- Remove hero banner widget (`_buildExecutiveHeader`).
- Remove `TextField` and search logic.
- Implement Compact Header (Model 1):
  - Row with `"Cabang Olahraga Aktif"`, `"Kecamatan Garut Kota"`, and capsule badge `"$totalSports Cabor · $totalAthletes Atlet"` (12.5sp, bold).
- Implement Horizontal Distribution Card (Format A):
  - Card with radius 16, border `Color(0xFFE5E7EB)`.
  - Section title `"SEBARAN ATLET PER CABANG OLAHRAGA"` (12.5sp, bold).
  - List of horizontal bars sorted by athlete count desc:
    * Sport name (13.5sp, bold, full text).
    * `Expanded(ClipRRect(borderRadius: BorderRadius.circular(6), child: Container(height: 12, ...)))` with fraction `count / maxCount` and `palette.chartColor`.
    * Count text `"$count atlet"` (13sp, bold).
    * Tap gesture navigates to `/sport/${Uri.encodeComponent(sport)}`.
  - Expandable behavior: default Top 5, if `allSports.length > 5` show text button `"Tampilkan ${allSports.length - 5} cabor lainnya ▾"`.
- Implement Clean Directory Section:
  - SectionHead `"Direktori cabor"` (16sp, bold).
  - Sport cards:
    * `SportAvatar(sport)`.
    * Title (16sp, bold, `KokColors.cardTitle`).
    * Metric chips row: `"$clubCount Klub"`, `"$athleteCount Atlet"`, `"$coachCount Pelatih"` (12sp).
    * Warning row (only if `missingCount > 0`): `Icons.warning_amber_rounded` (14px, `#DC2626`) + `"$missingCount atlet berkas kurang"` (12sp, `#DC2626`, bold).
    * Tap gesture navigates to `/sport/${Uri.encodeComponent(sport)}`.
- Ensure all text sizes are $\ge 12\text{px}$.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/sports_page_test.dart`  
Expected: PASS (all 4 tests pass).

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/sports_page.dart test/sports_page_test.dart
git commit -m "feat(sports-page): perbarui halaman cabor dengan header ringkas, horizontal bars, dan kartu bebas progress bar"
```

---

### Task 2: Pengujian Integrasi `test/app_test.dart`, Regenerasi Golden Preview, & Verifikasi Penuh

**Files:**
- Modify: `test/app_test.dart`
- Update: `previews/cabor.png`

- [ ] **Step 1: Verify and update `test/app_test.dart`**

Check tests interacting with the sports tab:
- Ensure any test expecting a search field on the sports tab is adjusted (sports tab no longer has search, global search is available via `/search` or home search bar).
- Verify integration navigation Tab Cabor -> Sport Detail -> Person Detail -> Back.
- Run `flutter test test/app_test.dart` to verify 100% pass.

- [ ] **Step 2: Regenerate golden preview for `previews/cabor.png`**

Run:
`flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`  
Check `git status`.  
Revert any accidental preview changes, keeping only `previews/cabor.png`.

- [ ] **Step 3: Run full suite verification & analyze**

Run: `flutter test`  
Expected: 100% tests pass.  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 4: Commit**

```bash
git add test/app_test.dart previews/cabor.png
git commit -m "test: perbarui pengujian integrasi dan golden preview cabor bebas clutter"
```

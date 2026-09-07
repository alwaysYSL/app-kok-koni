# Global Search Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun modul pencarian terpadu (*Global Search*) se-Kecamatan Garut Kota yang memungkinkan pengguna mencari langsung nama atlet, pelatih, klub, dan cabor dari Search Bar di Beranda tanpa navigasi bertingkat.

**Architecture:** Modul mandiri `GlobalSearchPage` di `lib/features/search/global_search_page.dart` yang mengonsumsi `snapshotProvider` untuk pencarian instan multi-entitas dengan filter kategori (`Semua`, `Atlet`, `Pelatih`, `Klub`, `Cabor`). Terintegrasi di `lib/features/home_page.dart` via `_HomeSearchBar` di dalam `DashboardHeaderDecoration` dan rute `/search` di `lib/app.dart`.

**Tech Stack:** Flutter 3.x, Riverpod (`ConsumerWidget`, `snapshotProvider`), GoRouter (`context.push`, `context.pop`), Dart Freezed Models (`SportPerson`, `Club`, `KokSnapshot`).

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-07-global-search-feature-design.md`.
- Menggunakan warna teks utama judul kartu `KokColors.cardTitle` (`#141414`) dan palet terpusat di `lib/core/theme.dart`.
- Tombol kembali menggunakan ikon `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
- Tidak mengubah struktur 5 tab navigasi bawah (`Beranda`, `Cabor`, `Klub`, `Anggota`, `Akun`).
- Avatar "PA" di pojok kanan atas header Beranda tetap dipertahankan.
- Padding dan layout header Beranda mempertahankan jarak visual aman 16px di atas `_FloatingStatsCard` (padding bawah 48px, translate offset -32px).
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Modul Pencarian Terpadu (`GlobalSearchPage`) & Test Suite Mandiri

**Files:**
- Create: `lib/features/search/global_search_page.dart`
- Create: `test/search_page_test.dart`

**Interfaces:**
- Consumes:
  - `snapshotProvider` dari `lib/shared/widgets.dart` / `lib/data/repository.dart`.
  - `KokColors` dari `lib/core/theme.dart`.
  - `SportPerson`, `Club`, `KokSnapshot` dari `lib/data/models.dart`.
  - `sportIcon(String sport)` dari `lib/shared/widgets.dart`.
  - `ClubBrandPaletteResolver.resolve(Club club)` dari `lib/features/club_detail/club_brand_palette.dart`.
- Produces:
  - `class GlobalSearchPage extends ConsumerStatefulWidget`
  - `enum SearchCategory { all, athletes, coaches, clubs, sports }`

- [ ] **Step 1: Write the failing unit/widget test in `test/search_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/search/global_search_page.dart';
import 'package:kok_app/shared/widgets.dart';

Widget createSearchTestApp({
  required KokSnapshot snapshot,
  void Function(String route)? onNavigated,
}) {
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => const GlobalSearchPage(),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, state) {
          onNavigated?.call('/person/${state.pathParameters['id']}');
          return Scaffold(body: Text('Person Detail ${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/club/:id',
        builder: (_, state) {
          onNavigated?.call('/club/${state.pathParameters['id']}');
          return Scaffold(body: Text('Club Detail ${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/sport/:name',
        builder: (_, state) {
          onNavigated?.call('/sport/${state.pathParameters['name']}');
          return Scaffold(body: Text('Sport Detail ${state.pathParameters['name']}'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      snapshotProvider.overrideWith((_) async => snapshot),
    ],
    child: MaterialApp.router(
      theme: kokTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('KokSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });

  group('GlobalSearchPage Widget Tests', () {
    testWidgets('renders search input with autofocus, back button, and category chips', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari nama atlet, pelatih, klub, cabor...'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Atlet'), findsOneWidget);
      expect(find.text('Pelatih'), findsOneWidget);
      expect(find.text('Klub'), findsOneWidget);
      expect(find.text('Cabor'), findsOneWidget);
    });

    testWidgets('searches for athlete by name and navigates to athlete detail on tap', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      String? navigatedRoute;
      await tester.pumpWidget(
        createSearchTestApp(
          snapshot: data!,
          onNavigated: (route) => navigatedRoute = route,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Voli Bina Muda');
      await tester.pumpAndSettle();

      expect(find.text('Atlet 1 · Voli Bina Muda'), findsOneWidget);
      expect(find.text('Voli Bina Muda · Voli'), findsWidgets);

      await tester.tap(find.text('Atlet 1 · Voli Bina Muda'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/person/voli-atlet-0');
      expect(find.text('Person Detail voli-atlet-0'), findsOneWidget);
    });

    testWidgets('category chip filters results by role', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Garuda');
      await tester.pumpAndSettle();

      // In 'Semua', both Club and Athletes/Coaches appear
      expect(find.text('Klub Garuda Muda'), findsOneWidget);

      // Tap 'Atlet' chip
      await tester.tap(find.text('Atlet'));
      await tester.pumpAndSettle();

      // Club should be filtered out
      expect(find.text('Klub Garuda Muda'), findsNothing);
      // Athletes should still be present
      expect(find.textContaining('Garuda Muda'), findsWidgets);
    });

    testWidgets('displays empty state when no matches found', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'KataKunciYangTidakMungkinAda123');
      await tester.pumpAndSettle();

      expect(find.textContaining('Tidak ditemukan hasil'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/search_page_test.dart`
Expected: FAIL (file `global_search_page.dart` does not exist).

- [ ] **Step 3: Implement `GlobalSearchPage` in `lib/features/search/global_search_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../club_detail/club_brand_palette.dart';

enum SearchCategory {
  all('Semua'),
  athletes('Atlet'),
  coaches('Pelatih'),
  clubs('Klub'),
  sports('Cabor');

  const SearchCategory(this.label);
  final String label;
}

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  SearchCategory _selectedCategory = SearchCategory.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KokColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            size: 28,
            color: KokColors.cardTitle,
          ),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14.5, color: KokColors.cardTitle),
            decoration: InputDecoration(
              hintText: 'Cari nama atlet, pelatih, klub, cabor...',
              hintStyle: const TextStyle(color: KokColors.muted, fontSize: 13.5),
              prefixIcon: const Icon(Icons.search, size: 20, color: KokColors.muted),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: KokColors.muted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) => setState(() => _query = val.trim()),
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      body: DataView(
        builder: (data) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategoryChips(),
              Expanded(
                child: _query.isEmpty
                    ? _buildInitialState(data)
                    : _buildSearchResults(data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: SearchCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat.label),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : KokColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                selectedColor: KokColors.bluePrimary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? KokColors.bluePrimary : const Color(0xFFE5E7EB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInitialState(KokSnapshot data) {
    final sports = data.clubs.map((c) => c.sport).toSet().take(6).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const Center(
          child: Icon(Icons.manage_search_rounded, size: 48, color: KokColors.blueMedium),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pencarian Terpadu Garut Kota',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: KokColors.cardTitle,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ketik nama atlet, pelatih, klub, atau cabang olahraga untuk menemukan data secara cepat.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: KokColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        const Text(
          'SARAN CABANG OLAHRAGA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: KokColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sports.map((sport) {
            return ActionChip(
              avatar: Icon(sportIcon(sport), size: 16, color: KokColors.bluePrimary),
              label: Text(sport),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KokColors.cardTitle,
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: () {
                _searchController.text = sport;
                setState(() => _query = sport);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults(KokSnapshot data) {
    final q = _query.toLowerCase();

    // 1. Match Athletes & Coaches
    final matchedPeople = data.people.where((p) {
      final club = data.clubs.firstWhere(
        (c) => c.id == p.clubId,
        orElse: () => Club(id: p.clubId, name: '', sport: '', village: ''),
      );

      final matchesText = p.name.toLowerCase().contains(q) ||
          club.name.toLowerCase().contains(q) ||
          club.sport.toLowerCase().contains(q) ||
          p.group.toLowerCase().contains(q);

      if (!matchesText) return false;

      return switch (_selectedCategory) {
        SearchCategory.all => true,
        SearchCategory.athletes => p.role == 'Atlet',
        SearchCategory.coaches => p.role == 'Pelatih',
        _ => false,
      };
    }).toList();

    // 2. Match Clubs
    final matchedClubs = switch (_selectedCategory) {
      SearchCategory.all || SearchCategory.clubs => data.clubs.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.sport.toLowerCase().contains(q) ||
              c.village.toLowerCase().contains(q);
        }).toList(),
      _ => <Club>[],
    };

    // 3. Match Sports
    final allSports = data.clubs.map((c) => c.sport).toSet().toList();
    final matchedSports = switch (_selectedCategory) {
      SearchCategory.all || SearchCategory.sports => allSports.where((s) {
          return s.toLowerCase().contains(q);
        }).toList(),
      _ => <String>[],
    };

    final totalCount = matchedPeople.length + matchedClubs.length + matchedSports.length;

    if (totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 52, color: KokColors.muted),
              const SizedBox(height: 12),
              Text(
                'Tidak ditemukan hasil untuk "$_query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Coba gunakan kata kunci lain atau periksa filter kategori di atas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: KokColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DITEMUKAN $totalCount HASIL',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: KokColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...matchedPeople.map((p) {
          final club = data.clubs.firstWhere(
            (c) => c.id == p.clubId,
            orElse: () => Club(id: p.clubId, name: 'Klub', sport: '', village: ''),
          );
          final palette = ClubBrandPaletteResolver.resolve(club);
          return _buildPersonResultCard(p, club, palette);
        }),
        ...matchedClubs.map((c) {
          final athletesCount = data.people.where((p) => p.clubId == c.id && p.role == 'Atlet').length;
          return _buildClubResultCard(c, athletesCount);
        }),
        ...matchedSports.map((s) {
          final clubsCount = data.clubs.where((c) => c.sport == s).length;
          final athletesCount = data.people.where((p) {
            final club = data.clubs.firstWhere(
              (c) => c.id == p.clubId,
              orElse: () => Club(id: p.clubId, name: '', sport: '', village: ''),
            );
            return club.sport == s && p.role == 'Atlet';
          }).length;
          return _buildSportResultCard(s, clubsCount, athletesCount);
        }),
      ],
    );
  }

  Widget _buildPersonResultCard(SportPerson person, Club club, ClubBrandPalette palette) {
    final isAthlete = person.role == 'Atlet';
    final roleBg = isAthlete ? const Color(0xFFD1FAE5) : const Color(0xFFE0E7FF);
    final roleFg = isAthlete ? const Color(0xFF059669) : const Color(0xFF3730A3);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/person/${person.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.fallbackAvatar,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.headerStart.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.headerStart,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: KokColors.cardTitle,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            person.role,
                            style: TextStyle(
                              color: roleFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.name} · ${club.sport} (${person.group})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubResultCard(Club club, int athleteCount) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/club/${club.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KokColors.pale,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(sportIcon(club.sport), size: 22, color: KokColors.bluePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KokColors.cardTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.sport} · ${club.village} · $athleteCount atlet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportResultCard(String sport, int clubsCount, int athletesCount) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/sport/${Uri.encodeComponent(sport)}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(sportIcon(sport), size: 22, color: KokColors.bluePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sport,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KokColors.cardTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$clubsCount klub · $athletesCount atlet terdaftar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/search_page_test.dart`
Expected: PASS (100% tests pass).

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/search/global_search_page.dart test/search_page_test.dart
git commit -m "feat(search): buat modul pencarian terpadu GlobalSearchPage se-Kecamatan Garut Kota"
```

---

### Task 2: Integrasi Search Bar di `HomePage`, Pendaftaran Rute di `lib/app.dart`, Integrasi Test, & Golden Preview

**Files:**
- Modify: `lib/features/home_page.dart`
- Modify: `lib/app.dart`
- Modify: `test/app_test.dart`
- Modify: `test/preview_test.dart`

**Interfaces:**
- Consumes:
  - `GlobalSearchPage` dari `lib/features/search/global_search_page.dart`.
- Produces:
  - `_HomeSearchBar` widget di `lib/features/home_page.dart`.
  - GoRoute `/search` di `lib/app.dart`.
  - Golden preview `previews/pencarian.png`.

- [ ] **Step 1: Write integration test assertion in `test/app_test.dart`**

In `test/app_test.dart`, in the full navigation test:
- Verify `find.byType(_HomeSearchBar)` (or `find.text('Cari nama atlet, klub, cabor...')`) exists on `HomePage`.
- Tap the search bar -> expect `/search` opens (`GlobalSearchPage`).
- Type an athlete name -> tap result -> expect `AthleteDetailPage` opens.
- Tap back -> expect returns to `/search`.
- Tap back again -> expect returns to `HomePage`.

- [ ] **Step 2: Update `lib/features/home_page.dart` with `_HomeSearchBar`**

In `lib/features/home_page.dart`:
- Change `DashboardHeaderDecoration` child from `Row` to `Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min)` containing:
  - The greeting `Row` (Logo, Greeting column, and Avatar PA).
  - `const SizedBox(height: 14)`.
  - `_HomeSearchBar(onTap: () => context.push('/search'))`.
- Keep `padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 48)`.
- Implement `_HomeSearchBar`:
  ```dart
  class _HomeSearchBar extends StatelessWidget {
    const _HomeSearchBar({required this.onTap});
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
      return Semantics(
        button: true,
        label: 'Cari nama atlet, klub, atau cabor',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: KokColors.muted, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cari nama atlet, klub, cabor...',
                    style: TextStyle(
                      color: KokColors.muted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: KokColors.pale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Cari',
                    style: TextStyle(
                      color: KokColors.bluePrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 3: Register `/search` in `lib/app.dart`**

In `lib/app.dart`:
- Import `package:kok_app/features/search/global_search_page.dart`.
- Add:
  ```dart
  GoRoute(
    path: '/search',
    builder: (_, _) => const GlobalSearchPage(),
  ),
  ```

- [ ] **Step 4: Update golden preview capture in `test/preview_test.dart`**

In `test/preview_test.dart`:
- Add `'pencarian': '/search'` in preview map.
- Run:
  `flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true`
- Check `git status` to ensure `previews/pencarian.png` is generated.

- [ ] **Step 5: Run tests and static analysis**

Run: `flutter test`
Expected: 100% tests pass.

Run: `flutter analyze`
Expected: 0 issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home_page.dart lib/app.dart test/app_test.dart test/preview_test.dart previews/
git commit -m "feat(home): integrasikan Search Bar di header Beranda menuju modul pencarian terpadu"
```

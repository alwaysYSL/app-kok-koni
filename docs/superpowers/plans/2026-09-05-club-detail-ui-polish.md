# Club Detail UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun ulang halaman detail klub mengikuti referensi Figma, mencakup empat tab dan identitas warna per klub yang aman, responsif, serta siap menerima logo dan warna dari SICABOR.

**Architecture:** Pindahkan detail klub dari `detail_pages.dart` ke feature kecil di `lib/features/club_detail/`. Data tetap serializable sebagai URL/string hex, sedangkan `ClubBrandPaletteResolver` menerjemahkannya menjadi token warna Flutter dengan fallback eksplisit → demo → cabor → KOK; komponen header, tab, daftar orang, dan dokumen hanya mengonsumsi palette semantik tersebut.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Material 3, Riverpod, GoRouter, Freezed, json_serializable, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-05-club-detail-ui-polish-design.md`

## Global Constraints

- Memoles keempat tab: Atlet, Pelatih, Official, dan Dokumen.
- Tidak mengubah `ThemeData` global untuk mengikuti warna klub.
- Data layer tidak boleh mengimpor `package:flutter/material.dart` atau menyimpan objek `Color`.
- Seluruh field SICABOR baru bersifat opsional dan data yang tidak tersedia tidak boleh dibuat seolah-olah data resmi.
- Merah tetap berarti bermasalah, hijau tetap berarti aktif/valid, dan warna klub hanya menjadi identitas/dekorasi.
- Ekstraksi warna dominan dari logo dan cache palette tidak diimplementasikan pada tahap ini.
- Tidak menambahkan dependency produksi baru.
- Halaman harus bebas overflow pada lebar 320 px dan 390 px.
- `flutter analyze` harus 0 issues dan `flutter test` harus lulus seluruhnya.

## File Structure

- `lib/data/models.dart`: kontrak field opsional branding klub dan metadata orang.
- `lib/data/repository.dart`: data demo yang mengaktifkan variasi warna dan metadata baru.
- `lib/features/club_detail/club_brand_palette.dart`: parsing hex, kontras, gradasi, dan fallback palette.
- `lib/features/club_detail/club_people_filter.dart`: state/filter domain yang murni dan mudah diuji.
- `lib/features/club_detail/club_detail_header.dart`: hero klub dan statistik.
- `lib/features/club_detail/club_detail_tabs.dart`: panel putih dan segmented `TabBar`.
- `lib/features/club_detail/club_person_card.dart`: presentasi anggota per peran.
- `lib/features/club_detail/club_people_tab.dart`: daftar dan bottom sheet filter per peran.
- `lib/features/club_detail/club_document_tab.dart`: dokumen klub read-only.
- `lib/features/club_detail/club_detail_page.dart`: komposisi route, nested scroll, tab, dan share.
- `lib/features/detail_pages.dart`: hanya halaman detail orang dan `MissingPage` setelah detail klub serta daftar lama diekstraksi.
- `lib/app.dart`: impor feature detail klub yang baru.
- `test/models_branding_test.dart`: kompatibilitas serialisasi field opsional.
- `test/club_brand_palette_test.dart`: perilaku resolver dan kontras.
- `test/club_people_filter_test.dart`: filter murni.
- `test/club_detail_widgets_test.dart`: komponen visual, fallback, tab, dan filter.
- `test/app_test.dart`: integrasi route, navigasi, share, dan responsivitas.
- `test/preview_test.dart`: rute golden tiga variasi klub.
- `previews/detail-klub.png`, `previews/detail-klub-pb.png`, `previews/detail-klub-voli.png`: hasil visual.

---

### Task 1: Extend the Serializable Club and Person Contracts

**Files:**
- Modify: `lib/data/models.dart`
- Regenerate: `lib/data/models.freezed.dart`
- Regenerate: `lib/data/models.g.dart`
- Create: `test/models_branding_test.dart`

**Interfaces:**
- Produces optional `Club.logoUrl`, `Club.brandPrimaryHex`, `Club.brandSecondaryHex`, `Club.foundedYear`, and `Club.registrationNumber`.
- Produces optional `SportPerson.photoUrl`, `SportPerson.gender`, and `SportPerson.age`.
- All existing constructors and JSON payloads without these keys remain valid.

- [ ] **Step 1: Write failing serialization tests**

Create `test/models_branding_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';

void main() {
  test('Club reads optional SICABOR branding fields', () {
    final club = Club.fromJson(const {
      'id': 'garuda',
      'name': 'Klub Garuda Muda',
      'sport': 'Sepak Bola',
      'village': 'Pakuwon',
      'logoUrl': 'https://example.test/garuda.png',
      'brandPrimaryHex': '#5B566E',
      'brandSecondaryHex': '#11294B',
      'foundedYear': 2011,
      'registrationNumber': 'SK 042/KONI/2023',
    });

    expect(club.logoUrl, 'https://example.test/garuda.png');
    expect(club.brandPrimaryHex, '#5B566E');
    expect(club.brandSecondaryHex, '#11294B');
    expect(club.foundedYear, 2011);
    expect(club.registrationNumber, 'SK 042/KONI/2023');
  });

  test('new branding and person fields remain optional', () {
    final club = Club.fromJson(const {
      'id': 'plain',
      'name': 'Klub Tanpa Branding',
      'sport': 'Lainnya',
      'village': 'Pakuwon',
    });
    final person = SportPerson.fromJson(const {
      'id': 'p1',
      'name': 'Nama Atlet',
      'clubId': 'plain',
      'role': 'Atlet',
      'group': 'U-18',
    });

    expect(club.logoUrl, isNull);
    expect(club.brandPrimaryHex, isNull);
    expect(club.foundedYear, isNull);
    expect(person.photoUrl, isNull);
    expect(person.gender, isNull);
    expect(person.age, isNull);
  });
}
```

- [ ] **Step 2: Run the test and confirm the contract is missing**

Run:

```powershell
flutter test test/models_branding_test.dart
```

Expected: FAIL at compile time because the new getters are not defined.

- [ ] **Step 3: Add optional fields to the Freezed factories**

Update the `Club` and `SportPerson` factories in `lib/data/models.dart`:

```dart
const factory Club({
  required String id,
  required String name,
  required String sport,
  required String village,
  @Default(true) bool active,
  String? logoUrl,
  String? brandPrimaryHex,
  String? brandSecondaryHex,
  int? foundedYear,
  String? registrationNumber,
}) = _Club;

const factory SportPerson({
  required String id,
  required String name,
  required String clubId,
  required String role,
  required String group,
  @Default(true) bool verified,
  @Default(false) bool expiredLicense,
  @Default(<String>[]) List<String> missingDocuments,
  String? photoUrl,
  String? gender,
  int? age,
}) = _SportPerson;
```

- [ ] **Step 4: Regenerate Freezed and JSON code**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Expected: `models.freezed.dart` and `models.g.dart` include every optional field and generation succeeds.

- [ ] **Step 5: Run the focused test**

Run:

```powershell
flutter test test/models_branding_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the data contract**

```powershell
git add lib/data/models.dart lib/data/models.freezed.dart lib/data/models.g.dart test/models_branding_test.dart
git commit -m "feat(club-detail): extend club branding data contract"
```

---

### Task 2: Build the Club Brand Palette Resolver

**Files:**
- Create: `lib/features/club_detail/club_brand_palette.dart`
- Create: `test/club_brand_palette_test.dart`

**Interfaces:**
- Consumes: `Club` from Task 1 and existing sport names.
- Produces: `ClubBrandPalette` with `headerStart`, `headerEnd`, `foreground`, `selectedTab`, `softAccent`, and `fallbackAvatar`.
- Produces: `ClubBrandPaletteResolver.resolve(Club club)` and `ClubBrandPaletteResolver.tryParseHex(String? value)`.

- [ ] **Step 1: Write failing resolver tests**

Create `test/club_brand_palette_test.dart` with these cases:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';

double contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

Club club({String id = 'custom', String? primary, String? secondary}) => Club(
  id: id,
  name: 'Klub Test',
  sport: 'Sepak Bola',
  village: 'Pakuwon',
  brandPrimaryHex: primary,
  brandSecondaryHex: secondary,
);

void main() {
  test('parses RGB and ARGB hex safely', () {
    expect(ClubBrandPaletteResolver.tryParseHex('#5B566E'), const Color(0xFF5B566E));
    expect(ClubBrandPaletteResolver.tryParseHex('FF11294B'), const Color(0xFF11294B));
    expect(ClubBrandPaletteResolver.tryParseHex('not-a-color'), isNull);
    expect(ClubBrandPaletteResolver.tryParseHex(null), isNull);
  });

  test('explicit club colors win over demo and sport fallbacks', () {
    final palette = ClubBrandPaletteResolver.resolve(
      club(id: 'garuda', primary: '#123456', secondary: '#102030'),
    );
    expect(palette.headerStart, const Color(0xFF123456));
    expect(palette.headerEnd, const Color(0xFF102030));
  });

  test('demo clubs resolve to distinct palettes', () {
    final garuda = ClubBrandPaletteResolver.resolve(club(id: 'garuda'));
    final pb = ClubBrandPaletteResolver.resolve(club(id: 'pb'));
    final voli = ClubBrandPaletteResolver.resolve(club(id: 'voli'));
    expect({garuda.headerStart, pb.headerStart, voli.headerStart}.length, 3);
  });

  test('foreground remains readable for bright amber', () {
    final palette = ClubBrandPaletteResolver.resolve(
      club(primary: '#FFC21C', secondary: '#D08A00'),
    );
    expect(contrast(palette.foreground, palette.headerStart), greaterThanOrEqualTo(4.5));
    expect(contrast(palette.foreground, palette.headerEnd), greaterThanOrEqualTo(4.5));
    expect(contrast(palette.foreground, palette.selectedTab), greaterThanOrEqualTo(4.5));
  });
}
```

- [ ] **Step 2: Run the tests and confirm the resolver is absent**

Run:

```powershell
flutter test test/club_brand_palette_test.dart
```

Expected: FAIL because `club_brand_palette.dart` does not exist.

- [ ] **Step 3: Implement immutable palette tokens and parsing**

Create `club_brand_palette.dart`. Use this public surface:

```dart
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

@immutable
class ClubBrandPalette {
  const ClubBrandPalette({
    required this.headerStart,
    required this.headerEnd,
    required this.foreground,
    required this.selectedTab,
    required this.softAccent,
    required this.fallbackAvatar,
  });

  final Color headerStart;
  final Color headerEnd;
  final Color foreground;
  final Color selectedTab;
  final Color softAccent;
  final Color fallbackAvatar;
}

abstract final class ClubBrandPaletteResolver {
  static const Map<String, (Color, Color)> _demoPalettes = {
    'garuda': (Color(0xFF5B566E), Color(0xFF11294B)),
    'pb': (Color(0xFFA51D2A), Color(0xFF670A13)),
    'voli': (Color(0xFFF3B51B), Color(0xFF8F6100)),
  };

  static Color? tryParseHex(String? value) {
    if (value == null) return null;
    var digits = value.trim().replaceFirst('#', '');
    if (digits.length == 6) digits = 'FF$digits';
    if (digits.length != 8) return null;
    final parsed = int.tryParse(digits, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static ClubBrandPalette resolve(Club club) {
    final explicitStart = tryParseHex(club.brandPrimaryHex);
    final explicitEnd = tryParseHex(club.brandSecondaryHex);
    final fallback = _demoPalettes[club.id] ?? _sportPalette(club.sport);
    final start = explicitStart ?? fallback.$1;
    final end = explicitEnd ?? _darken(start, 0.24);
    final safePair = _ensureHeaderPair(start, end);
    final selectedTab = _ensureContrast(safePair.$2, safePair.$3);
    return ClubBrandPalette(
      headerStart: safePair.$1,
      headerEnd: safePair.$2,
      foreground: safePair.$3,
      selectedTab: selectedTab,
      softAccent: Color.alphaBlend(safePair.$1.withValues(alpha: .12), Colors.white),
      fallbackAvatar: Color.alphaBlend(safePair.$3.withValues(alpha: .16), safePair.$1),
    );
  }
}
```

Implement the private helpers in the same file with the following behavior:

```dart
static (Color, Color) _sportPalette(String sport) => switch (sport) {
  'Sepak Bola' => (const Color(0xFF315A91), const Color(0xFF17345C)),
  'Bulu Tangkis' => (const Color(0xFF51478A), const Color(0xFF2F285D)),
  'Pencak Silat' => (const Color(0xFFA23A2B), const Color(0xFF642117)),
  'Voli' => (const Color(0xFFC88B08), const Color(0xFF795000)),
  'Renang' => (const Color(0xFF168A91), const Color(0xFF07555E)),
  _ => (KokColors.blue, KokColors.navy),
};

static Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

static Color _lighten(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

static double _contrastRatio(Color a, Color b) {
  final aLum = a.computeLuminance();
  final bLum = b.computeLuminance();
  final lighter = aLum > bLum ? aLum : bLum;
  final darker = aLum > bLum ? bLum : aLum;
  return (lighter + 0.05) / (darker + 0.05);
}

static (Color, Color, Color) _ensureHeaderPair(Color start, Color end) {
  const darkInk = Color(0xFF17191D);
  double minimum(Color foreground) => [
    _contrastRatio(foreground, start),
    _contrastRatio(foreground, end),
  ].reduce((a, b) => a < b ? a : b);

  final whiteMinimum = minimum(Colors.white);
  final darkMinimum = minimum(darkInk);
  if (whiteMinimum >= 4.5 || darkMinimum >= 4.5) {
    return whiteMinimum >= darkMinimum
        ? (start, end, Colors.white)
        : (start, end, darkInk);
  }

  var safeStart = start;
  var safeEnd = end;
  for (var i = 0; i < 12; i++) {
    safeStart = _darken(safeStart, 0.035);
    safeEnd = _darken(safeEnd, 0.035);
    if (_contrastRatio(Colors.white, safeStart) >= 4.5 &&
        _contrastRatio(Colors.white, safeEnd) >= 4.5) {
      break;
    }
  }
  return (safeStart, safeEnd, Colors.white);
}

static Color _ensureContrast(Color background, Color foreground) {
  var result = background;
  for (var i = 0; i < 12 && _contrastRatio(result, foreground) < 4.5; i++) {
    result = foreground == Colors.white
        ? _darken(result, 0.035)
        : _lighten(result, 0.035);
  }
  return result;
}
```

Tests must prove the single `foreground` reaches 4.5 against `headerStart`, `headerEnd`, and `selectedTab`, preventing amber from being readable at the bottom but illegible at the top.

- [ ] **Step 4: Run resolver tests**

Run:

```powershell
flutter test test/club_brand_palette_test.dart
```

Expected: PASS for parsing, precedence, distinct palettes, and contrast.

- [ ] **Step 5: Run static analysis for the new file**

Run:

```powershell
flutter analyze lib/features/club_detail/club_brand_palette.dart
```

Expected: No issues found.

- [ ] **Step 6: Commit the resolver**

```powershell
git add lib/features/club_detail/club_brand_palette.dart test/club_brand_palette_test.dart
git commit -m "feat(club-detail): add safe club brand palette resolver"
```

---

### Task 3: Add Demo Branding Data and Pure People Filtering

**Files:**
- Modify: `lib/data/repository.dart`
- Create: `lib/features/club_detail/club_people_filter.dart`
- Create: `test/club_people_filter_test.dart`
- Modify: `test/repository_test.dart`

**Interfaces:**
- Consumes: optional model fields from Task 1.
- Produces: `enum ClubPeopleStatusFilter { all, complete, needsAttention }`.
- Produces: `bool personNeedsAttention(SportPerson person)`.
- Produces: `List<SportPerson> filterClubPeople(List<SportPerson> people, {String query, String? group, ClubPeopleStatusFilter status})`.
- Produces: demo colors for club IDs `garuda`, `pb`, and `voli` without relying on network images.

- [ ] **Step 1: Write failing pure filter tests**

Create `test/club_people_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_people_filter.dart';

const people = [
  SportPerson(id: '1', name: 'Alya Putri', clubId: 'c', role: 'Atlet', group: 'U-18', gender: 'P', age: 17),
  SportPerson(id: '2', name: 'Bima Putra', clubId: 'c', role: 'Atlet', group: 'U-16', missingDocuments: ['Kartu Keluarga']),
  SportPerson(id: '3', name: 'Coach Dedi', clubId: 'c', role: 'Pelatih', group: 'Lisensi C', expiredLicense: true),
];

void main() {
  test('filters case-insensitive query and group together', () {
    final result = filterClubPeople(people, query: 'alya', group: 'U-18');
    expect(result.map((p) => p.id), ['1']);
  });

  test('needsAttention includes missing documents, expired license, and unverified', () {
    final result = filterClubPeople(
      people,
      status: ClubPeopleStatusFilter.needsAttention,
    );
    expect(result.map((p) => p.id), ['2', '3']);
  });

  test('complete excludes every attention condition', () {
    final result = filterClubPeople(
      people,
      status: ClubPeopleStatusFilter.complete,
    );
    expect(result.map((p) => p.id), ['1']);
  });
}
```

- [ ] **Step 2: Add failing repository assertions for demo branding**

Extend `test/repository_test.dart` with:

```dart
test('demo repository exposes distinct club branding without network logos', () async {
  final data = await DemoKokRepository().fetch();
  final clubs = {for (final club in data.clubs) club.id: club};
  expect(clubs['garuda']!.brandPrimaryHex, isNotNull);
  expect(clubs['pb']!.brandPrimaryHex, isNot(clubs['garuda']!.brandPrimaryHex));
  expect(clubs['voli']!.brandPrimaryHex, isNot(clubs['pb']!.brandPrimaryHex));
  expect(clubs['garuda']!.logoUrl, isNull);
});
```

- [ ] **Step 3: Run focused tests and verify failure**

Run:

```powershell
flutter test test/club_people_filter_test.dart test/repository_test.dart
```

Expected: FAIL because the filter file and demo colors do not exist.

- [ ] **Step 4: Implement pure filtering**

Create `club_people_filter.dart`:

```dart
import '../../data/models.dart';

enum ClubPeopleStatusFilter { all, complete, needsAttention }

bool personNeedsAttention(SportPerson person) =>
    person.missingDocuments.isNotEmpty ||
    person.expiredLicense ||
    !person.verified;

List<SportPerson> filterClubPeople(
  List<SportPerson> people, {
  String query = '',
  String? group,
  ClubPeopleStatusFilter status = ClubPeopleStatusFilter.all,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return people.where((person) {
    final matchesQuery = normalizedQuery.isEmpty ||
        person.name.toLowerCase().contains(normalizedQuery);
    final matchesGroup = group == null || person.group == group;
    final needsAttention = personNeedsAttention(person);
    final matchesStatus = switch (status) {
      ClubPeopleStatusFilter.all => true,
      ClubPeopleStatusFilter.complete => !needsAttention,
      ClubPeopleStatusFilter.needsAttention => needsAttention,
    };
    return matchesQuery && matchesGroup && matchesStatus;
  }).toList(growable: false);
}
```

- [ ] **Step 5: Populate safe demo fields**

Update only the existing demo records in `DemoKokRepository`:

```dart
Club(
  id: 'garuda',
  name: 'Klub Garuda Muda',
  sport: 'Sepak Bola',
  village: 'Pakuwon',
  brandPrimaryHex: '#5B566E',
  brandSecondaryHex: '#11294B',
),
Club(
  id: 'pb',
  name: 'PB Citra Garut',
  sport: 'Bulu Tangkis',
  village: 'Paminggir',
  brandPrimaryHex: '#A51D2A',
  brandSecondaryHex: '#670A13',
),
Club(
  id: 'voli',
  name: 'Voli Bina Muda',
  sport: 'Voli',
  village: 'Pakuwon',
  brandPrimaryHex: '#F3B51B',
  brandSecondaryHex: '#8F6100',
),
```

Do not add fake `logoUrl`, `registrationNumber`, or `foundedYear`. While generating demo athletes, set deterministic optional metadata without changing existing document rules:

```dart
gender: i.isEven ? 'L' : 'P',
age: 15 + (i % 4),
```

- [ ] **Step 6: Run focused tests**

Run:

```powershell
flutter test test/club_people_filter_test.dart test/repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit filtering and demo data**

```powershell
git add lib/data/repository.dart lib/features/club_detail/club_people_filter.dart test/club_people_filter_test.dart test/repository_test.dart
git commit -m "feat(club-detail): add role filters and demo club branding"
```

---

### Task 4: Build the Branded Header and Segmented Tabs

**Files:**
- Create: `lib/features/club_detail/club_detail_header.dart`
- Create: `lib/features/club_detail/club_detail_tabs.dart`
- Create: `test/club_detail_widgets_test.dart`

**Interfaces:**
- Consumes: `ClubBrandPalette`, `Club`, counts, callbacks.
- Produces: `ClubDetailHeader` with explicit counts and missing-file count.
- Produces: `ClubDetailTabBar` whose labels are exactly `Atlet`, `Pelatih`, `Official`, `Dokumen`.
- `ClubDetailHeader` remains a presentation widget; it does not read providers or navigate directly.

- [ ] **Step 1: Write failing header and tab widget tests**

Start `test/club_detail_widgets_test.dart` with helpers and two tests:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';
import 'package:kok_app/features/club_detail/club_detail_header.dart';
import 'package:kok_app/features/club_detail/club_detail_tabs.dart';

const testClub = Club(
  id: 'garuda',
  name: 'Klub Garuda Muda',
  sport: 'Sepak Bola',
  village: 'Pakuwon',
);

Widget app(Widget child) => MaterialApp(
  home: DefaultTabController(length: 4, child: Scaffold(body: child)),
);

void main() {
  testWidgets('header renders fallback identity, status, issues and counts', (tester) async {
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(app(ClubDetailHeader(
      club: testClub,
      palette: palette,
      athleteCount: 34,
      coachCount: 3,
      officialCount: 2,
      missingFileCount: 8,
      onBack: () {},
      onShare: () {},
    )));
    expect(find.text('Klub Garuda Muda'), findsOneWidget);
    expect(find.text('8 berkas kurang'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('ATLET'), findsOneWidget);
    expect(find.bySemanticsLabel('Logo fallback Klub Garuda Muda'), findsOneWidget);
  });

  testWidgets('segmented tabs expose all four labels', (tester) async {
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(app(ClubDetailTabBar(palette: palette)));
    for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Run widget tests and confirm missing components**

Run:

```powershell
flutter test test/club_detail_widgets_test.dart
```

Expected: FAIL because header and tab files are absent.

- [ ] **Step 3: Implement `ClubDetailHeader`**

The constructor must be:

```dart
const ClubDetailHeader({
  super.key,
  required this.club,
  required this.palette,
  required this.athleteCount,
  required this.coachCount,
  required this.officialCount,
  required this.missingFileCount,
  required this.onBack,
  required this.onShare,
});
```

Build a `DecoratedBox` with `LinearGradient(colors: [palette.headerStart, palette.headerEnd])`, safe horizontal padding of 24 px, and these vertical regions. The back button semantic label is `Kembali`; the share button semantic label is `Bagikan info klub`:

1. A 48 px actions row containing `IconButton` back/share with tooltips and semantic labels.
2. An 88 px logo region. Use `Image.network` only when `club.logoUrl` is non-empty; its `errorBuilder` returns the same fallback widget used when URL is absent.
3. Centered identity text with two metadata lines. The first is `${club.sport} · ${club.foundedYear == null ? 'tahun berdiri belum tersedia' : 'berdiri ${club.foundedYear}'}`. The second is `${club.registrationNumber ?? 'SK belum tersedia'} · Kel. ${club.village}`. These strings explicitly communicate missing demo data and never invent an official value.
4. Status and missing-file badges in a centered `Wrap` so 320 px cannot overflow.
5. A three-column statistics row using an internal `_StatColumn` and two vertical dividers.

The fallback logo semantics label must be `Logo fallback ${club.name}` and its visible content must be the sport icon from `sportIcon(club.sport)`; do not crop logos from the screenshots.

- [ ] **Step 4: Implement `ClubDetailTabBar`**

Build a white rounded container with `TabBar`, no divider, four equal tabs, and a rounded indicator:

```dart
class ClubDetailTabBar extends StatelessWidget {
  const ClubDetailTabBar({super.key, required this.palette});
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x14071B68), blurRadius: 14, offset: Offset(0, 5))],
    ),
    child: TabBar(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: palette.selectedTab,
        borderRadius: BorderRadius.circular(14),
      ),
      labelColor: palette.foreground,
      unselectedLabelColor: const Color(0xFF666A73),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      tabs: const [Tab(text: 'Atlet'), Tab(text: 'Pelatih'), Tab(text: 'Official'), Tab(text: 'Dokumen')],
    ),
  );
}
```

- [ ] **Step 5: Run the widget tests at 390 px and 320 px**

Add these responsive and failed-image cases:

```dart
testWidgets('header and tabs fit 320px with long missing metadata', (tester) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final longClub = testClub.copyWith(
    name: 'Klub Garuda Muda Kecamatan Garut Kota Bersatu',
    foundedYear: null,
    registrationNumber: null,
  );
  final palette = ClubBrandPaletteResolver.resolve(longClub);
  await tester.pumpWidget(app(SingleChildScrollView(
    child: Column(children: [
      ClubDetailHeader(
        club: longClub,
        palette: palette,
        athleteCount: 34,
        coachCount: 3,
        officialCount: 2,
        missingFileCount: 8,
        onBack: () {},
        onShare: () {},
      ),
      ClubDetailTabBar(palette: palette),
    ]),
  )));
  expect(find.textContaining('tahun berdiri belum tersedia'), findsOneWidget);
  expect(find.textContaining('SK belum tersedia'), findsOneWidget);
  expect(tester.takeException(), isNull);
});

testWidgets('failed network logo falls back without an exception', (tester) async {
  final club = testClub.copyWith(logoUrl: 'https://invalid.test/logo.png');
  final palette = ClubBrandPaletteResolver.resolve(club);
  await tester.pumpWidget(app(ClubDetailHeader(
    club: club,
    palette: palette,
    athleteCount: 1,
    coachCount: 0,
    officialCount: 0,
    missingFileCount: 0,
    onBack: () {},
    onShare: () {},
  )));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Logo fallback Klub Garuda Muda'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

Then run:

```powershell
flutter test test/club_detail_widgets_test.dart
```

Expected: PASS with no overflow exception.

- [ ] **Step 6: Commit header and tabs**

```powershell
git add lib/features/club_detail/club_detail_header.dart lib/features/club_detail/club_detail_tabs.dart test/club_detail_widgets_test.dart
git commit -m "feat(club-detail): build branded hero and segmented tabs"
```

---

### Task 5: Build Role-Aware Person Cards and Filtered People Tabs

**Files:**
- Create: `lib/features/club_detail/club_person_card.dart`
- Create: `lib/features/club_detail/club_people_tab.dart`
- Modify: `test/club_detail_widgets_test.dart`

**Interfaces:**
- Consumes: `filterClubPeople`, `personNeedsAttention`, `ClubBrandPalette`, and `SportPerson`.
- Produces: `ClubPersonCard({required SportPerson person, required ClubBrandPalette palette, required VoidCallback onTap})`.
- Produces: `ClubPeopleTab({required String role, required List<SportPerson> people, required ClubBrandPalette palette, required ValueChanged<SportPerson> onPersonTap})`.
- Each `ClubPeopleTab` owns independent query/group/status state and preserves it while its tab remains mounted.
- `ClubPeopleTab` defensively filters `people` by its own `role`, even though the page normally passes a role-specific list.

- [ ] **Step 1: Add failing card presentation tests**

Append to `test/club_detail_widgets_test.dart`:

```dart
testWidgets('person card hides unavailable metadata and shows document warning', (tester) async {
  const person = SportPerson(
    id: 'a1',
    name: 'Alya Putri',
    clubId: 'garuda',
    role: 'Atlet',
    group: 'U-18',
    missingDocuments: ['Kartu Keluarga'],
  );
  final palette = ClubBrandPaletteResolver.resolve(testClub);
  await tester.pumpWidget(app(ClubPersonCard(person: person, palette: palette, onTap: () {})));
  expect(find.text('Alya Putri'), findsOneWidget);
  expect(find.text('U-18'), findsOneWidget);
  expect(find.text('berkas'), findsOneWidget);
  expect(find.textContaining('null'), findsNothing);
});
```

- [ ] **Step 2: Add failing filter-sheet behavior tests**

Append this concrete interaction test:

```dart
testWidgets('people tab applies and resets role-specific filters', (tester) async {
  const people = [
    SportPerson(id: '1', name: 'Alya Putri', clubId: 'garuda', role: 'Atlet', group: 'U-18'),
    SportPerson(id: '2', name: 'Bima Putra', clubId: 'garuda', role: 'Atlet', group: 'U-16'),
    SportPerson(id: '3', name: 'Coach Dedi', clubId: 'garuda', role: 'Pelatih', group: 'Lisensi C'),
  ];
  final palette = ClubBrandPaletteResolver.resolve(testClub);
  await tester.pumpWidget(app(ClubPeopleTab(
    role: 'Atlet',
    people: people,
    palette: palette,
    onPersonTap: (_) {},
  )));

  expect(find.text('Alya Putri'), findsOneWidget);
  expect(find.text('Bima Putra'), findsOneWidget);
  expect(find.text('Coach Dedi'), findsNothing);

  await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('club-filter-query')), 'alya');
  await tester.tap(find.byKey(const ValueKey('club-filter-group')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('U-18').last);
  await tester.tap(find.text('Terapkan'));
  await tester.pumpAndSettle();

  expect(find.text('Alya Putri'), findsOneWidget);
  expect(find.text('Bima Putra'), findsNothing);

  await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reset'));
  await tester.pumpAndSettle();
  expect(find.text('Alya Putri'), findsOneWidget);
  expect(find.text('Bima Putra'), findsOneWidget);
});
```

- [ ] **Step 3: Run the widget tests and verify the missing widgets fail**

Run:

```powershell
flutter test test/club_detail_widgets_test.dart
```

Expected: FAIL because `ClubPersonCard` and `ClubPeopleTab` do not exist.

- [ ] **Step 4: Implement `ClubPersonCard`**

Use `Material` + `InkWell` with an 18 px radius and minimum vertical extent of 88 px. The leading media uses `Image.network` only for a non-empty `photoUrl`, otherwise a circle with initials. Build metadata without empty separators:

```dart
final metadata = <String>[
  if (person.gender case final value?) value,
  if (person.age case final value?) '$value th',
  if (person.group.trim().isNotEmpty) person.group,
];
```

The trailing state is:

```dart
if (personNeedsAttention(person))
  const _IssueBadge(label: 'berkas')
else
  DecoratedBox(
    decoration: BoxDecoration(color: palette.softAccent, shape: BoxShape.circle),
    child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.check_rounded, size: 20)),
  )
```

For Pelatih with `expiredLicense == true`, use label `lisensi`; for an unverified Official use label `verifikasi`. Preserve red as the issue color in every branch.

- [ ] **Step 5: Implement `ClubPeopleTab` and its filter sheet**

Use `StatefulWidget` with `AutomaticKeepAliveClientMixin`. State fields are:

```dart
String _query = '';
String? _group;
ClubPeopleStatusFilter _status = ClubPeopleStatusFilter.all;
```

The body must be a `ListView` suitable for `NestedScrollView`. Its first row contains `${filtered.length} ${role.toLowerCase()}` and a `TextButton.icon` labeled `Filter`. The bottom sheet uses local draft values; dismissing the sheet must not apply changes. `Terapkan` copies drafts into the tab state and closes the sheet. `Reset` clears both draft and committed filters, then closes the sheet.

Begin `build` by creating `rolePeople = widget.people.where((person) => person.role == widget.role).toList(growable: false)` and pass that list to `filterClubPeople`. Group options must be computed from `rolePeople.map((p) => p.group).toSet()` and sorted. Status options map to `Semua`, `Lengkap`, and `Perlu perhatian`. Give the filter trigger `ValueKey('club-people-filter-${widget.role}')`, the query field `ValueKey('club-filter-query')`, and the group dropdown `ValueKey('club-filter-group')`. Use an `InputDecoration(labelText: 'Cari nama')` rather than relying on hint text alone.

At the bottom, render the exact note:

```text
Data milik SICABOR. Perubahan diajukan lewat pengurus klub — aplikasi ini tidak menyunting.
```

- [ ] **Step 6: Run focused widget and filter tests**

Run:

```powershell
flutter test test/club_people_filter_test.dart test/club_detail_widgets_test.dart
```

Expected: PASS, including filter/reset and missing metadata behavior.

- [ ] **Step 7: Commit cards and people tabs**

```powershell
git add lib/features/club_detail/club_person_card.dart lib/features/club_detail/club_people_tab.dart test/club_detail_widgets_test.dart
git commit -m "feat(club-detail): add filtered role-aware member tabs"
```

---

### Task 6: Compose the Four-Tab Detail Page and Route Integration

**Files:**
- Create: `lib/features/club_detail/club_document_tab.dart`
- Create: `lib/features/club_detail/club_detail_page.dart`
- Modify: `lib/features/detail_pages.dart`
- Modify: `lib/app.dart`
- Modify: `test/app_test.dart`

**Interfaces:**
- Consumes: every component from Tasks 2–5, `snapshotProvider`, `clubPeople`, GoRouter, and Flutter Clipboard.
- Produces: public `ClubDetailPage({required String id})` at `features/club_detail/club_detail_page.dart`.
- Keeps route `/club/:id` unchanged.
- Produces: `ClubDocumentTab({required Club club})`.

- [ ] **Step 1: Write failing route-level tests for the four tabs**

Add a new test to `test/app_test.dart` that signs in, navigates to `/club/garuda`, and verifies:

```dart
expect(find.text('Klub Garuda Muda'), findsOneWidget);
for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
  expect(find.text(label), findsOneWidget);
}

await tester.tap(find.text('Pelatih'));
await tester.pumpAndSettle();
expect(find.textContaining('Pelatih 1'), findsWidgets);

await tester.tap(find.text('Official'));
await tester.pumpAndSettle();
expect(find.textContaining('Official'), findsWidgets);

await tester.tap(find.text('Dokumen'));
await tester.pumpAndSettle();
expect(find.text('SK Klub'), findsOneWidget);
expect(find.text('Kepengurusan'), findsOneWidget);
```

- [ ] **Step 2: Add failing share and navigation assertions**

In the same test, capture the clipboard method call and verify navigation with this sequence:

```dart
String? copiedText;
tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
  SystemChannels.platform,
  (call) async {
    if (call.method == 'Clipboard.setData') {
      copiedText = (call.arguments as Map<Object?, Object?>)['text'] as String?;
    }
    return null;
  },
);
addTearDown(() {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    null,
  );
});

await tester.tap(find.bySemanticsLabel('Bagikan info klub'));
await tester.pumpAndSettle();
expect(copiedText, contains('Klub Garuda Muda'));
expect(find.text('Info klub disalin'), findsOneWidget);

await tester.tap(find.text('Atlet'));
await tester.pumpAndSettle();
await tester.tap(find.textContaining('Atlet 1').first);
await tester.pumpAndSettle();
expect(find.text('Detail Atlet'), findsOneWidget);
```

- [ ] **Step 3: Run the route test and verify old UI fails**

Run:

```powershell
flutter test test/app_test.dart --plain-name "Club detail renders four polished tabs and share action"
```

Expected: FAIL because the polished page, share action, and document tab do not exist.

- [ ] **Step 4: Implement the read-only document tab**

Create `club_document_tab.dart`. It accepts a `Club` and renders a `ListView` with two white rounded cards:

```dart
ClubDocumentTab(club: club)
```

- `SK Klub`: `Tersedia` only when `club.registrationNumber` is non-empty; show its exact value as metadata.
- `Kepengurusan`: `Belum tersedia` because the current repository contract has no club-management document.
- Available state uses green; unavailable state uses muted gray, not a club color.
- The SICABOR ownership note appears at the bottom.
- There are no upload, edit, open-file, or download callbacks.

- [ ] **Step 5: Implement `ClubDetailPage` composition**

Create `club_detail_page.dart` with this high-level structure:

```dart
class ClubDetailPage extends StatelessWidget {
  const ClubDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => DataView(
    builder: (data) {
      final matches = data.clubs.where((club) => club.id == id);
      if (matches.isEmpty) return const MissingPage();
      final club = matches.first;
      final allPeople = clubPeople(data, id);
      final athletes = allPeople.where((p) => p.role == 'Atlet').toList();
      final coaches = allPeople.where((p) => p.role == 'Pelatih').toList();
      final officials = allPeople.where((p) => p.role == 'Official').toList();
      final missingCount = allPeople.where(personNeedsAttention).length;
      final palette = ClubBrandPaletteResolver.resolve(club);

      return DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: true,
                expandedHeight: 500,
                toolbarHeight: 64,
                backgroundColor: palette.headerEnd,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final titleOpacity =
                        ((500 - constraints.biggest.height) / 290).clamp(0.0, 1.0);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          background: ClubDetailHeader(
                            club: club,
                            palette: palette,
                            athleteCount: athletes.length,
                            coachCount: coaches.length,
                            officialCount: officials.length,
                            missingFileCount: missingCount,
                            onBack: () => context.pop(),
                            onShare: () => _shareClub(context, club),
                          ),
                        ),
                        IgnorePointer(
                          child: Opacity(
                            opacity: titleOpacity,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(64, 20, 64, 0),
                                child: Text(
                                  club.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(88),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: ClubDetailTabBar(palette: palette),
                  ),
                ),
              ),
            ],
            body: TabBarView(children: [
              ClubPeopleTab(role: 'Atlet', people: athletes, palette: palette, onPersonTap: (p) => context.push('/person/${p.id}')),
              ClubPeopleTab(role: 'Pelatih', people: coaches, palette: palette, onPersonTap: (p) => context.push('/person/${p.id}')),
              ClubPeopleTab(role: 'Official', people: officials, palette: palette, onPersonTap: (p) => context.push('/person/${p.id}')),
              ClubDocumentTab(club: club),
            ]),
          ),
        ),
      );
    },
  );
}
```

Keep the `ClubDetailHeader` content above the 88 px tab panel by giving its root bottom padding of at least 100 px. `FlexibleSpaceBar` clips/parallaxes the expanded header while the sliver collapses so its internal column is never relaid out at the collapsed height. The continuous opacity in the snippet is the only collapsed-title state; do not add a separate scroll listener.

Implement the share helper exactly as an internal async method:

```dart
Future<void> _shareClub(BuildContext context, Club club) async {
  await Clipboard.setData(
    ClipboardData(text: '${club.name} · ${club.sport} · Kel. ${club.village}'),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Info klub disalin')),
  );
}
```

- [ ] **Step 6: Move the public page and update imports**

Remove `ClubDetailPage`, `_PeopleList`, `_PeopleListState`, and the old `PersonTile` from `lib/features/detail_pages.dart` because they become unreachable after the new people tabs are integrated and would trigger unused-element analysis. Keep `PersonDetailPage` and `MissingPage`, and remove any imports made unused by the deletion. Import `features/club_detail/club_detail_page.dart` in `lib/app.dart`. The existing route remains:

```dart
GoRoute(
  path: '/club/:id',
  builder: (_, s) => ClubDetailPage(id: s.pathParameters['id']!),
),
```

- [ ] **Step 7: Run route and existing app tests**

Run:

```powershell
flutter test test/app_test.dart test/club_detail_widgets_test.dart
```

Expected: PASS. Update old assertions that expected `Detail Klub` only when they conflict with the approved hero copy; keep navigation coverage intact.

- [ ] **Step 8: Commit complete page integration**

```powershell
git add lib/app.dart lib/features/detail_pages.dart lib/features/club_detail/club_detail_page.dart lib/features/club_detail/club_document_tab.dart test/app_test.dart
git commit -m "feat(club-detail): integrate polished four-tab club page"
```

---

### Task 7: Responsive Regression Coverage and Golden Visual Verification

**Files:**
- Modify: `test/app_test.dart`
- Modify: `test/preview_test.dart`
- Modify: `previews/detail-klub.png`
- Create: `previews/detail-klub-pb.png`
- Create: `previews/detail-klub-voli.png`
- Modify implementation files from Tasks 2–6 only when visual verification reveals a specific defect.

**Interfaces:**
- Consumes: final `/club/:id` route and demo IDs `garuda`, `pb`, `voli`.
- Produces: regression coverage for layout at 320 px and three palette golden files.

- [ ] **Step 1: Strengthen the 320 px regression test**

In the existing `320px layout, search, missing routes and all major screens` test, after navigating to `/club/garuda`, tap each tab and call `pumpAndSettle`. Assert `tester.takeException()` is null after every tab. Add a focused text-scale test using the test platform dispatcher so the existing `start` helper and provider overrides remain unchanged:

```dart
testWidgets('club detail supports 1.3 text scale without overflow', (tester) async {
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = await start(tester, width: 320);
  await container.read(sessionProvider.notifier).signIn('DEMO-001', 'kokgarut123', false);
  container.read(routerProvider).go('/club/garuda');
  await tester.pumpAndSettle();
  for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: label);
  }
});
```

- [ ] **Step 2: Add three explicit golden routes**

Update the route map in `test/preview_test.dart` so it includes:

```dart
'detail-klub': '/club/garuda',
'detail-klub-pb': '/club/pb',
'detail-klub-voli': '/club/voli',
```

Keep every existing golden route.

- [ ] **Step 3: Run analysis before generating images**

Run:

```powershell
flutter analyze
```

Expected: No issues found.

- [ ] **Step 4: Run the complete test suite**

Run:

```powershell
flutter test
```

Expected: All tests passed.

- [ ] **Step 5: Generate updated golden previews**

Run:

```powershell
flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true
```

Expected: PASS and all three detail-club PNG files exist.

- [ ] **Step 6: Inspect every generated detail preview**

Open these files with the available local image viewer:

```text
previews/detail-klub.png
previews/detail-klub-pb.png
previews/detail-klub-voli.png
```

Compare them with the three `ui-screenshot-figma/detail-klub-*-atlet.png` references. Check, one by one:

- header and panel hierarchy;
- name and metadata legibility;
- distinct purple/navy, red, and amber palettes;
- amber foreground contrast;
- four tab labels without clipping;
- first list card visible at 390×844;
- no doubled safe-area padding;
- no image/fallback layout jump.

If a defect is found, write or tighten a widget assertion that exposes it, make the smallest implementation correction, rerun the focused test, and regenerate the affected golden.

- [ ] **Step 7: Run final verification after visual corrections**

Run:

```powershell
flutter analyze
flutter test
git diff --check
```

Expected: analysis clean, all tests pass, and no whitespace errors.

- [ ] **Step 8: Commit responsive tests and golden previews**

```powershell
git add test/app_test.dart test/preview_test.dart previews/detail-klub.png previews/detail-klub-pb.png previews/detail-klub-voli.png lib/features/club_detail
git commit -m "test: add responsive and golden coverage for club detail"
```

---

## Final Acceptance Checklist

- [ ] The existing club-detail route remains `/club/:id`.
- [ ] The hero uses a local club palette and does not mutate the global theme.
- [ ] Explicit colors override demo colors; invalid values fall back safely.
- [ ] Bright palettes meet a minimum 4.5 contrast for primary header/tab text.
- [ ] No network logo or photo is required for a complete layout.
- [ ] Atlet, Pelatih, Official, and Dokumen all render meaningful read-only content.
- [ ] Search and filter state is isolated per people tab.
- [ ] Status red/green semantics do not change with club branding.
- [ ] Share copies a deterministic club summary without a new dependency.
- [ ] 320 px and 390 px layouts are free of overflow.
- [ ] Three palette variants have visually reviewed golden previews.
- [ ] `flutter analyze`, `flutter test`, and `git diff --check` pass.

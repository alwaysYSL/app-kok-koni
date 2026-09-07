import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';
import 'package:kok_app/features/club_detail/club_detail_header.dart';
import 'package:kok_app/features/club_detail/club_detail_tabs.dart';
import 'package:kok_app/features/club_detail/club_people_tab.dart';
import 'package:kok_app/features/club_detail/club_person_card.dart';
import 'package:kok_app/features/dashboard_decorations.dart';

const testClub = Club(
  id: 'garuda',
  name: 'Klub Garuda Muda',
  sport: 'Sepak Bola',
  village: 'Pakuwon',
);

Widget app(Widget child) => MaterialApp(
  theme: kokTheme(),
  home: DefaultTabController(length: 4, child: Scaffold(body: child)),
);

Container badgeContainer(WidgetTester tester, String label) =>
    tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.child is Text &&
            (widget.child! as Text).data == label,
      ),
    );

void main() {
  setUpAll(() async {
    final font = FontLoader('KokSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });

  testWidgets('header renders fallback identity, status, issues and counts', (
    tester,
  ) async {
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(
      app(
        ClubDetailHeader(
          club: testClub,
          palette: palette,
          athleteCount: 34,
          coachCount: 3,
          officialCount: 2,
          missingFileCount: 8,
          onBack: () {},
          onShare: () {},
        ),
      ),
    );
    expect(find.text('Klub Garuda Muda'), findsOneWidget);
    expect(find.text('8 berkas kurang'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('ATLET'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Logo fallback Klub Garuda Muda'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is BrandHeaderPatternPainter,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
      findsOneWidget,
    );
    final backIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
    expect(backIcon.size, 28);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      findsOneWidget,
    );
  });

  testWidgets('segmented tabs expose all four labels', (tester) async {
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(app(ClubDetailTabBar(palette: palette)));
    for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'segmented tabs fully render every label at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final palette = ClubBrandPaletteResolver.resolve(testClub);

        await tester.pumpWidget(app(ClubDetailTabBar(palette: palette)));

        for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '$label must not fade at ${width.toInt()}px',
          );
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + 0.01),
            reason: '$label must fit its tab at ${width.toInt()}px',
          );
        }
      },
    );
  }

  testWidgets('header and tabs fit 320px with long missing metadata', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          child: Column(
            children: [
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
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('tahun berdiri belum tersedia'), findsOneWidget);
    expect(find.textContaining('SK belum tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed network logo falls back without an exception', (
    tester,
  ) async {
    final club = testClub.copyWith(logoUrl: 'https://invalid.test/logo.png');
    final palette = ClubBrandPaletteResolver.resolve(club);
    await tester.pumpWidget(
      app(
        ClubDetailHeader(
          club: club,
          palette: palette,
          athleteCount: 1,
          coachCount: 0,
          officialCount: 0,
          missingFileCount: 0,
          onBack: () {},
          onShare: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Logo fallback Klub Garuda Muda'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive club status uses neutral badge colors', (tester) async {
    final club = testClub.copyWith(active: false);
    final palette = ClubBrandPaletteResolver.resolve(club);
    await tester.pumpWidget(
      app(
        ClubDetailHeader(
          club: club,
          palette: palette,
          athleteCount: 0,
          coachCount: 0,
          officialCount: 0,
          missingFileCount: 0,
          onBack: () {},
          onShare: () {},
        ),
      ),
    );

    final badge = badgeContainer(tester, 'TIDAK AKTIF');
    expect((badge.decoration! as BoxDecoration).color, const Color(0xFFE9ECF2));
    expect(
      tester.widget<Text>(find.text('TIDAK AKTIF')).style!.color,
      const Color(0xFF4B5563),
    );
  });

  testWidgets('zero missing files omits the problem badge', (tester) async {
    final club = testClub.copyWith(active: false);
    final palette = ClubBrandPaletteResolver.resolve(club);
    await tester.pumpWidget(
      app(
        ClubDetailHeader(
          club: club,
          palette: palette,
          athleteCount: 0,
          coachCount: 0,
          officialCount: 0,
          missingFileCount: 0,
          onBack: () {},
          onShare: () {},
        ),
      ),
    );

    expect(find.text('0 berkas kurang'), findsNothing);
  });

  testWidgets(
    'person card hides unavailable metadata and shows document warning',
    (tester) async {
      const person = SportPerson(
        id: 'a1',
        name: 'Alya Putri',
        clubId: 'garuda',
        role: 'Atlet',
        group: 'U-18',
        missingDocuments: ['Kartu Keluarga'],
      );
      final palette = ClubBrandPaletteResolver.resolve(testClub);
      await tester.pumpWidget(
        app(ClubPersonCard(person: person, palette: palette, onTap: () {})),
      );
      expect(find.text('Alya Putri'), findsOneWidget);
      expect(find.text('U-18'), findsOneWidget);
      expect(find.text('berkas'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    },
  );

  testWidgets('person card uses role-specific warnings and callback', (
    tester,
  ) async {
    var selected = false;
    const coach = SportPerson(
      id: 'p1',
      name: 'Coach Dedi',
      clubId: 'garuda',
      role: 'Pelatih',
      group: 'Lisensi C',
      expiredLicense: true,
    );
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(
      app(
        ClubPersonCard(
          person: coach,
          palette: palette,
          onTap: () => selected = true,
        ),
      ),
    );

    expect(find.text('lisensi'), findsOneWidget);
    await tester.tap(find.text('Coach Dedi'));
    expect(selected, isTrue);

    await tester.pumpWidget(
      app(
        ClubPersonCard(
          person: coach.copyWith(
            id: 'o1',
            name: 'Official Rani',
            role: 'Official',
            expiredLicense: false,
            verified: false,
          ),
          palette: palette,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('verifikasi'), findsOneWidget);
  });

  testWidgets('complete person state stays green for a red club', (
    tester,
  ) async {
    const person = SportPerson(
      id: 'a1',
      name: 'Alya Putri',
      clubId: 'pb',
      role: 'Atlet',
      group: 'U-18',
    );
    final palette = ClubBrandPaletteResolver.resolve(
      testClub.copyWith(id: 'pb'),
    );
    await tester.pumpWidget(
      app(ClubPersonCard(person: person, palette: palette, onTap: () {})),
    );

    final completeIcon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    final completeDecoration = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.byIcon(Icons.check_rounded),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (completeDecoration.decoration as BoxDecoration).color,
      const Color(0xFFDDF6E6),
    );
    expect(completeIcon.color, const Color(0xFF176B38));
  });

  testWidgets('people tab applies and resets role-specific filters', (
    tester,
  ) async {
    const people = [
      SportPerson(
        id: '1',
        name: 'Alya Putri',
        clubId: 'garuda',
        role: 'Atlet',
        group: 'U-18',
      ),
      SportPerson(
        id: '2',
        name: 'Bima Putra',
        clubId: 'garuda',
        role: 'Atlet',
        group: 'U-16',
      ),
      SportPerson(
        id: '3',
        name: 'Coach Dedi',
        clubId: 'garuda',
        role: 'Pelatih',
        group: 'Lisensi C',
      ),
    ];
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(
      app(
        ClubPeopleTab(
          role: 'Atlet',
          people: people,
          palette: palette,
          onPersonTap: (_) {},
        ),
      ),
    );

    expect(find.text('Alya Putri'), findsOneWidget);
    expect(find.text('Bima Putra'), findsOneWidget);
    expect(find.text('Coach Dedi'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('club-filter-query')),
      'alya',
    );
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

  testWidgets('dismissing filter sheet preserves committed filters', (
    tester,
  ) async {
    const people = [
      SportPerson(
        id: '1',
        name: 'Alya Putri',
        clubId: 'garuda',
        role: 'Atlet',
        group: 'U-18',
      ),
      SportPerson(
        id: '2',
        name: 'Bima Putra',
        clubId: 'garuda',
        role: 'Atlet',
        group: 'U-16',
      ),
    ];
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(
      app(
        ClubPeopleTab(
          role: 'Atlet',
          people: people,
          palette: palette,
          onPersonTap: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('club-filter-query')),
      'alya',
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Alya Putri'), findsOneWidget);
    expect(find.text('Bima Putra'), findsOneWidget);
  });

  testWidgets('people tab clears a committed group removed by refreshed data', (
    tester,
  ) async {
    const alya = SportPerson(
      id: '1',
      name: 'Alya Putri',
      clubId: 'garuda',
      role: 'Atlet',
      group: 'U-18',
    );
    const bima = SportPerson(
      id: '2',
      name: 'Bima Putra',
      clubId: 'garuda',
      role: 'Atlet',
      group: 'U-16',
    );
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    Widget peopleTab(List<SportPerson> people) => app(
      ClubPeopleTab(
        role: 'Atlet',
        people: people,
        palette: palette,
        onPersonTap: (_) {},
      ),
    );

    await tester.pumpWidget(peopleTab(const [alya, bima]));
    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-filter-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U-18').last);
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Bima Putra'), findsNothing);

    await tester.pumpWidget(peopleTab(const [bima]));
    expect(find.text('Bima Putra'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Semua kelompok'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('open filter sheet cannot restore a group removed by refresh', (
    tester,
  ) async {
    const alya = SportPerson(
      id: '1',
      name: 'Alya Putri',
      clubId: 'garuda',
      role: 'Atlet',
      group: 'U-18',
    );
    const bima = SportPerson(
      id: '2',
      name: 'Bima Putra',
      clubId: 'garuda',
      role: 'Atlet',
      group: 'U-16',
    );
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    var people = const [alya, bima];
    late StateSetter refresh;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return ClubPeopleTab(
              role: 'Atlet',
              people: people,
              palette: palette,
              onPersonTap: (_) {},
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-filter-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U-18').last);

    refresh(() => people = const [bima]);
    await tester.pump();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Bima Putra'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Semua kelompok'), findsOneWidget);
  });

  testWidgets('filtered empty state explains and resets the active filter', (
    tester,
  ) async {
    const person = SportPerson(
      id: '1',
      name: 'Alya Putri',
      clubId: 'garuda',
      role: 'Atlet',
      group: 'U-18',
    );
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(
      app(
        ClubPeopleTab(
          role: 'Atlet',
          people: const [person],
          palette: palette,
          onPersonTap: (_) {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('club-people-filter-Atlet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('club-filter-query')),
      'tidak ditemukan',
    );
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada atlet yang sesuai filter'), findsOneWidget);
    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();
    expect(find.text('Alya Putri'), findsOneWidget);
  });

  testWidgets('naturally empty role has no misleading reset action', (
    tester,
  ) async {
    final palette = ClubBrandPaletteResolver.resolve(testClub);
    await tester.pumpWidget(
      app(
        ClubPeopleTab(
          role: 'Official',
          people: const [],
          palette: palette,
          onPersonTap: (_) {},
        ),
      ),
    );

    expect(find.text('Belum ada data official'), findsOneWidget);
    expect(find.text('Reset filter'), findsNothing);
  });
}

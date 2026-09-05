import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/theme.dart';
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
}

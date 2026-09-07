import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/athlete_detail/athlete_detail_page.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';
import 'package:kok_app/features/dashboard_decorations.dart';
import 'package:kok_app/features/detail_pages.dart';
import 'package:kok_app/shared/widgets.dart';

Widget createTestApp({
  required KokSnapshot snapshot,
  required String initialLocation,
  VoidCallback? onHomeReached,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/person/:id',
        builder: (_, state) => AthleteDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) {
          onHomeReached?.call();
          return const Scaffold(body: Text('Home Page'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

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

  group('AthleteDetailPage Widget Tests', () {
    testWidgets(
      'renders Voli Bina Muda athlete with dynamic amber/gold club brand palette',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        final voliClub = data!.clubs.firstWhere((c) => c.id == 'voli');
        final palette = ClubBrandPaletteResolver.resolve(voliClub);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data,
            initialLocation: '/person/voli-atlet-0',
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header & Title
        expect(find.text('Detail Atlet'), findsOneWidget);

        // Header container has gradient with club brand palette
        final headerContainer = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).gradient is LinearGradient,
          ),
        );
        final gradient =
            (headerContainer.decoration! as BoxDecoration).gradient
                as LinearGradient;
        expect(gradient.colors.first, palette.headerStart);
        expect(gradient.colors.last, palette.headerEnd);

        // Header pattern decoration (concentric circles & dot matrix)
        final patternCustomPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byWidget(headerContainer),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(patternCustomPaint.painter, isA<BrandHeaderPatternPainter>());
        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is BrandHeaderPatternPainter,
          ),
          findsOneWidget,
        );

        // 2. Profile identity
        expect(find.text('Atlet 1 · Voli Bina Muda'), findsOneWidget);
        expect(find.text('ID SICABOR · ATL-voli-atlet-0'), findsOneWidget);

        // 3. Status Badge: verified (soft green) independent of club brand color
        expect(find.text('terverifikasi'), findsOneWidget);
        final verifiedBadge = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.child is Text &&
                (w.child! as Text).data == 'terverifikasi',
          ),
        );
        final verifiedBox = verifiedBadge.decoration as BoxDecoration;
        expect(verifiedBox.color, const Color(0xFFD1FAE5));
        final verifiedText = verifiedBadge.child as Text;
        expect(verifiedText.style?.color, const Color(0xFF059669));

        // 4. Details rows
        expect(find.text('Klub'), findsOneWidget);
        expect(find.text('Voli Bina Muda'), findsOneWidget);
        expect(find.text('Cabor'), findsOneWidget);
        expect(find.text('Voli'), findsOneWidget);
        expect(find.text('Kelompok'), findsOneWidget);
        expect(find.text('U-18'), findsOneWidget);
        expect(find.text('Lahir / Usia'), findsOneWidget);
        expect(find.text('15 tahun'), findsOneWidget);
        expect(find.text('Alamat'), findsOneWidget);
        expect(find.text('Pakuwon, Kec. Garut Kota'), findsOneWidget);
        expect(find.text('Pelatih'), findsOneWidget);

        // Check icon container has palette.softAccent
        final iconContainers = tester.widgetList<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == palette.softAccent &&
                w.constraints?.maxWidth == 28,
          ),
        );
        expect(iconContainers, isNotEmpty);

        // 5. Kelengkapan Berkas section
        expect(find.text('KELENGKAPAN BERKAS'), findsOneWidget);
        expect(find.text('Kelengkapan dokumen'), findsOneWidget);
        expect(find.text('4 dari 4'), findsOneWidget);

        // Progress bar with palette.headerStart
        final progressBar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressBar.value, 1.0);
        expect(
          (progressBar.valueColor as AlwaysStoppedAnimation<Color>).value,
          palette.headerStart,
        );

        // 4 items with '✓ ada'
        expect(find.text('KTP / KIA'), findsOneWidget);
        expect(find.text('Kartu Keluarga'), findsOneWidget);
        expect(find.text('Akta kelahiran'), findsOneWidget);
        expect(find.text('Surat sehat'), findsOneWidget);
        expect(find.text('✓ ada'), findsNWidgets(4));

        // 6. Riwayat section
        expect(find.text('RIWAYAT'), findsOneWidget);
        expect(find.text('2026'), findsOneWidget);
        expect(find.text('2025'), findsOneWidget);
        expect(find.text('2024'), findsOneWidget);

        // 7. Action button with club color
        expect(find.text('Hubungi pengurus klub'), findsOneWidget);
        final buttonFinder = find.widgetWithText(
          FilledButton,
          'Hubungi pengurus klub',
        );
        final actionButton = tester.widget<FilledButton>(buttonFinder);
        expect(
          actionButton.style?.backgroundColor?.resolve({}),
          palette.headerStart,
        );
      },
    );

    testWidgets(
      'renders Garuda Muda athlete with slate/navy palette and berkas kurang badge',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        final garudaClub = data!.clubs.firstWhere((c) => c.id == 'garuda');
        final palette = ClubBrandPaletteResolver.resolve(garudaClub);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data,
            initialLocation: '/person/garuda-atlet-0',
          ),
        );
        await tester.pumpAndSettle();

        // Header has Garuda palette
        final headerContainer = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).gradient is LinearGradient,
          ),
        );
        final gradient =
            (headerContainer.decoration! as BoxDecoration).gradient
                as LinearGradient;
        expect(gradient.colors.first, palette.headerStart);

        // Status Badge: berkas kurang (soft red)
        expect(find.text('berkas kurang'), findsOneWidget);
        final warningBadge = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.child is Text &&
                (w.child! as Text).data == 'berkas kurang',
          ),
        );
        final warningBox = warningBadge.decoration as BoxDecoration;
        expect(warningBox.color, const Color(0xFFFEE2E2));
        final warningText = warningBadge.child as Text;
        expect(warningText.style?.color, const Color(0xFFDC2626));

        // Kelengkapan berkas: 2 dari 4 (Kartu Keluarga and Akta kelahiran missing)
        expect(find.text('2 dari 4'), findsOneWidget);
        final progressBar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressBar.value, 0.5);
        expect(find.text('✓ ada'), findsNWidgets(2));
        expect(find.text('belum'), findsNWidgets(2));
      },
    );

    testWidgets(
      'renders coach profile with lisensi kedaluwarsa status',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data!,
            initialLocation: '/person/garuda-pelatih-0',
          ),
        );
        await tester.pumpAndSettle();

        // Header title shows Detail Pelatih
        expect(find.text('Detail Pelatih'), findsOneWidget);

        // Status badge: lisensi kedaluwarsa
        expect(find.text('lisensi kedaluwarsa'), findsOneWidget);

        // Kelengkapan berkas has row for Lisensi
        expect(find.text('Lisensi'), findsOneWidget);
        expect(find.text('Kedaluwarsa'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Hubungi pengurus klub opens bottom sheet modal with secretariat details',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data!,
            initialLocation: '/person/voli-atlet-0',
          ),
        );
        await tester.pumpAndSettle();

        // Tap the button
        await tester.tap(find.text('Hubungi pengurus klub'));
        await tester.pumpAndSettle();

        // Modal should appear
        expect(find.text('Sekretariat Klub'), findsOneWidget);
        expect(find.text('Voli Bina Muda'), findsWidgets);
        expect(find.text('Pakuwon, Kec. Garut Kota'), findsWidgets);
        expect(find.text('0812-3456-7890'), findsOneWidget);
        expect(find.text('Tutup'), findsOneWidget);

        // Close modal
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();
        expect(find.text('Sekretariat Klub'), findsNothing);
      },
    );

    testWidgets(
      'displays MissingPage when athlete id is not found',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data!,
            initialLocation: '/person/non-existent-person',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissingPage), findsOneWidget);
        expect(find.text('Data tidak ditemukan'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping share icon shows snackbar feedback',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data!,
            initialLocation: '/person/voli-atlet-0',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.share_outlined));
        await tester.pump();

        expect(
          find.text('Tautan profil Atlet 1 · Voli Bina Muda disalin ke clipboard.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'profile card displays DashedDivider and overlapping avatar with border',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetch());
        expect(data, isNotNull);

        await tester.pumpWidget(
          createTestApp(
            snapshot: data!,
            initialLocation: '/person/voli-atlet-0',
          ),
        );
        await tester.pumpAndSettle();

        // DashedDivider present
        expect(find.byType(DashedDivider), findsOneWidget);

        // Overlapping avatar with 3.5px border
        final avatarContainer = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
                (w.decoration! as BoxDecoration).border != null &&
                ((w.decoration! as BoxDecoration).border! as Border).top.width == 3.5,
          ),
        );
        expect(avatarContainer, isNotNull);
      },
    );
  });
}

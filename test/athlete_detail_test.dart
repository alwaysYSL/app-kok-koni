import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/features/athlete_detail/athlete_detail_page.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';
import 'package:kok_app/features/dashboard_decorations.dart';
import 'package:kok_app/features/detail_pages.dart';
import 'package:kok_app/shared/widgets.dart';

const garutScope = AccessScope(
  type: AccessScopeType.district,
  id: 'garut_kota',
  name: 'Kecamatan Garut Kota',
);

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
        builder: (_, state) =>
            AthleteDetailPage(id: state.pathParameters['id']!),
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
    overrides: [snapshotProvider.overrideWith((_) async => snapshot)],
    child: MaterialApp.router(theme: kokTheme(), routerConfig: router),
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
        final data = await tester.runAsync(() => repo.fetchScope(garutScope));
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
        final backIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
        expect(backIcon.size, 28);

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
        final nameText = tester.widget<Text>(
          find.text('Atlet 1 · Voli Bina Muda'),
        );
        expect(nameText.style?.color, KokColors.cardTitle);
        expect(find.text('ID · ATL-voli-atlet-0'), findsOneWidget);
        expect(find.textContaining('SICABOR'), findsNothing);

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
        expect(find.text('Bola Voli'), findsOneWidget);
        expect(find.text('Kelompok'), findsOneWidget);
        expect(find.text('U-18'), findsOneWidget);
        expect(find.text('Lahir / Usia'), findsOneWidget);
        expect(find.text('15 tahun'), findsOneWidget);
        expect(find.text('Alamat'), findsOneWidget);
        expect(find.text('-'), findsWidgets);
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
        expect(
          tester.widget<Text>(find.text('KELENGKAPAN BERKAS')).style?.color,
          KokColors.cardTitle,
        );
        expect(find.text('Kelengkapan dokumen'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('Kelengkapan dokumen')).style?.color,
          KokColors.cardTitle,
        );
        expect(find.text('4 dari 4'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('4 dari 4')).style?.color,
          KokColors.cardTitle,
        );

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
        expect(
          tester.widget<Text>(find.text('RIWAYAT')).style?.color,
          KokColors.cardTitle,
        );
        expect(find.text('Riwayat prestasi belum tersedia.'), findsOneWidget);
        expect(find.text('2026'), findsNothing);
        expect(find.text('2025'), findsNothing);
        expect(find.text('2024'), findsNothing);

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
        final data = await tester.runAsync(() => repo.fetchScope(garutScope));
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

    testWidgets('renders coach profile with lisensi kedaluwarsa status', (
      tester,
    ) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetchScope(garutScope));
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

      // Role-aware ID label
      expect(find.text('ID · PEL-garuda-pelatih-0'), findsOneWidget);

      // Status badge: lisensi kedaluwarsa
      expect(find.text('lisensi kedaluwarsa'), findsOneWidget);

      // Kelengkapan berkas has row for Lisensi
      expect(find.text('Lisensi'), findsOneWidget);
      expect(find.text('Kedaluwarsa'), findsOneWidget);
    });

    testWidgets(
      'tapping Hubungi pengurus klub opens bottom sheet modal with secretariat details',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetchScope(garutScope));
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
        expect(find.text('-'), findsWidgets);
        expect(find.text('081211223344'), findsOneWidget);
        expect(find.text('Tutup'), findsOneWidget);

        // Close modal
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();
        expect(find.text('Sekretariat Klub'), findsNothing);
      },
    );

    testWidgets('renders athlete and club fields supplied by the API model', (
      tester,
    ) async {
      const club = Club(
        id: 'api-club',
        name: 'Klub API Garut',
        sport: 'Karate',
        village: 'Sukajaya',
        phone: '0800000000',
        email: 'klub-api@example.test',
        address: 'Jl. Data Resmi No. 1',
      );
      final snapshot = KokSnapshot(
        scope: garutScope,
        clubs: const [club],
        people: [
          SportPerson(
            id: 'api-athlete',
            name: 'Atlet API',
            clubId: 'api-club',
            role: 'Atlet',
            group: 'Senior',
            birthPlace: 'Garut',
            birthDate: DateTime(2008, 5, 1),
            address: 'Jl. Atlet No. 2',
            milestones: const [
              Milestone(
                year: '2024',
                title: 'Kejuaraan API',
                description: 'Juara satu.',
              ),
            ],
          ),
        ],
        committee: const [],
        loadedAt: DateTime(2026, 9, 12),
      );

      await tester.pumpWidget(
        createTestApp(
          snapshot: snapshot,
          initialLocation: '/person/api-athlete',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Garut · 1 Mei 2008'), findsOneWidget);
      expect(find.text('Jl. Atlet No. 2'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.textContaining('Kejuaraan API'), findsOneWidget);

      await tester.tap(find.text('Hubungi pengurus klub'));
      await tester.pumpAndSettle();
      expect(find.text('Jl. Data Resmi No. 1'), findsOneWidget);
      expect(find.text('0800000000'), findsOneWidget);
      expect(find.text('klub-api@example.test'), findsOneWidget);
    });

    testWidgets('displays MissingPage when athlete id is not found', (
      tester,
    ) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetchScope(garutScope));
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
    });

    testWidgets('tapping share icon shows snackbar feedback', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetchScope(garutScope));
      expect(data, isNotNull);

      await tester.pumpWidget(
        createTestApp(snapshot: data!, initialLocation: '/person/voli-atlet-0'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      expect(
        find.text(
          'Tautan profil Atlet 1 · Voli Bina Muda disalin ke clipboard.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'profile card displays DashedDivider and overlapping avatar with border',
      (tester) async {
        final repo = DemoKokRepository();
        final data = await tester.runAsync(() => repo.fetchScope(garutScope));
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
                ((w.decoration! as BoxDecoration).border! as Border)
                        .top
                        .width ==
                    3.5,
          ),
        );
        expect(avatarContainer, isNotNull);
      },
    );

    testWidgets(
      'profile card formats role-aware ID for official and avoids prefix doubling',
      (tester) async {
        final snapshot = KokSnapshot(
          scope: garutScope,
          clubs: const [
            Club(
              id: 'club-1',
              name: 'Klub Prima',
              sport: 'Atletik',
              village: 'Pakuwon',
            ),
          ],
          people: const [
            SportPerson(
              id: '123',
              name: 'Official Budi',
              clubId: 'club-1',
              role: 'Official',
              group: 'Manajer',
            ),
            SportPerson(
              id: 'PEL-456',
              name: 'Coach Joko',
              clubId: 'club-1',
              role: 'Pelatih',
              group: 'Lisensi B',
            ),
            SportPerson(
              id: 'ATL-789',
              name: 'Atlet Susi',
              clubId: 'club-1',
              role: 'Atlet',
              group: 'Senior',
            ),
          ],
          committee: const [],
          loadedAt: DateTime(2026, 9, 12),
        );

        // Test Official with raw id 123
        await tester.pumpWidget(
          createTestApp(snapshot: snapshot, initialLocation: '/person/123'),
        );
        await tester.pumpAndSettle();
        expect(find.text('ID · OFF-123'), findsOneWidget);

        // Test Coach with pre-prefixed ID PEL-456
        await tester.pumpWidget(
          createTestApp(snapshot: snapshot, initialLocation: '/person/PEL-456'),
        );
        await tester.pumpAndSettle();
        expect(find.text('ID · PEL-456'), findsOneWidget);
        expect(find.text('ID · PEL-PEL-456'), findsNothing);

        // Test Athlete with pre-prefixed ID ATL-789
        await tester.pumpWidget(
          createTestApp(snapshot: snapshot, initialLocation: '/person/ATL-789'),
        );
        await tester.pumpAndSettle();
        expect(find.text('ID · ATL-789'), findsOneWidget);
        expect(find.text('ID · ATL-ATL-789'), findsNothing);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/features/athlete_detail/athlete_detail_page.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';
import 'package:kok_app/features/dashboard_decorations.dart';
import 'package:kok_app/features/detail_pages.dart';
import 'package:kok_app/shared/widgets.dart';

import 'test_composition.dart';

const garutScope = AccessScope(
  type: AccessScopeType.district,
  id: 'garut_kota',
  name: 'Kecamatan Garut Kota',
);

AppComposition buildTestRemoteAppComposition() {
  final base = buildTestAppComposition();
  return AppComposition(
    profile: const DeploymentProfile(
      environment: AppEnv.production,
      authMode: AuthMode.remote,
      dataMode: DataMode.remote,
    ),
    authTokenStorage: base.authTokenStorage,
    sessionMetadataStore: base.sessionMetadataStore,
    rememberedUsernameStore: base.rememberedUsernameStore,
    authRepository: base.authRepository,
    kokRepository: base.kokRepository,
    profileService: base.profileService,
    caborService: base.caborService,
    athleteService: base.athleteService,
    clubService: base.clubService,
    credentialIdGenerator: base.credentialIdGenerator,
  );
}

Widget createRemoteTestApp({
  required String initialLocation,
  List<dynamic> overrides = const [],
  VoidCallback? onSportsReached,
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
        path: '/sports',
        builder: (_, _) {
          onSportsReached?.call();
          return const Scaffold(body: Text('Sports Page'));
        },
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home Page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  final remoteComposition = buildTestRemoteAppComposition();

  return ProviderScope(
    overrides: [
      appCompositionProvider.overrideWithValue(remoteComposition),
      ...overrides,
    ],
    child: MaterialApp.router(theme: kokTheme(), routerConfig: router),
  );
}

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

  group('AthleteDetailPage Remote Mode Tests', () {
    final sampleRemoteAthlete = AthleteDetail(
      id: 101,
      code: 'ATL-101',
      name: 'Budi Setiawan',
      sex: 'l',
      sexLabel: 'Laki-Laki',
      pob: 'Garut',
      dob: '12-05-2002',
      age: 24,
      photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      status: 1,
      statusLabel: 'Aktif',
      cabor: const AthleteCabor(id: 1, code: 'VOLI', name: 'Bola Voli'),
      club: const AthleteClub(id: 10, code: 'KLUB-01', name: 'Voli Bina Muda'),
      domicile: const AthleteDomicile(
        subdistrictId: 320501,
        subdistrictName: 'Garut Kota',
        districtId: 3205,
        districtName: 'Kabupaten Garut',
        village: 'Kota Kulon',
      ),
      phone: '081234567890',
      email: 'budi@example.test',
      height: 180,
      weight: 75,
      bloodType: 'O',
      address: 'Jl. Merdeka No. 10',
    );

    final sampleRemoteAthleteNoClub = const AthleteDetail(
      id: 102,
      code: 'ATL-102',
      name: 'Siti Rahma',
      sex: 'p',
      sexLabel: 'Perempuan',
      pob: 'Tarogong',
      dob: '20-10-2004',
      age: 22,
      photoUrl: 'invalid-photo-url',
      status: 1,
      statusLabel: 'Aktif',
      cabor: AthleteCabor(id: 2, code: 'SILAT', name: 'Pencak Silat'),
      club: null,
      domicile: AthleteDomicile(
        subdistrictId: 320502,
        subdistrictName: 'Tarogong Kidul',
        districtId: 3205,
        districtName: 'Kabupaten Garut',
      ),
      phone: '08987654321',
      email: null,
      height: 165,
      weight: 55,
      bloodType: 'A',
      address: null,
    );

    testWidgets(
      'renders complete remote athlete profile with physical data, contacts, domicile, and active status',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/person/101',
            overrides: [
              athleteDetailProvider(
                101,
              ).overrideWith((ref) async => sampleRemoteAthlete),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header & Title
        expect(find.text('Detail Atlet'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.byIcon(Icons.share_outlined), findsOneWidget);

        // 2. Profile identity
        expect(find.text('Budi Setiawan'), findsOneWidget);
        expect(find.text('ID · ATL-101'), findsOneWidget);
        expect(find.text('Aktif'), findsOneWidget);

        // 3. Detail rows
        expect(find.text('Klub'), findsOneWidget);
        expect(find.text('Voli Bina Muda'), findsOneWidget);
        expect(find.text('Kode Klub'), findsOneWidget);
        expect(find.text('KLUB-01'), findsOneWidget);
        expect(find.text('Cabor'), findsOneWidget);
        expect(find.text('Bola Voli'), findsOneWidget);
        expect(find.text('Jenis Kelamin'), findsOneWidget);
        expect(find.text('Laki-Laki'), findsOneWidget);
        expect(find.text('Lahir / Usia'), findsOneWidget);
        expect(find.text('Garut · 12-05-2002 (24 thn)'), findsOneWidget);
        expect(find.text('Domisili'), findsOneWidget);
        expect(find.text('Kota Kulon, Garut Kota'), findsOneWidget);

        // 4. Data Fisik
        expect(find.text('DATA FISIK'), findsOneWidget);
        expect(find.text('180 cm'), findsOneWidget);
        expect(find.text('Tinggi Badan'), findsOneWidget);
        expect(find.text('75 kg'), findsOneWidget);
        expect(find.text('Berat Badan'), findsOneWidget);
        expect(find.text('O'), findsOneWidget);
        expect(find.text('Golongan Darah'), findsOneWidget);

        // 5. Kontak & Alamat
        expect(find.text('KONTAK & ALAMAT'), findsOneWidget);
        expect(find.text('081234567890'), findsOneWidget);
        expect(find.text('budi@example.test'), findsOneWidget);
        expect(find.text('Jl. Merdeka No. 10'), findsOneWidget);

        // 6. Hidden items in remote mode
        expect(find.text('KELENGKAPAN BERKAS'), findsNothing);
        expect(find.text('RIWAYAT'), findsNothing);
        expect(find.text('terverifikasi'), findsNothing);
        expect(find.text('Hubungi pengurus klub'), findsNothing);
      },
    );

    testWidgets(
      'renders remote athlete without club and hides contact button',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/person/102',
            overrides: [
              athleteDetailProvider(
                102,
              ).overrideWith((ref) async => sampleRemoteAthleteNoClub),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Siti Rahma'), findsOneWidget);
        expect(find.text('ID · ATL-102'), findsOneWidget);
        expect(find.text('Klub belum tercatat'), findsOneWidget);
        expect(find.text('Aktif'), findsOneWidget);
        expect(find.text('Pencak Silat'), findsOneWidget);
        expect(find.textContaining('Berkas Lengkap'), findsNothing);
        expect(find.text('KELENGKAPAN BERKAS'), findsNothing);
        expect(find.text('Tarogong Kidul, Kabupaten Garut'), findsOneWidget);
        expect(find.text('Hubungi pengurus klub'), findsNothing);

        // Fallback avatar initial
        expect(find.text('SR'), findsOneWidget);
      },
    );

    testWidgets(
      'displays MissingPage with custom message when 404 NotFoundException is thrown',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/person/999',
            overrides: [
              athleteDetailProvider(999).overrideWith(
                (ref) => Future.error(
                  const NotFoundException('Data atlet tidak ditemukan.'),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissingPage), findsOneWidget);
        expect(find.text('Data atlet tidak ditemukan.'), findsOneWidget);
      },
    );

    testWidgets('displays error view with retry button on unexpected failure', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/person/101',
          overrides: [
            athleteDetailProvider(101).overrideWith((ref) {
              callCount++;
              if (callCount == 1) {
                return Future.error(
                  const ServerErrorException('Koneksi terputus'),
                );
              }
              return Future.value(sampleRemoteAthlete);
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat detail atlet'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Budi Setiawan'), findsOneWidget);
    });

    testWidgets(
      'displays MissingPage when athlete id is non-numeric in remote mode',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(initialLocation: '/person/abc'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissingPage), findsOneWidget);
        expect(find.text('Data atlet tidak ditemukan.'), findsOneWidget);
      },
    );

    testWidgets('tapping back button pops or navigates to /sports', (
      tester,
    ) async {
      var sportsReached = false;
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/person/101',
          onSportsReached: () => sportsReached = true,
          overrides: [
            athleteDetailProvider(
              101,
            ).overrideWith((ref) async => sampleRemoteAthlete),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(sportsReached, isTrue);
    });

    testWidgets('tapping share button shows SnackBar feedback', (tester) async {
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/person/101',
          overrides: [
            athleteDetailProvider(
              101,
            ).overrideWith((ref) async => sampleRemoteAthlete),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      expect(
        find.text('Tautan profil Budi Setiawan disalin ke clipboard.'),
        findsOneWidget,
      );
    });
  });
}

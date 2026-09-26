import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/club.dart' as domain_club;
import 'package:kok_app/data/models/club_detail.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/features/club_detail/club_detail_page.dart';
import 'package:kok_app/features/detail_pages.dart';

import 'test_composition.dart';

const testScope = AccessScope(
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
  VoidCallback? onClubsReached,
  VoidCallback? onPersonReached,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/club/:id',
        builder: (_, state) => ClubDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clubs',
        builder: (_, _) {
          onClubsReached?.call();
          return const Scaffold(body: Text('Clubs Page'));
        },
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, state) {
          onPersonReached?.call();
          return Scaffold(body: Text('Person ${state.pathParameters['id']}'));
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

Widget createDemoTestApp({
  required KokSnapshot snapshot,
  required String initialLocation,
  VoidCallback? onClubsReached,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/club/:id',
        builder: (_, state) => ClubDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clubs',
        builder: (_, _) {
          onClubsReached?.call();
          return const Scaffold(body: Text('Clubs Page'));
        },
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home Page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      appCompositionProvider.overrideWithValue(buildTestAppComposition()),
      snapshotProvider.overrideWith((_) async => snapshot),
    ],
    child: MaterialApp.router(theme: kokTheme(), routerConfig: router),
  );
}

final sampleRemoteClubDetail = ClubDetail(
  id: 10,
  code: 'KLUB-010',
  name: 'PB Garuda Perkasa',
  logoUrl: 'https://images.example.test/pb_garuda.png',
  cabor: const domain_club.ClubCabor(
    id: 1,
    code: 'BULUTANGKIS',
    name: 'Bulu Tangkis',
  ),
  headName: 'Haji Ahmad Subagja',
  phone: '081234567890',
  email: 'garuda@example.test',
  since: '2015',
  noSk: 'SK/012/KONI/2020',
  status: 1,
  statusLabel: 'Aktif',
  secretariat: const domain_club.ClubAddress(
    address: 'Jl. Merdeka No. 45',
    subdistrictId: 320501,
    subdistrictName: 'Kota Kulon',
    districtId: 3205,
    districtName: 'Garut Kota',
  ),
  totalAthleteInClub: 42,
  training: const domain_club.ClubAddress(
    address: 'GOR Gelora Merdeka, Jl. Cimanuk No. 88',
    subdistrictId: 320501,
    subdistrictName: 'Jayawaras',
    districtId: 3205,
    districtName: 'Tarogong Kidul',
  ),
  fileSkUrl: 'https://files.example.test/sk-garuda.pdf',
  officials: const ClubPersonnelBlock(
    dataAvailable: false,
    reason: 'NOT_RECORDED_IN_SYSTEM',
    items: [],
  ),
  coaches: const ClubPersonnelBlock(
    dataAvailable: false,
    reason: 'NOT_AVAILABLE',
    items: [],
  ),
  management: const ClubManagementBlock(
    dataAvailable: true,
    partial: true,
    source: 'SICABOR',
    items: [
      ClubPersonnelItem(
        id: 101,
        name: 'Haji Ahmad Subagja',
        role: 'Ketua Umum',
        phone: '081234567890',
      ),
      ClubPersonnelItem(
        id: null,
        name: 'Rahmat Hidayat',
        role: 'Sekretaris',
        phone: '089876543210',
      ),
    ],
  ),
);

final sampleRemoteClubDetailComplete = ClubDetail(
  id: 20,
  code: 'KLUB-020',
  name: 'Voli Bina Muda',
  logoUrl: '',
  cabor: const domain_club.ClubCabor(id: 2, code: 'VOLI', name: 'Bola Voli'),
  headName: null,
  phone: null,
  email: null,
  since: null,
  noSk: null,
  status: 0,
  statusLabel: 'Belum Aktif',
  secretariat: const domain_club.ClubAddress(
    address: null,
    subdistrictId: 320502,
    subdistrictName: 'Haurpanggung',
    districtId: 3205,
    districtName: 'Tarogong Kidul',
  ),
  totalAthleteInClub: 0,
  training: null,
  fileSkUrl: null,
  officials: const ClubPersonnelBlock(
    dataAvailable: true,
    items: [
      ClubPersonnelItem(
        id: 201,
        name: 'Bambang S',
        role: 'Manajer Tim',
        phone: '0811223344',
      ),
    ],
  ),
  coaches: const ClubPersonnelBlock(
    dataAvailable: true,
    items: [
      ClubPersonnelItem(
        id: null,
        name: 'Coach Joko',
        role: 'Pelatih Kepala',
        phone: '0855667788',
      ),
    ],
  ),
  management: const ClubManagementBlock(
    dataAvailable: true,
    partial: false,
    items: [],
  ),
);

class _TestAthletePaginationController extends AthletePaginationController {
  _TestAthletePaginationController(
    super.scope, [
    this._initialState = const AthletePaginationState(),
    this.onSearchUpdated,
    this.onLoadMore,
  ]);

  final AthletePaginationState _initialState;
  final void Function(String?)? onSearchUpdated;
  final VoidCallback? onLoadMore;

  @override
  AthletePaginationState build() => _initialState;

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async => onLoadMore?.call();

  @override
  void updateSearch(String? query) {
    onSearchUpdated?.call(query);
    state = query == null
        ? state.copyWith(clearSearch: true)
        : state.copyWith(search: query);
  }

  @override
  void updateSexFilter(String? sex) {
    state = sex == null
        ? state.copyWith(clearSex: true)
        : state.copyWith(sex: sex);
  }
}

const sampleAthlete1 = Athlete(
  id: 301,
  code: 'AT-301',
  name: 'Kevin Sanjaya',
  sex: 'l',
  sexLabel: 'Laki-Laki',
  photoUrl: '',
  status: 1,
  statusLabel: 'Aktif',
  cabor: AthleteCabor(id: 1, code: 'BULUTANGKIS', name: 'Bulu Tangkis'),
  club: AthleteClub(id: 10, code: 'KLUB-010', name: 'PB Garuda Perkasa'),
  domicile: AthleteDomicile(
    subdistrictId: 320501,
    subdistrictName: 'Kota Kulon',
    districtId: 3205,
    districtName: 'Garut Kota',
  ),
);

const sampleAthlete2 = Athlete(
  id: 302,
  code: 'AT-302',
  name: 'Greysia Polii',
  sex: 'p',
  sexLabel: 'Perempuan',
  photoUrl: '',
  status: 1,
  statusLabel: 'Aktif',
  cabor: AthleteCabor(id: 1, code: 'BULUTANGKIS', name: 'Bulu Tangkis'),
  club: AthleteClub(id: 10, code: 'KLUB-010', name: 'PB Garuda Perkasa'),
  domicile: AthleteDomicile(
    subdistrictId: 320501,
    subdistrictName: 'Kota Kulon',
    districtId: 3205,
    districtName: 'Garut Kota',
  ),
);

void main() {
  setUpAll(() async {
    final font = FontLoader('KokSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });

  group('ClubDetailPage Remote Mode Tests', () {
    testWidgets('club title and back action stay above tabs after scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/club/10',
          overrides: [
            clubDetailProvider(
              10,
            ).overrideWith((ref) async => sampleRemoteClubDetail),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('club-compact-header')), findsNothing);
      final heroGap =
          tester.getTopLeft(find.byKey(const Key('detail-header-lip'))).dy -
          tester
              .getBottomLeft(find.text('42 atlet terdaftar di klub').first)
              .dy;
      expect(heroGap, lessThan(80));
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('club-compact-header')), findsOneWidget);
      expect(
        find
            .descendant(
              of: find.byKey(const Key('club-compact-header')),
              matching: find.text('PB Garuda Perkasa'),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Info').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Kembali').hitTestable(), findsOneWidget);
    });

    testWidgets('club athlete search scrolls beneath the sticky tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loadMoreCalls = 0;
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/club/10',
          overrides: [
            clubDetailProvider(
              10,
            ).overrideWith((ref) async => sampleRemoteClubDetail),
            athletePaginationProvider((idCabor: null, idClub: 10)).overrideWith(
              () => _TestAthletePaginationController(
                (idCabor: null, idClub: 10),
                AthletePaginationState(
                  items: List.filled(20, sampleAthlete1),
                  total: 40,
                ),
                null,
                () => loadMoreCalls++,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atlet'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();

      expect(find.byType(TextField).hitTestable(), findsNothing);
      expect(
        find
            .descendant(
              of: find.byKey(const Key('club-compact-header')),
              matching: find.text('PB Garuda Perkasa'),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Atlet').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(loadMoreCalls, greaterThan(0));
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('long club identity fits ${width.toInt()} dp', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final longClub = sampleRemoteClubDetail.copyWith(
          name: 'Persatuan Bulutangkis Garuda Perkasa Kecamatan Garut Kota',
          code: 'KGCL-KODE-PANJANG-0001',
          cabor: const domain_club.ClubCabor(
            id: 1,
            code: 'BULUTANGKIS',
            name: 'Bulutangkis Prestasi Kecamatan Garut Kota',
          ),
        );
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(10).overrideWith((ref) async => longClub),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final lipTop = tester
            .getTopLeft(find.byKey(const Key('detail-header-lip')))
            .dy;
        final statsBottom = tester
            .getBottomLeft(find.text('42 atlet terdaftar di klub').first)
            .dy;
        expect(statsBottom, lessThan(lipTop - 16));
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in [320.0, 390.0]) {
      testWidgets('remote tabs fit ${width.toInt()} dp with inactive club', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/20',
            overrides: [
              clubDetailProvider(
                20,
              ).overrideWith((ref) async => sampleRemoteClubDetailComplete),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BELUM AKTIF'), findsOneWidget);
        expect(find.byKey(const Key('detail-header-lip')), findsOneWidget);
        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Pengurus'), findsOneWidget);
        expect(find.text('Atlet'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Pengurus'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'renders header, badges, and total counter with kecamatan note',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header identity
        expect(find.text('PB Garuda Perkasa'), findsWidgets);
        expect(find.text('KLUB-010'), findsWidgets);
        expect(find.text('Bulu Tangkis'), findsWidgets);
        expect(find.text('AKTIF'), findsOneWidget);

        // 2. Action buttons
        expect(find.byIcon(Icons.chevron_left), findsWidgets);
        expect(find.byIcon(Icons.share_outlined), findsWidgets);

        // 3. Counter & Note
        expect(find.text('42 atlet terdaftar di klub'), findsWidgets);
        expect(find.byKey(const Key('detail-header-lip')), findsOneWidget);
        expect(
          find.text('Cakupan klub dapat meliputi kecamatan lain'),
          findsWidgets,
        );
        expect(find.text('Termasuk atlet dari kecamatan lain'), findsNothing);

        // 4. Share button action
        await tester.tap(find.byIcon(Icons.share_outlined).first);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Info klub disalin'), findsOneWidget);
      },
    );

    testWidgets(
      'Tab 1 (Info) renders identitas, SK, kontak, alamat sekretariat & latihan',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Uri? launchedUri;
        LaunchMode? launchedMode;

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              urlLauncherProvider.overrideWithValue((
                uri, {
                mode = LaunchMode.platformDefault,
              }) async {
                launchedUri = uri;
                launchedMode = mode;
                return true;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 1. Identitas section
        expect(find.text('Identitas Klub'), findsOneWidget);
        expect(find.text('Haji Ahmad Subagja'), findsWidgets);
        expect(find.text('2015'), findsOneWidget);
        expect(find.text('Aktif'), findsOneWidget);

        // 2. SK section
        expect(find.text('Surat Keputusan (SK)'), findsOneWidget);
        expect(find.text('SK/012/KONI/2020'), findsOneWidget);
        expect(find.text('Berkas tersedia'), findsOneWidget);
        expect(find.byTooltip('Salin / Buka tautan berkas SK'), findsOneWidget);

        // Tap SK action button -> external browser launch
        await tester.tap(find.byTooltip('Salin / Buka tautan berkas SK'));
        await tester.pumpAndSettle();
        expect(
          launchedUri?.toString(),
          'https://files.example.test/sk-garuda.pdf',
        );
        expect(launchedMode, LaunchMode.externalApplication);

        // 3. Kontak section
        expect(find.text('Kontak'), findsOneWidget);
        expect(find.text('081234567890'), findsWidgets);
        expect(find.text('garuda@example.test'), findsOneWidget);

        // 4. Alamat section (Kecamatan & Kabupaten / Kota)
        expect(find.text('Alamat & Lokasi'), findsOneWidget);
        expect(find.text('Sekretariat'), findsOneWidget);
        expect(find.text('Jl. Merdeka No. 45'), findsOneWidget);
        expect(find.text('Kecamatan'), findsWidgets);
        expect(find.text('Kota Kulon'), findsOneWidget);
        expect(find.text('Kabupaten / Kota'), findsWidgets);
        expect(find.text('Garut Kota'), findsWidgets);
        expect(find.text('Tempat Latihan'), findsOneWidget);
        expect(
          find.text('GOR Gelora Merdeka, Jl. Cimanuk No. 88'),
          findsOneWidget,
        );
        expect(find.text('Jayawaras'), findsOneWidget);
        expect(find.text('Tarogong Kidul'), findsOneWidget);

        // 5. Total Anggota section
        expect(find.text('Total Anggota'), findsOneWidget);
        expect(find.text('42 atlet terdaftar di klub'), findsWidgets);
      },
    );

    testWidgets(
      'Tab 1 (Info) falls back to SnackBar with copy action when opening SK fails or launcher returns false',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              urlLauncherProvider.overrideWithValue(
                (uri, {mode = LaunchMode.platformDefault}) async => false,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Salin / Buka tautan berkas SK'));
        await tester.pumpAndSettle();

        expect(
          find.text('Tidak dapat membuka peramban eksternal.'),
          findsOneWidget,
        );
        expect(find.text('Salin Tautan'), findsOneWidget);

        await tester.tap(find.text('Salin Tautan'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Tab 1 (Info) falls back to SnackBar with copy action when SK URL is invalid without calling launcher',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var launcherCalled = false;
        final invalidUrlClub = sampleRemoteClubDetail.copyWith(
          fileSkUrl: 'not-a-valid-http-url',
        );
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => invalidUrlClub),
              urlLauncherProvider.overrideWithValue((
                uri, {
                mode = LaunchMode.platformDefault,
              }) async {
                launcherCalled = true;
                return true;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Salin / Buka tautan berkas SK'));
        await tester.pumpAndSettle();

        expect(launcherCalled, isFalse);
        expect(find.text('Tautan berkas SK tidak valid.'), findsOneWidget);
        expect(find.text('Salin Tautan'), findsOneWidget);

        await tester.tap(find.text('Salin Tautan'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Tab 1 (Info) renders fallback text for missing SK, training, and contacts',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/20',
            overrides: [
              clubDetailProvider(
                20,
              ).overrideWith((ref) async => sampleRemoteClubDetailComplete),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Voli Bina Muda'), findsWidgets);
        expect(find.text('BELUM AKTIF'), findsOneWidget);
        expect(find.text('SK belum tersedia'), findsOneWidget);
        expect(find.text('Berkas belum tersedia'), findsOneWidget);
        expect(find.byTooltip('Salin / Buka tautan berkas SK'), findsNothing);
        expect(find.text('Belum ada data tempat latihan'), findsOneWidget);
        expect(find.text('0 atlet terdaftar di klub'), findsWidgets);
        expect(
          find.text('Cakupan klub dapat meliputi kecamatan lain'),
          findsWidgets,
        );
        expect(find.text('Termasuk atlet dari kecamatan lain'), findsNothing);
      },
    );

    testWidgets(
      'Tab 2 (Pengurus) renders partial management banner, nullable IDs, and mapped reason notices',
      (tester) async {
        var personReached = false;
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
            ],
            onPersonReached: () => personReached = true,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 2
        await tester.tap(find.text('Pengurus'));
        await tester.pumpAndSettle();

        // 1. Management Section
        expect(find.text('Struktur Kepengurusan'), findsOneWidget);
        expect(find.text('Data belum lengkap'), findsOneWidget);
        expect(
          find.text(
            'Data kepengurusan ini bersifat parsial atau terbatas dari SICABOR.',
          ),
          findsOneWidget,
        );
        expect(find.text('Haji Ahmad Subagja'), findsOneWidget);
        expect(find.text('Ketua Umum'), findsOneWidget);
        expect(find.text('Rahmat Hidayat'), findsOneWidget);
        expect(find.text('Sekretaris'), findsOneWidget);

        // 2. Official Section (Mapped reason from NOT_RECORDED_IN_SYSTEM)
        expect(find.text('Official'), findsOneWidget);
        expect(find.text('Belum tercatat di sistem'), findsOneWidget);

        // 3. Pelatih Section (Mapped reason from NOT_AVAILABLE)
        expect(find.text('Pelatih'), findsOneWidget);
        expect(find.text('Data belum tersedia'), findsOneWidget);

        // 4. Test tap on non-null ID item navigates
        await tester.ensureVisible(find.text('Haji Ahmad Subagja'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Haji Ahmad Subagja'));
        await tester.pumpAndSettle();
        expect(personReached, isTrue);
      },
    );

    testWidgets(
      'Tab 2 (Pengurus) renders "Belum tercatat di sistem" when management dataAvailable is false',
      (tester) async {
        final unrecordedClub = sampleRemoteClubDetail.copyWith(
          management: const ClubManagementBlock(
            dataAvailable: false,
            partial: false,
            items: [],
          ),
        );
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => unrecordedClub),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 2
        await tester.tap(find.text('Pengurus'));
        await tester.pumpAndSettle();

        // Management section should show "Belum tercatat di sistem"
        expect(find.text('Struktur Kepengurusan'), findsOneWidget);
        expect(find.text('Belum tercatat di sistem'), findsWidgets);
        expect(find.text('Data belum lengkap'), findsNothing);
      },
    );

    testWidgets(
      'Tab 2 (Pengurus) renders available officials and coaches when dataAvailable is true',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/20',
            overrides: [
              clubDetailProvider(
                20,
              ).overrideWith((ref) async => sampleRemoteClubDetailComplete),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 2
        await tester.tap(find.text('Pengurus'));
        await tester.pumpAndSettle();

        // Management is empty with dataAvailable true -> displays standard empty state
        expect(find.text('Belum ada data kepengurusan.'), findsOneWidget);
        expect(find.text('Data Parsial'), findsNothing);

        // Officials list
        expect(find.text('Bambang S'), findsOneWidget);
        expect(find.text('Manajer Tim'), findsOneWidget);

        // Coaches list
        expect(find.text('Coach Joko'), findsOneWidget);
        expect(find.text('Pelatih Kepala'), findsOneWidget);
      },
    );

    testWidgets(
      'Tab 3 (Atlet) renders athlete list for club, badges, and navigates to /person/:id on tap',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var personReached = false;
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: null, idClub: 10),
                  const AthletePaginationState(
                    items: [sampleAthlete1, sampleAthlete2],
                    total: 2,
                  ),
                ),
              ),
            ],
            onPersonReached: () => personReached = true,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        // Athlete names & details
        expect(find.text('Kevin Sanjaya'), findsOneWidget);
        expect(find.text('Greysia Polii'), findsOneWidget);
        expect(find.text('PB Garuda Perkasa'), findsWidgets);
        expect(find.text('Bulu Tangkis'), findsWidgets);
        expect(find.text('Laki-Laki'), findsWidgets);
        expect(find.text('Perempuan'), findsWidgets);

        // Tap athlete -> navigation
        await tester.tap(find.text('Kevin Sanjaya'));
        await tester.pumpAndSettle();
        expect(personReached, isTrue);
      },
    );

    testWidgets(
      'Tab 3 (Atlet) renders warning banner when filterWarning is present',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: null, idClub: 10),
                  const AthletePaginationState(
                    items: [sampleAthlete1],
                    total: 1,
                    filterWarning: {
                      'code': 'CLUB_MEMBERSHIP_SPARSE',
                      'message':
                          'Keanggotaan club pada data atlet belum lengkap. Hanya menampilkan atlet dengan riwayat klub tercatat.',
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Keanggotaan club pada data atlet belum lengkap. Hanya menampilkan atlet dengan riwayat klub tercatat.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.info_outline), findsWidgets);
      },
    );

    testWidgets(
      'Tab 3 (Atlet) displays reconciliation note between total club members vs local athletes',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: null, idClub: 10),
                  const AthletePaginationState(
                    items: [sampleAthlete1, sampleAthlete2],
                    total: 2,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        // sampleRemoteClubDetail has totalAthleteInClub: 42, state.total: 2
        expect(
          find.text('2 atlet dari kecamatan ini · 42 atlet terdaftar di klub'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tab 3 (Atlet) hides athlete count header when athletePaginationProvider has error',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController((
                  idCabor: null,
                  idClub: 10,
                ), const AthletePaginationState(error: 'Gagal memuat atlet')),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Hasil filter wilayah ini:'), findsNothing);
      },
    );

    testWidgets(
      'Tab 3 (Atlet) handles gender filter chips and search debounce',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: null, idClub: 10),
                  const AthletePaginationState(
                    items: [sampleAthlete1, sampleAthlete2],
                    total: 2,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        // Search bar
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Cari nama atlet...'), findsOneWidget);

        // Filter chips
        expect(find.widgetWithText(FilterChip, 'Semua'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Laki-Laki'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Perempuan'), findsOneWidget);

        // Tap chip
        await tester.tap(find.widgetWithText(FilterChip, 'Perempuan'));
        await tester.pumpAndSettle();

        // Enter search
        await tester.enterText(find.byType(TextField), 'Greysia');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Tab 3 (Atlet) handles empty state when no athletes found for current subdistrict',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController((
                  idCabor: null,
                  idClub: 10,
                ), const AthletePaginationState(items: [], total: 0)),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Tidak ada atlet dari kecamatan ini yang tercatat di klub ini.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Tab 3 (Atlet) handles error state with retry button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/club/10',
          overrides: [
            clubDetailProvider(
              10,
            ).overrideWith((ref) async => sampleRemoteClubDetail),
            athletePaginationProvider((idCabor: null, idClub: 10)).overrideWith(
              () => _TestAthletePaginationController(
                (idCabor: null, idClub: 10),
                const AthletePaginationState(
                  items: [],
                  total: 0,
                  error: BadRequestException('Koneksi ke server terputus'),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Tab 3
      await tester.tap(find.text('Atlet'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat data atlet'), findsOneWidget);
      expect(find.text('Koneksi ke server terputus'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets(
      'Tab 3 (Atlet) handles NO_SUBDISTRICT error without retry button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: null, idClub: 10),
                  const AthletePaginationState(
                    items: [],
                    total: 0,
                    error: ForbiddenException(
                      'Akses ditolak',
                      'NO_SUBDISTRICT',
                      'Akun belum terikat pada kecamatan.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data atlet'), findsOneWidget);
        expect(
          find.text(
            'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
          ),
          findsOneWidget,
        );
        expect(find.text('Coba Lagi'), findsNothing);
      },
    );

    testWidgets(
      'DataMode.remote: fast typing followed by clear (< 500ms) in club athletes tab cancels debounce',
      (tester) async {
        final executedSearches = <String?>[];

        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              dataRequestContextProvider.overrideWithValue(
                const DataRequestContext(
                  environment: AppEnv.production,
                  userId: 'user-1',
                  scope: testScope,
                  generation: 1,
                ),
              ),
              clubDetailProvider(
                10,
              ).overrideWith((ref) async => sampleRemoteClubDetail),
              athletePaginationProvider((
                idCabor: null,
                idClub: 10,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: null, idClub: 10),
                  const AthletePaginationState(items: [], total: 0),
                  (q) => executedSearches.add(q),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 3 (Atlet)
        await tester.tap(find.text('Atlet'));
        await tester.pumpAndSettle();
        executedSearches.clear();

        // 1. Enter query in search bar of club athletes tab
        await tester.enterText(
          find.byType(TextField).first,
          'DiscardedClubAthleteQuery',
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 2. Clear (< 500ms)
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        // 3. Advance 600ms
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(executedSearches.contains('DiscardedClubAthleteQuery'), isFalse);
      },
    );

    testWidgets('renders MissingPage when non-integer club ID is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRemoteTestApp(initialLocation: '/club/invalid-id'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MissingPage), findsOneWidget);
      expect(find.text('Data klub tidak ditemukan.'), findsOneWidget);
    });

    testWidgets('renders MissingPage when provider throws NotFoundException', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/club/999',
          overrides: [
            clubDetailProvider(999).overrideWith((ref) async {
              throw const NotFoundException('Data tidak ditemukan');
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MissingPage), findsOneWidget);
      expect(find.text('Data klub tidak ditemukan.'), findsOneWidget);
    });

    testWidgets(
      'renders error state with retry button on general failure and allows refresh',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(10).overrideWith((ref) async {
                callCount++;
                if (callCount == 1) {
                  throw const ApiTimeoutException();
                }
                return sampleRemoteClubDetail;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat detail klub'), findsOneWidget);
        expect(find.text('Koneksi ke server terganggu.'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);

        // Tap retry button
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.text('PB Garuda Perkasa'), findsWidgets);
      },
    );

    testWidgets(
      'renders NO_SUBDISTRICT error state on club detail without retry button',
      (tester) async {
        await tester.pumpWidget(
          createRemoteTestApp(
            initialLocation: '/club/10',
            overrides: [
              clubDetailProvider(10).overrideWith((ref) async {
                throw const ForbiddenException(
                  'Akses ditolak',
                  'NO_SUBDISTRICT',
                  'Akun belum terikat pada kecamatan.',
                );
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat detail klub'), findsOneWidget);
        expect(
          find.text(
            'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
          ),
          findsOneWidget,
        );
        expect(find.text('Coba Lagi'), findsNothing);
      },
    );

    testWidgets('back button triggers navigation', (tester) async {
      var clubsReached = false;
      await tester.pumpWidget(
        createRemoteTestApp(
          initialLocation: '/club/10',
          overrides: [
            clubDetailProvider(
              10,
            ).overrideWith((ref) async => sampleRemoteClubDetail),
          ],
          onClubsReached: () => clubsReached = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left).first);
      await tester.pumpAndSettle();

      expect(clubsReached, isTrue);
    });
  });

  group('ClubDetailPage Demo Mode Tests', () {
    const demoClub = Club(
      id: 'demo-garuda',
      name: 'Klub Garuda Muda Demo',
      sport: 'Sepak Bola',
      village: 'Pakuwon',
      foundedYear: 2018,
      registrationNumber: 'SK-2018-001',
    );

    const demoPeople = [
      SportPerson(
        id: 'p1',
        name: 'Alya Putri',
        clubId: 'demo-garuda',
        role: 'Atlet',
        group: 'U-18',
      ),
      SportPerson(
        id: 'p2',
        name: 'Coach Dedi',
        clubId: 'demo-garuda',
        role: 'Pelatih',
        group: 'Lisensi C',
      ),
      SportPerson(
        id: 'p3',
        name: 'Official Rudi',
        clubId: 'demo-garuda',
        role: 'Official',
        group: 'Official',
      ),
    ];

    final demoSnapshot = KokSnapshot(
      scope: testScope,
      clubs: const [demoClub],
      people: demoPeople,
      committee: const [],
      loadedAt: DateTime(2026, 9, 21),
    );

    testWidgets(
      'renders 4 tabs (Atlet, Pelatih, Official, Dokumen) and header in demo mode',
      (tester) async {
        await tester.pumpWidget(
          createDemoTestApp(
            snapshot: demoSnapshot,
            initialLocation: '/club/demo-garuda',
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header
        expect(find.text('Klub Garuda Muda Demo'), findsOneWidget);
        expect(
          find.text('1'),
          findsNWidgets(3),
        ); // 1 athlete, 1 coach, 1 official
        expect(find.text('ATLET'), findsOneWidget);
        expect(find.text('PELATIH'), findsOneWidget);
        expect(find.text('OFFICIAL'), findsOneWidget);

        // 2. 4 Tabs present
        expect(find.text('Atlet'), findsWidgets);
        expect(find.text('Pelatih'), findsWidgets);
        expect(find.text('Official'), findsWidgets);
        expect(find.text('Dokumen'), findsWidgets);

        // 3. People in tab
        expect(find.text('Alya Putri'), findsOneWidget);
      },
    );

    testWidgets('renders MissingPage when demo club is not found', (
      tester,
    ) async {
      await tester.pumpWidget(
        createDemoTestApp(
          snapshot: demoSnapshot,
          initialLocation: '/club/non-existent',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MissingPage), findsOneWidget);
    });
  });
}

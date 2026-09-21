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
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/models/club.dart' as domain_club;
import 'package:kok_app/data/models/club_detail.dart';
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
    reason: 'Data official klub belum dipublikasikan oleh pengurus.',
    items: [],
  ),
  coaches: const ClubPersonnelBlock(
    dataAvailable: false,
    reason: 'Data pelatih klub belum dipublikasikan.',
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

void main() {
  setUpAll(() async {
    final font = FontLoader('KokSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });

  group('ClubDetailPage Remote Mode Tests', () {
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
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.byIcon(Icons.share_outlined), findsOneWidget);

        // 3. Counter & Note
        expect(find.text('42'), findsOneWidget);
        expect(find.text('TOTAL ANGGOTA'), findsOneWidget);
        expect(find.text('Termasuk atlet dari kecamatan lain'), findsWidgets);

        // 4. Share button action
        await tester.tap(find.byIcon(Icons.share_outlined));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Info klub disalin'), findsOneWidget);
      },
    );

    testWidgets(
      'Tab 1 (Info) renders identitas, SK, kontak, alamat sekretariat & latihan',
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

        // 1. Identitas section
        expect(find.text('Identitas Klub'), findsOneWidget);
        expect(find.text('Haji Ahmad Subagja'), findsWidgets);
        expect(find.text('2015'), findsOneWidget);
        expect(find.text('Aktif'), findsOneWidget);

        // 2. SK section
        expect(find.text('Surat Keputusan (SK)'), findsOneWidget);
        expect(find.text('SK/012/KONI/2020'), findsOneWidget);
        expect(find.text('Berkas tersedia'), findsOneWidget);

        // 3. Kontak section
        expect(find.text('Kontak'), findsOneWidget);
        expect(find.text('081234567890'), findsWidgets);
        expect(find.text('garuda@example.test'), findsOneWidget);

        // 4. Alamat section
        expect(find.text('Alamat & Lokasi'), findsOneWidget);
        expect(find.text('Sekretariat'), findsOneWidget);
        expect(find.text('Jl. Merdeka No. 45'), findsOneWidget);
        expect(find.text('Kota Kulon'), findsOneWidget);
        expect(find.text('Tempat Latihan'), findsOneWidget);
        expect(
          find.text('GOR Gelora Merdeka, Jl. Cimanuk No. 88'),
          findsOneWidget,
        );
        expect(find.text('Jayawaras'), findsOneWidget);

        // 5. Total Anggota section
        expect(find.text('Total Anggota'), findsOneWidget);
        expect(find.text('42 Atlet'), findsOneWidget);
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
        expect(find.text('Belum ada data tempat latihan'), findsOneWidget);
        expect(find.text('0 Atlet'), findsOneWidget);
      },
    );

    testWidgets(
      'Tab 2 (Pengurus) renders partial management banner, nullable IDs, and unavailable notices',
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
        expect(find.text('Data Parsial'), findsOneWidget);
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

        // 2. Official Section (Unavailable)
        expect(find.text('Official'), findsOneWidget);
        expect(
          find.text('Data official klub belum dipublikasikan oleh pengurus.'),
          findsOneWidget,
        );

        // 3. Pelatih Section (Unavailable)
        expect(find.text('Pelatih'), findsOneWidget);
        expect(
          find.text('Data pelatih klub belum dipublikasikan.'),
          findsOneWidget,
        );

        // 4. Test tap on non-null ID item navigates
        await tester.tap(find.text('Haji Ahmad Subagja'));
        await tester.pumpAndSettle();
        expect(personReached, isTrue);
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

        // Management is empty
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

    testWidgets('Tab 3 (Atlet) renders 4A integration placeholder', (
      tester,
    ) async {
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

      // Switch to Tab 3
      await tester.tap(find.text('Atlet'));
      await tester.pumpAndSettle();

      expect(
        find.text('Daftar atlet klub sedang dalam tahap integrasi.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.sync_outlined), findsOneWidget);
    });

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
                  throw Exception('Network connection timed out');
                }
                return sampleRemoteClubDetail;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat detail klub'), findsOneWidget);
        expect(
          find.textContaining('Network connection timed out'),
          findsOneWidget,
        );
        expect(find.text('Coba Lagi'), findsOneWidget);

        // Tap retry button
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.text('PB Garuda Perkasa'), findsWidgets);
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

      await tester.tap(find.byIcon(Icons.chevron_left));
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

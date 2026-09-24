import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models.dart' as demo;
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/club_service.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';
import 'package:kok_app/features/clubs_page.dart';

class _DummyAuthTokenStorage implements AuthTokenStorage {
  @override
  Future<StoredCredential?> read() async => null;
  @override
  Future<void> write(StoredCredential credential) async {}
  @override
  Future<bool> clearIfOwnedBy(String credentialId) async => true;
  @override
  Future<void> forceClearForRecovery() async {}
  @override
  Future<void> migrateLegacyStorage() async {}
}

class _DummySessionMetadataStore implements SessionMetadataStore {
  @override
  Future<SessionMetadata?> read() async => null;
  @override
  Future<void> write(SessionMetadata metadata) async {}
  @override
  Future<void> clear() async {}
}

class _DummyRememberedUsernameStore implements RememberedUsernameStore {
  @override
  Future<String?> readUsername() async => null;
  @override
  Future<void> saveUsername(String username) async {}
  @override
  Future<void> clear() async {}
}

class _DummyCredentialIdGenerator implements CredentialIdGenerator {
  @override
  String generate() => 'cred-123';
}

const _testContext = DataRequestContext(
  environment: AppEnv.staging,
  userId: 'user-123',
  scope: AccessScope(
    type: AccessScopeType.district,
    id: '1728',
    name: 'Garut Kota',
  ),
  generation: 1,
);

Club _createTestClub({
  int id = 1,
  String name = 'PB Garuda',
  String caborName = 'Bulutangkis',
  int status = 1,
  int totalAthlete = 10,
  String? headName,
  String? address,
  String subdistrictName = 'Garut Kota',
}) {
  return Club(
    id: id,
    code: 'KLUB-$id',
    name: name,
    cabor: ClubCabor(id: 1, code: 'CB-1', name: caborName),
    headName: headName,
    status: status,
    statusLabel: status == 1 ? 'Aktif' : 'Belum Aktif',
    secretariat: ClubAddress(
      address: address,
      subdistrictId: 1728,
      subdistrictName: subdistrictName,
      districtId: 126,
      districtName: 'Garut',
    ),
    totalAthleteInClub: totalAthlete,
  );
}

class MockClubService implements ClubService {
  MockClubService({this.onFetchList, this.onFetchDetail});

  final Future<PaginatedResult<Club>> Function({
    int limit,
    int offset,
    int? idCabor,
    int? status,
    String? search,
    String sort,
    RequestCancellation? cancellation,
  })?
  onFetchList;

  final Future<ClubDetail> Function(
    int id, {
    RequestCancellation? cancellation,
  })?
  onFetchDetail;

  @override
  Future<PaginatedResult<Club>> fetchClubList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? status,
    String? search,
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    if (onFetchList != null) {
      return onFetchList!(
        limit: limit,
        offset: offset,
        idCabor: idCabor,
        status: status,
        search: search,
        sort: sort,
        cancellation: cancellation,
      );
    }
    return const PaginatedResult(items: [], limit: 25, offset: 0, total: 0);
  }

  @override
  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    if (onFetchDetail != null) {
      return onFetchDetail!(id, cancellation: cancellation);
    }
    throw UnimplementedError();
  }
}

AppComposition _createTestComposition({
  DataMode dataMode = DataMode.remote,
  ClubService? clubService,
}) {
  final demoRepo = DemoKokRepository(simulateLatency: false);
  return AppComposition(
    profile: DeploymentProfile(
      environment: dataMode == DataMode.remote ? AppEnv.staging : AppEnv.demo,
      authMode: dataMode == DataMode.remote ? AuthMode.remote : AuthMode.demo,
      dataMode: dataMode,
      apiBaseUrl: dataMode == DataMode.remote
          ? 'https://staging.example.com'
          : '',
    ),
    authTokenStorage: _DummyAuthTokenStorage(),
    sessionMetadataStore: _DummySessionMetadataStore(),
    rememberedUsernameStore: _DummyRememberedUsernameStore(),
    authRepository: DemoAuthRepository(simulateLatency: false),
    kokRepository: demoRepo,
    profileService: DemoProfileService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    caborService: DemoCaborService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    athleteService: DemoAthleteService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    clubService:
        clubService ??
        DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => const AccessScope(
            type: AccessScopeType.district,
            id: '1728',
            name: 'Garut Kota',
          ),
        ),
    credentialIdGenerator: _DummyCredentialIdGenerator(),
  );
}

Widget _buildTestApp({
  required Widget child,
  required AppComposition composition,
  ClubService? clubService,
  demo.KokSnapshot? snapshot,
  GoRouter? router,
}) {
  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/clubs',
        routes: [
          GoRoute(path: '/clubs', builder: (_, _) => child),
          GoRoute(
            path: '/club/:id',
            builder: (context, state) => Scaffold(
              body: Text('Club Detail: ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/sports',
            builder: (_, _) => const Scaffold(body: Text('Sports Page')),
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      appCompositionProvider.overrideWithValue(composition),
      dataRequestContextProvider.overrideWithValue(_testContext),
      if (clubService != null)
        clubServiceProvider.overrideWithValue(clubService),
      if (snapshot != null)
        snapshotProvider.overrideWith((ref) async => snapshot),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  group('ClubsPage - Remote Mode', () {
    testWidgets('Renders club list with club cards, badges, and stats', (
      tester,
    ) async {
      final clubs = [
        _createTestClub(
          id: 101,
          name: 'PB Djarum Garut',
          caborName: 'Bulutangkis',
          headName: 'Budi Santoso',
          address: 'Jl. Merdeka No. 10',
          status: 1,
          totalAthlete: 15,
        ),
        _createTestClub(
          id: 102,
          name: 'Garuda Muda FC',
          caborName: 'Sepak Bola',
          subdistrictName: 'Tarogong Kidul',
          status: 0,
          totalAthlete: 8,
        ),
      ];

      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              return PaginatedResult(
                items: clubs,
                limit: limit,
                offset: offset,
                total: 2,
                filterWarning: const {'message': 'Data sebagian terbatas'},
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();

      // Dynamic count in AppBar
      expect(find.widgetWithText(AppBar, 'Klub'), findsOneWidget);
      expect(find.text('2 klub terdaftar'), findsOneWidget);

      // Warning banner
      expect(find.text('Data sebagian terbatas'), findsOneWidget);

      // Chips
      expect(find.widgetWithText(FilterChip, 'Semua'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Aktif'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Belum Aktif'), findsOneWidget);

      // Club 1 details
      expect(find.text('PB Djarum Garut'), findsOneWidget);
      expect(find.text('Ketua: Budi Santoso'), findsOneWidget);
      expect(find.text('Sekretariat: Jl. Merdeka No. 10'), findsOneWidget);
      expect(find.text('Bulutangkis'), findsOneWidget);
      expect(find.text('15 atlet terdaftar di klub'), findsOneWidget);

      // Club 2 details
      expect(find.text('Garuda Muda FC'), findsOneWidget);
      expect(find.text('Kec. Tarogong Kidul'), findsOneWidget);
      expect(find.text('Sepak Bola'), findsOneWidget);
      expect(find.text('8 atlet terdaftar di klub'), findsOneWidget);
    });

    testWidgets('Tapping status chip updates filter', (tester) async {
      int? lastStatus;
      var fetchCount = 0;

      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              fetchCount++;
              lastStatus = status;
              return PaginatedResult(
                items: [
                  _createTestClub(id: 1, name: 'PB Test', status: status ?? 1),
                ],
                limit: limit,
                offset: offset,
                total: 1,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();
      expect(lastStatus, isNull);

      // Tap 'Aktif'
      await tester.tap(find.widgetWithText(FilterChip, 'Aktif'));
      await tester.pumpAndSettle();
      expect(lastStatus, 1);

      // Tap 'Belum Aktif'
      await tester.tap(find.widgetWithText(FilterChip, 'Belum Aktif'));
      await tester.pumpAndSettle();
      expect(lastStatus, 0);

      // Tap 'Semua'
      await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
      await tester.pumpAndSettle();
      expect(lastStatus, isNull);
      expect(fetchCount, 4);
    });

    testWidgets('Entering search query debounces 500ms and updates search', (
      tester,
    ) async {
      String? lastSearch;

      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              lastSearch = search;
              return const PaginatedResult(
                items: [],
                limit: 25,
                offset: 0,
                total: 0,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();
      expect(lastSearch, isNull);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Garuda');
      await tester.pump(const Duration(milliseconds: 200));
      expect(lastSearch, isNull); // not yet debounced

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(lastSearch, 'Garuda');

      // Clear search with icon
      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pumpAndSettle();
      expect(lastSearch, isNull);
    });

    testWidgets(
      'Fast typing followed by clear (< 500ms) cancels debounce and does not execute discarded query',
      (tester) async {
        final executedSearches = <String?>[];

        final mockService = MockClubService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                int? idCabor,
                int? status,
                String? search,
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                executedSearches.add(search);
                return const PaginatedResult(
                  items: [],
                  limit: 25,
                  offset: 0,
                  total: 0,
                );
              },
        );

        final composition = _createTestComposition(
          dataMode: DataMode.remote,
          clubService: mockService,
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: const ClubsPage(),
            composition: composition,
            clubService: mockService,
          ),
        );
        await tester.pumpAndSettle();
        executedSearches.clear();

        // 1. Enter query
        await tester.enterText(find.byType(TextField), 'DiscardedQuery');
        await tester.pump(const Duration(milliseconds: 200));

        // 2. Clear within 500ms
        await tester.tap(find.byTooltip('Hapus pencarian'));
        await tester.pumpAndSettle();

        // 3. Advance past the original debounce duration
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // 'DiscardedQuery' must never have been requested
        expect(executedSearches.contains('DiscardedQuery'), isFalse);
      },
    );

    testWidgets('Opening sort modal and selecting option updates sort', (
      tester,
    ) async {
      String lastSort = 'name';

      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              lastSort = sort;
              return const PaginatedResult(
                items: [],
                limit: 25,
                offset: 0,
                total: 0,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();

      // Tap sort button in AppBar
      await tester.tap(find.byTooltip('Urutkan klub'));
      await tester.pumpAndSettle();

      expect(find.text('Urutkan Klub'), findsOneWidget);
      expect(find.text('Nama (A → Z)'), findsOneWidget);
      expect(find.text('Kode Klub'), findsOneWidget);
      expect(find.text('Tahun Berdiri'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);

      // Tap 'Kode Klub'
      await tester.tap(find.text('Kode Klub'));
      await tester.pumpAndSettle();

      expect(find.text('Urutkan Klub'), findsNothing);
      expect(lastSort, 'code');

      // Open sort modal again and tap 'Tahun Berdiri'
      await tester.tap(find.byTooltip('Urutkan klub'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tahun Berdiri'));
      await tester.pumpAndSettle();
      expect(lastSort, 'since');

      // Open sort modal again and tap 'Status'
      await tester.tap(find.byTooltip('Urutkan klub'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();
      expect(lastSort, 'status');
    });

    testWidgets('Empty state is displayed when items list is empty', (
      tester,
    ) async {
      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              return const PaginatedResult(
                items: [],
                limit: 25,
                offset: 0,
                total: 0,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada klub yang sesuai dengan filter.'),
        findsOneWidget,
      );
      expect(find.text('Reset filter'), findsOneWidget);

      // Tapping reset filter resets search and filters
      await tester.tap(find.text('Reset filter'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tidak ada klub yang sesuai dengan filter.'),
        findsOneWidget,
      );
    });

    testWidgets('Error state is displayed with retry button on error', (
      tester,
    ) async {
      var callCount = 0;

      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              callCount++;
              if (callCount == 1) {
                throw Exception('Koneksi internet terputus');
              }
              return PaginatedResult(
                items: [_createTestClub(id: 1, name: 'PB Sukses')],
                limit: limit,
                offset: offset,
                total: 1,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat data klub'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat data klub'), findsNothing);
      expect(find.text('PB Sukses'), findsOneWidget);
    });

    testWidgets('Tapping club card navigates to /club/:id', (tester) async {
      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              return PaginatedResult(
                items: [_createTestClub(id: 77, name: 'Klub Perkasa')],
                limit: limit,
                offset: offset,
                total: 1,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Klub Perkasa'), findsOneWidget);
      await tester.tap(find.text('Klub Perkasa'));
      await tester.pumpAndSettle();

      expect(find.text('Club Detail: 77'), findsOneWidget);
    });

    testWidgets('Infinite scroll pagination and load-more error retry row', (
      tester,
    ) async {
      var loadMoreCalled = false;
      var loadMoreSucceed = false;

      final page1 = List.generate(
        25,
        (i) => _createTestClub(id: i + 1, name: 'Club ${i + 1}'),
      );
      final page2 = [_createTestClub(id: 26, name: 'Club 26')];

      final mockService = MockClubService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              if (offset == 0) {
                return PaginatedResult(
                  items: page1,
                  limit: limit,
                  offset: 0,
                  total: 26,
                );
              }
              loadMoreCalled = true;
              if (!loadMoreSucceed) {
                throw Exception('Gagal load more');
              }
              return PaginatedResult(
                items: page2,
                limit: limit,
                offset: 25,
                total: 26,
              );
            },
      );

      final composition = _createTestComposition(
        dataMode: DataMode.remote,
        clubService: mockService,
      );

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          clubService: mockService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Club 1'), findsOneWidget);

      // Scroll to bottom until error row is visible
      await tester.scrollUntilVisible(
        find.text('Gagal memuat klub berikutnya'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(loadMoreCalled, isTrue);
      expect(find.text('Gagal memuat klub berikutnya'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      // Retry load more
      loadMoreSucceed = true;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Club 26'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Club 26'), findsOneWidget);
    });
  });

  group('ClubsPage - Demo Mode', () {
    testWidgets('Existing demo mode works as expected without regressions', (
      tester,
    ) async {
      final demoSnapshot = demo.KokSnapshot(
        scope: const AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        ),
        clubs: const [
          demo.Club(
            id: 'garuda',
            name: 'Klub Garuda Muda',
            sport: 'Sepak Bola',
            village: 'Pakuwon',
            active: true,
          ),
          demo.Club(
            id: 'pb',
            name: 'PB Citra Garut',
            sport: 'Bulu Tangkis',
            village: 'Paminggir',
            active: false,
          ),
        ],
        people: const [
          demo.SportPerson(
            id: 'p1',
            name: 'Atlet Satu',
            clubId: 'garuda',
            role: 'Atlet',
            group: 'U-16',
          ),
          demo.SportPerson(
            id: 'p2',
            name: 'Pelatih Satu',
            clubId: 'garuda',
            role: 'Pelatih',
            group: 'Lisensi C',
          ),
        ],
        committee: const [],
        loadedAt: DateTime(2026, 9, 5),
      );

      final composition = _createTestComposition(dataMode: DataMode.demo);

      await tester.pumpWidget(
        _buildTestApp(
          child: const ClubsPage(),
          composition: composition,
          snapshot: demoSnapshot,
        ),
      );
      await tester.pumpAndSettle();

      // Dynamic count
      expect(find.text('Klub (2)'), findsOneWidget);
      expect(find.text('2 klub · 2 cabor'), findsOneWidget);

      // Chips
      expect(find.text('Semua'), findsOneWidget);
      expect(find.widgetWithText(FilterChipDropdown, 'Cabor'), findsOneWidget);
      expect(find.widgetWithText(FilterChipDropdown, 'Status'), findsOneWidget);
      expect(find.widgetWithText(FilterChipDropdown, 'Kel.'), findsOneWidget);

      // Club items
      expect(find.text('Klub Garuda Muda'), findsOneWidget);
      expect(find.text('PB Citra Garut'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Pasif'), findsOneWidget);

      // Search filtering
      await tester.enterText(find.byType(TextField), 'PB');
      await tester.pumpAndSettle();
      expect(find.text('Klub Garuda Muda'), findsNothing);
      expect(find.text('PB Citra Garut'), findsOneWidget);

      // Clear search
      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pumpAndSettle();
      expect(find.text('Klub Garuda Muda'), findsOneWidget);

      // Sort modal
      await tester.tap(find.byTooltip('Urutkan klub'));
      await tester.pumpAndSettle();
      expect(find.text('Urutkan Klub'), findsOneWidget);
      await tester.tap(find.text('Jumlah Atlet Terbanyak'));
      await tester.pumpAndSettle();
      expect(find.text('Urutkan Klub'), findsNothing);

      // Tap card navigates
      await tester.tap(find.text('Klub Garuda Muda'));
      await tester.pumpAndSettle();
      expect(find.text('Club Detail: garuda'), findsOneWidget);
    });
  });
}

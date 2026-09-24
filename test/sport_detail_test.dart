import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/club.dart' as domain;
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';
import 'package:kok_app/features/sport_detail/sport_detail_page.dart';

class _FakeSecureKeyValStore implements SecureKeyValStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read({required String key}) async => _data[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      _data[key] = value;
  @override
  Future<void> delete({required String key}) async => _data.remove(key);
  @override
  Future<bool> containsKey({required String key}) async =>
      _data.containsKey(key);
}

class _FakeRemoteCaborService implements CaborService {
  _FakeRemoteCaborService(this.cabors);
  final List<Cabor> cabors;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final items = cabors.skip(offset).take(limit).toList();
    return PaginatedResult<Cabor>(
      items: items,
      limit: limit,
      offset: offset,
      total: cabors.length,
    );
  }
}

class _TestCaborPaginationController extends CaborPaginationController {
  _TestCaborPaginationController(this._initialState);
  final CaborPaginationState _initialState;

  @override
  CaborPaginationState build() => _initialState;
}

class _TestAthletePaginationController extends AthletePaginationController {
  _TestAthletePaginationController(
    super.scope, [
    this._initialState = const AthletePaginationState(),
    this.onSearchUpdated,
  ]);

  final AthletePaginationState _initialState;
  final void Function(String?)? onSearchUpdated;

  @override
  AthletePaginationState build() => _initialState;

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

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

class _TestClubPaginationController extends ClubPaginationController {
  _TestClubPaginationController(
    super.idCabor, [
    this._initialState = const ClubPaginationState(),
    this.onSearchUpdated,
  ]);

  final ClubPaginationState _initialState;
  final void Function(String?)? onSearchUpdated;

  @override
  ClubPaginationState build() => _initialState;

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  void updateSearch(String? query) {
    onSearchUpdated?.call(query);
    state = query == null
        ? state.copyWith(clearSearch: true)
        : state.copyWith(search: query);
  }

  @override
  void updateStatusFilter(int? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }
}

Future<AppComposition> _createTestComposition({
  DataMode dataMode = DataMode.demo,
  List<Cabor> remoteCabors = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final profile = dataMode == DataMode.demo
      ? const DeploymentProfile(
          environment: AppEnv.demo,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        )
      : const DeploymentProfile(
          environment: AppEnv.staging,
          authMode: AuthMode.remote,
          dataMode: DataMode.remote,
          apiBaseUrl: 'https://sicabor.test/api/v1/kok',
        );

  final tokenStorage = SecureAuthTokenStorage(
    store: _FakeSecureKeyValStore(),
    key: 'test_token',
  );
  final metadataStore = SharedPrefsSessionMetadataStore(
    prefs: prefs,
    key: 'test_metadata',
  );
  final usernameStore = RememberedUsernameStore(
    prefs: prefs,
    key: 'test_username',
  );

  final demoKokRepo = DemoKokRepository(simulateLatency: false);
  final profileService = DemoProfileService(
    demoRepo: demoKokRepo,
    currentScopeProvider: () => const AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
  );
  final caborService = dataMode == DataMode.remote
      ? _FakeRemoteCaborService(remoteCabors)
      : DemoCaborService(
          demoRepo: demoKokRepo,
          currentScopeProvider: () => const AccessScope(
            type: AccessScopeType.district,
            id: '1728',
            name: 'Garut Kota',
          ),
        );

  final demoAthleteService = DemoAthleteService(
    demoRepo: demoKokRepo,
    currentScopeProvider: () => const AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
  );
  final demoClubService = DemoClubService(
    demoRepo: demoKokRepo,
    currentScopeProvider: () => const AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
  );

  return AppComposition(
    profile: profile,
    authTokenStorage: tokenStorage,
    sessionMetadataStore: metadataStore,
    rememberedUsernameStore: usernameStore,
    authRepository: DemoAuthRepository(simulateLatency: false),
    kokRepository: demoKokRepo,
    profileService: profileService,
    caborService: caborService,
    athleteService: demoAthleteService,
    clubService: demoClubService,
    credentialIdGenerator: UuidCredentialIdGenerator(),
  );
}

void main() {
  const garutScope = AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  );

  final userWithExport = UserPrincipal(
    id: 'usr_garut_kota',
    username: 'DEMO-001',
    fullName: 'Pak Asep',
    roleTitle: 'Koordinator Kecamatan',
    scope: garutScope,
    permissions: const {'sports:read', 'reports:export'},
  );

  final userWithoutExport = UserPrincipal(
    id: 'usr_tarogong_kidul',
    username: 'DEMO-002',
    fullName: 'Pak Cecep',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'tarogong_kidul',
      name: 'Kecamatan Tarogong Kidul',
    ),
    permissions: const {'sports:read'},
  );

  group('SportDetailPage Widget Tests', () {
    testWidgets('remote identity retry reloads a failed page', (tester) async {
      var attempts = 0;
      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            currentUserProvider.overrideWithValue(userWithExport),
            dataRequestContextProvider.overrideWithValue(
              DataRequestContext(
                environment: AppEnv.staging,
                userId: '1',
                scope: userWithExport.scope,
                generation: 1,
              ),
            ),
            caborListProvider((
              offset: 0,
              limit: 100,
              source: 'all',
              sort: 'name',
            )).overrideWith((ref) async {
              attempts++;
              if (attempts == 1) throw StateError('temporary failure');
              return const PaginatedResult<Cabor>(
                items: [],
                limit: 100,
                offset: 0,
                total: 0,
              );
            }),
          ],
          child: const MaterialApp(home: SportDetailPage(sport: '31')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Cabang olahraga tidak ditemukan.'), findsOneWidget);
    });

    for (final counts in [(clubs: 0, athletes: 2), (clubs: 3, athletes: 0)]) {
      testWidgets('remote counts remain independent: $counts', (tester) async {
        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              caborByIdProvider(31).overrideWith(
                (ref) => Cabor(
                  id: 31,
                  code: 'CB',
                  name: 'Cabor Mandiri',
                  status: 1,
                  statusLabel: 'Aktif',
                  totalClub: counts.clubs,
                  totalAthlete: counts.athletes,
                ),
              ),
              athletePaginationProvider((
                idCabor: 31,
                idClub: null,
              )).overrideWith(
                () => _TestAthletePaginationController((
                  idCabor: 31,
                  idClub: null,
                )),
              ),
              clubPaginationProvider(
                31,
              ).overrideWith(() => _TestClubPaginationController(31)),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '31')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('${counts.clubs}'), findsOneWidget);
        expect(find.text('${counts.athletes}'), findsOneWidget);
        expect(find.text('Cari nama atlet...'), findsOneWidget);
        await tester.tap(find.text('Klub'));
        await tester.pumpAndSettle();
        expect(find.text('Cari nama klub...'), findsOneWidget);
      });
    }
    testWidgets('remote direct link waits without zeros then shows not found', (
      tester,
    ) async {
      final pending = Completer<Cabor?>();
      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            currentUserProvider.overrideWithValue(userWithExport),
            caborByIdProvider(999).overrideWith((ref) => pending.future),
          ],
          child: const MaterialApp(home: SportDetailPage(sport: '999')),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Cabang olahraga tidak ditemukan.'), findsOneWidget);
    });

    Widget buildSubject({
      String sport = 'Sepak Bola',
      GoRouter? router,
      AccessScope scope = garutScope,
      UserPrincipal? user,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          snapshotProvider.overrideWith(
            (ref) => DemoKokRepository().fetchScope(scope),
          ),
        ],
        child: MaterialApp.router(
          routerConfig:
              router ??
              GoRouter(
                initialLocation: '/sport/$sport',
                routes: [
                  GoRoute(
                    path: '/sport/:id',
                    builder: (_, s) =>
                        SportDetailPage(sport: s.pathParameters['id'] ?? sport),
                  ),
                  GoRoute(
                    path: '/club/:id',
                    builder: (_, s) =>
                        Scaffold(body: Text('Club: ${s.pathParameters['id']}')),
                  ),
                  GoRoute(
                    path: '/person/:id',
                    builder: (_, s) => Scaffold(
                      body: Text('Person: ${s.pathParameters['id']}'),
                    ),
                  ),
                ],
              ),
        ),
      );
    }

    testWidgets('renders sport dynamic header, floating stats card, and tabs', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      expect(find.text('Sepak Bola'), findsWidgets);
      expect(find.text('Kecamatan Garut Kota'), findsWidgets);
      expect(find.text('Klub'), findsWidgets);
      expect(find.text('Atlet'), findsWidgets);
      expect(find.text('Pelatih'), findsWidgets);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('resolves numeric ID in demo mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: '2'));
      await tester.pumpAndSettle();

      // Sport 2 in sorted list is Bulu Tangkis
      expect(find.text('Bulu Tangkis'), findsWidgets);
      expect(find.text('Kecamatan Garut Kota'), findsWidgets);
    });

    testWidgets(
      'renders analytic fl_chart and toggles between age groups and document status',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
        await tester.pumpAndSettle();

        expect(find.text('Kelompok Usia'), findsOneWidget);
        expect(find.text('Status Berkas'), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);

        await tester.tap(find.text('Status Berkas'));
        await tester.pumpAndSettle();

        expect(find.byType(PieChart), findsOneWidget);
      },
    );

    testWidgets(
      'switches to Atlet tab, filters age group, and taps athlete to open detail',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Atlet').first);
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Semua'), findsWidgets);

        await tester.tap(find.text('U-16'));
        await tester.pumpAndSettle();

        final firstPerson = find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.textContaining('Atlet'),
            )
            .first;
        await tester.tap(firstPerson);
        await tester.pumpAndSettle();

        expect(find.textContaining('Person:'), findsOneWidget);
      },
    );

    testWidgets('switches to Pelatih tab and taps coach to open detail', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pelatih').first);
      await tester.pumpAndSettle();

      final coachFinder = find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.textContaining('Pelatih'),
          )
          .first;
      await tester.tap(coachFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Person:'), findsOneWidget);
    });

    testWidgets(
      'SC-30: user without reports:export cannot export (share button disabled)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildSubject(sport: 'Sepak Bola', user: userWithoutExport),
        );
        await tester.pumpAndSettle();

        final shareBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.share_outlined),
        );
        expect(shareBtn.onPressed, isNull);
        expect(shareBtn.tooltip, 'Akses ekspor laporan tidak diizinkan');
        final icon = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
        expect(icon.color, Colors.white38);

        final bottomCopyButton = tester.widget<ButtonStyleButton>(
          find.widgetWithText(FilledButton, 'Salin Rekapitulasi Cabor'),
        );
        expect(bottomCopyButton.onPressed, isNull);
      },
    );

    testWidgets(
      'SC-30: user with reports:export can export and summary contains dynamic scope name',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          buildSubject(sport: 'Sepak Bola', user: userWithExport),
        );
        await tester.pumpAndSettle();

        final shareBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.share_outlined),
        );
        expect(shareBtn.onPressed, isNotNull);
        expect(shareBtn.tooltip, 'Bagikan info cabor');
        final icon = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
        expect(icon.color, Colors.white);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.share_outlined));
        await tester.pumpAndSettle();

        expect(copiedText, isNotNull);
        expect(copiedText, contains('REKAPITULASI CABANG OLAHRAGA'));
        expect(copiedText, contains('Cabang Olahraga : Sepak Bola'));
        expect(copiedText, contains('Wilayah         : Kecamatan Garut Kota'));
        expect(
          find.text(
            'Rekapitulasi cabor Sepak Bola berhasil disalin ke papan klip.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders dynamic territory name from snapshot scope in header',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const tarogongScope = AccessScope(
          type: AccessScopeType.district,
          id: 'tarogong_kidul',
          name: 'Kecamatan Tarogong Kidul',
        );

        await tester.pumpWidget(
          buildSubject(
            sport: 'Sepak Bola',
            scope: tarogongScope,
            user: userWithExport,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kecamatan Tarogong Kidul'), findsWidgets);
        expect(find.text('Kecamatan Garut Kota'), findsNothing);
      },
    );

    testWidgets(
      'DataMode.remote: renders contract-backed cabor identity and two tabs',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-042',
          name: 'Arung Jeram',
          groupName: 'FAJI',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 7,
          totalAthlete: 64,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        const remoteSummary = ProfileSummary(
          scope: SicaborScope(
            subdistrictId: 1728,
            subdistrictName: 'Kecamatan Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
          member: SicaborMember(
            id: 1,
            username: 'admin',
            name: 'Pak Asep',
            type: 'admin',
            status: 1,
            statusLabel: 'Aktif',
          ),
          totalCabor: 1,
          totalCaborFromClub: 1,
          totalCaborFromAthlete: 1,
          totalClub: 7,
          totalAthlete: 64,
          totalAthleteWithoutClub: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              profileSummaryProvider.overrideWith((ref) => remoteSummary),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();

        // Header shows cabor name and scope name
        expect(find.text('Arung Jeram'), findsWidgets);
        expect(find.text('Kecamatan Garut Kota'), findsWidgets);

        // Stats card shows club & athlete counts from remote cabor
        expect(find.text('7'), findsOneWidget);
        expect(find.text('64'), findsOneWidget);

        expect(find.text('FAJI'), findsOneWidget);
        expect(find.text('Pelatih'), findsNothing);
        expect(find.textContaining('Berkas Lengkap'), findsNothing);
        expect(find.byType(BarChart), findsNothing);
        expect(find.byType(PieChart), findsNothing);
        expect(find.byKey(const Key('detail-header-lip')), findsOneWidget);
        final tabs = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabs.tabs.map((tab) => (tab as Tab).text), ['Atlet', 'Klub']);
      },
    );

    testWidgets(
      'DataMode.remote: switches to Tab Atlet and renders remote athlete cards, search bar, and filter chips',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 7,
          totalAthlete: 64,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        final athlete1 = const Athlete(
          id: 101,
          code: 'KGAT-001',
          name: 'Budi Raharja',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          photoUrl: '',
          status: 1,
          statusLabel: 'Aktif',
          cabor: AthleteCabor(id: 42, code: 'CB-42', name: 'Arung Jeram'),
          club: AthleteClub(
            id: 10,
            code: 'CL-10',
            name: 'Klub Cimanuk Rafting',
          ),
          domicile: AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
        );

        final athlete2 = const Athlete(
          id: 102,
          code: 'KGAT-002',
          name: 'Siti Aminah',
          sex: 'p',
          sexLabel: 'Perempuan',
          photoUrl: '',
          status: 1,
          statusLabel: 'Aktif',
          cabor: AthleteCabor(id: 42, code: 'CB-42', name: 'Arung Jeram'),
          domicile: AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
        );

        String? pushedRoute;
        final router = GoRouter(
          initialLocation: '/sport/42',
          routes: [
            GoRoute(
              path: '/sport/:id',
              builder: (context, state) => const SportDetailPage(sport: '42'),
            ),
            GoRoute(
              path: '/person/:id',
              builder: (context, state) {
                pushedRoute = state.uri.toString();
                return Scaffold(
                  body: Text('Person ${state.pathParameters['id']}'),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              athletePaginationProvider((
                idCabor: 42,
                idClub: null,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: 42, idClub: null),
                  AthletePaginationState(
                    items: [athlete1, athlete2],
                    total: 2,
                    filterWarning: const {
                      'message':
                          'Menampilkan atlet terdaftar di klub wilayah Garut Kota.',
                    },
                  ),
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab Atlet (index 1)
        await tester.tap(find.text('Atlet').first);
        await tester.pumpAndSettle();

        // Search bar is present
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Cari nama atlet...'), findsOneWidget);

        // Gender filter chips are present
        expect(find.widgetWithText(FilterChip, 'Semua'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Laki-Laki'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Perempuan'), findsOneWidget);

        // Filter warning banner is displayed
        expect(
          find.text('Menampilkan atlet terdaftar di klub wilayah Garut Kota.'),
          findsOneWidget,
        );

        // Athlete cards are rendered with code, name, club, and statusLabel
        expect(find.text('Budi Raharja'), findsOneWidget);
        expect(find.text('KGAT-001'), findsOneWidget);
        expect(find.text('Klub Cimanuk Rafting'), findsOneWidget);

        expect(find.text('Siti Aminah'), findsOneWidget);
        expect(find.text('KGAT-002'), findsOneWidget);
        expect(find.text('Belum terdaftar di klub'), findsOneWidget);

        expect(find.text('Aktif'), findsWidgets);

        // Tap athlete card -> navigates to /person/101
        await tester.tap(find.text('Budi Raharja'));
        await tester.pumpAndSettle();
        expect(pushedRoute, '/person/101');
      },
    );

    testWidgets(
      'DataMode.remote: Tab Atlet shows empty state when athlete list is empty',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 0,
          totalAthlete: 0,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              athletePaginationProvider((
                idCabor: 42,
                idClub: null,
              )).overrideWith(
                () => _TestAthletePaginationController((
                  idCabor: 42,
                  idClub: null,
                ), const AthletePaginationState(items: [], total: 0)),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab Atlet
        await tester.tap(find.text('Atlet').first);
        await tester.pumpAndSettle();

        expect(
          find.text('Tidak ada atlet yang sesuai dengan filter.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DataMode.remote: Tab Atlet shows error view when error occurs',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              athletePaginationProvider((
                idCabor: 42,
                idClub: null,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: 42, idClub: null),
                  const AthletePaginationState(
                    items: [],
                    total: 0,
                    error: BadRequestException('Koneksi ke server terputus'),
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab Atlet
        await tester.tap(find.text('Atlet').first);
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data atlet'), findsOneWidget);
        expect(find.text('Koneksi ke server terputus'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);
      },
    );

    testWidgets(
      'DataMode.remote: Tab Atlet handles NO_SUBDISTRICT without retry button',
      (tester) async {
        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              athletePaginationProvider((
                idCabor: 42,
                idClub: null,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: 42, idClub: null),
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
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab Atlet
        await tester.tap(find.text('Atlet').first);
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
      'DataMode.remote: renders remote clubs list with club cards, name, status, cabor badge, and member count',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 2,
          totalAthlete: 12,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        final club1 = domain.Club(
          id: 1,
          code: 'KLUB-001',
          name: 'PB Garuda Perkasa',
          headName: 'Bambang Sudirman',
          cabor: const domain.ClubCabor(
            id: 42,
            code: 'CB-42',
            name: 'Arung Jeram',
          ),
          status: 1,
          statusLabel: 'Aktif',
          secretariat: const domain.ClubAddress(
            address: 'Jl. Ahmad Yani No. 45',
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
          totalAthleteInClub: 12,
        );

        final club2 = domain.Club(
          id: 2,
          code: 'KLUB-002',
          name: 'Klub Cimanuk Bahari',
          cabor: const domain.ClubCabor(
            id: 42,
            code: 'CB-42',
            name: 'Arung Jeram',
          ),
          status: 0,
          statusLabel: 'Belum Aktif',
          secretariat: const domain.ClubAddress(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
          totalAthleteInClub: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              clubPaginationProvider(42).overrideWith(
                () => _TestClubPaginationController(
                  42,
                  ClubPaginationState(
                    items: [club1, club2],
                    total: 2,
                    filterWarning: const {
                      'message':
                          'Menampilkan klub terdaftar di wilayah Garut Kota.',
                    },
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Klub').first);
        await tester.pumpAndSettle();

        // Search bar is present
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Cari nama klub...'), findsOneWidget);

        // Status filter chips are present
        expect(find.widgetWithText(FilterChip, 'Semua'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Aktif'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Belum Aktif'), findsOneWidget);

        // Filter warning banner is displayed
        expect(
          find.text('Menampilkan klub terdaftar di wilayah Garut Kota.'),
          findsOneWidget,
        );

        // Club 1 card details
        expect(find.text('PB Garuda Perkasa'), findsOneWidget);
        expect(find.text('Ketua: Bambang Sudirman'), findsOneWidget);
        expect(find.text('Jl. Ahmad Yani No. 45'), findsOneWidget);
        expect(find.text('12 Atlet'), findsOneWidget);

        // Club 2 card details
        expect(find.text('Klub Cimanuk Bahari'), findsOneWidget);
        expect(find.text('Kec. Garut Kota'), findsOneWidget);
        expect(find.text('0 Atlet'), findsOneWidget);
      },
    );

    testWidgets(
      'DataMode.remote: Tab Klub filters by status when chip tapped',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        final controller = _TestClubPaginationController(
          42,
          const ClubPaginationState(items: [], total: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              clubPaginationProvider(42).overrideWith(() => controller),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Klub').first);
        await tester.pumpAndSettle();

        expect(controller.state.status, isNull);

        await tester.tap(find.widgetWithText(FilterChip, 'Aktif'));
        await tester.pumpAndSettle();
        expect(controller.state.status, 1);

        await tester.tap(find.widgetWithText(FilterChip, 'Belum Aktif'));
        await tester.pumpAndSettle();
        expect(controller.state.status, 0);

        await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
        await tester.pumpAndSettle();
        expect(controller.state.status, isNull);
      },
    );

    testWidgets('DataMode.remote: Tab Klub searches clubs with debounce', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sampleCabor = Cabor(
        id: 42,
        code: 'CB-42',
        name: 'Arung Jeram',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 1,
        totalAthlete: 10,
      );

      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
        remoteCabors: [sampleCabor],
      );

      final controller = _TestClubPaginationController(
        42,
        const ClubPaginationState(items: [], total: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            currentUserProvider.overrideWithValue(userWithExport),
            dataRequestContextProvider.overrideWithValue(
              DataRequestContext(
                environment: AppEnv.staging,
                userId: '1',
                scope: userWithExport.scope,
                generation: 1,
              ),
            ),
            caborPaginationProvider.overrideWith(
              () => _TestCaborPaginationController(
                const CaborPaginationState(items: [sampleCabor], total: 1),
              ),
            ),
            clubPaginationProvider(42).overrideWith(() => controller),
          ],
          child: const MaterialApp(home: SportDetailPage(sport: '42')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Klub').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Garuda');
      expect(controller.state.search, isNull);

      // Advance debounce timer (500ms)
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.state.search, 'Garuda');
    });

    testWidgets(
      'DataMode.remote: Tab Klub shows empty state when club list is empty',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 0,
          totalAthlete: 0,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              clubPaginationProvider(42).overrideWith(
                () => _TestClubPaginationController(
                  42,
                  const ClubPaginationState(items: [], total: 0),
                ),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Klub').first);
        await tester.pumpAndSettle();

        expect(
          find.text('Tidak ada klub yang sesuai dengan filter.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DataMode.remote: Tab Klub shows error view when error occurs',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              clubPaginationProvider(42).overrideWith(
                () => _TestClubPaginationController(
                  42,
                  const ClubPaginationState(
                    items: [],
                    total: 0,
                    error: BadRequestException('Koneksi ke server terputus'),
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Klub').first);
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data klub'), findsOneWidget);
        expect(find.text('Koneksi ke server terputus'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);
      },
    );

    testWidgets(
      'DataMode.remote: Tab Klub handles NO_SUBDISTRICT without retry button',
      (tester) async {
        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              clubPaginationProvider(42).overrideWith(
                () => _TestClubPaginationController(
                  42,
                  const ClubPaginationState(
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
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Klub').first);
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data klub'), findsOneWidget);
        expect(
          find.text(
            'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
          ),
          findsOneWidget,
        );
        expect(find.text('Coba Lagi'), findsNothing);
      },
    );

    testWidgets('DataMode.remote: tapping club card navigates to /club/:id', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sampleCabor = Cabor(
        id: 42,
        code: 'CB-42',
        name: 'Arung Jeram',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 1,
        totalAthlete: 10,
      );

      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
        remoteCabors: [sampleCabor],
      );

      final club = domain.Club(
        id: 88,
        code: 'KLUB-088',
        name: 'PB Garuda Perkasa',
        cabor: const domain.ClubCabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
        ),
        status: 1,
        statusLabel: 'Aktif',
        secretariat: const domain.ClubAddress(
          address: 'Jl. Ahmad Yani No. 45',
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Kabupaten Garut',
        ),
        totalAthleteInClub: 12,
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/sport/42',
        routes: [
          GoRoute(
            path: '/sport/:id',
            builder: (context, state) => const SportDetailPage(sport: '42'),
          ),
          GoRoute(
            path: '/club/:id',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return Scaffold(body: Text('Club ${state.pathParameters['id']}'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            currentUserProvider.overrideWithValue(userWithExport),
            dataRequestContextProvider.overrideWithValue(
              DataRequestContext(
                environment: AppEnv.staging,
                userId: '1',
                scope: userWithExport.scope,
                generation: 1,
              ),
            ),
            caborPaginationProvider.overrideWith(
              () => _TestCaborPaginationController(
                const CaborPaginationState(items: [sampleCabor], total: 1),
              ),
            ),
            clubPaginationProvider(42).overrideWith(
              () => _TestClubPaginationController(
                42,
                ClubPaginationState(items: [club], total: 1),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Klub').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('PB Garuda Perkasa'));
      await tester.pumpAndSettle();
      expect(pushedRoute, '/club/88');
    });

    testWidgets(
      'DataMode.remote: fast typing followed by clear (< 500ms) in clubs tab cancels debounce',
      (tester) async {
        final executedSearches = <String?>[];
        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              clubPaginationProvider(42).overrideWith(
                () => _TestClubPaginationController(
                  42,
                  const ClubPaginationState(items: [], total: 0),
                  (q) => executedSearches.add(q),
                ),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Klub').first);
        await tester.pumpAndSettle();
        executedSearches.clear();

        // 1. Enter text in search bar of Clubs tab
        await tester.enterText(
          find.byType(TextField).first,
          'DiscardedClubQuery',
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 2. Tap clear button (< 500ms)
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        // 3. Advance past original 500ms debounce
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(executedSearches.contains('DiscardedClubQuery'), isFalse);
      },
    );

    testWidgets(
      'DataMode.remote: fast typing followed by clear (< 500ms) in athletes tab cancels debounce',
      (tester) async {
        final executedSearches = <String?>[];
        const sampleCabor = Cabor(
          id: 42,
          code: 'CB-42',
          name: 'Arung Jeram',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: 1,
          totalAthlete: 10,
        );

        final composition = await _createTestComposition(
          dataMode: DataMode.remote,
          remoteCabors: [sampleCabor],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCompositionProvider.overrideWithValue(composition),
              currentUserProvider.overrideWithValue(userWithExport),
              dataRequestContextProvider.overrideWithValue(
                DataRequestContext(
                  environment: AppEnv.staging,
                  userId: '1',
                  scope: userWithExport.scope,
                  generation: 1,
                ),
              ),
              caborPaginationProvider.overrideWith(
                () => _TestCaborPaginationController(
                  const CaborPaginationState(items: [sampleCabor], total: 1),
                ),
              ),
              athletePaginationProvider((
                idCabor: 42,
                idClub: null,
              )).overrideWith(
                () => _TestAthletePaginationController(
                  (idCabor: 42, idClub: null),
                  const AthletePaginationState(items: [], total: 0),
                  (q) => executedSearches.add(q),
                ),
              ),
            ],
            child: const MaterialApp(home: SportDetailPage(sport: '42')),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Athletes tab (Tab index 1)
        await tester.tap(find.text('Atlet').first);
        await tester.pumpAndSettle();
        executedSearches.clear();

        // 1. Enter text in search bar of Athletes tab
        await tester.enterText(
          find.byType(TextField).first,
          'DiscardedAthleteQuery',
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 2. Tap clear button (< 500ms)
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        // 3. Advance past original 500ms debounce
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(executedSearches.contains('DiscardedAthleteQuery'), isFalse);
      },
    );
  });
}

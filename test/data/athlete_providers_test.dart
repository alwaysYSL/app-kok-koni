import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';

class MockAthleteService implements AthleteService {
  MockAthleteService({this.onFetchList, this.onFetchDetail});

  final Future<PaginatedResult<Athlete>> Function({
    int limit,
    int offset,
    int? idCabor,
    int? idClub,
    String? sex,
    int? status,
    String? search,
    String sort,
    RequestCancellation? cancellation,
  })?
  onFetchList;

  final Future<AthleteDetail> Function(
    int id, {
    RequestCancellation? cancellation,
  })?
  onFetchDetail;

  @override
  Future<PaginatedResult<Athlete>> fetchAthleteList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? idClub,
    String? sex,
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
        idClub: idClub,
        sex: sex,
        status: status,
        search: search,
        sort: sort,
        cancellation: cancellation,
      );
    }
    final items = List.generate(
      limit,
      (i) => Athlete(
        id: offset + i + 1,
        code: 'AT-${offset + i + 1}',
        name: 'Athlete ${offset + i + 1}',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        photoUrl: 'https://example.com/avatar.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: const AthleteCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
        club: const AthleteClub(id: 1, code: 'CL-1', name: 'PB Garuda'),
        domicile: const AthleteDomicile(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
        ),
      ),
    );
    return PaginatedResult(
      items: items,
      limit: limit,
      offset: offset,
      total: 100,
    );
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    if (onFetchDetail != null) {
      return onFetchDetail!(id, cancellation: cancellation);
    }
    return AthleteDetail(
      id: id,
      code: 'AT-$id',
      name: 'Athlete $id',
      sex: 'l',
      sexLabel: 'Laki-Laki',
      photoUrl: 'https://example.com/avatar.jpg',
      status: 1,
      statusLabel: 'Aktif',
      cabor: const AthleteCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
      club: const AthleteClub(id: 1, code: 'CL-1', name: 'PB Garuda'),
      domicile: const AthleteDomicile(
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      ),
      height: 175,
      weight: 68,
      bloodType: 'O',
      phone: '081234567890',
      email: 'athlete@example.com',
      address: 'Jl. Merdeka No. 10',
    );
  }
}

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
  environment: AppEnv.demo,
  userId: 'user-123',
  scope: AccessScope(
    type: AccessScopeType.district,
    id: '1728',
    name: 'Garut Kota',
  ),
  generation: 1,
);

AppComposition _createTestComposition({
  DeploymentProfile profile = const DeploymentProfile(
    environment: AppEnv.demo,
    authMode: AuthMode.demo,
    dataMode: DataMode.demo,
  ),
  AthleteService? athleteService,
}) {
  final demoRepo = DemoKokRepository(simulateLatency: false);
  return AppComposition(
    profile: profile,
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
    athleteService:
        athleteService ??
        DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => const AccessScope(
            type: AccessScopeType.district,
            id: '1728',
            name: 'Garut Kota',
          ),
        ),
    clubService: DemoClubService(
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

void main() {
  group('athleteServiceProvider Tests', () {
    test('returns DemoAthleteService dynamically in demo mode', () {
      final container = ProviderContainer(
        overrides: [
          appCompositionProvider.overrideWithValue(_createTestComposition()),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(athleteServiceProvider);
      expect(service, isA<DemoAthleteService>());
      final demoService = service as DemoAthleteService;
      expect(demoService.currentScopeProvider().id, '1728');
    });

    test('returns composition.athleteService in remote mode', () {
      final mockService = MockAthleteService();
      final container = ProviderContainer(
        overrides: [
          appCompositionProvider.overrideWithValue(
            _createTestComposition(
              profile: const DeploymentProfile(
                environment: AppEnv.staging,
                authMode: AuthMode.remote,
                dataMode: DataMode.remote,
                apiBaseUrl: 'https://staging.example.com',
              ),
              athleteService: mockService,
            ),
          ),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(athleteServiceProvider);
      expect(service, same(mockService));
    });
  });

  group('athleteListProvider Tests', () {
    test(
      'throws RequestCancelledException if session context is null',
      () async {
        final container = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(_createTestComposition()),
            dataRequestContextProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        const params = (
          offset: 0,
          limit: 25,
          idCabor: null,
          idClub: null,
          sex: null,
          status: null,
          search: null,
          sort: 'name',
        );

        expect(
          () => container.read(athleteListProvider(params).future),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test(
      'forwards parameters to service and returns paginated result',
      () async {
        late int capturedLimit;
        late int capturedOffset;
        late int? capturedIdCabor;
        late String? capturedSex;
        late String? capturedSearch;
        late String capturedSort;

        final mockService = MockAthleteService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                int? idCabor,
                int? idClub,
                String? sex,
                int? status,
                String? search,
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                capturedLimit = limit;
                capturedOffset = offset;
                capturedIdCabor = idCabor;
                capturedSex = sex;
                capturedSearch = search;
                capturedSort = sort;
                return PaginatedResult(
                  items: [
                    const Athlete(
                      id: 1,
                      code: 'AT-1',
                      name: 'Budi Santoso',
                      sex: 'l',
                      sexLabel: 'Laki-Laki',
                      photoUrl: 'https://example.com/budi.jpg',
                      status: 1,
                      statusLabel: 'Aktif',
                      cabor: AthleteCabor(
                        id: 1,
                        code: 'CB-1',
                        name: 'Bulutangkis',
                      ),
                      domicile: AthleteDomicile(
                        subdistrictId: 1728,
                        subdistrictName: 'Garut Kota',
                        districtId: 126,
                        districtName: 'Garut',
                      ),
                    ),
                  ],
                  limit: limit,
                  offset: offset,
                  total: 1,
                  filterWarning: {'message': 'Warning klub'},
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(_testContext),
          ],
        );
        addTearDown(container.dispose);

        const params = (
          offset: 10,
          limit: 15,
          idCabor: 3,
          idClub: null,
          sex: 'l',
          status: 1,
          search: 'Budi',
          sort: 'name_desc',
        );

        final result = await container.read(athleteListProvider(params).future);

        expect(capturedLimit, 15);
        expect(capturedOffset, 10);
        expect(capturedIdCabor, 3);
        expect(capturedSex, 'l');
        expect(capturedSearch, 'Budi');
        expect(capturedSort, 'name_desc');
        expect(result.items.length, 1);
        expect(result.items.first.name, 'Budi Santoso');
        expect(result.hasFilterWarning, isTrue);
        expect(result.filterWarningMessage, 'Warning klub');
      },
    );

    test(
      'cancels request if container/provider disposed during fetch',
      () async {
        final completer = Completer<PaginatedResult<Athlete>>();
        RequestCancellation? capturedCancellation;

        final mockService = MockAthleteService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                int? idCabor,
                int? idClub,
                String? sex,
                int? status,
                String? search,
                String sort = 'name',
                RequestCancellation? cancellation,
              }) {
                capturedCancellation = cancellation;
                return completer.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(_testContext),
          ],
        );

        const params = (
          offset: 0,
          limit: 25,
          idCabor: null,
          idClub: null,
          sex: null,
          status: null,
          search: null,
          sort: 'name',
        );

        final future = container.read(athleteListProvider(params).future);
        expect(capturedCancellation?.isCancelled, isFalse);

        container.dispose();
        expect(capturedCancellation?.isCancelled, isTrue);

        completer.complete(
          const PaginatedResult(items: [], limit: 25, offset: 0, total: 0),
        );
        expect(() => future, throwsA(anything));
      },
    );
  });

  group('AthletePaginationController & athletePaginationProvider Tests', () {
    const defaultScope = (idCabor: 1, idClub: null);

    test('initializes with empty state', () {
      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(MockAthleteService()),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(athletePaginationProvider(defaultScope));
      expect(state.items, isEmpty);
      expect(state.total, 0);
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.error, isNull);
      expect(state.sort, 'name');
    });

    test('loadFirstPage fetches first page and sets state', () async {
      final items = List.generate(
        25,
        (i) => Athlete(
          id: i + 1,
          code: 'AT-${i + 1}',
          name: 'Athlete ${i + 1}',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          photoUrl: 'https://example.com/avatar.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: const AthleteCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
          domicile: const AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Garut',
          ),
        ),
      );

      final mockService = MockAthleteService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? idClub,
              String? sex,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              return PaginatedResult(
                items: items,
                limit: limit,
                offset: offset,
                total: 60,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        athletePaginationProvider(defaultScope).notifier,
      );
      await controller.loadFirstPage();

      final state = container.read(athletePaginationProvider(defaultScope));
      expect(state.items.length, 25);
      expect(state.total, 60);
      expect(state.hasMore, isTrue);
      expect(state.canLoadMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loadFirstPage passes idClub when scoped by club', () async {
      int? capturedIdCabor;
      int? capturedIdClub;

      final mockService = MockAthleteService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? idClub,
              String? sex,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              capturedIdCabor = idCabor;
              capturedIdClub = idClub;
              return const PaginatedResult(
                items: [],
                limit: 25,
                offset: 0,
                total: 0,
                filterWarning: {'message': 'Keanggotaan club belum lengkap'},
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      const clubScope = (idCabor: null, idClub: 10);
      final controller = container.read(
        athletePaginationProvider(clubScope).notifier,
      );
      await controller.loadFirstPage();

      expect(capturedIdCabor, isNull);
      expect(capturedIdClub, 10);

      final state = container.read(athletePaginationProvider(clubScope));
      expect(state.hasFilterWarning, isTrue);
      expect(state.filterWarningMessage, 'Keanggotaan club belum lengkap');
    });

    test('loadMore loads next page and appends items', () async {
      final page1 = List.generate(
        25,
        (i) => Athlete(
          id: i + 1,
          code: 'AT-${i + 1}',
          name: 'Athlete ${i + 1}',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          photoUrl: 'https://example.com/avatar.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: const AthleteCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
          domicile: const AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Garut',
          ),
        ),
      );

      final page2 = List.generate(
        10,
        (i) => Athlete(
          id: 25 + i + 1,
          code: 'AT-${25 + i + 1}',
          name: 'Athlete ${25 + i + 1}',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          photoUrl: 'https://example.com/avatar.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: const AthleteCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
          domicile: const AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Garut',
          ),
        ),
      );

      final mockService = MockAthleteService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? idClub,
              String? sex,
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
                  total: 35,
                );
              }
              return PaginatedResult(
                items: page2,
                limit: limit,
                offset: 25,
                total: 35,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        athletePaginationProvider(defaultScope).notifier,
      );
      await controller.loadFirstPage();

      expect(
        container.read(athletePaginationProvider(defaultScope)).items.length,
        25,
      );
      expect(
        container.read(athletePaginationProvider(defaultScope)).hasMore,
        isTrue,
      );

      await controller.loadMore();

      final state = container.read(athletePaginationProvider(defaultScope));
      expect(state.items.length, 35);
      expect(state.total, 35);
      expect(state.hasMore, isFalse);
      expect(state.canLoadMore, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreError, isNull);
    });

    test(
      'updateSearch, updateSexFilter, updateStatusFilter, updateSort reload first page',
      () async {
        String? lastSearch;
        String? lastSex;
        int? lastStatus;
        String? lastSort;

        final mockService = MockAthleteService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                int? idCabor,
                int? idClub,
                String? sex,
                int? status,
                String? search,
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                lastSearch = search;
                lastSex = sex;
                lastStatus = status;
                lastSort = sort;
                return const PaginatedResult(
                  items: [],
                  limit: 25,
                  offset: 0,
                  total: 0,
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(_testContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );

        controller.updateSearch('Ahmad');
        await container.pump();
        expect(lastSearch, 'Ahmad');

        controller.updateSexFilter('p');
        await container.pump();
        expect(lastSex, 'p');

        controller.updateStatusFilter(1);
        await container.pump();
        expect(lastStatus, 1);

        controller.updateSort('name_desc');
        await container.pump();
        expect(lastSort, 'name_desc');

        await controller.refresh();
        expect(lastSort, 'name_desc');
      },
    );

    test('handles error on loadFirstPage and loadMore cleanly', () async {
      var shouldFail = true;
      final mockService = MockAthleteService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              int? idCabor,
              int? idClub,
              String? sex,
              int? status,
              String? search,
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              if (shouldFail) {
                throw const ServerErrorException('Server error');
              }
              return PaginatedResult(
                items: [
                  const Athlete(
                    id: 1,
                    code: 'AT-1',
                    name: 'Athlete 1',
                    sex: 'l',
                    sexLabel: 'Laki-Laki',
                    photoUrl: 'https://example.com/avatar.jpg',
                    status: 1,
                    statusLabel: 'Aktif',
                    cabor: AthleteCabor(
                      id: 1,
                      code: 'CB-1',
                      name: 'Bulutangkis',
                    ),
                    domicile: AthleteDomicile(
                      subdistrictId: 1728,
                      subdistrictName: 'Garut Kota',
                      districtId: 126,
                      districtName: 'Garut',
                    ),
                  ),
                ],
                limit: 25,
                offset: offset,
                total: 50,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        athletePaginationProvider(defaultScope).notifier,
      );
      await controller.loadFirstPage();

      var state = container.read(athletePaginationProvider(defaultScope));
      expect(state.error, isA<ServerErrorException>());
      expect(state.isLoading, isFalse);

      // Now succeed on loadFirstPage, but fail on loadMore
      shouldFail = false;
      await controller.loadFirstPage();
      state = container.read(athletePaginationProvider(defaultScope));
      expect(state.error, isNull);
      expect(state.items.length, 1);
      expect(state.hasMore, isTrue);

      shouldFail = true;
      await controller.loadMore();
      state = container.read(athletePaginationProvider(defaultScope));
      expect(state.loadMoreError, isA<ServerErrorException>());
      expect(state.isLoadingMore, isFalse);
      expect(state.items.length, 1); // retains previous items
    });
  });

  group('athleteDetailProvider Tests', () {
    test(
      'throws RequestCancelledException when session context is null',
      () async {
        final container = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(_createTestComposition()),
            dataRequestContextProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        expect(
          () => container.read(athleteDetailProvider(1).future),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('fetches athlete detail successfully', () async {
      final mockService = MockAthleteService(
        onFetchDetail: (id, {cancellation}) async {
          return AthleteDetail(
            id: id,
            code: 'KGAT-$id',
            name: 'Jonatan Christie',
            sex: 'l',
            sexLabel: 'Laki-Laki',
            photoUrl: 'https://example.com/jojo.jpg',
            status: 1,
            statusLabel: 'Aktif',
            cabor: const AthleteCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
            club: const AthleteClub(id: 5, code: 'CL-5', name: 'PB Tangkas'),
            domicile: const AthleteDomicile(
              subdistrictId: 1728,
              subdistrictName: 'Garut Kota',
              districtId: 126,
              districtName: 'Garut',
              village: 'Kota Kulon',
            ),
            phone: '08123456789',
            email: 'jojo@koni.id',
            height: 180,
            weight: 75,
            bloodType: 'A',
            address: 'Jl. Merdeka No. 45',
          );
        },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final detail = await container.read(athleteDetailProvider(42).future);

      expect(detail.id, 42);
      expect(detail.name, 'Jonatan Christie');
      expect(detail.cabor.name, 'Bulutangkis');
      expect(detail.club?.name, 'PB Tangkas');
      expect(detail.height, 180);
      expect(detail.weight, 75);
      expect(detail.bloodType, 'A');
      expect(detail.domicile.village, 'Kota Kulon');
    });

    test('propagates NotFoundException if athlete is not found', () async {
      final mockService = MockAthleteService(
        onFetchDetail: (id, {cancellation}) async {
          throw const NotFoundException('Data atlet tidak ditemukan.');
        },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(athleteDetailProvider(999).future),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}

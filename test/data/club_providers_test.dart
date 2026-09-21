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

Club _createTestClub({
  int id = 1,
  String name = 'PB Garuda',
  int status = 1,
  int totalAthlete = 10,
}) {
  return Club(
    id: id,
    code: 'KLUB-$id',
    name: name,
    cabor: const ClubCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
    status: status,
    statusLabel: status == 1 ? 'Aktif' : 'Belum Aktif',
    secretariat: const ClubAddress(
      address: 'Jl. Merdeka No. 10',
      subdistrictId: 1728,
      subdistrictName: 'Garut Kota',
      districtId: 126,
      districtName: 'Garut',
    ),
    totalAthleteInClub: totalAthlete,
  );
}

ClubDetail _createTestClubDetail({
  int id = 1,
  String name = 'PB Garuda',
  int status = 1,
  int totalAthlete = 10,
  String? phone,
  String? email,
}) {
  return ClubDetail(
    id: id,
    code: 'KLUB-$id',
    name: name,
    cabor: const ClubCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
    status: status,
    statusLabel: status == 1 ? 'Aktif' : 'Belum Aktif',
    secretariat: const ClubAddress(
      address: 'Jl. Merdeka No. 10',
      subdistrictId: 1728,
      subdistrictName: 'Garut Kota',
      districtId: 126,
      districtName: 'Garut',
    ),
    totalAthleteInClub: totalAthlete,
    phone: phone,
    email: email,
    officials: const ClubPersonnelBlock(dataAvailable: false, items: []),
    coaches: const ClubPersonnelBlock(dataAvailable: false, items: []),
    management: const ClubManagementBlock(
      dataAvailable: false,
      partial: false,
      items: [],
    ),
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
    final items = List.generate(
      limit,
      (i) =>
          _createTestClub(id: offset + i + 1, name: 'Club ${offset + i + 1}'),
    );
    return PaginatedResult(
      items: items,
      limit: limit,
      offset: offset,
      total: 100,
    );
  }

  @override
  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    if (onFetchDetail != null) {
      return onFetchDetail!(id, cancellation: cancellation);
    }
    return _createTestClubDetail(id: id, name: 'Club $id');
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
  ClubService? clubService,
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

void main() {
  group('clubServiceProvider Tests', () {
    test('returns DemoClubService dynamically in demo mode', () {
      final container = ProviderContainer(
        overrides: [
          appCompositionProvider.overrideWithValue(_createTestComposition()),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(clubServiceProvider);
      expect(service, isA<DemoClubService>());
      final demoService = service as DemoClubService;
      expect(demoService.currentScopeProvider().id, '1728');
    });

    test('returns composition.clubService in remote mode', () {
      final mockService = MockClubService();
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
              clubService: mockService,
            ),
          ),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(clubServiceProvider);
      expect(service, same(mockService));
    });
  });

  group('clubListProvider Tests', () {
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
          status: null,
          search: null,
          sort: 'name',
        );

        expect(
          () => container.read(clubListProvider(params).future),
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
        late int? capturedStatus;
        late String? capturedSearch;
        late String capturedSort;

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
                capturedLimit = limit;
                capturedOffset = offset;
                capturedIdCabor = idCabor;
                capturedStatus = status;
                capturedSearch = search;
                capturedSort = sort;
                return PaginatedResult(
                  items: [
                    _createTestClub(id: 1, name: 'PB Garuda', totalAthlete: 12),
                  ],
                  limit: limit,
                  offset: offset,
                  total: 1,
                  filterWarning: {'message': 'Warning filter klub'},
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(_testContext),
          ],
        );
        addTearDown(container.dispose);

        const params = (
          offset: 10,
          limit: 15,
          idCabor: 3,
          status: 1,
          search: 'Garuda',
          sort: 'name_desc',
        );

        final result = await container.read(clubListProvider(params).future);

        expect(capturedLimit, 15);
        expect(capturedOffset, 10);
        expect(capturedIdCabor, 3);
        expect(capturedStatus, 1);
        expect(capturedSearch, 'Garuda');
        expect(capturedSort, 'name_desc');
        expect(result.items.length, 1);
        expect(result.items.first.name, 'PB Garuda');
        expect(result.hasFilterWarning, isTrue);
        expect(result.filterWarningMessage, 'Warning filter klub');
      },
    );

    test(
      'cancels request if container/provider disposed during fetch',
      () async {
        final completer = Completer<PaginatedResult<Club>>();
        RequestCancellation? capturedCancellation;

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
              }) {
                capturedCancellation = cancellation;
                return completer.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(_testContext),
          ],
        );

        const params = (
          offset: 0,
          limit: 25,
          idCabor: null,
          status: null,
          search: null,
          sort: 'name',
        );

        final future = container.read(clubListProvider(params).future);
        expect(capturedCancellation?.isCancelled, isFalse);

        container.dispose();
        expect(capturedCancellation?.isCancelled, isTrue);

        completer.complete(
          const PaginatedResult(items: [], limit: 25, offset: 0, total: 0),
        );
        expect(() => future, throwsA(anything));
      },
    );

    test(
      'rejects stale response when session context changes during fetch',
      () async {
        final completerA = Completer<PaginatedResult<Club>>();
        final completerB = Completer<PaginatedResult<Club>>();
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
              }) {
                fetchCount++;
                if (fetchCount == 1) {
                  return completerA.future;
                }
                return completerB.future;
              },
        );

        var activeContext = _testContext;
        late final ProviderContainer container;

        container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => activeContext),
          ],
        );
        addTearDown(container.dispose);

        const params = (
          offset: 0,
          limit: 25,
          idCabor: null,
          status: null,
          search: null,
          sort: 'name',
        );

        // 1. Start fetch for context A
        final sub = container.listen(
          clubListProvider(params),
          (previous, next) {},
        );
        addTearDown(sub.close);
        expect(fetchCount, 1);

        // 2. Switch session context
        activeContext = const DataRequestContext(
          environment: AppEnv.demo,
          userId: 'user-456',
          scope: AccessScope(
            type: AccessScopeType.district,
            id: '1729',
            name: 'Tarogong Kidul',
          ),
          generation: 2,
        );
        container.refresh(dataRequestContextProvider);

        // 3. Start fetch for context B
        final futureB = container.read(clubListProvider(params).future);
        expect(fetchCount, 2);

        // 4. Complete A with stale data
        completerA.complete(
          PaginatedResult(
            items: [
              _createTestClub(id: 1, name: 'Garut Kota Club', totalAthlete: 5),
            ],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );

        // 5. Complete B with current data
        completerB.complete(
          PaginatedResult(
            items: [
              _createTestClub(
                id: 2,
                name: 'Tarogong Kidul Club',
                totalAthlete: 15,
              ),
            ],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );

        final result = await futureB;
        expect(result.items.first.name, 'Tarogong Kidul Club');
      },
    );
  });

  group('ClubPaginationState & ClubPaginationController Tests', () {
    test('initializes with empty state', () {
      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(MockClubService()),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(clubPaginationProvider(1));
      expect(state.items, isEmpty);
      expect(state.total, 0);
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.error, isNull);
      expect(state.loadMoreError, isNull);
      expect(state.filterWarning, isNull);
      expect(state.search, isNull);
      expect(state.status, isNull);
      expect(state.sort, 'name');
    });

    test('loadFirstPage fetches first page and sets state', () async {
      final items = List.generate(
        25,
        (i) => _createTestClub(id: i + 1, name: 'Club ${i + 1}'),
      );

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
                items: items,
                limit: limit,
                offset: offset,
                total: 60,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(clubPaginationProvider(1).notifier);
      await controller.loadFirstPage();

      final state = container.read(clubPaginationProvider(1));
      expect(state.items.length, 25);
      expect(state.total, 60);
      expect(state.hasMore, isTrue);
      expect(state.canLoadMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loadMore loads next page and appends items', () async {
      final page1 = List.generate(
        25,
        (i) => _createTestClub(id: i + 1, name: 'Club ${i + 1}'),
      );

      final page2 = List.generate(
        10,
        (i) => _createTestClub(id: 25 + i + 1, name: 'Club ${25 + i + 1}'),
      );

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
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(clubPaginationProvider(1).notifier);
      await controller.loadFirstPage();

      expect(container.read(clubPaginationProvider(1)).items.length, 25);
      expect(container.read(clubPaginationProvider(1)).hasMore, isTrue);

      await controller.loadMore();

      final state = container.read(clubPaginationProvider(1));
      expect(state.items.length, 35);
      expect(state.total, 35);
      expect(state.hasMore, isFalse);
      expect(state.canLoadMore, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreError, isNull);
    });

    test(
      'updateSearch, updateStatusFilter, updateSort reload first page',
      () async {
        String? lastSearch;
        int? lastStatus;
        String? lastSort;

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
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(_testContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(clubPaginationProvider(1).notifier);

        controller.updateSearch('Garuda');
        await container.pump();
        expect(lastSearch, 'Garuda');

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
              if (shouldFail) {
                throw const ServerErrorException('Server error');
              }
              return PaginatedResult(
                items: [_createTestClub(id: 1, name: 'Club 1')],
                limit: 25,
                offset: offset,
                total: 50,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(clubPaginationProvider(1).notifier);
      await controller.loadFirstPage();

      var state = container.read(clubPaginationProvider(1));
      expect(state.error, isA<ServerErrorException>());
      expect(state.isLoading, isFalse);

      // Now succeed on loadFirstPage, but fail on loadMore
      shouldFail = false;
      await controller.loadFirstPage();
      state = container.read(clubPaginationProvider(1));
      expect(state.error, isNull);
      expect(state.items.length, 1);
      expect(state.hasMore, isTrue);

      shouldFail = true;
      await controller.loadMore();
      state = container.read(clubPaginationProvider(1));
      expect(state.loadMoreError, isA<ServerErrorException>());
      expect(state.isLoadingMore, isFalse);
      expect(state.items.length, 1); // retains previous items
    });

    test('ClubPaginationState equality and copyWith tests', () {
      const state1 = ClubPaginationState();
      const state2 = ClubPaginationState();
      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      final state3 = state1.copyWith(
        items: [_createTestClub(id: 1, name: 'Club 1')],
        total: 1,
        search: 'Garuda',
        status: 1,
        sort: 'name_desc',
        filterWarning: {'message': 'Warning'},
      );

      expect(state3.hasFilterWarning, isTrue);
      expect(state3.filterWarningMessage, 'Warning');
      expect(state3, isNot(equals(state1)));

      final cleared = state3.copyWith(
        clearSearch: true,
        clearStatus: true,
        clearFilterWarning: true,
      );
      expect(cleared.search, isNull);
      expect(cleared.status, isNull);
      expect(cleared.filterWarning, isNull);
    });
  });

  group('clubDetailProvider Tests', () {
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
          () => container.read(clubDetailProvider(1).future),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('fetches club detail successfully', () async {
      final mockService = MockClubService(
        onFetchDetail: (id, {cancellation}) async {
          return _createTestClubDetail(
            id: id,
            name: 'PB Jaya Raya',
            totalAthlete: 25,
            phone: '081234567890',
            email: 'pbj@example.com',
          );
        },
      );

      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      final detail = await container.read(clubDetailProvider(1).future);
      expect(detail.id, 1);
      expect(detail.name, 'PB Jaya Raya');
      expect(detail.phone, '081234567890');
    });

    test('propagates NotFoundException error', () async {
      final mockService = MockClubService(
        onFetchDetail: (id, {cancellation}) async {
          throw const NotFoundException('Data club tidak ditemukan.');
        },
      );

      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(clubDetailProvider(999).future),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('cancels token on provider dispose', () async {
      final completer = Completer<ClubDetail>();
      RequestCancellation? capturedCancellation;

      final mockService = MockClubService(
        onFetchDetail: (id, {cancellation}) {
          capturedCancellation = cancellation;
          return completer.future;
        },
      );

      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(_testContext),
        ],
      );

      final future = container.read(clubDetailProvider(1).future);
      expect(capturedCancellation?.isCancelled, isFalse);

      container.dispose();
      expect(capturedCancellation?.isCancelled, isTrue);

      completer.complete(_createTestClubDetail(id: 1, name: 'Club 1'));
      expect(() => future, throwsA(anything));
    });

    test(
      'rejects stale response when session context changes during fetch',
      () async {
        final completerA = Completer<ClubDetail>();
        final completerB = Completer<ClubDetail>();
        var fetchCount = 0;

        final mockService = MockClubService(
          onFetchDetail: (id, {cancellation}) {
            fetchCount++;
            if (fetchCount == 1) {
              return completerA.future;
            }
            return completerB.future;
          },
        );

        var activeContext = _testContext;
        late final ProviderContainer container;

        container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => activeContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Start fetch A
        final sub = container.listen(
          clubDetailProvider(1),
          (previous, next) {},
        );
        addTearDown(sub.close);
        expect(fetchCount, 1);

        // 2. Switch session context
        activeContext = const DataRequestContext(
          environment: AppEnv.demo,
          userId: 'user-456',
          scope: AccessScope(
            type: AccessScopeType.district,
            id: '1729',
            name: 'Tarogong Kidul',
          ),
          generation: 2,
        );
        container.refresh(dataRequestContextProvider);

        // 3. Start fetch B
        final futureB = container.read(clubDetailProvider(1).future);
        expect(fetchCount, 2);

        // 4. Complete A with stale data
        completerA.complete(
          _createTestClubDetail(id: 1, name: 'Garut Kota Club'),
        );

        // 5. Complete B with current data
        completerB.complete(
          _createTestClubDetail(id: 1, name: 'Tarogong Kidul Club'),
        );

        final result = await futureB;
        expect(result.name, 'Tarogong Kidul Club');
      },
    );
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/club_service.dart';

Club _createTestClub({required int id, required String name}) {
  return Club(
    id: id,
    code: 'KLUB-$id',
    name: name,
    cabor: const ClubCabor(id: 1, code: 'CB-1', name: 'Bulutangkis'),
    status: 1,
    statusLabel: 'Aktif',
    secretariat: const ClubAddress(
      address: 'Jl. Merdeka No. 10',
      subdistrictId: 1728,
      subdistrictName: 'Garut Kota',
      districtId: 126,
      districtName: 'Garut',
    ),
    totalAthleteInClub: 10,
  );
}

class _MockClubService implements ClubService {
  _MockClubService({this.onFetchList});

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
    return PaginatedResult(
      items: [
        _createTestClub(id: offset + 1, name: 'Default Club ${offset + 1}'),
      ],
      limit: limit,
      offset: offset,
      total: 50,
    );
  }

  @override
  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  const contextA = DataRequestContext(
    environment: AppEnv.demo,
    userId: 'user-a',
    scope: AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
    generation: 1,
  );

  const contextB = DataRequestContext(
    environment: AppEnv.demo,
    userId: 'user-b',
    scope: AccessScope(
      type: AccessScopeType.district,
      id: '1729',
      name: 'Tarogong Kidul',
    ),
    generation: 2,
  );

  group('ClubPaginationController Session & Context Switching Tests', () {
    test('loads data successfully under Context A', () async {
      final mockService = _MockClubService(
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
                items: [
                  _createTestClub(id: 1, name: 'Garut Club 1'),
                  _createTestClub(id: 2, name: 'Garut Club 2'),
                ],
                limit: limit,
                offset: offset,
                total: 2,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(contextA),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(clubPaginationProvider(null).notifier);
      await controller.loadFirstPage();

      final state = container.read(clubPaginationProvider(null));
      expect(state.items.length, 2);
      expect(state.items.first.name, 'Garut Club 1');
      expect(state.total, 2);
    });

    test(
      'resets pagination state when context switches from Context A to Context B',
      () async {
        DataRequestContext? currentContext = contextA;

        final mockService = _MockClubService(
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
                if (currentContext?.userId == 'user-a') {
                  return PaginatedResult(
                    items: [_createTestClub(id: 1, name: 'Context A Club')],
                    limit: limit,
                    offset: offset,
                    total: 1,
                  );
                } else {
                  return PaginatedResult(
                    items: [_createTestClub(id: 2, name: 'Context B Club')],
                    limit: limit,
                    offset: offset,
                    total: 1,
                  );
                }
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Initial load under Context A
        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controller.loadFirstPage();

        expect(
          container.read(clubPaginationProvider(null)).items.first.name,
          'Context A Club',
        );

        // 2. Switch context to Context B
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);

        // State is automatically reset because build() watches dataRequestContextProvider
        final resetState = container.read(clubPaginationProvider(null));
        expect(resetState.items, isEmpty);
        expect(resetState.total, 0);

        // 3. Load first page under Context B
        final controllerB = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controllerB.loadFirstPage();

        expect(
          container.read(clubPaginationProvider(null)).items.first.name,
          'Context B Club',
        );
      },
    );

    test(
      'resets state and rejects loadFirstPage when user logs out (context becomes null)',
      () async {
        DataRequestContext? currentContext = contextA;
        var fetchCallCount = 0;

        final mockService = _MockClubService(
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
                fetchCallCount++;
                return PaginatedResult(
                  items: [_createTestClub(id: 1, name: 'Active Club')],
                  limit: limit,
                  offset: offset,
                  total: 1,
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Load under active session
        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controller.loadFirstPage();
        expect(fetchCallCount, 1);
        expect(container.read(clubPaginationProvider(null)).items.length, 1);

        // 2. Logout (context -> null)
        currentContext = null;
        container.refresh(dataRequestContextProvider);

        final loggedOutState = container.read(clubPaginationProvider(null));
        expect(loggedOutState.items, isEmpty);
        expect(loggedOutState.total, 0);

        // 3. Attempting loadFirstPage when logged out does nothing
        final controllerLoggedOut = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controllerLoggedOut.loadFirstPage();
        expect(fetchCallCount, 1); // No new network call was made
        expect(container.read(clubPaginationProvider(null)).items, isEmpty);
      },
    );

    test(
      'loadMore discards response if session context changes while in-flight',
      () async {
        DataRequestContext? currentContext = contextA;
        final completerMore = Completer<PaginatedResult<Club>>();

        final mockService = _MockClubService(
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
                    items: [_createTestClub(id: 1, name: 'Initial Club')],
                    limit: limit,
                    offset: offset,
                    total: 50,
                  );
                }
                return completerMore.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controller.loadFirstPage();
        expect(container.read(clubPaginationProvider(null)).items.length, 1);

        // Start loadMore
        controller.loadMore();

        // Session switches before loadMore completes
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);

        // Complete the pending loadMore from context A
        completerMore.complete(
          PaginatedResult(
            items: [_createTestClub(id: 2, name: 'Stale Context A Club')],
            limit: 25,
            offset: 1,
            total: 50,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        // The stale data must NOT be appended to state
        final state = container.read(clubPaginationProvider(null));
        expect(
          state.items.any((c) => c.name == 'Stale Context A Club'),
          isFalse,
        );
      },
    );

    test('loadMore returns immediately if context is null', () async {
      final container = ProviderContainer(
        overrides: [
          clubServiceProvider.overrideWithValue(_MockClubService()),
          dataRequestContextProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(clubPaginationProvider(null).notifier);
      await controller.loadMore();

      final state = container.read(clubPaginationProvider(null));
      expect(state.items, isEmpty);
      expect(state.isLoadingMore, isFalse);
    });

    test(
      'loadFirstPage ignores error if session context changes while in-flight',
      () async {
        DataRequestContext? currentContext = contextA;
        final completerFirst = Completer<PaginatedResult<Club>>();

        final mockService = _MockClubService(
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
                return completerFirst.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        controller.loadFirstPage();

        // Switch session before loadFirstPage completes
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);
        // Access provider under context B so it is re-evaluated for Context B
        expect(container.read(clubPaginationProvider(null)).error, isNull);

        // Pending loadFirstPage from context A fails
        completerFirst.completeError(
          Exception('Network error under Context A'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // State for Context B must NOT have Context A's error
        final state = container.read(clubPaginationProvider(null));
        expect(state.error, isNull);
      },
    );

    test(
      'loadMore ignores error if session context changes while in-flight',
      () async {
        DataRequestContext? currentContext = contextA;
        final completerMore = Completer<PaginatedResult<Club>>();

        final mockService = _MockClubService(
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
                    items: [_createTestClub(id: 1, name: 'Initial Club')],
                    limit: limit,
                    offset: offset,
                    total: 50,
                  );
                }
                return completerMore.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controller.loadFirstPage();
        expect(container.read(clubPaginationProvider(null)).items.length, 1);

        // Start loadMore under Context A
        controller.loadMore();

        // Switch session before loadMore completes
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);
        // Access provider under Context B so it is re-evaluated for Context B
        expect(
          container.read(clubPaginationProvider(null)).loadMoreError,
          isNull,
        );

        // Fail pending loadMore from Context A
        completerMore.completeError(
          Exception('loadMore error under Context A'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // State for Context B must NOT have Context A's loadMore error
        final state = container.read(clubPaginationProvider(null));
        expect(state.loadMoreError, isNull);
      },
    );
  });
}

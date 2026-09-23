import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/athlete_service.dart';
import 'package:kok_app/data/services/cabor_service.dart';
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

Athlete _createTestAthlete({required int id, required String name}) {
  return Athlete(
    id: id,
    code: 'AT-$id',
    name: name,
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
  );
}

Cabor _createTestCabor({required int id, required String name}) {
  return Cabor(
    id: id,
    code: 'CB-$id',
    name: name,
    status: 1,
    statusLabel: 'Aktif',
    totalClub: 1,
    totalAthlete: 10,
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
    return const PaginatedResult(items: [], limit: 25, offset: 0, total: 0);
  }

  @override
  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async => throw UnimplementedError();
}

class _MockAthleteService implements AthleteService {
  _MockAthleteService({this.onFetchList});

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
    return const PaginatedResult(items: [], limit: 25, offset: 0, total: 0);
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async => throw UnimplementedError();
}

class _MockCaborService implements CaborService {
  _MockCaborService({this.onFetchList});

  final Future<PaginatedResult<Cabor>> Function({
    int limit,
    int offset,
    String source,
    String sort,
    RequestCancellation? cancellation,
  })?
  onFetchList;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    if (onFetchList != null) {
      return onFetchList!(
        limit: limit,
        offset: offset,
        source: source,
        sort: sort,
        cancellation: cancellation,
      );
    }
    return const PaginatedResult(items: [], limit: 25, offset: 0, total: 0);
  }
}

void main() {
  const defaultContext = DataRequestContext(
    environment: AppEnv.demo,
    userId: 'user-123',
    scope: AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
    generation: 1,
  );

  group('Pagination Race Condition Tests — ClubPaginationController', () {
    test(
      'slower first request does not overwrite faster second request',
      () async {
        final completerSlow = Completer<PaginatedResult<Club>>();
        final completerFast = Completer<PaginatedResult<Club>>();
        var callCount = 0;

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
              }) {
                callCount++;
                if (search == 'slow') {
                  return completerSlow.future;
                } else if (search == 'fast') {
                  return completerFast.future;
                }
                return Future.value(
                  const PaginatedResult(
                    items: [],
                    limit: 25,
                    offset: 0,
                    total: 0,
                  ),
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );

        // 1. Trigger search 1 ('slow')
        controller.updateSearch('slow');
        expect(callCount, 1);

        // 2. Immediately trigger search 2 ('fast')
        controller.updateSearch('fast');
        expect(callCount, 2);

        // 3. Complete fast request first
        completerFast.complete(
          PaginatedResult(
            items: [_createTestClub(id: 2, name: 'Fast Result Club')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          container.read(clubPaginationProvider(null)).items.first.name,
          'Fast Result Club',
        );

        // 4. Complete slow request later with stale result
        completerSlow.complete(
          PaginatedResult(
            items: [_createTestClub(id: 1, name: 'Slow Stale Result Club')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 5. State must NOT have been overwritten by slow request
        final finalState = container.read(clubPaginationProvider(null));
        expect(finalState.items.first.name, 'Fast Result Club');
        expect(finalState.items.length, 1);
      },
    );

    test(
      'late error from superseded request does not corrupt active state',
      () async {
        final completer1 = Completer<PaginatedResult<Club>>();
        final completer2 = Completer<PaginatedResult<Club>>();

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
              }) {
                if (search == 'query1') return completer1.future;
                if (search == 'query2') return completer2.future;
                return Future.value(
                  const PaginatedResult(
                    items: [],
                    limit: 25,
                    offset: 0,
                    total: 0,
                  ),
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );

        // 1. Query 1 fires
        controller.updateSearch('query1');
        // 2. Query 2 supersedes
        controller.updateSearch('query2');

        // 3. Query 2 succeeds
        completer2.complete(
          PaginatedResult(
            items: [_createTestClub(id: 2, name: 'Success Club 2')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(clubPaginationProvider(null)).items.length, 1);

        // 4. Query 1 completes with error
        completer1.completeError(Exception('Network timeout'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // State remains successful and error is suppressed
        final state = container.read(clubPaginationProvider(null));
        expect(state.error, isNull);
        expect(state.items.first.name, 'Success Club 2');
      },
    );

    test(
      'in-flight loadMore is invalidated when loadFirstPage is triggered',
      () async {
        final completerMore = Completer<PaginatedResult<Club>>();
        final completerNewSearch = Completer<PaginatedResult<Club>>();

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
                if (offset == 0 && search == null) {
                  return PaginatedResult(
                    items: [_createTestClub(id: 1, name: 'Initial Club')],
                    limit: 25,
                    offset: 0,
                    total: 50,
                  );
                }
                if (offset > 0) {
                  return completerMore.future;
                }
                return completerNewSearch.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controller.loadFirstPage();
        expect(container.read(clubPaginationProvider(null)).items.length, 1);

        // 1. Start loadMore
        final loadMoreFuture = controller.loadMore();

        // 2. User suddenly updates search (starts new generation)
        controller.updateSearch('new_search');

        // 3. New search resolves
        completerNewSearch.complete(
          PaginatedResult(
            items: [_createTestClub(id: 99, name: 'Search Result Club')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 4. Stale loadMore finishes
        completerMore.complete(
          PaginatedResult(
            items: [_createTestClub(id: 2, name: 'Stale Page 2 Club')],
            limit: 25,
            offset: 1,
            total: 50,
          ),
        );
        await loadMoreFuture;

        final state = container.read(clubPaginationProvider(null));
        expect(state.items.length, 1);
        expect(state.items.first.name, 'Search Result Club');
      },
    );

    test(
      'updating filter/search clears old items and total immediately during loading and leaves them empty on error',
      () async {
        final completerSearch = Completer<PaginatedResult<Club>>();

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
                if (search == null) {
                  return PaginatedResult(
                    items: [_createTestClub(id: 1, name: 'Old Club')],
                    limit: 25,
                    offset: 0,
                    total: 10,
                  );
                }
                return completerSearch.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            clubServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          clubPaginationProvider(null).notifier,
        );
        await controller.loadFirstPage();

        final loadedState = container.read(clubPaginationProvider(null));
        expect(loadedState.items.length, 1);
        expect(loadedState.total, 10);

        // 1. Trigger search update
        controller.updateSearch('new_query');

        // Immediately during loading, old items and total must be reset
        final loadingState = container.read(clubPaginationProvider(null));
        expect(loadingState.isLoading, isTrue);
        expect(loadingState.items, isEmpty);
        expect(loadingState.total, 0);
        expect(loadingState.hasMore, isFalse);

        // 2. Request fails
        completerSearch.completeError(Exception('Network error'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // After error, items must remain empty (not reverting to 'Old Club')
        final errorState = container.read(clubPaginationProvider(null));
        expect(errorState.isLoading, isFalse);
        expect(errorState.items, isEmpty);
        expect(errorState.total, 0);
        expect(errorState.hasMore, isFalse);
        expect(errorState.error, isNotNull);
      },
    );
  });

  group('Pagination Race Condition Tests — AthletePaginationController', () {
    const defaultScope = (idCabor: null, idClub: null);

    test(
      'slower first request does not overwrite faster second request',
      () async {
        final completerSlow = Completer<PaginatedResult<Athlete>>();
        final completerFast = Completer<PaginatedResult<Athlete>>();

        final mockService = _MockAthleteService(
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
                if (search == 'slow') return completerSlow.future;
                if (search == 'fast') return completerFast.future;
                return Future.value(
                  const PaginatedResult(
                    items: [],
                    limit: 25,
                    offset: 0,
                    total: 0,
                  ),
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );

        controller.updateSearch('slow');
        controller.updateSearch('fast');

        completerFast.complete(
          PaginatedResult(
            items: [_createTestAthlete(id: 2, name: 'Fast Athlete')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          container
              .read(athletePaginationProvider(defaultScope))
              .items
              .first
              .name,
          'Fast Athlete',
        );

        completerSlow.complete(
          PaginatedResult(
            items: [_createTestAthlete(id: 1, name: 'Slow Athlete')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final finalState = container.read(
          athletePaginationProvider(defaultScope),
        );
        expect(finalState.items.first.name, 'Fast Athlete');
        expect(finalState.items.length, 1);
      },
    );

    test(
      'late error from superseded request does not corrupt active state',
      () async {
        final completer1 = Completer<PaginatedResult<Athlete>>();
        final completer2 = Completer<PaginatedResult<Athlete>>();

        final mockService = _MockAthleteService(
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
                if (search == 'query1') return completer1.future;
                if (search == 'query2') return completer2.future;
                return Future.value(
                  const PaginatedResult(
                    items: [],
                    limit: 25,
                    offset: 0,
                    total: 0,
                  ),
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );

        // 1. Query 1 fires
        controller.updateSearch('query1');
        // 2. Query 2 supersedes
        controller.updateSearch('query2');

        // 3. Query 2 succeeds
        completer2.complete(
          PaginatedResult(
            items: [_createTestAthlete(id: 2, name: 'Success Athlete 2')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          container.read(athletePaginationProvider(defaultScope)).items.length,
          1,
        );

        // 4. Query 1 completes with error
        completer1.completeError(Exception('Network timeout'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // State remains successful and error is suppressed
        final state = container.read(athletePaginationProvider(defaultScope));
        expect(state.error, isNull);
        expect(state.items.first.name, 'Success Athlete 2');
      },
    );

    test(
      'in-flight loadMore is invalidated when loadFirstPage is triggered',
      () async {
        final completerMore = Completer<PaginatedResult<Athlete>>();
        final completerNewSearch = Completer<PaginatedResult<Athlete>>();

        final mockService = _MockAthleteService(
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
                if (offset == 0 && search == null) {
                  return PaginatedResult(
                    items: [_createTestAthlete(id: 1, name: 'Initial Athlete')],
                    limit: 25,
                    offset: 0,
                    total: 50,
                  );
                }
                if (offset > 0) {
                  return completerMore.future;
                }
                return completerNewSearch.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );
        await controller.loadFirstPage();
        expect(
          container.read(athletePaginationProvider(defaultScope)).items.length,
          1,
        );

        // 1. Start loadMore
        final loadMoreFuture = controller.loadMore();

        // 2. User suddenly updates search (starts new generation)
        controller.updateSearch('new_search');

        // 3. New search resolves
        completerNewSearch.complete(
          PaginatedResult(
            items: [_createTestAthlete(id: 99, name: 'Search Result Athlete')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 4. Stale loadMore finishes
        completerMore.complete(
          PaginatedResult(
            items: [_createTestAthlete(id: 2, name: 'Stale Page 2 Athlete')],
            limit: 25,
            offset: 1,
            total: 50,
          ),
        );
        await loadMoreFuture;

        final state = container.read(athletePaginationProvider(defaultScope));
        expect(state.items.length, 1);
        expect(state.items.first.name, 'Search Result Athlete');
      },
    );

    test(
      'updating filter/search clears old items and total immediately during loading and leaves them empty on error',
      () async {
        final completerSearch = Completer<PaginatedResult<Athlete>>();

        final mockService = _MockAthleteService(
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
                if (search == null) {
                  return PaginatedResult(
                    items: [_createTestAthlete(id: 1, name: 'Old Athlete')],
                    limit: 25,
                    offset: 0,
                    total: 10,
                  );
                }
                return completerSearch.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );
        await controller.loadFirstPage();

        final loadedState = container.read(
          athletePaginationProvider(defaultScope),
        );
        expect(loadedState.items.length, 1);
        expect(loadedState.total, 10);

        // 1. Trigger search update
        controller.updateSearch('new_query');

        // Immediately during loading, old items and total must be reset
        final loadingState = container.read(
          athletePaginationProvider(defaultScope),
        );
        expect(loadingState.isLoading, isTrue);
        expect(loadingState.items, isEmpty);
        expect(loadingState.total, 0);
        expect(loadingState.hasMore, isFalse);

        // 2. Request fails
        completerSearch.completeError(Exception('Network error'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // After error, items must remain empty (not reverting to 'Old Athlete')
        final errorState = container.read(
          athletePaginationProvider(defaultScope),
        );
        expect(errorState.isLoading, isFalse);
        expect(errorState.items, isEmpty);
        expect(errorState.total, 0);
        expect(errorState.hasMore, isFalse);
        expect(errorState.error, isNotNull);
      },
    );
  });

  group('Pagination Race Condition Tests — CaborPaginationController', () {
    test(
      'slower first request does not overwrite faster second request',
      () async {
        final completerSlow = Completer<PaginatedResult<Cabor>>();
        final completerFast = Completer<PaginatedResult<Cabor>>();

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) {
                if (source == 'slow_source') return completerSlow.future;
                if (source == 'fast_source') return completerFast.future;
                return Future.value(
                  const PaginatedResult(
                    items: [],
                    limit: 25,
                    offset: 0,
                    total: 0,
                  ),
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(caborPaginationProvider.notifier);

        controller.loadFirstPage(source: 'slow_source');
        controller.loadFirstPage(source: 'fast_source');

        completerFast.complete(
          PaginatedResult(
            items: [_createTestCabor(id: 2, name: 'Fast Cabor')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          container.read(caborPaginationProvider).items.first.name,
          'Fast Cabor',
        );

        completerSlow.complete(
          PaginatedResult(
            items: [_createTestCabor(id: 1, name: 'Slow Cabor')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final finalState = container.read(caborPaginationProvider);
        expect(finalState.items.first.name, 'Fast Cabor');
        expect(finalState.items.length, 1);
      },
    );

    test(
      'late error from superseded request does not corrupt active state',
      () async {
        final completer1 = Completer<PaginatedResult<Cabor>>();
        final completer2 = Completer<PaginatedResult<Cabor>>();

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) {
                if (source == 'source1') return completer1.future;
                if (source == 'source2') return completer2.future;
                return Future.value(
                  const PaginatedResult(
                    items: [],
                    limit: 25,
                    offset: 0,
                    total: 0,
                  ),
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(caborPaginationProvider.notifier);

        // 1. Source 1 fires
        controller.loadFirstPage(source: 'source1');
        // 2. Source 2 supersedes
        controller.loadFirstPage(source: 'source2');

        // 3. Source 2 succeeds
        completer2.complete(
          PaginatedResult(
            items: [_createTestCabor(id: 2, name: 'Success Cabor 2')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(caborPaginationProvider).items.length, 1);

        // 4. Source 1 completes with error
        completer1.completeError(Exception('Network timeout'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // State remains successful and error is suppressed
        final state = container.read(caborPaginationProvider);
        expect(state.error, isNull);
        expect(state.items.first.name, 'Success Cabor 2');
      },
    );

    test(
      'in-flight loadMore is invalidated when loadFirstPage is triggered',
      () async {
        final completerMore = Completer<PaginatedResult<Cabor>>();
        final completerNewSearch = Completer<PaginatedResult<Cabor>>();

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                if (offset == 0 && source == 'all') {
                  return PaginatedResult(
                    items: [_createTestCabor(id: 1, name: 'Initial Cabor')],
                    limit: 25,
                    offset: 0,
                    total: 50,
                  );
                }
                if (offset > 0) {
                  return completerMore.future;
                }
                return completerNewSearch.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(caborPaginationProvider.notifier);
        await controller.loadFirstPage();
        expect(container.read(caborPaginationProvider).items.length, 1);

        // 1. Start loadMore
        final loadMoreFuture = controller.loadMore();

        // 2. User suddenly triggers new loadFirstPage (starts new generation)
        controller.loadFirstPage(source: 'new_source');

        // 3. New fetch resolves
        completerNewSearch.complete(
          PaginatedResult(
            items: [_createTestCabor(id: 99, name: 'Search Result Cabor')],
            limit: 25,
            offset: 0,
            total: 1,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 4. Stale loadMore finishes
        completerMore.complete(
          PaginatedResult(
            items: [_createTestCabor(id: 2, name: 'Stale Page 2 Cabor')],
            limit: 25,
            offset: 1,
            total: 50,
          ),
        );
        await loadMoreFuture;

        final state = container.read(caborPaginationProvider);
        expect(state.items.length, 1);
        expect(state.items.first.name, 'Search Result Cabor');
      },
    );

    test(
      'updating filter clears old items and total immediately during loading and leaves them empty on error',
      () async {
        final completerFetch = Completer<PaginatedResult<Cabor>>();

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                if (source == 'all') {
                  return PaginatedResult(
                    items: [_createTestCabor(id: 1, name: 'Old Cabor')],
                    limit: 25,
                    offset: 0,
                    total: 10,
                  );
                }
                return completerFetch.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWithValue(defaultContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(caborPaginationProvider.notifier);
        await controller.loadFirstPage();

        final loadedState = container.read(caborPaginationProvider);
        expect(loadedState.items.length, 1);
        expect(loadedState.total, 10);

        // 1. Trigger filter update
        controller.loadFirstPage(source: 'filtered');

        // Immediately during loading, old items and total must be reset
        final loadingState = container.read(caborPaginationProvider);
        expect(loadingState.isLoading, isTrue);
        expect(loadingState.items, isEmpty);
        expect(loadingState.total, 0);
        expect(loadingState.hasMore, isFalse);

        // 2. Request fails
        completerFetch.completeError(Exception('Network error'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // After error, items must remain empty (not reverting to 'Old Cabor')
        final errorState = container.read(caborPaginationProvider);
        expect(errorState.isLoading, isFalse);
        expect(errorState.items, isEmpty);
        expect(errorState.total, 0);
        expect(errorState.hasMore, isFalse);
        expect(errorState.error, isNotNull);
      },
    );
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/athlete_service.dart';

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
    return PaginatedResult(
      items: [
        _createTestAthlete(
          id: offset + 1,
          name: 'Default Athlete ${offset + 1}',
        ),
      ],
      limit: limit,
      offset: offset,
      total: 50,
    );
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  const defaultScope = (idCabor: null, idClub: null);

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

  group('AthletePaginationController Session & Context Switching Tests', () {
    test('loads data successfully under Context A', () async {
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
              return PaginatedResult(
                items: [
                  _createTestAthlete(id: 1, name: 'Garut Athlete 1'),
                  _createTestAthlete(id: 2, name: 'Garut Athlete 2'),
                ],
                limit: limit,
                offset: offset,
                total: 2,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(contextA),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        athletePaginationProvider(defaultScope).notifier,
      );
      await controller.loadFirstPage();

      final state = container.read(athletePaginationProvider(defaultScope));
      expect(state.items.length, 2);
      expect(state.items.first.name, 'Garut Athlete 1');
      expect(state.total, 2);
    });

    test(
      'resets pagination state when context switches from Context A to Context B',
      () async {
        DataRequestContext? currentContext = contextA;

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
                if (currentContext?.userId == 'user-a') {
                  return PaginatedResult(
                    items: [
                      _createTestAthlete(id: 1, name: 'Context A Athlete'),
                    ],
                    limit: limit,
                    offset: offset,
                    total: 1,
                  );
                } else {
                  return PaginatedResult(
                    items: [
                      _createTestAthlete(id: 2, name: 'Context B Athlete'),
                    ],
                    limit: limit,
                    offset: offset,
                    total: 1,
                  );
                }
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Initial load under Context A
        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );
        await controller.loadFirstPage();

        expect(
          container
              .read(athletePaginationProvider(defaultScope))
              .items
              .first
              .name,
          'Context A Athlete',
        );

        // 2. Switch context to Context B
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);

        // State is automatically reset because build() watches dataRequestContextProvider
        final resetState = container.read(
          athletePaginationProvider(defaultScope),
        );
        expect(resetState.items, isEmpty);
        expect(resetState.total, 0);

        // 3. Load first page under Context B
        final controllerB = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );
        await controllerB.loadFirstPage();

        expect(
          container
              .read(athletePaginationProvider(defaultScope))
              .items
              .first
              .name,
          'Context B Athlete',
        );
      },
    );

    test(
      'resets state and rejects loadFirstPage when user logs out (context becomes null)',
      () async {
        DataRequestContext? currentContext = contextA;
        var fetchCallCount = 0;

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
                fetchCallCount++;
                return PaginatedResult(
                  items: [_createTestAthlete(id: 1, name: 'Active Athlete')],
                  limit: limit,
                  offset: offset,
                  total: 1,
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Load under active session
        final controller = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );
        await controller.loadFirstPage();
        expect(fetchCallCount, 1);
        expect(
          container.read(athletePaginationProvider(defaultScope)).items.length,
          1,
        );

        // 2. Logout (context -> null)
        currentContext = null;
        container.refresh(dataRequestContextProvider);

        final loggedOutState = container.read(
          athletePaginationProvider(defaultScope),
        );
        expect(loggedOutState.items, isEmpty);
        expect(loggedOutState.total, 0);

        // 3. Attempting loadFirstPage when logged out does nothing
        final controllerLoggedOut = container.read(
          athletePaginationProvider(defaultScope).notifier,
        );
        await controllerLoggedOut.loadFirstPage();
        expect(fetchCallCount, 1); // No new network call was made
        expect(
          container.read(athletePaginationProvider(defaultScope)).items,
          isEmpty,
        );
      },
    );

    test(
      'loadMore discards response if session context changes while in-flight',
      () async {
        DataRequestContext? currentContext = contextA;
        final completerMore = Completer<PaginatedResult<Athlete>>();

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
                if (offset == 0) {
                  return PaginatedResult(
                    items: [_createTestAthlete(id: 1, name: 'Initial Athlete')],
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
            athleteServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
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

        // Start loadMore
        controller.loadMore();

        // Session switches before loadMore completes
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);

        // Complete pending loadMore from context A
        completerMore.complete(
          PaginatedResult(
            items: [_createTestAthlete(id: 2, name: 'Stale Context A Athlete')],
            limit: 25,
            offset: 1,
            total: 50,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        // The stale data must NOT be appended to state
        final state = container.read(athletePaginationProvider(defaultScope));
        expect(
          state.items.any((a) => a.name == 'Stale Context A Athlete'),
          isFalse,
        );
      },
    );

    test('loadMore returns immediately if context is null', () async {
      final container = ProviderContainer(
        overrides: [
          athleteServiceProvider.overrideWithValue(_MockAthleteService()),
          dataRequestContextProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        athletePaginationProvider(defaultScope).notifier,
      );
      await controller.loadMore();

      final state = container.read(athletePaginationProvider(defaultScope));
      expect(state.items, isEmpty);
      expect(state.isLoadingMore, isFalse);
    });
  });
}

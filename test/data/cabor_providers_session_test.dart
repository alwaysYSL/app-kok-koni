import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';

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
    return PaginatedResult(
      items: [
        _createTestCabor(id: offset + 1, name: 'Default Cabor ${offset + 1}'),
      ],
      limit: limit,
      offset: offset,
      total: 50,
    );
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

  group('CaborPaginationController Session & Context Switching Tests', () {
    test('loads data successfully under Context A', () async {
      final mockService = _MockCaborService(
        onFetchList:
            ({
              int limit = 25,
              int offset = 0,
              String source = 'all',
              String sort = 'name',
              RequestCancellation? cancellation,
            }) async {
              return PaginatedResult(
                items: [
                  _createTestCabor(id: 1, name: 'Garut Cabor 1'),
                  _createTestCabor(id: 2, name: 'Garut Cabor 2'),
                ],
                limit: limit,
                offset: offset,
                total: 2,
              );
            },
      );

      final container = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(contextA),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(caborPaginationProvider.notifier);
      await controller.loadFirstPage();

      final state = container.read(caborPaginationProvider);
      expect(state.items.length, 2);
      expect(state.items.first.name, 'Garut Cabor 1');
      expect(state.total, 2);
    });

    test(
      'resets pagination state when context switches from Context A to Context B',
      () async {
        DataRequestContext? currentContext = contextA;

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                if (currentContext?.userId == 'user-a') {
                  return PaginatedResult(
                    items: [_createTestCabor(id: 1, name: 'Context A Cabor')],
                    limit: limit,
                    offset: offset,
                    total: 1,
                  );
                } else {
                  return PaginatedResult(
                    items: [_createTestCabor(id: 2, name: 'Context B Cabor')],
                    limit: limit,
                    offset: offset,
                    total: 1,
                  );
                }
              },
        );

        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Initial load under Context A
        final controller = container.read(caborPaginationProvider.notifier);
        await controller.loadFirstPage();

        expect(
          container.read(caborPaginationProvider).items.first.name,
          'Context A Cabor',
        );

        // 2. Switch context to Context B
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);

        // State is automatically reset because build() watches dataRequestContextProvider
        final resetState = container.read(caborPaginationProvider);
        expect(resetState.items, isEmpty);
        expect(resetState.total, 0);

        // 3. Load first page under Context B
        final controllerB = container.read(caborPaginationProvider.notifier);
        await controllerB.loadFirstPage();

        expect(
          container.read(caborPaginationProvider).items.first.name,
          'Context B Cabor',
        );
      },
    );

    test(
      'resets state and rejects loadFirstPage when user logs out (context becomes null)',
      () async {
        DataRequestContext? currentContext = contextA;
        var fetchCallCount = 0;

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                fetchCallCount++;
                return PaginatedResult(
                  items: [_createTestCabor(id: 1, name: 'Active Cabor')],
                  limit: limit,
                  offset: offset,
                  total: 1,
                );
              },
        );

        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Load under active session
        final controller = container.read(caborPaginationProvider.notifier);
        await controller.loadFirstPage();
        expect(fetchCallCount, 1);
        expect(container.read(caborPaginationProvider).items.length, 1);

        // 2. Logout (context -> null)
        currentContext = null;
        container.refresh(dataRequestContextProvider);

        final loggedOutState = container.read(caborPaginationProvider);
        expect(loggedOutState.items, isEmpty);
        expect(loggedOutState.total, 0);

        // 3. Attempting loadFirstPage when logged out does nothing
        final controllerLoggedOut = container.read(
          caborPaginationProvider.notifier,
        );
        await controllerLoggedOut.loadFirstPage();
        expect(fetchCallCount, 1); // No new network call was made
        expect(container.read(caborPaginationProvider).items, isEmpty);
      },
    );

    test(
      'loadMore discards response if session context changes while in-flight',
      () async {
        DataRequestContext? currentContext = contextA;
        final completerMore = Completer<PaginatedResult<Cabor>>();

        final mockService = _MockCaborService(
          onFetchList:
              ({
                int limit = 25,
                int offset = 0,
                String source = 'all',
                String sort = 'name',
                RequestCancellation? cancellation,
              }) async {
                if (offset == 0) {
                  return PaginatedResult(
                    items: [_createTestCabor(id: 1, name: 'Initial Cabor')],
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
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => currentContext),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(caborPaginationProvider.notifier);
        await controller.loadFirstPage();
        expect(container.read(caborPaginationProvider).items.length, 1);

        // Start loadMore
        controller.loadMore();

        // Session switches before loadMore completes
        currentContext = contextB;
        container.refresh(dataRequestContextProvider);

        // Complete pending loadMore from context A
        completerMore.complete(
          PaginatedResult(
            items: [_createTestCabor(id: 2, name: 'Stale Context A Cabor')],
            limit: 25,
            offset: 1,
            total: 50,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        // The stale data must NOT be appended to state
        final state = container.read(caborPaginationProvider);
        expect(
          state.items.any((c) => c.name == 'Stale Context A Cabor'),
          isFalse,
        );
      },
    );

    test('loadMore returns immediately if context is null', () async {
      final container = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(_MockCaborService()),
          dataRequestContextProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(caborPaginationProvider.notifier);
      await controller.loadMore();

      final state = container.read(caborPaginationProvider);
      expect(state.items, isEmpty);
      expect(state.isLoadingMore, isFalse);
    });
  });
}

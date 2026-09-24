import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';
import 'package:kok_app/data/services/profile_service.dart';

class MockProfileService implements ProfileService {
  MockProfileService({this.onFetch});

  final Future<ProfileSummary> Function(RequestCancellation? cancellation)?
  onFetch;

  @override
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  }) async {
    if (onFetch != null) {
      return onFetch!(cancellation);
    }
    return const ProfileSummary(
      scope: SicaborScope(
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      ),
      member: SicaborMember(
        id: 1,
        username: 'user',
        name: 'User',
        type: 'admin_kok',
        status: 1,
        statusLabel: 'Aktif',
      ),
      totalCabor: 5,
      totalCaborFromClub: 5,
      totalCaborFromAthlete: 5,
      totalClub: 10,
      totalAthlete: 50,
      totalAthleteWithoutClub: 0,
    );
  }
}

class MockCaborService implements CaborService {
  MockCaborService({this.onFetch});

  final Future<PaginatedResult<Cabor>> Function({
    int limit,
    int offset,
    String source,
    String sort,
    RequestCancellation? cancellation,
  })?
  onFetch;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    if (onFetch != null) {
      return onFetch!(
        limit: limit,
        offset: offset,
        source: source,
        sort: sort,
        cancellation: cancellation,
      );
    }
    final items = List.generate(
      limit,
      (i) => Cabor(
        id: offset + i + 1,
        code: 'CB-${offset + i + 1}',
        name: 'Cabor ${offset + i + 1}',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 1,
        totalAthlete: 10,
      ),
    );
    return PaginatedResult(
      items: items,
      limit: limit,
      offset: offset,
      total: 50,
    );
  }
}

void main() {
  const defaultContext = DataRequestContext(
    environment: AppEnv.demo,
    userId: '1',
    scope: AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
    generation: 1,
  );

  test('caborById resolves a direct link on the second page', () async {
    final offsets = <int>[];
    final container = ProviderContainer(
      overrides: [
        dataRequestContextProvider.overrideWithValue(defaultContext),
        caborServiceProvider.overrideWithValue(
          MockCaborService(
            onFetch:
                ({
                  int limit = 25,
                  int offset = 0,
                  String source = 'all',
                  String sort = 'name',
                  RequestCancellation? cancellation,
                }) async {
                  offsets.add(offset);
                  expect(limit, 100);
                  expect(source, 'all');
                  expect(sort, 'name');
                  return PaginatedResult(
                    items: [
                      Cabor(
                        id: offset == 0 ? 1 : 31,
                        code: 'CB',
                        name: 'Cabor',
                        status: 1,
                        statusLabel: 'Aktif',
                        totalClub: 0,
                        totalAthlete: 2,
                      ),
                    ],
                    limit: limit,
                    offset: offset,
                    total: 2,
                  );
                },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect((await container.read(caborByIdProvider(31).future))?.id, 31);
    expect(offsets, [0, 1]);
  });

  test('caborById stops on an empty page even with remaining total', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        dataRequestContextProvider.overrideWithValue(defaultContext),
        caborServiceProvider.overrideWithValue(
          MockCaborService(
            onFetch:
                ({
                  int limit = 25,
                  int offset = 0,
                  String source = 'all',
                  String sort = 'name',
                  RequestCancellation? cancellation,
                }) async {
                  calls++;
                  return PaginatedResult(
                    items: const <Cabor>[],
                    limit: limit,
                    offset: offset,
                    total: 200,
                  );
                },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(caborByIdProvider(31).future), isNull);
    expect(calls, 1);
    expect(await container.read(caborByIdProvider(0).future), isNull);
    expect(calls, 1);
  });

  test('caborById does not continue pagination after session ends', () async {
    final pending = Completer<PaginatedResult<Cabor>>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        dataRequestContextProvider.overrideWithValue(defaultContext),
        caborServiceProvider.overrideWithValue(
          MockCaborService(
            onFetch:
                ({
                  int limit = 25,
                  int offset = 0,
                  String source = 'all',
                  String sort = 'name',
                  RequestCancellation? cancellation,
                }) {
                  calls++;
                  return pending.future;
                },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(caborByIdProvider(31), (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    container.updateOverrides([
      dataRequestContextProvider.overrideWithValue(null),
      caborServiceProvider.overrideWithValue(
        container.read(caborServiceProvider),
      ),
    ]);
    await container.pump();
    pending.complete(
      const PaginatedResult(
        items: [
          Cabor(
            id: 1,
            code: 'CB',
            name: 'Cabor',
            status: 1,
            statusLabel: 'Aktif',
            totalClub: 0,
            totalAthlete: 1,
          ),
        ],
        limit: 100,
        offset: 0,
        total: 2,
      ),
    );
    await container.pump();
    expect(calls, 1);
    expect(container.read(caborByIdProvider(31)).hasError, isTrue);
  });

  group('Profile Providers Tests', () {
    test('profileSummaryProvider loads data successfully', () async {
      final container = ProviderContainer(
        overrides: [
          profileServiceProvider.overrideWithValue(MockProfileService()),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(profileSummaryProvider.future);
      expect(summary.totalCabor, equals(5));
      expect(summary.totalClub, equals(10));
    });

    test(
      'profileSummaryProvider throws RequestCancelledException when context is null',
      () async {
        final container = ProviderContainer(
          overrides: [
            profileServiceProvider.overrideWithValue(MockProfileService()),
            dataRequestContextProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        expect(
          () => container.read(profileSummaryProvider.future),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('profileSummaryProvider cancels token on dispose', () async {
      RequestCancellation? capturedToken;
      final completer = Completer<ProfileSummary>();

      final mockService = MockProfileService(
        onFetch: (cancellation) {
          capturedToken = cancellation;
          cancellation?.whenCancelled.then((reason) {
            if (!completer.isCompleted) {
              completer.complete(
                const ProfileSummary(
                  scope: SicaborScope(
                    subdistrictId: 0,
                    subdistrictName: '',
                    districtId: 0,
                    districtName: '',
                  ),
                  member: SicaborMember(
                    id: 0,
                    username: '',
                    name: '',
                    type: '',
                    status: 0,
                    statusLabel: '',
                  ),
                  totalCabor: 0,
                  totalCaborFromClub: 0,
                  totalCaborFromAthlete: 0,
                  totalClub: 0,
                  totalAthlete: 0,
                  totalAthleteWithoutClub: 0,
                ),
              );
            }
          });
          return completer.future;
        },
      );

      final container = ProviderContainer(
        overrides: [
          profileServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );

      final sub = container.listen(profileSummaryProvider, (previous, next) {});
      expect(capturedToken, isNotNull);
      expect(capturedToken!.isCancelled, isFalse);

      sub.close();
      container.dispose();

      expect(capturedToken!.isCancelled, isTrue);
      expect(capturedToken!.reason, 'Provider disposed');
    });

    test(
      'profileSummaryProvider rejects stale response when session changes in background',
      () async {
        final completerA = Completer<ProfileSummary>();
        final completerB = Completer<ProfileSummary>();
        var fetchCount = 0;

        final mockService = MockProfileService(
          onFetch: (cancellation) {
            fetchCount++;
            if (fetchCount == 1) {
              return completerA.future;
            }
            return completerB.future;
          },
        );

        var activeContext = defaultContext;
        late final ProviderContainer container;

        container = ProviderContainer(
          overrides: [
            profileServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => activeContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Start fetch for context A
        final sub = container.listen(
          profileSummaryProvider,
          (previous, next) {},
        );
        addTearDown(sub.close);
        expect(fetchCount, equals(1));

        // 2. Session switches to context B
        activeContext = const DataRequestContext(
          environment: AppEnv.demo,
          userId: '2',
          scope: AccessScope(
            type: AccessScopeType.district,
            id: '1729',
            name: 'Tarogong Kidul',
          ),
          generation: 2,
        );
        container.refresh(dataRequestContextProvider);

        // 3. Start fetch for context B
        final futureB = container.read(profileSummaryProvider.future);
        expect(fetchCount, equals(2));

        // 4. Complete A late
        completerA.complete(
          const ProfileSummary(
            scope: SicaborScope(
              subdistrictId: 1728,
              subdistrictName: 'Garut Kota',
              districtId: 126,
              districtName: 'Garut',
            ),
            member: SicaborMember(
              id: 1,
              username: 'user1',
              name: 'User 1',
              type: 'admin_kok',
              status: 1,
              statusLabel: 'Aktif',
            ),
            totalCabor: 1,
            totalCaborFromClub: 1,
            totalCaborFromAthlete: 1,
            totalClub: 1,
            totalAthlete: 10,
            totalAthleteWithoutClub: 0,
          ),
        );

        // 5. Complete B with B's data
        const summaryB = ProfileSummary(
          scope: SicaborScope(
            subdistrictId: 1729,
            subdistrictName: 'Tarogong Kidul',
            districtId: 126,
            districtName: 'Garut',
          ),
          member: SicaborMember(
            id: 2,
            username: 'user2',
            name: 'User 2',
            type: 'admin_kok',
            status: 1,
            statusLabel: 'Aktif',
          ),
          totalCabor: 2,
          totalCaborFromClub: 2,
          totalCaborFromAthlete: 2,
          totalClub: 2,
          totalAthlete: 20,
          totalAthleteWithoutClub: 0,
        );
        completerB.complete(summaryB);

        // 6. Read profileSummaryProvider - it MUST return summary B, never stale A!
        final result = await futureB;
        expect(result.scope.subdistrictName, equals('Tarogong Kidul'));
        expect(result.member.username, equals('user2'));
      },
    );
  });

  group('Cabor Providers Tests', () {
    test('caborListProvider loads data with parameters', () async {
      final container = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(MockCaborService()),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        caborListProvider((
          offset: 0,
          limit: 10,
          source: 'all',
          sort: 'name',
        )).future,
      );
      expect(result.items.length, equals(10));
      expect(result.total, equals(50));
      expect(result.hasMore, isTrue);
    });

    test(
      'caborListProvider throws RequestCancelledException when context is null',
      () async {
        final container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(MockCaborService()),
            dataRequestContextProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        expect(
          () => container.read(
            caborListProvider((
              offset: 0,
              limit: 10,
              source: 'all',
              sort: 'name',
            )).future,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('caborListProvider cancels token on dispose', () async {
      RequestCancellation? capturedToken;
      final completer = Completer<PaginatedResult<Cabor>>();

      final mockService = MockCaborService(
        onFetch:
            ({
              limit = 25,
              offset = 0,
              source = 'all',
              sort = 'name',
              cancellation,
            }) {
              capturedToken = cancellation;
              cancellation?.whenCancelled.then((reason) {
                if (!completer.isCompleted) {
                  completer.complete(
                    const PaginatedResult(
                      items: [],
                      limit: 25,
                      offset: 0,
                      total: 0,
                    ),
                  );
                }
              });
              return completer.future;
            },
      );

      final container = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(mockService),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );

      final sub = container.listen(
        caborListProvider((offset: 0, limit: 10, source: 'all', sort: 'name')),
        (previous, next) {},
      );
      expect(capturedToken, isNotNull);
      expect(capturedToken!.isCancelled, isFalse);

      sub.close();
      container.dispose();

      expect(capturedToken!.isCancelled, isTrue);
      expect(capturedToken!.reason, 'Provider disposed');
    });

    test(
      'caborListProvider rejects stale response when session changes in background',
      () async {
        final completerA = Completer<PaginatedResult<Cabor>>();
        final completerB = Completer<PaginatedResult<Cabor>>();
        var fetchCount = 0;

        final mockService = MockCaborService(
          onFetch:
              ({
                limit = 25,
                offset = 0,
                source = 'all',
                sort = 'name',
                cancellation,
              }) {
                fetchCount++;
                if (fetchCount == 1) {
                  return completerA.future;
                }
                return completerB.future;
              },
        );

        var activeContext = defaultContext;
        late final ProviderContainer container;

        container = ProviderContainer(
          overrides: [
            caborServiceProvider.overrideWithValue(mockService),
            dataRequestContextProvider.overrideWith((ref) => activeContext),
          ],
        );
        addTearDown(container.dispose);

        // 1. Start fetch for context A
        final sub = container.listen(
          caborListProvider((
            offset: 0,
            limit: 10,
            source: 'all',
            sort: 'name',
          )),
          (previous, next) {},
        );
        addTearDown(sub.close);
        expect(fetchCount, equals(1));

        // 2. Session switches to context B
        activeContext = const DataRequestContext(
          environment: AppEnv.demo,
          userId: '2',
          scope: AccessScope(
            type: AccessScopeType.district,
            id: '1729',
            name: 'Tarogong Kidul',
          ),
          generation: 2,
        );
        container.refresh(dataRequestContextProvider);

        // 3. Start fetch for context B
        final futureB = container.read(
          caborListProvider((
            offset: 0,
            limit: 10,
            source: 'all',
            sort: 'name',
          )).future,
        );
        expect(fetchCount, equals(2));

        // 4. Complete A late with stale data
        completerA.complete(
          const PaginatedResult(
            items: [
              Cabor(
                id: 1,
                code: 'CB-1',
                name: 'Garut Kota Cabor',
                status: 1,
                statusLabel: 'Aktif',
                totalClub: 1,
                totalAthlete: 5,
              ),
            ],
            limit: 10,
            offset: 0,
            total: 1,
          ),
        );

        // 5. Complete B with B's data
        completerB.complete(
          const PaginatedResult(
            items: [
              Cabor(
                id: 2,
                code: 'CB-2',
                name: 'Tarogong Kidul Cabor',
                status: 1,
                statusLabel: 'Aktif',
                totalClub: 2,
                totalAthlete: 10,
              ),
            ],
            limit: 10,
            offset: 0,
            total: 1,
          ),
        );

        // 6. Read caborListProvider - it MUST return B's data, never stale A!
        final result = await futureB;
        expect(result.items.first.name, equals('Tarogong Kidul Cabor'));
      },
    );
  });

  group('CaborPaginationController Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(MockCaborService()),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('initial state is default', () {
      final state = container.read(caborPaginationProvider);
      expect(state.items, isEmpty);
      expect(state.total, equals(0));
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.error, isNull);
      expect(state.loadMoreError, isNull);
      expect(state.source, equals('all'));
      expect(state.sort, equals('name'));
    });

    test('loadFirstPage loads first page and updates state', () async {
      final controller = container.read(caborPaginationProvider.notifier);
      await controller.loadFirstPage();

      final state = container.read(caborPaginationProvider);
      expect(state.items.length, equals(25));
      expect(state.total, equals(50));
      expect(state.hasMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loadFirstPage captures error in state', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(
            MockCaborService(
              onFetch:
                  ({
                    limit = 25,
                    offset = 0,
                    source = 'all',
                    sort = 'name',
                    cancellation,
                  }) => Future.error(Exception('Network error')),
            ),
          ),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );
      addTearDown(errorContainer.dispose);

      final controller = errorContainer.read(caborPaginationProvider.notifier);
      await controller.loadFirstPage();

      final state = errorContainer.read(caborPaginationProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.items, isEmpty);
    });

    test('loadMore loads next page and appends items', () async {
      final controller = container.read(caborPaginationProvider.notifier);
      await controller.loadFirstPage();

      final state1 = container.read(caborPaginationProvider);
      expect(state1.items.length, equals(25));
      expect(state1.hasMore, isTrue);

      await controller.loadMore();
      final state2 = container.read(caborPaginationProvider);
      expect(state2.items.length, equals(50));
      expect(state2.hasMore, isFalse);
      expect(state2.isLoadingMore, isFalse);
      expect(state2.loadMoreError, isNull);
    });

    test(
      'loadMore does nothing if hasMore is false or already loading',
      () async {
        final controller = container.read(caborPaginationProvider.notifier);
        await controller.loadFirstPage();
        await controller.loadMore();

        final stateAfterFull = container.read(caborPaginationProvider);
        expect(stateAfterFull.hasMore, isFalse);

        // Call loadMore again when hasMore is false
        await controller.loadMore();
        final stateAfterExtra = container.read(caborPaginationProvider);
        expect(stateAfterExtra.items.length, equals(50));
      },
    );

    test('loadMore preserves existing items on loadMore error', () async {
      var callCount = 0;
      final errorContainer = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(
            MockCaborService(
              onFetch:
                  ({
                    limit = 25,
                    offset = 0,
                    source = 'all',
                    sort = 'name',
                    cancellation,
                  }) async {
                    callCount++;
                    if (callCount == 1) {
                      return PaginatedResult(
                        items: List.generate(
                          25,
                          (i) => Cabor(
                            id: i + 1,
                            code: 'CB-${i + 1}',
                            name: 'Cabor ${i + 1}',
                            status: 1,
                            statusLabel: 'Aktif',
                            totalClub: 1,
                            totalAthlete: 5,
                          ),
                        ),
                        limit: 25,
                        offset: 0,
                        total: 50,
                      );
                    } else {
                      throw Exception('Load more failed');
                    }
                  },
            ),
          ),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );
      addTearDown(errorContainer.dispose);

      final controller = errorContainer.read(caborPaginationProvider.notifier);
      await controller.loadFirstPage();

      final state1 = errorContainer.read(caborPaginationProvider);
      expect(state1.items.length, equals(25));
      expect(state1.hasMore, isTrue);

      await controller.loadMore();
      final state2 = errorContainer.read(caborPaginationProvider);
      expect(state2.items.length, equals(25)); // Preserved!
      expect(state2.isLoadingMore, isFalse);
      expect(state2.loadMoreError, isNotNull);
    });

    test('refresh reloads first page with current sort and source', () async {
      String? lastSource;
      String? lastSort;

      final refreshContainer = ProviderContainer(
        overrides: [
          caborServiceProvider.overrideWithValue(
            MockCaborService(
              onFetch:
                  ({
                    limit = 25,
                    offset = 0,
                    source = 'all',
                    sort = 'name',
                    cancellation,
                  }) async {
                    lastSource = source;
                    lastSort = sort;
                    return PaginatedResult(
                      items: [
                        const Cabor(
                          id: 1,
                          code: 'CB-1',
                          name: 'Cabor 1',
                          status: 1,
                          statusLabel: 'Aktif',
                          totalClub: 1,
                          totalAthlete: 5,
                        ),
                      ],
                      limit: limit,
                      offset: offset,
                      total: 1,
                    );
                  },
            ),
          ),
          dataRequestContextProvider.overrideWithValue(defaultContext),
        ],
      );
      addTearDown(refreshContainer.dispose);

      final controller = refreshContainer.read(
        caborPaginationProvider.notifier,
      );
      await controller.loadFirstPage(source: 'club', sort: 'athlete_count');

      expect(lastSource, equals('club'));
      expect(lastSort, equals('athlete_count'));

      await controller.refresh();
      expect(lastSource, equals('club'));
      expect(lastSort, equals('athlete_count'));
    });
  });
}

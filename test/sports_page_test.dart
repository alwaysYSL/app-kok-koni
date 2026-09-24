import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';
import 'package:kok_app/features/sports_page.dart';

class FakeCaborService implements CaborService {
  FakeCaborService({
    required this.allCabors,
    this.shouldThrow = false,
    this.errorToThrow,
    this.onFetch,
  });

  final List<Cabor> allCabors;
  final bool shouldThrow;
  final Object? errorToThrow;
  final Future<PaginatedResult<Cabor>> Function(
    int limit,
    int offset,
    String source,
    String sort,
  )?
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
      return onFetch!(limit, offset, source, sort);
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (shouldThrow) {
      throw Exception('Network error');
    }
    final items = allCabors.skip(offset).take(limit).toList();
    return PaginatedResult<Cabor>(
      items: items,
      limit: limit,
      offset: offset,
      total: allCabors.length,
    );
  }
}

void main() {
  const defaultScope = SicaborScope(
    subdistrictId: 1728,
    subdistrictName: 'Kecamatan Garut Kota',
    districtId: 126,
    districtName: 'Kabupaten Garut',
  );

  const defaultSummary = ProfileSummary(
    scope: defaultScope,
    member: SicaborMember(
      id: 1,
      username: 'admin',
      name: 'Pak Asep',
      type: 'admin',
      status: 1,
      statusLabel: 'Aktif',
    ),
    totalCabor: 5,
    totalCaborFromClub: 5,
    totalCaborFromAthlete: 5,
    totalClub: 15,
    totalAthlete: 120,
    totalAthleteWithoutClub: 0,
  );

  final sampleCabors = [
    const Cabor(
      id: 1,
      code: 'CB-001',
      name: 'Pencak Silat',
      groupName: 'IPSI',
      status: 1,
      statusLabel: 'Aktif',
      totalClub: 5,
      totalAthlete: 44,
      logoUrl: 'https://example.com/ipsi.png',
    ),
    const Cabor(
      id: 2,
      code: 'CB-002',
      name: 'Sepak Bola',
      groupName: 'PSSI',
      status: 1,
      statusLabel: 'Aktif',
      totalClub: 4,
      totalAthlete: 34,
    ),
    const Cabor(
      id: 3,
      code: 'CB-003',
      name: 'Bulu Tangkis',
      groupName: 'PBSI',
      status: 1,
      statusLabel: 'Aktif',
      totalClub: 3,
      totalAthlete: 22,
    ),
    const Cabor(
      id: 4,
      code: 'CB-004',
      name: 'Bola Voli',
      groupName: 'PBVSI',
      status: 1,
      statusLabel: 'Aktif',
      totalClub: 2,
      totalAthlete: 14,
    ),
    const Cabor(
      id: 5,
      code: 'CB-005',
      name: 'Renang',
      groupName: 'PRSI',
      status: 1,
      statusLabel: 'Aktif',
      totalClub: 1,
      totalAthlete: 6,
    ),
  ];

  group('SportsPage Widget Tests', () {
    Widget buildSubject({
      List<Cabor>? cabors,
      ProfileSummary? summary = defaultSummary,
      bool shouldThrow = false,
      Object? errorToThrow,
      Future<PaginatedResult<Cabor>> Function(
        int limit,
        int offset,
        String source,
        String sort,
      )?
      onFetch,
      String? Function(String route)? onNavigated,
      UserPrincipal? user,
    }) {
      final fakeService = FakeCaborService(
        allCabors: cabors ?? sampleCabors,
        shouldThrow: shouldThrow,
        errorToThrow: errorToThrow,
        onFetch: onFetch,
      );

      final router = GoRouter(
        initialLocation: '/sports',
        routes: [
          GoRoute(path: '/sports', builder: (_, _) => const SportsPage()),
          GoRoute(
            path: '/sport/:id',
            builder: (_, s) {
              final id = s.pathParameters['id'];
              onNavigated?.call('/sport/$id');
              return Scaffold(body: Text('Detail ID: $id'));
            },
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          caborServiceProvider.overrideWithValue(fakeService),
          if (summary != null)
            profileSummaryProvider.overrideWith((ref) => summary),
          if (user != null) currentUserProvider.overrideWithValue(user),
          dataRequestContextProvider.overrideWithValue(
            const DataRequestContext(
              environment: AppEnv.demo,
              userId: 'test_user',
              scope: AccessScope(
                type: AccessScopeType.district,
                id: 'garut_kota',
                name: 'Kecamatan Garut Kota',
              ),
              generation: 1,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets(
      'renders compact header with dynamic scope name and total stats',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Cabang Olahraga'), findsOneWidget);
        expect(find.text('Cabang Olahraga Aktif'), findsNothing);
        expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
        expect(find.text('5 Cabor'), findsOneWidget);
        expect(find.text('DIREKTORI CABANG OLAHRAGA'), findsNothing);
      },
    );

    testWidgets('filters the directory to cabors with clubs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ada Klub'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SportsPage)),
      );
      expect(container.read(caborPaginationProvider).source, 'club');
      expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsNothing);
    });

    testWidgets('sort selection requests athlete order', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Atlet').first);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SportsPage)),
      );
      expect(container.read(caborPaginationProvider).sort, 'athlete');
    });

    testWidgets('shows zero scoped cabors after selecting Ada Klub', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(
          onFetch: (limit, offset, source, sort) async {
            final items = source == 'club' ? <Cabor>[] : sampleCabors;
            return PaginatedResult<Cabor>(
              items: items,
              limit: limit,
              offset: offset,
              total: items.length,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pencak Silat'), findsOneWidget);

      await tester.tap(find.text('Ada Klub'));
      await tester.pumpAndSettle();

      expect(find.text('0 Cabor'), findsOneWidget);
      expect(find.text('Pencak Silat'), findsNothing);
      expect(find.text('Belum ada cabang olahraga terdaftar.'), findsOneWidget);
    });

    testWidgets(
      'displays cabor cards with groupName, metric chips, and logo or avatar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Verify group names
        expect(find.text('IPSI'), findsOneWidget);
        expect(find.text('PSSI'), findsOneWidget);
        expect(find.text('PBSI'), findsOneWidget);
        expect(find.text('PBVSI'), findsOneWidget);
        expect(find.text('PRSI'), findsOneWidget);

        // Verify metric chips
        expect(find.text('5 Klub'), findsOneWidget);
        expect(find.text('44 Atlet'), findsOneWidget);
        expect(find.text('4 Klub'), findsOneWidget);
        expect(find.text('34 Atlet'), findsOneWidget);
      },
    );

    testWidgets('tapping cabor card navigates to /sport/:id', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? navigatedRoute;
      await tester.pumpWidget(
        buildSubject(onNavigated: (route) => navigatedRoute = route),
      );
      await tester.pumpAndSettle();

      // Ensure visible and tap Bulu Tangkis card (id = 3)
      final buluTangkisFinder = find.text('Bulu Tangkis').last;
      await tester.ensureVisible(buluTangkisFinder);
      await tester.pumpAndSettle();
      await tester.tap(buluTangkisFinder);
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/sport/3');
      expect(find.text('Detail ID: 3'), findsOneWidget);
    });

    testWidgets(
      'renders dynamic territory scope title when profileSummary has custom scope',
      (tester) async {
        const customScope = SicaborScope(
          subdistrictId: 1729,
          subdistrictName: 'Kecamatan Tarogong Kidul',
          districtId: 126,
          districtName: 'Kabupaten Garut',
        );

        const customSummary = ProfileSummary(
          scope: customScope,
          member: SicaborMember(
            id: 2,
            username: 'admin2',
            name: 'Pak Cecep',
            type: 'admin',
            status: 1,
            statusLabel: 'Aktif',
          ),
          totalCabor: 4,
          totalCaborFromClub: 4,
          totalCaborFromAthlete: 4,
          totalClub: 8,
          totalAthlete: 60,
          totalAthleteWithoutClub: 0,
        );

        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject(summary: customSummary));
        await tester.pumpAndSettle();

        expect(find.text('Cabang Olahraga'), findsOneWidget);
        expect(find.text('Cabang Olahraga Aktif'), findsNothing);
        expect(find.text('Kecamatan Tarogong Kidul'), findsOneWidget);
        expect(find.text('Kecamatan Garut Kota'), findsNothing);
      },
    );

    testWidgets('header uses API total for a partial paginated list', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fortyCabors = List.generate(
        40,
        (i) => Cabor(
          id: i + 1,
          code: 'CB-${(i + 1).toString().padLeft(3, '0')}',
          name: 'Cabor ${i + 1}',
          groupName: 'GROUP ${i + 1}',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: (i % 5) + 1,
          totalAthlete: (40 - i) * 2,
        ),
      );

      await tester.pumpWidget(buildSubject(cabors: fortyCabors));
      await tester.pumpAndSettle();

      expect(find.text('40 Cabor'), findsOneWidget);
      expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsNothing);
    });

    testWidgets('infinite scroll triggers loadMore when scrolled to bottom', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Create 30 cabors so page 1 loads 25 and page 2 loads 5
      final thirtyCabors = List.generate(
        30,
        (i) => Cabor(
          id: i + 1,
          code: 'CB-${(i + 1).toString().padLeft(3, '0')}',
          name: 'Cabor ${i + 1}',
          groupName: 'GROUP ${i + 1}',
          status: 1,
          statusLabel: 'Aktif',
          totalClub: (i % 5) + 1,
          totalAthlete: (30 - i) * 2,
        ),
      );

      await tester.pumpWidget(buildSubject(cabors: thirtyCabors));
      await tester.pumpAndSettle();

      // Initially first page has Cabor 1 but not Cabor 30
      expect(find.text('Cabor 1'), findsWidgets);
      expect(find.text('Cabor 30'), findsNothing);

      // Scroll to the end of the scrollable
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Cabor 25').last,
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      // Drag further to trigger loadMore
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Now Cabor 30 should be loaded and visible
      expect(find.text('Cabor 30'), findsOneWidget);
    });

    testWidgets(
      'renders error state and retry button when initial fetch fails',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject(shouldThrow: true));
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data.'), findsOneWidget);
        expect(find.text('Coba lagi'), findsOneWidget);
      },
    );

    testWidgets('renders NO_SUBDISTRICT error state without retry button', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(
          errorToThrow: const ForbiddenException(
            'Akses ditolak',
            'NO_SUBDISTRICT',
            'Akun belum terikat pada kecamatan.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsNothing);
    });

    testWidgets(
      'renders ApiConfigurationException error message without retry button',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildSubject(errorToThrow: const ApiConfigurationException()),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Respons server bukan JSON. Periksa alamat API.'),
          findsOneWidget,
        );
        expect(find.text('Coba lagi'), findsNothing);
      },
    );

    testWidgets('renders empty state when no cabors are returned', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(cabors: []));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada cabang olahraga terdaftar.'), findsOneWidget);
    });

    testWidgets(
      'retry button reloads first page and displays cabors after initial error',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var callCount = 0;
        final fakeService = FakeCaborService(
          allCabors: sampleCabors,
          onFetch: (limit, offset, source, sort) async {
            callCount++;
            if (callCount == 1) {
              throw Exception('Network error');
            }
            return PaginatedResult<Cabor>(
              items: sampleCabors,
              limit: limit,
              offset: offset,
              total: sampleCabors.length,
            );
          },
        );

        final router = GoRouter(
          initialLocation: '/sports',
          routes: [
            GoRoute(path: '/sports', builder: (_, _) => const SportsPage()),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              caborServiceProvider.overrideWithValue(fakeService),
              profileSummaryProvider.overrideWith((ref) => defaultSummary),
              dataRequestContextProvider.overrideWithValue(
                const DataRequestContext(
                  environment: AppEnv.demo,
                  userId: 'test_user',
                  scope: AccessScope(
                    type: AccessScopeType.district,
                    id: 'garut_kota',
                    name: 'Kecamatan Garut Kota',
                  ),
                  generation: 1,
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data.'), findsOneWidget);
        expect(find.text('Pencak Silat'), findsNothing);

        // Tap 'Coba lagi'
        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat data.'), findsNothing);
        expect(find.text('Pencak Silat'), findsWidgets);
      },
    );
  });
}

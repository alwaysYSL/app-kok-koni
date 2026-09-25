import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/app.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/providers/athlete_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/athlete_service.dart';
import 'package:kok_app/features/athlete_detail/athlete_detail_page.dart';
import 'package:kok_app/shared/widgets.dart';

import 'test_composition.dart';

const _scope = AccessScope(
  type: AccessScopeType.district,
  id: '1728',
  name: 'Garut Kota',
);

class _SignedInController extends AuthController {
  @override
  AuthState build() => AuthSignedIn(
    user: UserPrincipal(
      id: 'tester',
      username: 'tester',
      fullName: 'Test User',
      roleTitle: 'Admin',
      scope: _scope,
    ),
    generation: 1,
  );
}

const _cabor = AthleteCabor(id: 5, code: 'BLT', name: 'Bulutangkis');
const _domicile = AthleteDomicile(
  subdistrictId: 1728,
  subdistrictName: 'Garut Kota',
  districtId: 126,
  districtName: 'Garut',
);

Athlete _athlete(int id, {AthleteClub? club, String? name}) => Athlete(
  id: id,
  code: 'AT-$id',
  name: name ?? 'Atlet $id',
  sex: 'l',
  sexLabel: 'Laki-Laki',
  photoUrl: '',
  status: 1,
  statusLabel: 'Aktif',
  cabor: _cabor,
  club: club,
  domicile: _domicile,
);

class _AthleteService implements AthleteService {
  _AthleteService(this.fetch);

  final PaginatedResult<Athlete> Function({
    required int offset,
    required int limit,
    String? sex,
    int? status,
    String? search,
  })
  fetch;

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
    expect(idCabor, isNull);
    expect(idClub, isNull);
    return fetch(
      offset: offset,
      limit: limit,
      sex: sex,
      status: status,
      search: search,
    );
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  }) => throw UnimplementedError();
}

Future<ProviderContainer> _pumpDirectory(
  WidgetTester tester,
  _AthleteService service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      appCompositionProvider.overrideWithValue(
        buildTestAppComposition(
          profile: const DeploymentProfile(
            environment: AppEnv.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.remote,
          ),
        ),
      ),
      authControllerProvider.overrideWith(_SignedInController.new),
      dataRequestContextProvider.overrideWithValue(
        const DataRequestContext(
          environment: AppEnv.demo,
          userId: 'tester',
          scope: _scope,
          generation: 1,
        ),
      ),
      athleteServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KokApp()),
  );
  container.read(routerProvider).go('/athletes');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('athlete card uses shared surface and allows two name lines', (
    tester,
  ) async {
    const longName = 'Atlet Berprestasi Garut Kota dengan Nama Sangat Panjang';
    final service = _AthleteService(
      ({required offset, required limit, sex, status, search}) =>
          PaginatedResult(
            items: [_athlete(1, name: longName)],
            limit: limit,
            offset: offset,
            total: 1,
          ),
    );
    await _pumpDirectory(tester, service);

    expect(
      find.ancestor(of: find.text(longName), matching: find.byType(Surface)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(find.text(longName)).maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'directory shows server total and nullable club, then opens athlete',
    (tester) async {
      final service = _AthleteService(
        ({required offset, required limit, sex, status, search}) =>
            PaginatedResult(
              items: [
                _athlete(2375),
                _athlete(
                  2376,
                  club: const AthleteClub(id: 9, code: 'PB', name: 'PB Garut'),
                ),
              ],
              limit: limit,
              offset: offset,
              total: 361,
            ),
      );
      await _pumpDirectory(tester, service);

      expect(find.text('Atlet'), findsWidgets);
      expect(find.text('361 atlet'), findsOneWidget);
      expect(find.text('Klub belum tercatat'), findsOneWidget);
      expect(find.text('PB Garut'), findsOneWidget);
      expect(find.text('AT-2375'), findsOneWidget);
      expect(find.text('Bulutangkis'), findsWidgets);
      await tester.tap(find.text('Klub belum tercatat'));
      await tester.pumpAndSettle();
      expect(find.byType(AthleteDetailPage), findsOneWidget);
    },
  );

  testWidgets('scrolling loads the next page and keeps the server total', (
    tester,
  ) async {
    final service = _AthleteService(
      ({required offset, required limit, sex, status, search}) =>
          PaginatedResult(
            items: offset == 0
                ? List.generate(25, (i) => _athlete(i + 1))
                : [_athlete(26)],
            limit: limit,
            offset: offset,
            total: 26,
          ),
    );
    final container = await _pumpDirectory(tester, service);
    expect(find.text('26 atlet'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('athlete-list')),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();
    expect(
      container
          .read(athletePaginationProvider((idCabor: null, idClub: null)))
          .items
          .length,
      26,
    );
    await tester.scrollUntilVisible(
      find.text('Atlet 26'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('athlete-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Atlet 26'), findsOneWidget);
    expect(find.text('26 atlet'), findsOneWidget);
  });

  testWidgets('timeout on next page shows guidance and allows manual retry', (
    tester,
  ) async {
    var nextPageCalls = 0;
    final service = _AthleteService(({
      required offset,
      required limit,
      sex,
      status,
      search,
    }) {
      if (offset == 0) {
        return PaginatedResult(
          items: List.generate(25, (i) => _athlete(i + 1)),
          limit: limit,
          offset: offset,
          total: 26,
        );
      }
      nextPageCalls++;
      if (nextPageCalls == 1) throw const ApiTimeoutException();
      return PaginatedResult(
        items: [_athlete(26)],
        limit: limit,
        offset: offset,
        total: 26,
      );
    });
    final container = await _pumpDirectory(tester, service);
    await tester.drag(
      find.byKey(const ValueKey('athlete-list')),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();
    expect(
      container
          .read(athletePaginationProvider((idCabor: null, idClub: null)))
          .loadMoreError,
      isA<ApiTimeoutException>(),
    );
    await tester.scrollUntilVisible(
      find.text('Koneksi ke server terganggu.'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('athlete-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Koneksi ke server terganggu.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('athlete-list')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Koneksi ke server terganggu.'), findsNothing);
    expect(nextPageCalls, 2);
  });

  testWidgets(
    'NO_SUBDISTRICT on next page shows server guidance without retry',
    (tester) async {
      var nextPageCalls = 0;
      final service = _AthleteService(({
        required offset,
        required limit,
        sex,
        status,
        search,
      }) {
        if (offset == 0) {
          return PaginatedResult(
            items: List.generate(25, (i) => _athlete(i + 1)),
            limit: limit,
            offset: offset,
            total: 26,
          );
        }
        nextPageCalls++;
        throw const ForbiddenException(
          'Akses ditolak',
          'NO_SUBDISTRICT',
          'Akun belum terikat pada kecamatan.',
        );
      });
      final container = await _pumpDirectory(tester, service);
      await tester.drag(
        find.byKey(const ValueKey('athlete-list')),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();
      expect(
        container
            .read(athletePaginationProvider((idCabor: null, idClub: null)))
            .loadMoreError,
        isA<ForbiddenException>(),
      );
      await tester.scrollUntilVisible(
        find.text(
          'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
        ),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('athlete-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.text(
          'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('athlete-list')),
        const Offset(0, 100),
      );
      await tester.drag(
        find.byKey(const ValueKey('athlete-list')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(nextPageCalls, 1);
    },
  );

  testWidgets('search waits 500 ms and displays an empty result', (
    tester,
  ) async {
    final service = _AthleteService(
      ({required offset, required limit, sex, status, search}) =>
          PaginatedResult(
            items: search == 'missing' ? [] : [_athlete(1)],
            limit: limit,
            offset: offset,
            total: search == 'missing' ? 0 : 1,
          ),
    );
    await _pumpDirectory(tester, service);
    await tester.enterText(
      find.byKey(const ValueKey('athlete-search')),
      'missing',
    );
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text('Atlet 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('0 atlet'), findsOneWidget);
    expect(find.text('Tidak ada atlet yang sesuai filter.'), findsOneWidget);
  });

  testWidgets(
    'reopening directory restores the active server search in the field',
    (tester) async {
      final service = _AthleteService(
        ({required offset, required limit, sex, status, search}) =>
            PaginatedResult(
              items: search == 'Atlet 9' ? [_athlete(9)] : [_athlete(1)],
              limit: limit,
              offset: offset,
              total: 1,
            ),
      );
      final container = await _pumpDirectory(tester, service);
      await tester.enterText(
        find.byKey(const ValueKey('athlete-search')),
        'Atlet 9',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('athlete-list')),
          matching: find.text('Atlet 9'),
        ),
        findsOneWidget,
      );

      container.read(routerProvider).go('/home');
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/athletes');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('athlete-search')))
            .controller!
            .text,
        'Atlet 9',
      );
      expect(find.byTooltip('Hapus pencarian'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('athlete-list')),
          matching: find.text('Atlet 9'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'filter sheet stages gender and status until apply, then resets',
    (tester) async {
      final requests = <(String?, int?)>[];
      final service = _AthleteService(({
        required offset,
        required limit,
        sex,
        status,
        search,
      }) {
        requests.add((sex, status));
        return PaginatedResult(
          items: sex == 'l' && status == 1 ? [_athlete(9)] : [],
          limit: limit,
          offset: offset,
          total: sex == 'l' && status == 1 ? 1 : 0,
        );
      });
      await _pumpDirectory(tester, service);
      expect(requests, [(null, null)]);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laki-Laki').last);
      await tester.tap(find.text('Aktif').last);
      expect(requests, [(null, null)]);
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(requests, [(null, null), ('l', 1)]);
      expect(find.text('Atlet 9'), findsOneWidget);
      expect(find.text('1 atlet'), findsOneWidget);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      expect(requests, [(null, null), ('l', 1)]);
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(requests.last, (null, null));
      expect(find.text('0 atlet'), findsOneWidget);
    },
  );
}

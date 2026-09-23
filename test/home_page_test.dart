import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';
import 'package:kok_app/features/home_page.dart';

class _FakeHomeAuthController extends AuthController {
  final UserPrincipal user;
  _FakeHomeAuthController(this.user);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);
}

class _FakeSecureKeyValStore implements SecureKeyValStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key}) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<bool> containsKey({required String key}) async =>
      _data.containsKey(key);
}

Future<AppComposition> _createTestComposition({
  DataMode dataMode = DataMode.demo,
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
  final demoProfileService = DemoProfileService(
    demoRepo: demoKokRepo,
    currentScopeProvider: () => const AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    ),
  );
  final demoCaborService = DemoCaborService(
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
    profileService: demoProfileService,
    caborService: demoCaborService,
    athleteService: demoAthleteService,
    clubService: demoClubService,
    credentialIdGenerator: UuidCredentialIdGenerator(),
  );
}

void main() {
  final cecepUser = UserPrincipal(
    id: 'usr_tarogong_kidul',
    username: 'DEMO-002',
    fullName: 'Pak Cecep',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'tarogong_kidul',
      name: 'Kecamatan Tarogong Kidul',
    ),
    permissions: {'sports:read'},
  );

  final sampleSummary = ProfileSummary(
    scope: const SicaborScope(
      subdistrictId: 1728,
      subdistrictName: 'Tarogong Kidul',
      districtId: 126,
      districtName: 'Kabupaten Garut',
    ),
    member: const SicaborMember(
      id: 578,
      username: 'kt.tarogongkidul',
      name: 'Pak Cecep',
      type: 'admin_kok',
      status: 1,
      statusLabel: 'Koordinator Aktif',
    ),
    kontingen: const SicaborKontingen(
      id: 1,
      code: 'KGPK-0002',
      name: 'Tarogong Kidul',
    ),
    totalCabor: 14,
    totalCaborFromClub: 8,
    totalCaborFromAthlete: 14,
    totalClub: 22,
    totalAthlete: 245,
    totalAthleteWithoutClub: 18,
    dataNotes: const [
      'Sinkronisasi SICABOR aktif per 2026-09-20.',
      'Data atlet mandiri diverifikasi oleh KONI.',
    ],
  );

  testWidgets(
    'HomePage menampilkan nama pengurus, KOK wilayah, dan inisial avatar secara dinamis',
    (tester) async {
      final composition = await _createTestComposition();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) => sampleSummary),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Pak Cecep'), findsWidgets);
      expect(find.textContaining('KOK Tarogong Kidul'), findsWidgets);
      expect(find.text('PC'), findsOneWidget);
    },
  );

  testWidgets(
    'HomePage menampilkan metrik ringkasan server (Cabor, Klub, Atlet, Tanpa Klub) secara akurat',
    (tester) async {
      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) => sampleSummary),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      // Total Atlet
      expect(find.text('245'), findsOneWidget);
      expect(find.text('ATLET'), findsOneWidget);

      // Total Cabor
      expect(find.text('14'), findsOneWidget);
      expect(find.text('CABOR'), findsOneWidget);
      expect(find.text('8 klub · 14 atlet'), findsOneWidget);

      // Total Klub
      expect(find.text('22'), findsOneWidget);
      expect(find.text('KLUB'), findsOneWidget);

      // Atlet Tanpa Klub
      expect(find.text('18'), findsOneWidget);
      expect(find.text('TANPA KLUB'), findsOneWidget);
      expect(find.text('18 atlet tanpa klub'), findsOneWidget);
    },
  );

  testWidgets(
    'HomePage menampilkan kartu Catatan Data Server jika dataNotes tersedia',
    (tester) async {
      final composition = await _createTestComposition();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) => sampleSummary),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Catatan Data Server'), findsOneWidget);
      expect(
        find.text('Sinkronisasi SICABOR aktif per 2026-09-20.'),
        findsOneWidget,
      );
      expect(
        find.text('Data atlet mandiri diverifikasi oleh KONI.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('HomePage menampilkan kartu Kontingen jika kontingen tersedia', (
    tester,
  ) async {
    final composition = await _createTestComposition();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeHomeAuthController(cecepUser),
          ),
          profileSummaryProvider.overrideWith((ref) => sampleSummary),
          appCompositionProvider.overrideWithValue(composition),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('KONTINGEN KECAMATAN'), findsOneWidget);
    expect(find.text('Tarogong Kidul (KGPK-0002)'), findsOneWidget);
  });

  testWidgets(
    'HomePage menyembunyikan elemen metrik demo dalam DataMode.remote',
    (tester) async {
      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) => sampleSummary),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      // In remote mode, unpopulated demo tiles and notes are hidden
      expect(find.text('Perlu Perhatian'), findsNothing);
      expect(find.text('Atlet berkas kurang'), findsNothing);
      expect(find.text('Lisensi pelatih kedaluwarsa'), findsNothing);
      expect(find.textContaining('MODE DEMO'), findsNothing);
      expect(find.textContaining('terverifikasi'), findsNothing);
    },
  );

  testWidgets(
    'HomePage menampilkan elemen demo dalam DataMode.demo dengan snapshot',
    (tester) async {
      final composition = await _createTestComposition(dataMode: DataMode.demo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) => sampleSummary),
            snapshotProvider.overrideWith(
              (ref) => DemoKokRepository(
                simulateLatency: false,
              ).fetchScope(cecepUser.scope),
            ),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Perlu Perhatian'), findsOneWidget);
      expect(find.text('Atlet berkas kurang'), findsOneWidget);
      expect(find.text('Lisensi pelatih kedaluwarsa'), findsOneWidget);
      expect(find.textContaining('MODE DEMO'), findsOneWidget);
    },
  );

  testWidgets(
    'HomePage menampilkan label Terakhir Dimuat dengan format WIB yang jujur',
    (tester) async {
      final composition = await _createTestComposition();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) => sampleSummary),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Terakhir Dimuat:'), findsOneWidget);
      expect(find.textContaining('WIB'), findsWidgets);
      expect(find.textContaining('Terakhir Tersinkron SICABOR'), findsNothing);
    },
  );

  testWidgets(
    'HomePage menampilkan state error dan tombol Coba Lagi dapat melakukan retry',
    (tester) async {
      final composition = await _createTestComposition();
      var attempt = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) {
              attempt++;
              if (attempt == 1) {
                throw const BadRequestException(
                  'Gagal menghubungi server SICABOR',
                );
              }
              return sampleSummary;
            }),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gagal menghubungi server SICABOR'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Tap Coba Lagi
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal menghubungi server SICABOR'), findsNothing);
      expect(find.text('245'), findsOneWidget);
    },
  );

  testWidgets(
    'HomePage menampilkan pesan NO_SUBDISTRICT dan menyembunyikan tombol Coba Lagi',
    (tester) async {
      final composition = await _createTestComposition(
        dataMode: DataMode.remote,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            profileSummaryProvider.overrideWith((ref) {
              throw const ForbiddenException(
                'Akses ditolak',
                'NO_SUBDISTRICT',
                'Akun belum terikat pada kecamatan.',
              );
            }),
            appCompositionProvider.overrideWithValue(composition),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsNothing);
    },
  );
}

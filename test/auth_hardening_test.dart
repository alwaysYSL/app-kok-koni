import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kok_app/app.dart';
import 'package:kok_app/core/config/app_environment.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/auth/presentation/session_signing_out_page.dart';
import 'package:kok_app/core/preferences.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/login_page.dart';

// Test doubles for auth hardening scenarios

class _ControlledAuthRepository implements AuthRepository {
  Completer<AuthResult>? loginCompleter;
  Completer<AuthResult>? restoreCompleter;
  int restoreCallCount = 0;
  int loginCallCount = 0;
  int logoutCallCount = 0;

  _ControlledAuthRepository({this.loginCompleter, this.restoreCompleter});

  @override
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  }) async {
    loginCallCount++;
    if (loginCompleter != null) {
      return loginCompleter!.future;
    }
    return const AuthResult.failed(InvalidCredentialsFailure());
  }

  @override
  Future<AuthResult> restoreSession() async {
    restoreCallCount++;
    if (restoreCompleter != null) {
      return restoreCompleter!.future;
    }
    return const AuthResult.failed(SessionExpiredFailure('Expired'));
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession();
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
  }
}

class _InMemoryTokenStorage implements AuthTokenStorage {
  String? token;
  bool shouldThrow = false;
  String throwMessage = 'Hardware keystore error';

  @override
  Future<String?> getRefreshToken() async {
    if (shouldThrow) throw StorageException(throwMessage);
    return token;
  }

  @override
  Future<String?> readRefreshToken() async {
    if (shouldThrow) throw StorageException(throwMessage);
    return token;
  }

  @override
  Future<void> saveRefreshToken(String t) async {
    if (shouldThrow) throw StorageException(throwMessage);
    token = t;
  }

  @override
  Future<void> clear() async {
    if (shouldThrow) throw StorageException(throwMessage);
    token = null;
  }
}

class _CountingKokRepository implements KokRepository {
  int fetchDistrictCount = 0;
  final DemoKokRepository _inner = DemoKokRepository();

  @override
  Future<KokSnapshot> fetch() => fetchDistrict('garut_kota');

  @override
  Future<KokSnapshot> fetchDistrict(
    String districtId, {
    CancelToken? cancelToken,
  }) async {
    fetchDistrictCount++;
    return _inner.fetchDistrict(districtId, cancelToken: cancelToken);
  }
}

class _MutableAuthController extends AuthController {
  void setHardeningState(AuthState s) {
    state = s;
  }
}

final _testGarutUser = UserPrincipal(
  id: 'usr-garut-kota-001',
  skNumber: 'DEMO-001',
  fullName: 'Pak Asep',
  roleTitle: 'Koordinator Kecamatan',
  scope: const AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  ),
  permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
);

void main() {
  group('Audit A-01 s/d A-09 & Section 5: Hardening Regression Suite', () {
    // -------------------------------------------------------------------------
    // 1. Race Condition Asinkron Login-Logout (Menutup A-02)
    // -------------------------------------------------------------------------
    test(
      '1. Skenario A-02: Race condition asinkron login-logout membatalkan commit token dan menghasilkan AuthSignedOut',
      () async {
        final loginCompleter = Completer<AuthResult>();
        final repo = _ControlledAuthRepository(loginCompleter: loginCompleter);
        final storage = _InMemoryTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(prefs);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            authTokenStorageProvider.overrideWithValue(storage),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            preferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);

        // Mulai login yang tertahan secara asinkron
        final loginFuture = controller.login(
          skNumber: 'DEMO-001',
          password: 'password123',
          staySignedIn: true,
          rememberSk: true,
        );
        expect(container.read(authControllerProvider), isA<AuthSigningIn>());

        // Pengguna memanggil logout sebelum respon login tiba
        await controller.logout();
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());

        // Selesaikan operasi login lama yang terlambat
        loginCompleter.complete(
          AuthResult.success(
            user: _testGarutUser,
            accessToken: 'jwt_token_garut',
            refreshToken: 'token_usr_garut_kota',
          ),
        );
        final loginSuccess = await loginFuture;

        // Token tidak boleh di-commit, login dinyatakan gagal, state tetap signed out
        expect(loginSuccess, isFalse);
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());
        expect(await storage.readRefreshToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
      },
    );

    // -------------------------------------------------------------------------
    // 2. Single-Flight Bootstrap (Menutup A-07)
    // -------------------------------------------------------------------------
    test(
      '2. Skenario A-07: Single-flight bootstrap mencegah duplikasi restoreSession saat dipanggil secara simultan',
      () async {
        final restoreCompleter = Completer<AuthResult>();
        final repo = _ControlledAuthRepository(
          restoreCompleter: restoreCompleter,
        );
        final storage = _InMemoryTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(prefs);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            authTokenStorageProvider.overrideWithValue(storage),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            preferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);

        // Panggil bootstrap berulang kali secara bersamaan
        final f1 = controller.bootstrap();
        final f2 = controller.bootstrap();
        final f3 = controller.bootstrap();

        // Hanya 1 restore session request yang dikirimkan ke repository
        expect(repo.restoreCallCount, equals(1));

        // Selesaikan restore session
        restoreCompleter.complete(
          const AuthResult.failed(SessionExpiredFailure('Token tidak valid')),
        );
        await Future.wait([f1, f2, f3]);

        // Tetap hanya 1 call count
        expect(repo.restoreCallCount, equals(1));
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());
      },
    );

    // -------------------------------------------------------------------------
    // 3. Penolakan Mutlak snapshotProvider tanpa Sesi (Menutup A-03)
    // -------------------------------------------------------------------------
    test(
      '3. Skenario A-03: snapshotProvider melempar SessionRequiredException saat sessionScope null tanpa memanggil fetchDistrict',
      () async {
        final countingRepo = _CountingKokRepository();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(countingRepo)],
        );
        addTearDown(container.dispose);

        // Pastikan sessionScopeProvider bernilai null
        expect(container.read(sessionScopeProvider), isNull);

        // Pembacaan snapshotProvider harus menolak dengan SessionRequiredException
        expect(
          () => container.read(snapshotProvider.future),
          throwsA(
            isA<SessionRequiredException>().having(
              (e) => e.toString(),
              'toString',
              contains('Sesi terautentikasi aktif dibutuhkan'),
            ),
          ),
        );

        // Repositori keolahragaan sama sekali tidak boleh dipanggil
        expect(countingRepo.fetchDistrictCount, equals(0));
      },
    );

    // -------------------------------------------------------------------------
    // 4. Router Guard Mengunci Rute Internal saat AuthSigningIn & AuthSigningOut (Menutup A-01)
    // -------------------------------------------------------------------------
    testWidgets(
      '4. Skenario A-01: Router guard mengunci rute internal saat AuthSigningIn dan AuthSigningOut',
      (tester) async {
        final mutableController = _MutableAuthController();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = _InMemoryTokenStorage();
        final skStore = RememberedSkStore(prefs);

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authControllerProvider.overrideWith(() => mutableController),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const KokApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Kasus 1: State AuthSigningIn -> akses /club/garuda harus dialihkan ke /login
        mutableController.setHardeningState(const AuthSigningIn());
        container.read(routerProvider).go('/club/garuda');
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.text('Masuk Akun'), findsOneWidget);
        expect(find.text('Klub Garuda Muda'), findsNothing);

        // Kasus 2: State AuthSigningOut -> akses /club/garuda harus dialihkan ke /signing-out
        mutableController.setHardeningState(const AuthSigningOut());
        container.read(routerProvider).go('/club/garuda');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SessionSigningOutPage), findsOneWidget);
        expect(find.text('Mengeluarkan Akun'), findsOneWidget);
        expect(
          find.text('Membersihkan sesi lokal dan mengamankan data...'),
          findsOneWidget,
        );
        expect(find.text('Klub Garuda Muda'), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // 5. Penanganan StorageException beralih ke AuthTemporarilyUnavailable (Menutup A-05)
    // -------------------------------------------------------------------------
    test(
      '5. Skenario A-05: StorageException pada pembacaan token dialihkan ke AuthTemporarilyUnavailable dengan reason jujur',
      () async {
        final storage = _InMemoryTokenStorage()
          ..shouldThrow = true
          ..throwMessage = 'Penyimpanan hardware keystore tidak merespons.';
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(prefs);
        final repo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthTemporarilyUnavailable>());
        expect(
          (state as AuthTemporarilyUnavailable).reason,
          'Penyimpanan hardware keystore tidak merespons.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // 6. Penolakan Token Tak Dikenal oleh DemoAuthRepository (Menutup A-06)
    // -------------------------------------------------------------------------
    test(
      '6. Skenario A-06: DemoAuthRepository menolak token acak/tidak valid tanpa fallback ke Garut Kota',
      () async {
        final storage = _InMemoryTokenStorage();
        await storage.saveRefreshToken('token_acak_palsu_99999');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(prefs);

        final repo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final result = await repo.restoreSession();

        expect(result.isSuccess, isFalse);
        expect(result.user, isNull);
        expect(result.failure, isA<SessionExpiredFailure>());
        expect(
          result.failure?.message,
          contains('Sesi Anda tidak valid atau telah kedaluwarsa.'),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 7. Validasi validateAppConfiguration Fail-Closed di Lingkungan Produksi (Menutup A-04)
    // -------------------------------------------------------------------------
    test(
      '7. Skenario A-04: validateAppConfiguration melempar StateError saat production memakai adapter/data demo',
      () {
        // Produksi dengan demo auth -> StateError
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.production,
            usesDemoAuth: true,
            usesDemoData: false,
          ),
          throwsStateError,
        );

        // Produksi dengan demo data -> StateError
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.production,
            usesDemoAuth: false,
            usesDemoData: true,
          ),
          throwsStateError,
        );

        // Produksi dengan keduanya demo -> StateError
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.production,
            usesDemoAuth: true,
            usesDemoData: true,
          ),
          throwsStateError,
        );

        // Demo & Staging lolos normal
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.demo,
            usesDemoAuth: true,
            usesDemoData: true,
          ),
          returnsNormally,
        );

        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.staging,
            usesDemoAuth: true,
            usesDemoData: true,
          ),
          returnsNormally,
        );

        // Produksi dengan adapter riil lolos normal
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.production,
            usesDemoAuth: false,
            usesDemoData: false,
          ),
          returnsNormally,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 8. Rekapitulasi Data Tarogong Kidul Dinamis (Menutup A-09)
    // -------------------------------------------------------------------------
    testWidgets(
      '8. Skenario A-09: Rekapitulasi data menampilkan Tarogong Kidul secara dinamis pada modal sheet dan teks clipboard',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = _InMemoryTokenStorage();
        final skStore = RememberedSkStore(prefs);
        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        // Setup clipboard mock
        String? copiedClipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedClipboardText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const KokApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Login akun Pak Cecep (Tarogong Kidul)
        final controller = container.read(authControllerProvider.notifier);
        await controller.login(
          skNumber: 'DEMO-002',
          password: 'koktarogong123',
          staySignedIn: false,
          rememberSk: false,
        );
        await tester.pumpAndSettle();

        // Buka halaman profil
        container.read(routerProvider).go('/profile');
        await tester.pumpAndSettle();

        // Verifikasi identitas Pak Cecep & Kecamatan Tarogong Kidul
        expect(find.text('Pak Cecep'), findsOneWidget);
        expect(find.text('Koordinator · Kec. Tarogong Kidul'), findsOneWidget);

        // Ketuk tombol rekapitulasi data wilayah
        final rekapButton = find.text('Rekap Data Kecamatan');
        await tester.scrollUntilVisible(rekapButton, 200);
        await tester.tap(rekapButton);
        await tester.pumpAndSettle();

        // Verifikasi modal sheet menampilkan judul dan ringkasan dinamis Tarogong Kidul
        expect(
          find.text('Rekapitulasi Data KOK Tarogong Kidul'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Ringkasan data keolahragaan wilayah Kecamatan Tarogong Kidul.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Garut Kota'), findsNothing);

        // Ketuk tombol Salin Ringkasan
        final copyButton = find.text('Salin Teks Rekapitulasi');
        expect(copyButton, findsOneWidget);
        await tester.tap(copyButton);
        await tester.pumpAndSettle();

        // Verifikasi teks clipboard memuat Tarogong Kidul secara lengkap
        expect(copiedClipboardText, isNotNull);
        expect(
          copiedClipboardText,
          contains('REKAPITULASI DATA KECAMATAN TAROGONG KIDUL'),
        );
        expect(
          copiedClipboardText,
          contains(
            'Status: Terdaftar pada Sistem KOK Kecamatan Tarogong Kidul',
          ),
        );
        expect(copiedClipboardText, contains('Total Cabang Olahraga: 4'));
        expect(copiedClipboardText, contains('Total Klub: 4'));
        expect(copiedClipboardText, contains('Total Atlet: 88'));
        expect(copiedClipboardText, isNot(contains('Garut Kota')));
      },
    );

    // -------------------------------------------------------------------------
    // 9. UserPrincipal Immutable Permissions & Value Equality (Menutup Bagian 5)
    // -------------------------------------------------------------------------
    test(
      '9. Skenario Bagian 5: UserPrincipal memastikan permissions unmodifiable dan kesetaraan nilai menyeluruh',
      () {
        final p1 = UserPrincipal(
          id: 'usr-01',
          skNumber: 'DEMO-001',
          fullName: 'Pak Asep',
          roleTitle: 'Koordinator',
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
          permissions: {'sports:read', 'clubs:read'},
        );

        final p2 = UserPrincipal(
          id: 'usr-01',
          skNumber: 'DEMO-001',
          fullName: 'Pak Asep',
          roleTitle: 'Koordinator',
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
          permissions: {'sports:read', 'clubs:read'},
        );

        final pDifferentPermission = UserPrincipal(
          id: 'usr-01',
          skNumber: 'DEMO-001',
          fullName: 'Pak Asep',
          roleTitle: 'Koordinator',
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
          permissions: {'sports:read', 'clubs:read', 'clubs:delete'},
        );

        final pDifferentDistrict = UserPrincipal(
          id: 'usr-01',
          skNumber: 'DEMO-001',
          fullName: 'Pak Asep',
          roleTitle: 'Koordinator',
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'tarogong_kidul',
            name: 'Kecamatan Tarogong Kidul',
          ),
          permissions: {'sports:read', 'clubs:read'},
        );

        // Immutability test
        expect(
          () => (p1.permissions as dynamic).add('sports:write'),
          throwsUnsupportedError,
        );

        // Value equality & HashCode tests
        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));

        expect(p1, isNot(equals(pDifferentPermission)));
        expect(p1.hashCode, isNot(equals(pDifferentPermission.hashCode)));

        expect(p1, isNot(equals(pDifferentDistrict)));
        expect(p1.hashCode, isNot(equals(pDifferentDistrict.hashCode)));
      },
    );
  });
}

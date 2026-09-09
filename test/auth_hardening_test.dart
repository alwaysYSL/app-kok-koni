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
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
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
  Future<AuthResult> restoreSession([String? refreshToken]) async {
    restoreCallCount++;
    if (restoreCompleter != null) {
      return restoreCompleter!.future;
    }
    return const AuthResult.failed(SessionExpiredFailure('Expired'));
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession(refreshToken);
  }

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
  }
}

class _InMemoryTokenStorage implements AuthTokenStorage {
  StoredCredential? credential;
  bool shouldThrow = false;
  bool shouldThrowOnRead = false;
  bool shouldThrowOnWrite = false;
  bool shouldThrowOnClearIfOwned = false;
  bool shouldThrowOnForceClear = false;
  bool? clearIfOwnedOverride;
  void Function()? onWriteHook;
  int forceClearCallCount = 0;
  int clearIfOwnedCallCount = 0;
  String throwMessage = 'Hardware keystore error';

  @override
  Future<StoredCredential?> read() async {
    if (shouldThrow || shouldThrowOnRead) throw StorageException(throwMessage);
    return credential;
  }

  @override
  Future<void> write(StoredCredential cred) async {
    if (shouldThrow || shouldThrowOnWrite) throw StorageException(throwMessage);
    credential = cred;
    if (onWriteHook != null) onWriteHook!();
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (shouldThrow || shouldThrowOnClearIfOwned) {
      throw StorageException(throwMessage);
    }
    clearIfOwnedCallCount++;
    if (clearIfOwnedOverride != null) {
      if (clearIfOwnedOverride == true) credential = null;
      return clearIfOwnedOverride!;
    }
    if (credential != null && credential!.credentialId == credentialId) {
      credential = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    if (shouldThrow || shouldThrowOnForceClear) {
      throw StorageException(throwMessage);
    }
    forceClearCallCount++;
    credential = null;
  }

  @override
  Future<void> migrateLegacyStorage() async {
    if (shouldThrow) throw StorageException(throwMessage);
  }

  @override
  Future<String?> getRefreshToken() async {
    if (shouldThrow) throw StorageException(throwMessage);
    return credential?.refreshToken;
  }

  @override
  Future<String?> readRefreshToken() async {
    if (shouldThrow) throw StorageException(throwMessage);
    return credential?.refreshToken;
  }

  @override
  Future<void> saveRefreshToken(String t) async {
    if (shouldThrow) throw StorageException(throwMessage);
    credential = StoredCredential(credentialId: 'legacy', refreshToken: t);
  }

  @override
  Future<void> clear() async {
    if (shouldThrow) throw StorageException(throwMessage);
    credential = null;
  }
}

class _FakeSessionMetadataStore implements SessionMetadataStore {
  SessionMetadata? metadata;
  bool shouldThrowOnRead = false;
  bool shouldThrowOnWrite = false;
  int? throwOnWriteCallIndex;
  int writeCount = 0;

  _FakeSessionMetadataStore([this.metadata]);

  @override
  Future<SessionMetadata?> read() async {
    if (shouldThrowOnRead) throw const StorageException('Metadata read error');
    return metadata;
  }

  @override
  Future<void> write(SessionMetadata meta) async {
    writeCount++;
    if (shouldThrowOnWrite ||
        (throwOnWriteCallIndex != null &&
            writeCount == throwOnWriteCallIndex)) {
      throw const StorageException('Metadata write error');
    }
    metadata = meta;
  }

  @override
  Future<void> clear() async {
    metadata = null;
  }
}

class _CountingKokRepository implements KokRepository {
  int fetchScopeCount = 0;
  final DemoKokRepository _inner = DemoKokRepository();

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) async {
    fetchScopeCount++;
    return _inner.fetchScope(scope, cancellation: cancellation);
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
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );

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
        await controller.bootstrap();
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());

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

        // Token tidak boleh di-commit, login dinyatakan dibatalkan, state tetap signed out
        expect(loginSuccess.isSuccess, isFalse);
        expect(loginSuccess.status, equals(AuthCommandStatus.cancelled));
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
        await storage.write(
          const StoredCredential(
            credentialId: 'cred-a07',
            refreshToken: 'token-a07',
          ),
        );
        final metadataStore = _FakeSessionMetadataStore(
          SessionMetadata.restoreEnabled('cred-a07'),
        );
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
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

        await pumpEventQueue();

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
      '3. Skenario A-03: snapshotProvider melempar SessionRequiredException saat sessionScope null tanpa memanggil fetchScope',
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
        expect(countingRepo.fetchScopeCount, equals(0));
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
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );

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
    // 5. Penanganan StorageException beralih ke AuthSignedOut(failed) (Menutup A-05 & Row 3)
    // -------------------------------------------------------------------------
    test(
      '5. Skenario A-05: StorageException pada pembacaan token dialihkan ke AuthSignedOut(failed) sesuai Bootstrap Truth Table Row 3',
      () async {
        final storage = _InMemoryTokenStorage()
          ..shouldThrow = true
          ..throwMessage = 'Penyimpanan hardware keystore tidak merespons.';
        final metadataStore = _FakeSessionMetadataStore();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );
        final repo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final state = container.read(authControllerProvider);
        expect(
          state,
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
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
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );

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
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );
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

  group('Fault-Injection Suite (FT-01 s/d FT-08)', () {
    late SharedPreferences prefs;
    late RememberedSkStore skStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      skStore = RememberedSkStore(prefs: prefs, key: 'test_hardening_sk');
    });

    // FT-01: Metadata pending login gagal -> tidak ada credential baru; state unavailable
    test(
      'FT-01: Metadata pending login gagal -> tidak ada credential baru, state AuthTemporarilyUnavailable',
      () async {
        final storage = _InMemoryTokenStorage();
        final metadataStore = _FakeSessionMetadataStore(
          const SessionMetadata.signedOutClean(),
        );
        // Gagalkan penulisan pertama saat login (penulisan metadata pending)
        metadataStore.throwOnWriteCallIndex = 1;

        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        expect(
          container.read(authControllerProvider),
          isA<AuthTemporarilyUnavailable>(),
        );
        expect(storage.credential, isNull);
        expect(controller.signInPhase, equals(SignInPhase.idle));
      },
    );

    // FT-02: Credential write melempar -> metadata failed; state failed
    test(
      'FT-02: Credential write melempar -> metadata failed, state AuthSignedOut(failed)',
      () async {
        final storage = _InMemoryTokenStorage()..shouldThrowOnWrite = true;
        final metadataStore = _FakeSessionMetadataStore(
          const SessionMetadata.signedOutClean(),
        );
        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(
          metadataStore.metadata,
          equals(const SessionMetadata.cleanupFailed()),
        );
        expect(controller.signInPhase, equals(SignInPhase.idle));
      },
    );

    // FT-03: Epoch berubah setelah credential write -> rollback owned credential
    test(
      'FT-03: Epoch berubah setelah credential write -> rollback owned credential',
      () async {
        final storage = _InMemoryTokenStorage();
        final metadataStore = _FakeSessionMetadataStore(
          const SessionMetadata.signedOutClean(),
        );
        final generator = DeterministicCredentialIdGenerator('ft03');
        late ProviderContainer container;

        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
            credentialIdGeneratorProvider.overrideWithValue(generator),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // Saat write credential dieksekusi, picu perubahan epoch sebelum commit memeriksa epoch
        Future<LogoutResult>? logoutFuture;
        storage.onWriteHook = () {
          logoutFuture = controller.logout();
        };

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        await logoutFuture;

        expect(result.status, equals(AuthCommandStatus.cancelled));
        // Kredensial yang sempat ditulis harus di-rollback
        expect(storage.credential, isNull);
        expect(storage.clearIfOwnedCallCount, greaterThanOrEqualTo(1));
      },
    );

    // FT-04: Metadata final gagal -> rollback; clean hanya bila rollback+metadata sukses
    test(
      'FT-04: Metadata final gagal -> rollback credential dan set clean bila rollback+clean sukses',
      () async {
        final storage = _InMemoryTokenStorage();
        final metadataStore = _FakeSessionMetadataStore(
          const SessionMetadata.signedOutClean(),
        );
        // Gagal saat penulisan ke-2 (penulisan metadata restore-enabled)
        metadataStore.throwOnWriteCallIndex = 2;

        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        // Credential di-rollback
        expect(storage.credential, isNull);
        expect(storage.clearIfOwnedCallCount, equals(1));
        // Karena rollback dan penulisan metadata clean berikutnya berhasil -> clean
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
      },
    );

    // FT-05: clearIfOwnedBy false -> credential lain tetap utuh; state failed
    test(
      'FT-05: clearIfOwnedBy return false saat logout -> foreign credential utuh, state failed',
      () async {
        final foreignCred = const StoredCredential(
          credentialId: 'foreign-cred-999',
          refreshToken: 'foreign-token',
        );
        final storage = _InMemoryTokenStorage();
        final metadataStore = _FakeSessionMetadataStore(
          const SessionMetadata.signedOutClean(),
        );
        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // Login sukses terlebih dahulu
        final loginRes = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );
        expect(loginRes.isSuccess, isTrue);

        // Ubah kredensial di storage menjadi milik foreign credential
        storage.credential = foreignCred;

        // Logout dipanggil
        final logoutRes = await controller.logout();

        // Ownership mismatch:
        expect(logoutRes.credentialCleared, isFalse);
        expect(storage.credential, equals(foreignCred));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // FT-06: Restore expired dan cleanup gagal -> state failed
    test(
      'FT-06: Restore expired dan clearIfOwnedBy gagal -> AuthSignedOut(failed)',
      () async {
        final expiredCred = const StoredCredential(
          credentialId: 'cred-expired-ft06',
          refreshToken: 'token-expired',
        );
        final storage = _InMemoryTokenStorage()
          ..credential = expiredCred
          ..clearIfOwnedOverride = false;
        final metadataStore = _FakeSessionMetadataStore(
          SessionMetadata.restoreEnabled('cred-expired-ft06'),
        );
        final repo = _ControlledAuthRepository(
          restoreCompleter: Completer<AuthResult>()
            ..complete(
              const AuthResult.failed(SessionExpiredFailure('Expired token')),
            ),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            preferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // FT-07: Token clear sukses, metadata clean gagal -> state failed
    test(
      'FT-07: Token clear sukses tetapi metadata clean gagal saat logout -> state failed',
      () async {
        final storage = _InMemoryTokenStorage();
        final metadataStore = _FakeSessionMetadataStore(
          const SessionMetadata.signedOutClean(),
        );
        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        // Saat logout, izinkan penulisan metadata pending, lalu gagalkan penulisan metadata clean
        metadataStore.throwOnWriteCallIndex = metadataStore.writeCount + 2;

        final logoutRes = await controller.logout();
        expect(logoutRes.credentialCleared, isTrue);
        expect(logoutRes.metadataClean, isFalse);
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // FT-08: Force clear sukses, metadata recovery gagal -> state failed
    test(
      'FT-08: Force clear sukses tetapi metadata recovery gagal -> state failed dan return false',
      () async {
        final storage = _InMemoryTokenStorage();
        final metadataStore = _FakeSessionMetadataStore();
        final authRepo = DemoAuthRepository(
          tokenStorage: storage,
          skStore: skStore,
          simulateLatency: false,
        );

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        // Force state failed dari read error
        storage.shouldThrowOnRead = true;
        await controller.bootstrap();
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );

        // Reset storage error, tapi gagalkan write metadata
        storage.shouldThrowOnRead = false;
        metadataStore.shouldThrowOnWrite = true;

        final recovered = await controller.retryLocalCredentialCleanup();
        expect(recovered, isFalse);
        expect(storage.forceClearCallCount, equals(1));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );
  });
}

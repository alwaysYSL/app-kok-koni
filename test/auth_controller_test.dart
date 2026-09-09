import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

final fakeGarutKotaUser = UserPrincipal(
  id: 'usr-garut-kota-001',
  skNumber: 'DEMO-001',
  fullName: 'Pak Asep',
  roleTitle: 'Koordinator Kecamatan',
  districtId: 'garut_kota',
  districtName: 'Kecamatan Garut Kota',
  permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
);

class InMemoryRememberedSkStore implements RememberedSkStore {
  String? _sk;

  @override
  Future<String?> readSk() async => _sk;

  @override
  Future<void> saveSk(String sk) async {
    _sk = sk;
  }

  @override
  Future<void> clear() async {
    _sk = null;
  }
}

class CompleterAuthRepository implements AuthRepository {
  final Completer<AuthResult>? loginCompleter;
  final Completer<AuthResult>? restoreCompleter;
  int restoreCallCount = 0;
  int loginCallCount = 0;
  int logoutCallCount = 0;

  CompleterAuthRepository({
    this.loginCompleter,
    this.restoreCompleter,
  });

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
    return const AuthResult.failed(SessionExpiredFailure('None'));
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

void main() {
  late InMemoryAuthTokenStorage tokenStorage;
  late RememberedSkStore skStore;
  late DemoAuthRepository authRepository;

  setUp(() async {
    tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    skStore = RememberedSkStore(prefs);
    authRepository = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );
  });

  test('bootstrap mengarahkan ke AuthSignedOut jika storage kosong', () async {
    final container = ProviderContainer(
      overrides: [
        authTokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(authRepository),
        rememberedSkStoreProvider.overrideWithValue(skStore),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrap();

    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
  });

  test('bootstrap memulihkan sesi ke AuthSignedIn jika ada token', () async {
    await tokenStorage.saveRefreshToken('token_usr_garut_kota');
    final container = ProviderContainer(
      overrides: [
        authTokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(authRepository),
        rememberedSkStoreProvider.overrideWithValue(skStore),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrap();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).user.name, 'Pak Asep');
  });

  test('login sukses menaikkan session generation dan set AuthSignedIn', () async {
    final container = ProviderContainer(
      overrides: [
        authTokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(authRepository),
        rememberedSkStoreProvider.overrideWithValue(skStore),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    final success = await controller.login(
      skNumber: 'DEMO-001',
      password: 'kokgarut123',
      staySignedIn: true,
      rememberSk: true,
    );

    expect(success, isTrue);
    final state = container.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).generation, greaterThan(0));
    expect(await skStore.readSk(), 'DEMO-001');
  });

  test('logout membersihkan sesi dan menaikkan generation counter', () async {
    final container = ProviderContainer(
      overrides: [
        authTokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(authRepository),
        rememberedSkStoreProvider.overrideWithValue(skStore),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(
      skNumber: 'DEMO-001',
      password: 'kokgarut123',
      staySignedIn: true,
      rememberSk: false,
    );
    final gen1 = (container.read(authControllerProvider) as AuthSignedIn).generation;

    await controller.logout();
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    expect(controller.currentGeneration, greaterThan(gen1));
  });

  test('logout saat login masih berjalan membatalkan commit token dan menghasilkan AuthSignedOut', () async {
    final loginCompleter = Completer<AuthResult>();
    final fakeRepo = CompleterAuthRepository(loginCompleter: loginCompleter);
    final fakeStorage = InMemoryAuthTokenStorage();
    final fakeSkStore = InMemoryRememberedSkStore();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
        authTokenStorageProvider.overrideWithValue(fakeStorage),
        rememberedSkStoreProvider.overrideWithValue(fakeSkStore),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    // 1. Mulai login (asinkron tertahan)
    final loginFuture = controller.login(
      skNumber: 'DEMO-001',
      password: 'password',
      staySignedIn: true,
      rememberSk: true,
    );
    expect(container.read(authControllerProvider), isA<AuthSigningIn>());

    // 2. Pengguna memanggil logout sebelum login selesai
    await controller.logout();
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());

    // 3. Selesaikan operasi login yang tertunda
    loginCompleter.complete(
      AuthResult.success(
        user: fakeGarutKotaUser,
        accessToken: 'acc_token',
        refreshToken: 'token_usr_garut_kota',
      ),
    );
    final loginResult = await loginFuture;

    // 4. Verifikasi: login harus ditolak (return false), state tetap AuthSignedOut, storage token kosong
    expect(loginResult, isFalse);
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    expect(await fakeStorage.getRefreshToken(), isNull);
  });

  test('panggilan bootstrap ganda secara simultan hanya mengeksekusi satu kali (single-flight)', () async {
    final bootstrapCompleter = Completer<AuthResult>();
    final fakeRepo = CompleterAuthRepository(restoreCompleter: bootstrapCompleter);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
        authTokenStorageProvider.overrideWithValue(InMemoryAuthTokenStorage()),
        rememberedSkStoreProvider.overrideWithValue(InMemoryRememberedSkStore()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    final f1 = controller.bootstrap();
    final f2 = controller.bootstrap();

    expect(fakeRepo.restoreCallCount, equals(1));

    bootstrapCompleter.complete(const AuthResult.failed(SessionExpiredFailure('None')));
    await Future.wait([f1, f2]);

    expect(fakeRepo.restoreCallCount, equals(1));
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  test('Regression Audit: Remembered SK tidak memulihkan sesi autentikasi', () async {
    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
    final prefs = await SharedPreferences.getInstance();
    final tokenStorage = InMemoryAuthTokenStorage();
    final skStore = RememberedSkStore(prefs);
    final authRepo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        rememberedSkStoreProvider.overrideWithValue(skStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).bootstrap();
    expect(await skStore.readSk(), 'DEMO-001');
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    expect(container.read(sessionScopeProvider), isNull);
  });

  test('SessionScope mengisolasi snapshot data antar akun kecamatan', () async {
    final tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final skStore = RememberedSkStore(prefs);
    final authRepo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        rememberedSkStoreProvider.overrideWithValue(skStore),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    // Login Pak Asep (Garut Kota)
    await controller.login(
      skNumber: 'DEMO-001',
      password: 'kokgarut123',
      staySignedIn: false,
      rememberSk: false,
    );

    final scopeAsep = container.read(sessionScopeProvider);
    expect(scopeAsep?.districtId, 'garut_kota');
    final snapshotAsep = await container.read(snapshotProvider.future);
    expect(snapshotAsep.districtName, 'Kecamatan Garut Kota');
    expect(snapshotAsep.clubs.length, 5);

    // Logout
    await controller.logout();
    expect(container.read(sessionScopeProvider), isNull);

    // Login Pak Cecep (Tarogong Kidul)
    await controller.login(
      skNumber: 'DEMO-002',
      password: 'koktarogong123',
      staySignedIn: false,
      rememberSk: false,
    );

    final scopeCecep = container.read(sessionScopeProvider);
    expect(scopeCecep?.districtId, 'tarogong_kidul');
    final snapshotCecep = await container.read(snapshotProvider.future);
    expect(snapshotCecep.districtName, 'Kecamatan Tarogong Kidul');
    expect(snapshotCecep.clubs.length, 4);
  });

  test('snapshotProvider melempar SessionRequiredException saat sessionScope bernilai null', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(snapshotProvider.future),
      throwsA(isA<SessionRequiredException>()),
    );
  });
}

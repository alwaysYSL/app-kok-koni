import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

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
}

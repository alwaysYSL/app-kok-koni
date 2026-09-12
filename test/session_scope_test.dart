import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/kok_repository.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  test(
    'Regression Audit: Remembered SK tidak memulihkan sesi autentikasi',
    () async {
      SharedPreferences.setMockInitialValues({
        'test_remembered_sk': 'DEMO-001',
      });
      final prefs = await SharedPreferences.getInstance();
      final tokenStorage = InMemoryAuthTokenStorage();
      final skStore = RememberedSkStore(
        prefs: prefs,
        key: 'test_remembered_sk',
      );
      final authRepo = DemoAuthRepository(simulateLatency: false);
      final composition = AppComposition.fromProfile(
        const DeploymentProfile(
          environment: AppEnv.demo,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        ),
        preferences: prefs,
        secureStore: FakeSecureKeyValStore(),
      );

      final container = ProviderContainer(
        overrides: [
          appCompositionProvider.overrideWithValue(composition),
          authTokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrap();
      expect(await skStore.readSk(), 'DEMO-001');
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());
      expect(container.read(dataRequestContextProvider), isNull);
    },
  );

  test(
    'DataRequestContext mengisolasi snapshot data antar akun kecamatan',
    () async {
      final tokenStorage = InMemoryAuthTokenStorage();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final skStore = RememberedSkStore(
        prefs: prefs,
        key: 'test_remembered_sk',
      );
      final authRepo = DemoAuthRepository(simulateLatency: false);
      final composition = AppComposition.fromProfile(
        const DeploymentProfile(
          environment: AppEnv.demo,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        ),
        preferences: prefs,
        secureStore: FakeSecureKeyValStore(),
      );

      final container = ProviderContainer(
        overrides: [
          appCompositionProvider.overrideWithValue(composition),
          authTokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await controller.bootstrap();

      // Login Pak Asep (Garut Kota)
      await controller.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: false,
        rememberSk: false,
      );

      final scopeAsep = container.read(dataRequestContextProvider);
      expect(scopeAsep?.scope.id, 'garut_kota');
      final snapshotAsep = await container.read(snapshotProvider.future);
      expect(snapshotAsep.scope.name, 'Kecamatan Garut Kota');
      expect(snapshotAsep.clubs.length, 5);

      // Logout
      await controller.logout();
      expect(container.read(dataRequestContextProvider), isNull);

      // Login Pak Cecep (Tarogong Kidul)
      await controller.login(
        skNumber: 'DEMO-002',
        password: 'koktarogong123',
        staySignedIn: false,
        rememberSk: false,
      );

      final scopeCecep = container.read(dataRequestContextProvider);
      expect(scopeCecep?.scope.id, 'tarogong_kidul');
      final snapshotCecep = await container.read(snapshotProvider.future);
      expect(snapshotCecep.scope.name, 'Kecamatan Tarogong Kidul');
      expect(snapshotCecep.clubs.length, 4);
    },
  );

  test(
    'snapshotProvider melempar SessionRequiredException saat sessionScope bernilai null',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(snapshotProvider.future),
        throwsA(isA<SessionRequiredException>()),
      );
    },
  );

  group('DataRequestContext, Cancellation, and Stale Guard (Task 6)', () {
    test('DataRequestContext equality and hash code', () {
      const scopeA = AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      );
      const scopeB = AccessScope(
        type: AccessScopeType.district,
        id: 'tarogong_kidul',
        name: 'Kecamatan Tarogong Kidul',
      );

      const context1 = DataRequestContext(
        environment: AppEnv.demo,
        userId: 'usr_001',
        scope: scopeA,
        generation: 1,
      );
      const context2 = DataRequestContext(
        environment: AppEnv.demo,
        userId: 'usr_001',
        scope: scopeA,
        generation: 1,
      );
      const contextDiffEnv = DataRequestContext(
        environment: AppEnv.staging,
        userId: 'usr_001',
        scope: scopeA,
        generation: 1,
      );
      const contextDiffUser = DataRequestContext(
        environment: AppEnv.demo,
        userId: 'usr_002',
        scope: scopeA,
        generation: 1,
      );
      const contextDiffScope = DataRequestContext(
        environment: AppEnv.demo,
        userId: 'usr_001',
        scope: scopeB,
        generation: 1,
      );
      const contextDiffGen = DataRequestContext(
        environment: AppEnv.demo,
        userId: 'usr_001',
        scope: scopeA,
        generation: 2,
      );

      expect(context1, equals(context2));
      expect(context1.hashCode, equals(context2.hashCode));
      expect(context1, isNot(equals(contextDiffEnv)));
      expect(context1, isNot(equals(contextDiffUser)));
      expect(context1, isNot(equals(contextDiffScope)));
      expect(context1, isNot(equals(contextDiffGen)));
    });

    test(
      'RequestCancellationController.cancel is idempotent and preserves first reason',
      () async {
        final controller = RequestCancellationController();
        expect(controller.token.isCancelled, isFalse);
        expect(controller.token.reason, isNull);

        controller.cancel('First cancellation reason');
        expect(controller.token.isCancelled, isTrue);
        expect(controller.token.reason, 'First cancellation reason');
        expect(
          await controller.token.whenCancelled,
          'First cancellation reason',
        );

        controller.cancel('Second cancellation reason');
        expect(controller.token.isCancelled, isTrue);
        expect(controller.token.reason, 'First cancellation reason');
        expect(
          await controller.token.whenCancelled,
          'First cancellation reason',
        );

        expect(
          () => controller.token.throwIfCancelled(),
          throwsA(
            isA<RequestCancelledException>().having(
              (e) => e.reason,
              'reason',
              'First cancellation reason',
            ),
          ),
        );
      },
    );

    test(
      'dataRequestContextProvider maps signed-in auth state to DataRequestContext',
      () async {
        final tokenStorage = InMemoryAuthTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(prefs: prefs, key: 'test_sk');
        final authRepo = DemoAuthRepository(simulateLatency: false);
        final composition = AppComposition.fromProfile(
          const DeploymentProfile(
            environment: AppEnv.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ),
          preferences: prefs,
          secureStore: FakeSecureKeyValStore(),
        );

        final container = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            authRepositoryProvider.overrideWithValue(authRepo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(dataRequestContextProvider), isNull);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();
        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: false,
        );

        final context = container.read(dataRequestContextProvider);
        expect(context, isNotNull);
        expect(
          context?.environment,
          DeploymentProfile.fromEnvironment().environment,
        );
        expect(context?.userId, 'usr_garut_kota');
        expect(context?.scope.id, 'garut_kota');
        expect(context?.generation, greaterThanOrEqualTo(1));

        await controller.logout();
        expect(container.read(dataRequestContextProvider), isNull);
      },
    );

    test(
      'snapshotProvider cancels cancellation token when disposed before fetch completes',
      () async {
        final testRepo = _CancellableTestRepository();
        const testContext = DataRequestContext(
          environment: AppEnv.demo,
          userId: 'usr_001',
          scope: AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
          generation: 1,
        );

        final container = ProviderContainer(
          overrides: [
            dataRequestContextProvider.overrideWithValue(testContext),
            repositoryProvider.overrideWithValue(testRepo),
          ],
        );

        // Trigger provider read
        container.listen(snapshotProvider, (previous, next) {});

        expect(testRepo.capturedCancellation, isNotNull);
        expect(testRepo.capturedCancellation!.isCancelled, isFalse);

        // Dispose container before completer completes
        container.dispose();

        expect(testRepo.capturedCancellation!.isCancelled, isTrue);
        expect(testRepo.capturedCancellation!.reason, 'Provider disposed');
      },
    );

    test(
      'snapshotProvider stale guard rejects slow response when session changed',
      () async {
        final tokenStorage = InMemoryAuthTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(prefs: prefs, key: 'test_sk');
        final authRepo = DemoAuthRepository(simulateLatency: false);
        final slowRepo = _SlowIgnoringCancellationRepository();
        final composition = AppComposition.fromProfile(
          const DeploymentProfile(
            environment: AppEnv.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ),
          preferences: prefs,
          secureStore: FakeSecureKeyValStore(),
        );

        final container = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            authRepositoryProvider.overrideWithValue(authRepo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            repositoryProvider.overrideWithValue(slowRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // 1. Login User A (Garut Kota)
        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: false,
        );

        // 2. Start snapshot fetch for User A with active listener
        final sub = container.listen(snapshotProvider, (previous, next) {});
        addTearDown(sub.close);
        expect(slowRepo.completers.containsKey('garut_kota'), isTrue);
        final completerA = slowRepo.completers['garut_kota']!;

        // 3. User switches to User B (Tarogong Kidul) while User A request is in-flight
        await controller.logout();
        await controller.login(
          skNumber: 'DEMO-002',
          password: 'koktarogong123',
          staySignedIn: false,
          rememberSk: false,
        );

        // 4. Slow transport now completes User A's data late (transport ignored cancellation)
        final dummySnapshotA = KokSnapshot(
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Garut Kota',
          ),
          clubs: const [],
          people: const [],
          committee: const [],
          loadedAt: DateTime(2026, 9, 9),
        );
        completerA.complete(dummySnapshotA);

        // 5. User B requests snapshot
        final futureB = container.read(snapshotProvider.future);
        expect(slowRepo.completers.containsKey('tarogong_kidul'), isTrue);
        final dummySnapshotB = KokSnapshot(
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'tarogong_kidul',
            name: 'Tarogong Kidul',
          ),
          clubs: const [],
          people: const [],
          committee: const [],
          loadedAt: DateTime(2026, 9, 9),
        );
        slowRepo.completers['tarogong_kidul']!.complete(dummySnapshotB);

        // 6. User B receives clean Tarogong Kidul data, never contaminated by User A's stale response (SC-24)
        final snapshotB = await futureB;
        expect(snapshotB.scope.id, 'tarogong_kidul');
        expect(snapshotB, equals(dummySnapshotB));
        expect(snapshotB, isNot(equals(dummySnapshotA)));
      },
    );

    test(
      'snapshotProvider retry policy does not retry lifecycle exceptions',
      () {
        final retryPolicy = snapshotProvider.retry;
        expect(retryPolicy, isNotNull);

        // Lifecycle exceptions return null (do not retry)
        expect(retryPolicy!(1, const SessionRequiredException()), isNull);
        expect(retryPolicy(1, const RequestCancelledException()), isNull);
        expect(
          retryPolicy(
            1,
            const UnsupportedScopeException(
              AccessScope(
                type: AccessScopeType.county,
                id: 'test',
                name: 'test',
              ),
            ),
          ),
          isNull,
        );
        expect(retryPolicy(1, StateError('Scope mismatch test')), isNull);

        // Non-lifecycle exceptions are retried using defaultRetry
        final regularError = Exception('Network timeout');
        final defaultDuration = ProviderContainer.defaultRetry(1, regularError);
        expect(retryPolicy(1, regularError), equals(defaultDuration));
      },
    );

    test(
      'snapshotProvider melempar StateError saat repository mengembalikan snapshot dengan scope tidak cocok',
      () async {
        final tokenStorage = InMemoryAuthTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'test_remembered_sk',
        );
        final authRepo = DemoAuthRepository(simulateLatency: false);

        final mismatchRepo = _MismatchedScopeRepository(
          mismatchedScope: const AccessScope(
            type: AccessScopeType.district,
            id: 'tarogong_kidul',
            name: 'Kecamatan Tarogong Kidul',
          ),
        );
        final composition = AppComposition.fromProfile(
          const DeploymentProfile(
            environment: AppEnv.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ),
          preferences: prefs,
          secureStore: FakeSecureKeyValStore(),
        );

        final container = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            authRepositoryProvider.overrideWithValue(authRepo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            repositoryProvider.overrideWithValue(mismatchRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // Login Pak Asep (Garut Kota)
        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: false,
        );

        expect(
          () => container.read(snapshotProvider.future),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Repository mengembalikan snapshot dengan scope tidak cocok',
              ),
            ),
          ),
        );
      },
    );
  });
}

class _MismatchedScopeRepository implements KokRepository {
  final AccessScope mismatchedScope;
  _MismatchedScopeRepository({required this.mismatchedScope});

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) async {
    return KokSnapshot(
      scope: mismatchedScope,
      clubs: const [],
      people: const [],
      committee: const [],
      loadedAt: DateTime.now(),
    );
  }
}

class _CancellableTestRepository implements KokRepository {
  RequestCancellation? capturedCancellation;
  final Completer<KokSnapshot> completer = Completer<KokSnapshot>();

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) {
    capturedCancellation = cancellation;
    return completer.future;
  }
}

class _SlowIgnoringCancellationRepository implements KokRepository {
  final Map<String, Completer<KokSnapshot>> completers = {};
  final Map<String, RequestCancellation?> capturedCancellations = {};

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) {
    capturedCancellations[scope.id] = cancellation;
    final completer = Completer<KokSnapshot>();
    completers[scope.id] = completer;
    return completer.future;
  }
}

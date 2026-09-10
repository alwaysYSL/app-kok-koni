import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/app_environment.dart';
import 'package:kok_app/core/preferences.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/kok_repository.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test Doubles & Helpers
// ---------------------------------------------------------------------------

final class _MemorySecureKeyValStore implements SecureKeyValStore {
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

final class _ControllableTokenStorage implements AuthTokenStorage {
  StoredCredential? credential;
  bool failClearIfOwned = false;
  bool failForceClear = false;

  @override
  Future<StoredCredential?> read() async => credential;

  @override
  Future<void> write(StoredCredential cred) async {
    credential = cred;
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (failClearIfOwned) {
      throw const StorageException('Simulated clearIfOwnedBy storage error');
    }
    if (credential?.credentialId == credentialId) {
      credential = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    if (failForceClear) {
      throw const StorageException(
        'Simulated forceClearForRecovery storage error',
      );
    }
    credential = null;
  }

  @override
  Future<void> migrateLegacyStorage() async {}
}

final class _TrackingAuthRepository extends DemoAuthRepository {
  _TrackingAuthRepository() : super(simulateLatency: false);

  RemoteSessionHandle? lastRevokedHandle;
  int revokeCount = 0;

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    revokeCount++;
    lastRevokedHandle = session;
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }
}

final class _DelayedSwitchKokRepository implements KokRepository {
  final Map<String, Completer<KokSnapshot>> completers = {};
  final List<String> requestedScopeIds = [];

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) {
    requestedScopeIds.add(scope.id);
    final completer = Completer<KokSnapshot>();
    completers[scope.id] = completer;

    cancellation?.whenCancelled.then((reason) {
      if (!completer.isCompleted) {
        completer.completeError(RequestCancelledException(reason));
      }
    });

    return completer.future;
  }
}

// ---------------------------------------------------------------------------
// Main Regression Suite
// ---------------------------------------------------------------------------

void main() {
  group('Auth Hardening & Lifecycle Remediation: Cross-Layer Regression', () {
    // -------------------------------------------------------------------------
    // Flow 1: DEMO-003 persistent login -> restart -> restored as usr_koni_kab
    //         with county scope -> county snapshot: 5 sports, 9 clubs,
    //         213 athletes, 18 coaches.
    // -------------------------------------------------------------------------
    test(
      'Flow 1: DEMO-003 persistent login -> restart -> county restore & 5-sport snapshot',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final secureStore = _MemorySecureKeyValStore();

        final composition1 = AppComposition.fromProfile(
          const DeploymentProfile(
            environment: AppEnvironment.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ),
          preferences: prefs,
          secureStore: secureStore,
        );

        // Bootstrap container 1
        final container1 = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(composition1),
            preferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(
              DemoAuthRepository(simulateLatency: false),
            ),
            repositoryProvider.overrideWithValue(
              DemoKokRepository(simulateLatency: false),
            ),
          ],
        );

        final controller1 = container1.read(authControllerProvider.notifier);
        await controller1.bootstrap();
        expect(
          container1.read(authControllerProvider),
          isA<AuthSignedOut>().having(
            (s) => s.cleanupStatus,
            'cleanupStatus',
            LocalCleanupStatus.clean,
          ),
        );

        // Step 1: Persistent login as DEMO-003 (Ibu Rina, KONI Kab)
        final loginResult = await controller1.login(
          skNumber: 'DEMO-003',
          password: 'konigarut123',
          staySignedIn: true,
          rememberSk: false,
        );
        expect(loginResult.isSuccess, isTrue);

        final signedInState1 = container1.read(authControllerProvider);
        expect(signedInState1, isA<AuthSignedIn>());
        final user1 = (signedInState1 as AuthSignedIn).user;
        expect(user1.id, 'usr_koni_kab');
        expect(user1.fullName, 'Ibu Rina');
        expect(user1.scope.type, AccessScopeType.county);
        expect(user1.scope.id, 'koni_kab');
        expect(user1.scope.name, 'KONI Kabupaten Garut');

        // Step 2: Simulate app termination / restart by disposing container 1
        container1.dispose();

        // Step 3: Bootstrap fresh container 2 using the same persistent storage
        final composition2 = AppComposition.fromProfile(
          const DeploymentProfile(
            environment: AppEnvironment.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ),
          preferences: prefs,
          secureStore: secureStore,
        );

        final container2 = ProviderContainer(
          overrides: [
            appCompositionProvider.overrideWithValue(composition2),
            preferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(
              DemoAuthRepository(simulateLatency: false),
            ),
            repositoryProvider.overrideWithValue(
              DemoKokRepository(simulateLatency: false),
            ),
          ],
        );
        addTearDown(container2.dispose);

        final controller2 = container2.read(authControllerProvider.notifier);
        await controller2.bootstrap();

        // Step 4: Verify user is restored as usr_koni_kab with county scope
        final state2 = container2.read(authControllerProvider);
        expect(state2, isA<AuthSignedIn>());
        final user2 = (state2 as AuthSignedIn).user;
        expect(user2.id, 'usr_koni_kab');
        expect(user2.fullName, 'Ibu Rina');
        expect(user2.scope.type, AccessScopeType.county);
        expect(user2.scope.id, 'koni_kab');
        expect(user2.scope.name, 'KONI Kabupaten Garut');

        // Step 5: Fetch snapshotProvider and verify County snapshot
        final snapshot = await container2.read(snapshotProvider.future);
        expect(snapshot.scope.type, AccessScopeType.county);
        expect(snapshot.scope.id, 'koni_kab');
        expect(snapshot.scope.name, 'KONI Kabupaten Garut');

        // Exactly 5 unique sports
        final uniqueSports = snapshot.clubs.map((c) => c.sport).toSet();
        expect(uniqueSports.length, equals(5));
        expect(
          uniqueSports,
          equals({
            'Sepak Bola',
            'Bulu Tangkis',
            'Pencak Silat',
            'Bola Voli',
            'Renang',
          }),
        );

        // Exactly 9 clubs
        expect(snapshot.clubs.length, equals(9));

        // Exactly 213 athletes
        final athletes = snapshot.people
            .where((p) => p.role == 'Atlet')
            .toList();
        expect(athletes.length, equals(213));

        // Exactly 18 coaches
        final coaches = snapshot.people
            .where((p) => p.role == 'Pelatih')
            .toList();
        expect(coaches.length, equals(18));
      },
    );

    // -------------------------------------------------------------------------
    // Flow 2: Delayed fetch on account A -> switch to account B -> stale
    //         response from A is rejected and does not pollute B.
    // -------------------------------------------------------------------------
    test(
      'Flow 2: Delayed fetch switch-user stale guard rejects stale response without cross-session pollution',
      () async {
        final delayedRepo = _DelayedSwitchKokRepository();
        final tokenStorage = _ControllableTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final metadataStore = SharedPrefsSessionMetadataStore(
          prefs: prefs,
          key: 'kok.auth.v2.demo.metadata',
        );
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'kok.auth.v2.demo.remembered_sk',
        );
        final authRepo = DemoAuthRepository(simulateLatency: false);

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
            repositoryProvider.overrideWithValue(delayedRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // 1. User A (Pak Asep, Garut Kota) logs in
        final loginA = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: false,
        );
        expect(loginA.isSuccess, isTrue);
        final initialGeneration = controller.sessionGeneration;

        // 2. User A initiates delayed fetch on snapshotProvider
        final subA = container.listen(snapshotProvider, (prev, next) {});
        addTearDown(subA.close);

        expect(delayedRepo.completers.containsKey('garut_kota'), isTrue);
        final completerA = delayedRepo.completers['garut_kota']!;

        // 3. Before fetch completes, User A logs out and User B logs in
        await controller.logout();
        final loginB = await controller.login(
          skNumber: 'DEMO-002',
          password: 'koktarogong123',
          staySignedIn: false,
          rememberSk: false,
        );
        expect(loginB.isSuccess, isTrue);
        expect(controller.sessionGeneration, greaterThan(initialGeneration));

        // 4. User A's slow transport resolves late
        final staleGarutSnapshot = KokSnapshot(
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
          clubs: const [
            Club(
              id: 'club-gk-stale',
              name: 'Stale GK Club',
              sport: 'Renang',
              village: 'Pakuwon',
            ),
          ],
          people: const [],
          committee: const [],
          loadedAt: DateTime.now(),
        );
        completerA.complete(staleGarutSnapshot);

        // 5. User B fetches snapshotProvider
        final futureB = container.read(snapshotProvider.future);
        expect(delayedRepo.completers.containsKey('tarogong_kidul'), isTrue);

        final cleanTarogongSnapshot = KokSnapshot(
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'tarogong_kidul',
            name: 'Kecamatan Tarogong Kidul',
          ),
          clubs: const [
            Club(
              id: 'club-tk-clean',
              name: 'Clean TK Club',
              sport: 'Sepak Bola',
              village: 'Sukagalih',
            ),
          ],
          people: const [],
          committee: const [],
          loadedAt: DateTime.now(),
        );
        delayedRepo.completers['tarogong_kidul']!.complete(
          cleanTarogongSnapshot,
        );

        // 6. User B receives clean Tarogong Kidul data, free of any Garut Kota data
        final snapshotB = await futureB;
        expect(snapshotB.scope.id, equals('tarogong_kidul'));
        expect(snapshotB.scope.name, equals('Kecamatan Tarogong Kidul'));
        expect(snapshotB.clubs.first.id, equals('club-tk-clean'));
        expect(snapshotB.clubs.any((c) => c.id == 'club-gk-stale'), isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // Flow 3: Logout clear fails -> restart -> restore rejected, state
    //         signed-out failed -> recovery succeeds -> re-login available
    //         and succeeds.
    // -------------------------------------------------------------------------
    test(
      'Flow 3: Logout clear fails -> restart -> restore rejected failed -> recovery succeeds -> re-login succeeds',
      () async {
        final tokenStorage = _ControllableTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final metadataStore = SharedPrefsSessionMetadataStore(
          prefs: prefs,
          key: 'kok.auth.v2.demo.metadata',
        );
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'kok.auth.v2.demo.remembered_sk',
        );
        final authRepo = DemoAuthRepository(simulateLatency: false);

        final container1 = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );

        final controller1 = container1.read(authControllerProvider.notifier);
        await controller1.bootstrap();

        // 1. Login with staySignedIn: true
        final loginResult = await controller1.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );
        expect(loginResult.isSuccess, isTrue);
        expect(tokenStorage.credential, isNotNull);

        // 2. Storage suffers hardware fault during logout clear
        tokenStorage.failClearIfOwned = true;
        final logoutResult = await controller1.logout();
        expect(logoutResult.credentialCleared, isFalse);
        expect(logoutResult.metadataClean, isFalse);
        expect(
          container1.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );

        // Metadata recorded cleanupStatus: failed
        final metaAfterLogout = await metadataStore.read();
        expect(metaAfterLogout?.restoreAllowed, isFalse);
        expect(metaAfterLogout?.cleanupStatus, LocalCleanupStatus.failed);

        // 3. Simulated app restart: dispose container 1 and boot container 2
        container1.dispose();

        final container2 = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container2.dispose);

        final controller2 = container2.read(authControllerProvider.notifier);
        await controller2.bootstrap();

        // Restore is rejected fail-closed, state remains signed-out failed
        expect(
          container2.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );

        // 4. User invokes recovery action (retryLocalCredentialCleanup)
        tokenStorage.failClearIfOwned = false;
        tokenStorage.failForceClear = false;

        final recoverySuccess = await controller2.retryLocalCredentialCleanup();
        expect(recoverySuccess, isTrue);

        // State transitions to clean and stored credential is cleared
        expect(
          container2.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(tokenStorage.credential, isNull);

        final metaAfterRecovery = await metadataStore.read();
        expect(metaAfterRecovery?.restoreAllowed, isFalse);
        expect(metaAfterRecovery?.cleanupStatus, LocalCleanupStatus.clean);

        // 5. Re-login is available and succeeds cleanly
        final reLoginResult = await controller2.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );
        expect(reLoginResult.isSuccess, isTrue);
        expect(container2.read(authControllerProvider), isA<AuthSignedIn>());
      },
    );

    // -------------------------------------------------------------------------
    // Flow 4: Nonpersistent login -> logout -> remote revocation executed and
    //         awaited -> remoteRevocationStatus available without credential
    //         persisted.
    // -------------------------------------------------------------------------
    test(
      'Flow 4: Nonpersistent login -> logout -> remote revocation executed and awaited without persisted credential',
      () async {
        final tokenStorage = _ControllableTokenStorage();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final metadataStore = SharedPrefsSessionMetadataStore(
          prefs: prefs,
          key: 'kok.auth.v2.demo.metadata',
        );
        final skStore = RememberedSkStore(
          prefs: prefs,
          key: 'kok.auth.v2.demo.remembered_sk',
        );
        final trackingRepo = _TrackingAuthRepository();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            authRepositoryProvider.overrideWithValue(trackingRepo),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // 1. Login with staySignedIn: false
        final loginResult = await controller.login(
          skNumber: 'DEMO-002',
          password: 'koktarogong123',
          staySignedIn: false,
          rememberSk: false,
        );
        expect(loginResult.isSuccess, isTrue);

        // 2. Verify no credential was written to secure storage
        expect(tokenStorage.credential, isNull);
        final metadata = await metadataStore.read();
        expect(metadata?.restoreAllowed, isFalse);

        // 3. User logs out -> remote revocation is executed and awaited
        final logoutResult = await controller.logout();
        expect(logoutResult.localSessionClosed, isTrue);
        expect(logoutResult.credentialCleared, isTrue);
        expect(logoutResult.metadataClean, isTrue);
        expect(
          logoutResult.remoteRevocationStatus,
          equals(RemoteRevocationStatus.revoked),
        );

        // Verify remote revocation repository was called with the session handle
        expect(trackingRepo.revokeCount, equals(1));
        expect(
          trackingRepo.lastRevokedHandle,
          equals(RemoteSessionHandle('session_usr_tarogong_kidul')),
        );

        // Verify state is clean and no credential was ever persisted
        expect(tokenStorage.credential, isNull);
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
      },
    );

    // -------------------------------------------------------------------------
    // Flow 5: Production profile in Phase A fails closed with StateError.
    // -------------------------------------------------------------------------
    test(
      'Flow 5: Production profile in Phase A fails closed with StateError',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final secureStore = _MemorySecureKeyValStore();

        // Profile deployment production (remote auth + remote data)
        const prodProfile = DeploymentProfile(
          environment: AppEnvironment.production,
          authMode: AuthMode.remote,
          dataMode: DataMode.remote,
        );

        // Profile itself is structurally valid
        expect(() => prodProfile.validate(), returnsNormally);

        // AppComposition.fromProfile must fail closed because remote adapters are not yet implemented in Phase A
        expect(
          () => AppComposition.fromProfile(
            prodProfile,
            preferences: prefs,
            secureStore: secureStore,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('fail-closed'),
            ),
          ),
        );

        // Illegal combinations must fail closed via validate()
        const illegalAuthProfile = DeploymentProfile(
          environment: AppEnvironment.production,
          authMode: AuthMode.demo,
          dataMode: DataMode.remote,
        );
        expect(
          () => illegalAuthProfile.validate(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Production wajib'),
            ),
          ),
        );

        const illegalDataProfile = DeploymentProfile(
          environment: AppEnvironment.production,
          authMode: AuthMode.remote,
          dataMode: DataMode.demo,
        );
        expect(
          () => illegalDataProfile.validate(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Production wajib'),
            ),
          ),
        );
      },
    );
  });
}

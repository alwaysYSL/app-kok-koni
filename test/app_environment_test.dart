import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remote_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/remote_kok_repository.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';
import 'package:kok_app/data/services/remote/remote_athlete_service.dart';
import 'package:kok_app/data/services/remote/remote_cabor_service.dart';
import 'package:kok_app/data/services/remote/remote_profile_service.dart';

class _FakeSecureKeyValStore implements SecureKeyValStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }

  @override
  Future<bool> containsKey({required String key}) async =>
      data.containsKey(key);
}

void main() {
  group('DeploymentProfile Truth Table Tests', () {
    test('Positive: all allowed combinations validate successfully', () {
      // 1. demo / demo / demo
      const demoProfile = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.demo,
        dataMode: DataMode.demo,
      );
      expect(() => demoProfile.validate(), returnsNormally);

      // 2. staging / demo / demo
      const stagingDemoDemo = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.demo,
        dataMode: DataMode.demo,
      );
      expect(() => stagingDemoDemo.validate(), returnsNormally);

      // 3. staging / remote / demo
      const stagingRemoteDemo = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.demo,
        apiBaseUrl: 'https://api.example.test',
      );
      expect(() => stagingRemoteDemo.validate(), returnsNormally);

      // 4. staging / remote / remote
      const stagingRemoteRemote = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
        apiBaseUrl: 'https://api.example.test',
      );
      expect(() => stagingRemoteRemote.validate(), returnsNormally);

      // 5. production / remote / remote
      const prodRemoteRemote = DeploymentProfile(
        environment: AppEnv.production,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
        apiBaseUrl: 'https://api.example.test',
      );
      expect(() => prodRemoteRemote.validate(), returnsNormally);
    });

    test('Negative: illegal demo combinations throw StateError', () {
      // demo / remote / demo
      const demoRemoteDemo = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.remote,
        dataMode: DataMode.demo,
      );
      expect(
        () => demoRemoteDemo.validate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'Environment demo hanya mendukung auth demo dan data demo.',
            ),
          ),
        ),
      );

      // demo / demo / remote
      const demoDemoRemote = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.demo,
        dataMode: DataMode.remote,
      );
      expect(
        () => demoDemoRemote.validate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'Environment demo hanya mendukung auth demo dan data demo.',
            ),
          ),
        ),
      );

      // demo / remote / remote
      const demoRemoteRemote = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
      );
      expect(
        () => demoRemoteRemote.validate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'Environment demo hanya mendukung auth demo dan data demo.',
            ),
          ),
        ),
      );
    });

    test('Negative: staging strictly rejects demo auth with remote data', () {
      const stagingDemoRemote = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.demo,
        dataMode: DataMode.remote,
      );
      expect(
        () => stagingDemoRemote.validate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Staging menolak kombinasi auth demo dengan data remote.'),
          ),
        ),
      );
    });

    test(
      'Negative: production rejects any combination other than remote/remote',
      () {
        // prod / demo / demo
        const prodDemoDemo = DeploymentProfile(
          environment: AppEnv.production,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        );
        expect(
          () => prodDemoDemo.validate(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Production wajib menggunakan auth remote dan data remote.',
              ),
            ),
          ),
        );

        // prod / demo / remote
        const prodDemoRemote = DeploymentProfile(
          environment: AppEnv.production,
          authMode: AuthMode.demo,
          dataMode: DataMode.remote,
        );
        expect(
          () => prodDemoRemote.validate(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Production wajib menggunakan auth remote dan data remote.',
              ),
            ),
          ),
        );

        // prod / remote / demo
        const prodRemoteDemo = DeploymentProfile(
          environment: AppEnv.production,
          authMode: AuthMode.remote,
          dataMode: DataMode.demo,
        );
        expect(
          () => prodRemoteDemo.validate(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Production wajib menggunakan auth remote dan data remote.',
              ),
            ),
          ),
        );
      },
    );

    test('DeploymentProfile equality and hashCode', () {
      const profileA1 = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.demo,
        dataMode: DataMode.demo,
      );
      const profileA2 = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.demo,
        dataMode: DataMode.demo,
      );
      const profileB = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.demo,
        dataMode: DataMode.demo,
      );

      expect(profileA1, equals(profileA2));
      expect(profileA1.hashCode, equals(profileA2.hashCode));
      expect(profileA1, isNot(equals(profileB)));
    });

    test('DeploymentProfile.fromEnvironment defaults to demo/demo/demo', () {
      final profile = DeploymentProfile.fromEnvironment();
      expect(profile.environment, AppEnv.demo);
      expect(profile.authMode, AuthMode.demo);
      expect(profile.dataMode, DataMode.demo);
    });
  });

  group('AppComposition.fromProfile and Fail-Closed Tests', () {
    late SharedPreferences prefs;
    late _FakeSecureKeyValStore secureStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secureStore = _FakeSecureKeyValStore();
    });

    test('fromProfile creates valid demo composition', () {
      const profile = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.demo,
        dataMode: DataMode.demo,
      );

      final composition = AppComposition.fromProfile(
        profile,
        preferences: prefs,
        secureStore: secureStore,
      );

      expect(composition.profile, profile);
      expect(composition.authTokenStorage, isA<SecureAuthTokenStorage>());
      expect(
        composition.sessionMetadataStore,
        isA<SharedPrefsSessionMetadataStore>(),
      );
      expect(
        composition.rememberedUsernameStore,
        isA<RememberedUsernameStore>(),
      );
      expect(composition.authRepository, isA<DemoAuthRepository>());
      expect(composition.kokRepository, isA<DemoKokRepository>());
      expect(composition.profileService, isA<DemoProfileService>());
      expect(composition.caborService, isA<DemoCaborService>());
      expect(composition.athleteService, isA<DemoAthleteService>());
      expect(
        composition.credentialIdGenerator,
        isA<UuidCredentialIdGenerator>(),
      );
      expect(composition.revocationTimeout, const Duration(seconds: 5));
    });

    test(
      'fromProfile builds fail-closed remote adapters without guessing endpoints',
      () {
        const stagingRemoteAuth = DeploymentProfile(
          environment: AppEnv.staging,
          authMode: AuthMode.remote,
          dataMode: DataMode.demo,
          apiBaseUrl: 'https://api.example.test',
        );

        final stagingComposition = AppComposition.fromProfile(
          stagingRemoteAuth,
          preferences: prefs,
          secureStore: secureStore,
        );
        expect(stagingComposition.authRepository, isA<RemoteAuthRepository>());
        expect(stagingComposition.kokRepository, isA<DemoKokRepository>());
        expect(stagingComposition.profileService, isA<DemoProfileService>());
        expect(stagingComposition.caborService, isA<DemoCaborService>());
        expect(stagingComposition.athleteService, isA<DemoAthleteService>());
        expect(stagingComposition.apiClient, isNotNull);

        const prodRemoteAuth = DeploymentProfile(
          environment: AppEnv.production,
          authMode: AuthMode.remote,
          dataMode: DataMode.remote,
          apiBaseUrl: 'https://api.example.test',
        );

        final productionComposition = AppComposition.fromProfile(
          prodRemoteAuth,
          preferences: prefs,
          secureStore: secureStore,
        );
        expect(
          productionComposition.authRepository,
          isA<RemoteAuthRepository>(),
        );
        expect(productionComposition.kokRepository, isA<RemoteKokRepository>());
        expect(
          productionComposition.profileService,
          isA<RemoteProfileService>(),
        );
        expect(productionComposition.caborService, isA<RemoteCaborService>());
        expect(
          productionComposition.athleteService,
          isA<RemoteAthleteService>(),
        );
        expect(productionComposition.apiClient, isNotNull);
      },
    );

    test('fromProfile validates profile before composition', () {
      const invalidProfile = DeploymentProfile(
        environment: AppEnv.demo,
        authMode: AuthMode.remote,
        dataMode: DataMode.demo,
      );

      expect(
        () => AppComposition.fromProfile(
          invalidProfile,
          preferences: prefs,
          secureStore: secureStore,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'Environment demo hanya mendukung auth demo dan data demo.',
            ),
          ),
        ),
      );
    });
  });

  group('Key Namespace Isolation Tests (SC-29)', () {
    test(
      'demo and staging key namespaces are isolated and non-colliding',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final secureStore = _FakeSecureKeyValStore();

        const demoProfile = DeploymentProfile(
          environment: AppEnv.demo,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        );
        const stagingProfile = DeploymentProfile(
          environment: AppEnv.staging,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        );

        final demoComposition = AppComposition.fromProfile(
          demoProfile,
          preferences: prefs,
          secureStore: secureStore,
        );
        final stagingComposition = AppComposition.fromProfile(
          stagingProfile,
          preferences: prefs,
          secureStore: secureStore,
        );

        // Write Demo data
        await demoComposition.authTokenStorage.write(
          StoredCredential(
            credentialId: 'demo_cid',
            sessionToken: 'demo_token',
          ),
        );
        await demoComposition.sessionMetadataStore.write(
          SessionMetadata.restoreEnabled('demo_cid'),
        );
        await demoComposition.rememberedUsernameStore.saveUsername('DEMO-001');

        // Write Staging data
        await stagingComposition.authTokenStorage.write(
          StoredCredential(
            credentialId: 'staging_cid',
            sessionToken: 'staging_token',
          ),
        );
        await stagingComposition.sessionMetadataStore.write(
          SessionMetadata.restoreEnabled('staging_cid'),
        );
        await stagingComposition.rememberedUsernameStore.saveUsername(
          'SK-STAGING-002',
        );

        // Verify exact keys in stores
        expect(
          secureStore.data.containsKey('kok.auth.v3.demo.credential'),
          isTrue,
        );
        expect(
          secureStore.data['kok.auth.v3.demo.credential'],
          contains('demo_cid'),
        );
        expect(
          secureStore.data.containsKey('kok.auth.v3.staging.credential'),
          isTrue,
        );
        expect(
          secureStore.data['kok.auth.v3.staging.credential'],
          contains('staging_cid'),
        );

        expect(prefs.containsKey('kok.auth.v3.demo.metadata'), isTrue);
        expect(
          prefs.getString('kok.auth.v3.demo.metadata'),
          contains('demo_cid'),
        );
        expect(prefs.containsKey('kok.auth.v3.staging.metadata'), isTrue);
        expect(
          prefs.getString('kok.auth.v3.staging.metadata'),
          contains('staging_cid'),
        );

        expect(
          prefs.getString('kok.auth.v3.demo.remembered_username'),
          'DEMO-001',
        );
        expect(
          prefs.getString('kok.auth.v3.staging.remembered_username'),
          'SK-STAGING-002',
        );

        // Verify reads from each composition read only its own namespace
        final demoCred = await demoComposition.authTokenStorage.read();
        final stagingCred = await stagingComposition.authTokenStorage.read();
        expect(demoCred?.credentialId, 'demo_cid');
        expect(stagingCred?.credentialId, 'staging_cid');

        final demoMeta = await demoComposition.sessionMetadataStore.read();
        final stagingMeta = await stagingComposition.sessionMetadataStore
            .read();
        expect(demoMeta?.expectedCredentialId, 'demo_cid');
        expect(stagingMeta?.expectedCredentialId, 'staging_cid');

        final demoUsername = await demoComposition.rememberedUsernameStore
            .readUsername();
        final stagingUsername = await stagingComposition.rememberedUsernameStore
            .readUsername();
        expect(demoUsername, 'DEMO-001');
        expect(stagingUsername, 'SK-STAGING-002');
      },
    );
  });

  group('Provider Wiring with appCompositionProvider Tests', () {
    test(
      'Derived providers read injected instances when appCompositionProvider is overridden',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final secureStore = _FakeSecureKeyValStore();

        const profile = DeploymentProfile(
          environment: AppEnv.demo,
          authMode: AuthMode.demo,
          dataMode: DataMode.demo,
        );
        final composition = AppComposition.fromProfile(
          profile,
          preferences: prefs,
          secureStore: secureStore,
        );

        final container = ProviderContainer(
          overrides: [appCompositionProvider.overrideWithValue(composition)],
        );
        addTearDown(container.dispose);

        expect(
          container.read(authTokenStorageProvider),
          same(composition.authTokenStorage),
        );
        expect(
          container.read(sessionMetadataStoreProvider),
          same(composition.sessionMetadataStore),
        );
        expect(
          container.read(rememberedUsernameStoreProvider),
          same(composition.rememberedUsernameStore),
        );
        expect(
          container.read(authRepositoryProvider),
          same(composition.authRepository),
        );
        expect(
          container.read(credentialIdGeneratorProvider),
          same(composition.credentialIdGenerator),
        );
        expect(
          container.read(repositoryProvider),
          same(composition.kokRepository),
        );
        expect(
          container.read(profileServiceProvider),
          same(composition.profileService),
        );
        expect(
          container.read(caborServiceProvider),
          same(composition.caborService),
        );
      },
    );

    test('providers fail fast without an injected AppComposition', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      void expectMissingComposition(Object Function() readProvider) {
        expect(
          readProvider,
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'AppComposition must be injected at startup.',
              ),
              'a provider error containing the fail-fast message',
            ),
          ),
        );
      }

      expectMissingComposition(() => container.read(appCompositionProvider));
      expectMissingComposition(() => container.read(authTokenStorageProvider));
      expectMissingComposition(
        () => container.read(sessionMetadataStoreProvider),
      );
      expectMissingComposition(
        () => container.read(rememberedUsernameStoreProvider),
      );
      expectMissingComposition(() => container.read(authRepositoryProvider));
      expectMissingComposition(() => container.read(repositoryProvider));
      expectMissingComposition(() => container.read(profileServiceProvider));
      expectMissingComposition(() => container.read(caborServiceProvider));
    });
  });

  group('DeploymentProfile direct validation tests', () {
    test(
      'DeploymentProfile.validate melempar StateError saat production menggunakan demo auth atau data',
      () {
        expect(
          () => const DeploymentProfile(
            environment: AppEnv.production,
            authMode: AuthMode.demo,
            dataMode: DataMode.remote,
            apiBaseUrl: 'https://api.example.test',
          ).validate(),
          throwsStateError,
        );

        expect(
          () => const DeploymentProfile(
            environment: AppEnv.production,
            authMode: AuthMode.remote,
            dataMode: DataMode.demo,
            apiBaseUrl: 'https://api.example.test',
          ).validate(),
          throwsStateError,
        );
      },
    );

    test(
      'DeploymentProfile.validate menolak HTTP plaintext untuk production',
      () {
        expect(
          () => const DeploymentProfile(
            environment: AppEnv.production,
            authMode: AuthMode.remote,
            dataMode: DataMode.remote,
            apiBaseUrl: 'http://api.example.test',
          ).validate(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Production wajib menggunakan HTTPS untuk API_BASE_URL.',
              ),
            ),
          ),
        );

        expect(
          () => const DeploymentProfile(
            environment: AppEnv.production,
            authMode: AuthMode.remote,
            dataMode: DataMode.remote,
            apiBaseUrl: 'https://api.example.test',
          ).validate(),
          returnsNormally,
        );
      },
    );

    test(
      'DeploymentProfile.validate lolos saat demo atau staging menggunakan demo auth',
      () {
        expect(
          () => const DeploymentProfile(
            environment: AppEnv.demo,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ).validate(),
          returnsNormally,
        );

        expect(
          () => const DeploymentProfile(
            environment: AppEnv.staging,
            authMode: AuthMode.demo,
            dataMode: DataMode.demo,
          ).validate(),
          returnsNormally,
        );
      },
    );
  });
}

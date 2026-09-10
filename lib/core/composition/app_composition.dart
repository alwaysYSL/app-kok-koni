import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/data/auth_repository.dart';
import '../auth/data/auth_token_storage.dart';
import '../auth/data/demo_auth_repository.dart';
import '../auth/data/remembered_sk_store.dart';
import '../auth/data/session_metadata_store.dart';
import '../auth/domain/credential_id_generator.dart';
import '../config/deployment_profile.dart';
import '../../data/demo_kok_repository.dart';
import '../../data/kok_repository.dart';

export '../config/deployment_profile.dart';

final class AppComposition {
  const AppComposition({
    required this.profile,
    required this.authTokenStorage,
    required this.sessionMetadataStore,
    required this.rememberedSkStore,
    required this.authRepository,
    required this.kokRepository,
    required this.credentialIdGenerator,
    this.revocationTimeout = const Duration(seconds: 5),
  });

  final DeploymentProfile profile;
  final AuthTokenStorage authTokenStorage;
  final SessionMetadataStore sessionMetadataStore;
  final RememberedSkStore rememberedSkStore;
  final AuthRepository authRepository;
  final KokRepository kokRepository;
  final CredentialIdGenerator credentialIdGenerator;
  final Duration revocationTimeout;

  factory AppComposition.fromProfile(
    DeploymentProfile profile, {
    required SharedPreferences preferences,
    required SecureKeyValStore secureStore,
    CredentialIdGenerator? credentialIdGenerator,
    Duration revocationTimeout = const Duration(seconds: 5),
  }) {
    profile.validate();

    final envName = profile.environment.name;
    final idGen = credentialIdGenerator ?? UuidCredentialIdGenerator();

    final tokenStorage = SecureAuthTokenStorage(
      store: secureStore,
      key: 'kok.auth.v2.$envName.credential',
    );

    final metadataStore = SharedPrefsSessionMetadataStore(
      prefs: preferences,
      key: 'kok.auth.v2.$envName.metadata',
    );

    final skStore = RememberedSkStore(
      prefs: preferences,
      key: 'kok.auth.v2.$envName.remembered_sk',
    );

    final AuthRepository authRepo;
    if (profile.authMode == AuthMode.demo) {
      authRepo = DemoAuthRepository(simulateLatency: false);
    } else {
      throw StateError(
        'Adapter RemoteAuthRepository belum tersedia (fail-closed).',
      );
    }

    final KokRepository kokRepo;
    if (profile.dataMode == DataMode.demo) {
      kokRepo = DemoKokRepository();
    } else {
      throw StateError(
        'Adapter RemoteKokRepository belum tersedia (fail-closed).',
      );
    }

    return AppComposition(
      profile: profile,
      authTokenStorage: tokenStorage,
      sessionMetadataStore: metadataStore,
      rememberedSkStore: skStore,
      authRepository: authRepo,
      kokRepository: kokRepo,
      credentialIdGenerator: idGen,
      revocationTimeout: revocationTimeout,
    );
  }
}

final appCompositionProvider = Provider<AppComposition?>((ref) => null);

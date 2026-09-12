import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/data/auth_repository.dart';
import '../auth/data/auth_token_storage.dart';
import '../auth/data/demo_auth_repository.dart';
import '../auth/data/remote_auth_repository.dart';
import '../auth/data/remembered_sk_store.dart';
import '../auth/data/session_metadata_store.dart';
import '../auth/domain/credential_id_generator.dart';
import '../config/deployment_profile.dart';
import '../network/auth_session_tokens.dart';
import '../network/api_client.dart';
import '../../data/demo_kok_repository.dart';
import '../../data/kok_repository.dart';
import '../../data/remote_kok_repository.dart';

final class AppComposition {
  AppComposition({
    required this.profile,
    required this.authTokenStorage,
    required this.sessionMetadataStore,
    required this.rememberedSkStore,
    required this.authRepository,
    required this.kokRepository,
    required this.credentialIdGenerator,
    AuthSessionTokens? sessionTokens,
    this.apiClient,
    this.revocationTimeout = const Duration(seconds: 5),
  }) : sessionTokens = sessionTokens ?? AuthSessionTokens();

  final DeploymentProfile profile;
  final AuthTokenStorage authTokenStorage;
  final SessionMetadataStore sessionMetadataStore;
  final RememberedSkStore rememberedSkStore;
  final AuthRepository authRepository;
  final KokRepository kokRepository;
  final CredentialIdGenerator credentialIdGenerator;
  final AuthSessionTokens sessionTokens;
  final ApiClient? apiClient;
  final Duration revocationTimeout;

  factory AppComposition.fromProfile(
    DeploymentProfile profile, {
    required SharedPreferences preferences,
    required SecureKeyValStore secureStore,
    CredentialIdGenerator? credentialIdGenerator,
    AuthSessionTokens? sessionTokens,
    Duration revocationTimeout = const Duration(seconds: 5),
  }) {
    profile.validate();

    final envName = profile.environment.name;
    final idGen = credentialIdGenerator ?? UuidCredentialIdGenerator();
    final bridge = sessionTokens ?? AuthSessionTokens();

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

    final ApiClient? apiClient;
    final AuthRepository authRepo;
    if (profile.authMode == AuthMode.demo) {
      apiClient = null;
      authRepo = DemoAuthRepository(simulateLatency: false);
    } else {
      late final RemoteAuthRepository remoteAuthRepository;
      final client = ApiClient(
        profile: profile,
        tokens: bridge,
        refreshSession: (refreshToken) =>
            remoteAuthRepository.refreshToken(refreshToken),
      );
      remoteAuthRepository = RemoteAuthRepository(client);
      apiClient = client;
      authRepo = remoteAuthRepository;
    }

    final KokRepository kokRepo;
    if (profile.dataMode == DataMode.demo) {
      kokRepo = DemoKokRepository();
    } else {
      kokRepo = RemoteKokRepository(apiClient!);
    }

    return AppComposition(
      profile: profile,
      authTokenStorage: tokenStorage,
      sessionMetadataStore: metadataStore,
      rememberedSkStore: skStore,
      authRepository: authRepo,
      kokRepository: kokRepo,
      credentialIdGenerator: idGen,
      sessionTokens: bridge,
      apiClient: apiClient,
      revocationTimeout: revocationTimeout,
    );
  }
}

final appCompositionProvider = Provider<AppComposition>((ref) {
  throw StateError('AppComposition must be injected at startup.');
});

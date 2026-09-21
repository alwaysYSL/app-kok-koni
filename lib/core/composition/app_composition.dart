import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/data/auth_repository.dart';
import '../auth/data/auth_token_storage.dart';
import '../auth/data/demo_auth_repository.dart';
import '../auth/data/remote_auth_repository.dart';
import '../auth/data/remembered_username_store.dart';
import '../auth/data/session_metadata_store.dart';
import '../auth/domain/credential_id_generator.dart';
import '../auth/domain/user_principal.dart';
import '../config/deployment_profile.dart';
import '../network/auth_session_tokens.dart';
import '../network/api_client.dart';
import '../../data/demo_kok_repository.dart';
import '../../data/kok_repository.dart';
import '../../data/remote_kok_repository.dart';
import '../../data/services/athlete_service.dart';
import '../../data/services/cabor_service.dart';
import '../../data/services/club_service.dart';
import '../../data/services/demo/demo_athlete_service.dart';
import '../../data/services/demo/demo_cabor_service.dart';
import '../../data/services/demo/demo_profile_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/remote/remote_athlete_service.dart';
import '../../data/services/remote/remote_cabor_service.dart';
import '../../data/services/remote/remote_profile_service.dart';

final class AppComposition {
  AppComposition({
    required this.profile,
    required this.authTokenStorage,
    required this.sessionMetadataStore,
    required this.rememberedUsernameStore,
    required this.authRepository,
    required this.kokRepository,
    required this.profileService,
    required this.caborService,
    required this.athleteService,
    this.clubService,
    required this.credentialIdGenerator,
    AuthSessionTokens? sessionTokens,
    this.apiClient,
    this.revocationTimeout = const Duration(seconds: 5),
  }) : sessionTokens = sessionTokens ?? AuthSessionTokens();

  final DeploymentProfile profile;
  final AuthTokenStorage authTokenStorage;
  final SessionMetadataStore sessionMetadataStore;
  final RememberedUsernameStore rememberedUsernameStore;
  final AuthRepository authRepository;
  final KokRepository kokRepository;
  final ProfileService profileService;
  final CaborService caborService;
  final AthleteService athleteService;
  final ClubService? clubService;
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
      key: 'kok.auth.v3.$envName.credential',
    );

    final metadataStore = SharedPrefsSessionMetadataStore(
      prefs: preferences,
      key: 'kok.auth.v3.$envName.metadata',
    );

    final usernameStore = RememberedUsernameStore(
      prefs: preferences,
      key: 'kok.auth.v3.$envName.remembered_username',
    );

    final ApiClient? apiClient;
    final AuthRepository authRepo;
    if (profile.authMode == AuthMode.demo) {
      apiClient = null;
      authRepo = DemoAuthRepository(simulateLatency: false);
    } else {
      final client = ApiClient(profile: profile, tokens: bridge);
      final remoteAuthRepository = RemoteAuthRepository(
        dio: Dio(),
        profile: profile,
      );
      apiClient = client;
      authRepo = remoteAuthRepository;
    }

    final KokRepository kokRepo;
    final ProfileService profileService;
    final CaborService caborService;
    final AthleteService athleteService;
    if (profile.dataMode == DataMode.demo) {
      final demoKokRepo = DemoKokRepository();
      kokRepo = demoKokRepo;
      profileService = DemoProfileService(
        demoRepo: demoKokRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      );
      caborService = DemoCaborService(
        demoRepo: demoKokRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      );
      athleteService = DemoAthleteService(
        demoRepo: demoKokRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      );
    } else {
      kokRepo = RemoteKokRepository(apiClient!);
      profileService = RemoteProfileService(client: apiClient);
      caborService = RemoteCaborService(client: apiClient);
      athleteService = RemoteAthleteService(client: apiClient);
    }

    return AppComposition(
      profile: profile,
      authTokenStorage: tokenStorage,
      sessionMetadataStore: metadataStore,
      rememberedUsernameStore: usernameStore,
      authRepository: authRepo,
      kokRepository: kokRepo,
      profileService: profileService,
      caborService: caborService,
      athleteService: athleteService,
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

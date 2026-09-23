import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';

final class _TestAuthTokenStorage implements AuthTokenStorage {
  @override
  Future<StoredCredential?> read() async => null;

  @override
  Future<void> write(StoredCredential credential) async {}

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async => true;

  @override
  Future<void> forceClearForRecovery() async {}

  @override
  Future<void> migrateLegacyStorage() async {}
}

final class _TestSessionMetadataStore implements SessionMetadataStore {
  @override
  Future<SessionMetadata?> read() async => null;

  @override
  Future<void> write(SessionMetadata metadata) async {}

  @override
  Future<void> clear() async {}
}

final class _TestRememberedUsernameStore implements RememberedUsernameStore {
  @override
  Future<String?> readUsername() async => null;

  @override
  Future<void> saveUsername(String username) async {}

  @override
  Future<void> clear() async {}
}

final class _TestCredentialIdGenerator implements CredentialIdGenerator {
  @override
  String generate() => 'test-composition-credential';
}

AppComposition buildTestAppComposition({
  DeploymentProfile profile = const DeploymentProfile(
    environment: AppEnv.demo,
    authMode: AuthMode.demo,
    dataMode: DataMode.demo,
  ),
}) {
  final demoRepo = DemoKokRepository(simulateLatency: false);
  return AppComposition(
    profile: profile,
    authTokenStorage: _TestAuthTokenStorage(),
    sessionMetadataStore: _TestSessionMetadataStore(),
    rememberedUsernameStore: _TestRememberedUsernameStore(),
    authRepository: DemoAuthRepository(simulateLatency: false),
    kokRepository: demoRepo,
    profileService: DemoProfileService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    caborService: DemoCaborService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    athleteService: DemoAthleteService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    clubService: DemoClubService(
      demoRepo: demoRepo,
      currentScopeProvider: () => const AccessScope(
        type: AccessScopeType.district,
        id: '1728',
        name: 'Garut Kota',
      ),
    ),
    credentialIdGenerator: _TestCredentialIdGenerator(),
  );
}

ProviderContainer createTestProviderContainer({
  List<dynamic> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      appCompositionProvider.overrideWithValue(buildTestAppComposition()),
      ...overrides,
    ],
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/demo_kok_repository.dart';

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

final class _TestRememberedSkStore implements RememberedSkStore {
  @override
  Future<String?> readSk() async => null;

  @override
  Future<void> saveSk(String sk) async {}

  @override
  Future<void> clear() async {}
}

final class _TestCredentialIdGenerator implements CredentialIdGenerator {
  @override
  String generate() => 'test-composition-credential';
}

AppComposition buildTestAppComposition() {
  return AppComposition(
    profile: const DeploymentProfile(
      environment: AppEnv.demo,
      authMode: AuthMode.demo,
      dataMode: DataMode.demo,
    ),
    authTokenStorage: _TestAuthTokenStorage(),
    sessionMetadataStore: _TestSessionMetadataStore(),
    rememberedSkStore: _TestRememberedSkStore(),
    authRepository: DemoAuthRepository(simulateLatency: false),
    kokRepository: DemoKokRepository(simulateLatency: false),
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

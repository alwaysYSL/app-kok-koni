import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'test_composition.dart';

void main() {
  test(
    'AuthSessionTokens hanya menyimpan token di memori dan dapat di-clear',
    () {
      final tokens = AuthSessionTokens();

      tokens.replace(accessToken: 'access-1', sessionToken: 'session-1');
      expect(tokens.accessToken, 'access-1');
      expect(tokens.sessionToken, 'session-1');

      tokens.clear();
      expect(tokens.accessToken, isNull);
      expect(tokens.sessionToken, isNull);
    },
  );

  test(
    'login mengekspos access token dan session token di bridge',
    () async {
      final storage = _MemoryTokenStorage();
      final container = createTestProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_TokenAuthRepository()),
          authTokenStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await controller.bootstrap();
      final result = await controller.login(
        username: 'DEMO-001',
        password: 'password',
        staySignedIn: true,
        rememberUsername: false,
      );

      expect(result.isSuccess, isTrue);
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).accessToken, 'access-1');
      final tokens = container.read(sessionTokensProvider);
      expect(tokens.accessToken, 'access-1');
      expect(tokens.sessionToken, 'refresh-1');
      expect((await storage.read())?.sessionToken, 'refresh-1');

      await controller.logout();
      expect(tokens.accessToken, isNull);
      expect(tokens.sessionToken, isNull);
    },
  );

  test(
    'restore mengisi access token state dan token bridge dari session token aktif',
    () async {
      final storage = _MemoryTokenStorage()
        ..credential = StoredCredential(
          credentialId: 'credential-restore',
          sessionToken: 'refresh-restore',
        );
      final metadata = _MetadataStore(
        SessionMetadata.restoreEnabled('credential-restore'),
      );
      final container = createTestProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_TokenAuthRepository()),
          authTokenStorageProvider.overrideWithValue(storage),
          sessionMetadataStoreProvider.overrideWithValue(metadata),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrap();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).accessToken, 'access-restore');
      expect(
        container.read(sessionTokensProvider).sessionToken,
        'refresh-restore',
      );
    },
  );

  test('AuthSignedIn equality and hashCode include accessToken', () {
    final user = UserPrincipal(
      id: 'usr-1',
      username: 'DEMO-001',
      fullName: 'Nama User',
      roleTitle: 'Koordinator Kecamatan',
      scope: const AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      ),
    );

    final state1 = AuthSignedIn(
      user: user,
      generation: 1,
      accessToken: 'token-a',
    );
    final state2 = AuthSignedIn(
      user: user,
      generation: 1,
      accessToken: 'token-b',
    );
    final state3 = AuthSignedIn(
      user: user,
      generation: 1,
      accessToken: 'token-a',
    );

    expect(state1, isNot(equals(state2)));
    expect(state1.hashCode, isNot(equals(state2.hashCode)));
    expect(state1, equals(state3));
    expect(state1.hashCode, equals(state3.hashCode));
  });
}

final class _TokenAuthRepository implements AuthRepository {
  static final _user = UserPrincipal(
    id: 'usr-1',
    username: 'DEMO-001',
    fullName: 'Nama User',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'garut_kota',
      name: 'Kecamatan Garut Kota',
    ),
  );

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    required bool staySignedIn,
  }) async => AuthResult.success(
    user: _user,
    accessToken: 'access-1',
    sessionToken: staySignedIn ? 'refresh-1' : null,
  );

  @override
  Future<AuthResult> restoreSession(String sessionToken) async =>
      AuthResult.success(
        user: _user,
        accessToken: 'access-restore',
        sessionToken: sessionToken,
      );

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async => const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
}

final class _MemoryTokenStorage implements AuthTokenStorage {
  StoredCredential? credential;

  @override
  Future<StoredCredential?> read() async => credential;

  @override
  Future<void> write(StoredCredential value) async => credential = value;

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (credential?.credentialId != credentialId) return false;
    credential = null;
    return true;
  }

  @override
  Future<void> forceClearForRecovery() async => credential = null;

  @override
  Future<void> migrateLegacyStorage() async {}
}

final class _MetadataStore implements SessionMetadataStore {
  _MetadataStore(this.metadata);

  SessionMetadata? metadata;

  @override
  Future<SessionMetadata?> read() async => metadata;

  @override
  Future<void> write(SessionMetadata value) async => metadata = value;

  @override
  Future<void> clear() async => metadata = null;
}

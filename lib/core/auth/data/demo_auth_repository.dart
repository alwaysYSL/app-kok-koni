import 'dart:async';
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';
import 'auth_repository.dart';
import 'auth_token_storage.dart';
import 'remembered_sk_store.dart';

class DemoAuthRepository implements AuthRepository {
  final AuthTokenStorage tokenStorage;
  final RememberedSkStore? skStore;
  final bool simulateLatency;

  AuthTokenStorage get storage => tokenStorage;

  static final _garutKotaUser = UserPrincipal(
    id: 'usr-garut-kota-001',
    skNumber: 'DEMO-001',
    fullName: 'Pak Asep',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'garut_kota',
      name: 'Kecamatan Garut Kota',
    ),
    permissions: {
      'sports:read',
      'clubs:read',
      'members:read',
      'reports:export',
    },
  );

  static final _tarogongKidulUser = UserPrincipal(
    id: 'usr-tarogong-kidul-002',
    skNumber: 'DEMO-002',
    fullName: 'Pak Cecep',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'tarogong_kidul',
      name: 'Kecamatan Tarogong Kidul',
    ),
    permissions: {'sports:read', 'clubs:read', 'members:read'},
  );

  static final _koniKabUser = UserPrincipal(
    id: 'usr-koni-kab-003',
    skNumber: 'DEMO-003',
    fullName: 'Ibu Rina',
    roleTitle: 'Tim Verifikator',
    scope: const AccessScope(
      type: AccessScopeType.county,
      id: 'koni_kab',
      name: 'KONI Kabupaten Garut',
    ),
    permissions: {
      'sports:read',
      'clubs:read',
      'members:read',
      'documents:verify',
    },
  );

  DemoAuthRepository({
    AuthTokenStorage? storage,
    AuthTokenStorage? tokenStorage,
    this.skStore,
    this.simulateLatency = true,
  }) : tokenStorage = storage ?? tokenStorage ?? _DefaultAuthTokenStorage();

  Future<void> _maybeDelay() async {
    if (simulateLatency) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  }) async {
    await _maybeDelay();

    if (skNumber == 'DEMO-TIMEOUT') {
      return const AuthResult.failed(NetworkTimeoutFailure());
    }

    UserPrincipal? matchedUser;
    String? accessToken;
    String? refreshTokenValue;
    RemoteSessionHandle? sessionHandle;

    if (skNumber == 'DEMO-001' && password == 'kokgarut123') {
      matchedUser = _garutKotaUser;
      accessToken = 'access_demo_garut_kota';
      refreshTokenValue = 'token_usr_garut_kota';
      sessionHandle = RemoteSessionHandle('session_usr_garut_kota');
    } else if (skNumber == 'DEMO-002' && password == 'koktarogong123') {
      matchedUser = _tarogongKidulUser;
      accessToken = 'access_demo_tarogong_kidul';
      refreshTokenValue = 'token_usr_tarogong_kidul';
      sessionHandle = RemoteSessionHandle('session_usr_tarogong_kidul');
    } else if (skNumber == 'DEMO-003' && password == 'konigarut123') {
      matchedUser = _koniKabUser;
      accessToken = 'access_demo_koni_kab';
      refreshTokenValue = 'token_usr_koni_kab';
      sessionHandle = RemoteSessionHandle('session_usr_koni_kab');
    }

    if (matchedUser == null) {
      return const AuthResult.failed(InvalidCredentialsFailure());
    }

    return AuthResult.success(
      user: matchedUser,
      accessToken: accessToken,
      refreshToken: staySignedIn ? refreshTokenValue : null,
      sessionHandle: sessionHandle,
    );
  }

  @override
  Future<AuthResult> restoreSession([String? refreshToken]) async {
    await _maybeDelay();
    final token = refreshToken ?? await tokenStorage.getRefreshToken();
    if (token == null || token.isEmpty) {
      return const AuthResult.failed(
        SessionExpiredFailure(
          'Tidak ada sesi yang tersimpan di perangkat ini.',
        ),
      );
    }

    if (token == 'token_usr_garut_kota') {
      return AuthResult.success(
        user: _garutKotaUser,
        accessToken: 'access_demo_garut_kota',
        refreshToken: token,
        sessionHandle: RemoteSessionHandle('session_usr_garut_kota'),
      );
    } else if (token == 'token_usr_tarogong_kidul') {
      return AuthResult.success(
        user: _tarogongKidulUser,
        accessToken: 'access_demo_tarogong_kidul',
        refreshToken: token,
        sessionHandle: RemoteSessionHandle('session_usr_tarogong_kidul'),
      );
    } else if (token == 'token_usr_koni_kab') {
      return AuthResult.success(
        user: _koniKabUser,
        accessToken: 'access_demo_koni_kab',
        refreshToken: token,
        sessionHandle: RemoteSessionHandle('session_usr_koni_kab'),
      );
    }

    return const AuthResult.failed(
      SessionExpiredFailure('Sesi Anda tidak valid atau telah kedaluwarsa.'),
    );
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession(refreshToken);
  }

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    await _maybeDelay();
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }

  @override
  Future<void> logout() async {
    await _maybeDelay();
    await tokenStorage.clear();
  }
}

final class _DefaultAuthTokenStorage implements AuthTokenStorage {
  StoredCredential? _credential;

  @override
  Future<StoredCredential?> read() async => _credential;

  @override
  Future<void> write(StoredCredential credential) async {
    _credential = credential;
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (_credential?.credentialId == credentialId) {
      _credential = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    _credential = null;
  }

  @override
  Future<void> migrateLegacyStorage() async {}

  @override
  Future<String?> readRefreshToken() async => _credential?.refreshToken;

  @override
  Future<String?> getRefreshToken() => readRefreshToken();

  @override
  Future<void> saveRefreshToken(String token) async {
    _credential = StoredCredential(credentialId: 'demo', refreshToken: token);
  }

  @override
  Future<void> clear() async {
    _credential = null;
  }
}

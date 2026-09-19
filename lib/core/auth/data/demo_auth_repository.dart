import 'dart:async';
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';
import 'auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  final bool simulateLatency;

  static final _garutKotaUser = UserPrincipal(
    id: 'usr_garut_kota',
    username: 'DEMO-001',
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
    id: 'usr_tarogong_kidul',
    username: 'DEMO-002',
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
    id: 'usr_koni_kab',
    username: 'DEMO-003',
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
      'reports:export',
    },
  );

  DemoAuthRepository({this.simulateLatency = true});

  Future<void> _maybeDelay() async {
    if (simulateLatency) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    required bool staySignedIn,
  }) async {
    await _maybeDelay();

    if (username == 'DEMO-TIMEOUT') {
      return const AuthResult.failed(NetworkTimeoutFailure());
    }

    UserPrincipal? matchedUser;
    String? accessToken;
    String? sessionTokenValue;
    RemoteSessionHandle? sessionHandle;

    if (username == 'DEMO-001' && password == 'kokgarut123') {
      matchedUser = _garutKotaUser;
      accessToken = 'access_demo_garut_kota';
      sessionTokenValue = 'token_usr_garut_kota';
      sessionHandle = RemoteSessionHandle('session_usr_garut_kota');
    } else if (username == 'DEMO-002' && password == 'koktarogong123') {
      matchedUser = _tarogongKidulUser;
      accessToken = 'access_demo_tarogong_kidul';
      sessionTokenValue = 'token_usr_tarogong_kidul';
      sessionHandle = RemoteSessionHandle('session_usr_tarogong_kidul');
    } else if (username == 'DEMO-003' && password == 'konigarut123') {
      matchedUser = _koniKabUser;
      accessToken = 'access_demo_koni_kab';
      sessionTokenValue = 'token_usr_koni_kab';
      sessionHandle = RemoteSessionHandle('session_usr_koni_kab');
    }

    if (matchedUser == null) {
      return const AuthResult.failed(InvalidCredentialsFailure());
    }

    return AuthResult.success(
      user: matchedUser,
      accessToken: accessToken,
      sessionToken: staySignedIn ? sessionTokenValue : null,
      sessionHandle: sessionHandle,
    );
  }

  @override
  Future<AuthResult> restoreSession(String sessionToken) async {
    await _maybeDelay();
    if (sessionToken.trim().isEmpty) {
      return const AuthResult.failed(
        SessionExpiredFailure(
          'Tidak ada sesi yang tersimpan di perangkat ini.',
        ),
      );
    }

    if (sessionToken == 'token_usr_garut_kota') {
      return AuthResult.success(
        user: _garutKotaUser,
        accessToken: 'access_demo_garut_kota',
        sessionToken: sessionToken,
        sessionHandle: RemoteSessionHandle('session_usr_garut_kota'),
      );
    } else if (sessionToken == 'token_usr_tarogong_kidul') {
      return AuthResult.success(
        user: _tarogongKidulUser,
        accessToken: 'access_demo_tarogong_kidul',
        sessionToken: sessionToken,
        sessionHandle: RemoteSessionHandle('session_usr_tarogong_kidul'),
      );
    } else if (sessionToken == 'token_usr_koni_kab') {
      return AuthResult.success(
        user: _koniKabUser,
        accessToken: 'access_demo_koni_kab',
        sessionToken: sessionToken,
        sessionHandle: RemoteSessionHandle('session_usr_koni_kab'),
      );
    }

    return const AuthResult.failed(
      SessionExpiredFailure('Sesi Anda tidak valid atau telah kedaluwarsa.'),
    );
  }

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    await _maybeDelay();
    return const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
  }
}

import 'dart:async';
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';
import 'auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  final bool simulateLatency;

  static final _garutKotaUser = UserPrincipal(
    id: 'usr_garut_kota',
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
    id: 'usr_tarogong_kidul',
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
    id: 'usr_koni_kab',
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
  Future<AuthResult> restoreSession(String refreshToken) async {
    await _maybeDelay();
    if (refreshToken.trim().isEmpty) {
      return const AuthResult.failed(
        SessionExpiredFailure(
          'Tidak ada sesi yang tersimpan di perangkat ini.',
        ),
      );
    }

    if (refreshToken == 'token_usr_garut_kota') {
      return AuthResult.success(
        user: _garutKotaUser,
        accessToken: 'access_demo_garut_kota',
        refreshToken: refreshToken,
        sessionHandle: RemoteSessionHandle('session_usr_garut_kota'),
      );
    } else if (refreshToken == 'token_usr_tarogong_kidul') {
      return AuthResult.success(
        user: _tarogongKidulUser,
        accessToken: 'access_demo_tarogong_kidul',
        refreshToken: refreshToken,
        sessionHandle: RemoteSessionHandle('session_usr_tarogong_kidul'),
      );
    } else if (refreshToken == 'token_usr_koni_kab') {
      return AuthResult.success(
        user: _koniKabUser,
        accessToken: 'access_demo_koni_kab',
        refreshToken: refreshToken,
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
    return const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
  }
}

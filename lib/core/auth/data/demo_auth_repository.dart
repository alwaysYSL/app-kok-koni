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
    districtId: 'garut_kota',
    districtName: 'Kecamatan Garut Kota',
    permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
  );

  static final _tarogongKidulUser = UserPrincipal(
    id: 'usr-tarogong-kidul-002',
    skNumber: 'DEMO-002',
    fullName: 'Pak Cecep',
    roleTitle: 'Koordinator Kecamatan',
    districtId: 'tarogong_kidul',
    districtName: 'Kecamatan Tarogong Kidul',
    permissions: {'sports:read', 'clubs:read', 'members:read'},
  );

  static final _koniKabUser = UserPrincipal(
    id: 'usr-koni-kab-003',
    skNumber: 'DEMO-003',
    fullName: 'Ibu Rina',
    roleTitle: 'Tim Verifikator',
    districtId: 'koni_kab',
    districtName: 'KONI Kabupaten Garut',
    permissions: {'sports:read', 'clubs:read', 'members:read', 'documents:verify'},
  );

  DemoAuthRepository({
    AuthTokenStorage? storage,
    AuthTokenStorage? tokenStorage,
    this.skStore,
    this.simulateLatency = true,
  }) : tokenStorage = (storage ?? tokenStorage ?? (throw ArgumentError('storage or tokenStorage must be provided')));

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
    if (skNumber == 'DEMO-001' && password == 'kokgarut123') {
      matchedUser = _garutKotaUser;
    } else if (skNumber == 'DEMO-002' && password == 'koktarogong123') {
      matchedUser = _tarogongKidulUser;
    } else if (skNumber == 'DEMO-003' && password == 'konigarut123') {
      matchedUser = _koniKabUser;
    }

    if (matchedUser == null) {
      return const AuthResult.failed(InvalidCredentialsFailure());
    }

    final isGarutKota = matchedUser.id == 'usr_garut_kota' ||
        matchedUser.id == 'usr-garut-kota-001' ||
        matchedUser.districtId == 'garut_kota';

    return AuthResult.success(
      user: matchedUser,
      accessToken: isGarutKota
          ? 'access_demo_garut_kota'
          : 'access_demo_tarogong_kidul',
      refreshToken: staySignedIn
          ? (isGarutKota
              ? 'token_usr_garut_kota'
              : 'token_usr_tarogong_kidul')
          : null,
    );
  }

  @override
  Future<AuthResult> restoreSession() async {
    await _maybeDelay();
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return const AuthResult.failed(
        SessionExpiredFailure('Tidak ada sesi yang tersimpan di perangkat ini.'),
      );
    }

    if (refreshToken == 'token_usr_garut_kota') {
      return AuthResult.success(
        user: _garutKotaUser,
        accessToken: 'access_demo_garut_kota',
        refreshToken: refreshToken,
      );
    } else if (refreshToken == 'token_usr_tarogong_kidul') {
      return AuthResult.success(
        user: _tarogongKidulUser,
        accessToken: 'access_demo_tarogong_kidul',
        refreshToken: refreshToken,
      );
    }

    return const AuthResult.failed(
      SessionExpiredFailure('Sesi Anda tidak valid atau telah kedaluwarsa.'),
    );
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession();
  }

  @override
  Future<void> logout() async {
    await _maybeDelay();
    await tokenStorage.clear();
  }
}

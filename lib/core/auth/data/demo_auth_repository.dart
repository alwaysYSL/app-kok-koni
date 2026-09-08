import 'dart:async';
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';
import 'auth_repository.dart';
import 'auth_token_storage.dart';
import 'remembered_sk_store.dart';

class DemoAuthRepository implements AuthRepository {
  final AuthTokenStorage tokenStorage;
  final RememberedSkStore skStore;
  final bool simulateLatency;

  static const _garutKotaUser = UserPrincipal(
    id: 'usr-garut-kota-001',
    skNumber: 'DEMO-001',
    name: 'Pak Asep',
    role: 'Koordinator Kecamatan',
    districtId: 'garut_kota',
    districtName: 'Kecamatan Garut Kota',
    permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
  );

  static const _tarogongKidulUser = UserPrincipal(
    id: 'usr-tarogong-kidul-002',
    skNumber: 'DEMO-002',
    name: 'Pak Cecep',
    role: 'Koordinator Kecamatan',
    districtId: 'tarogong_kidul',
    districtName: 'Kecamatan Tarogong Kidul',
    permissions: {'sports:read', 'clubs:read', 'members:read'},
  );

  static const _koniKabUser = UserPrincipal(
    id: 'usr-koni-kab-003',
    skNumber: 'DEMO-003',
    name: 'Ibu Rina',
    role: 'Tim Verifikator',
    districtId: 'koni_kab',
    districtName: 'KONI Kabupaten Garut',
    permissions: {'sports:read', 'clubs:read', 'members:read', 'documents:verify'},
  );

  DemoAuthRepository({
    required this.tokenStorage,
    required this.skStore,
    this.simulateLatency = true,
  });

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

    if (staySignedIn) {
      await tokenStorage.saveRefreshToken('token_${matchedUser.id}');
    } else {
      await tokenStorage.clear();
    }

    return AuthResult.success(
      user: matchedUser,
      accessToken: 'demo_access_token_${matchedUser.id}',
    );
  }

  @override
  Future<AuthResult> restoreSession() async {
    await _maybeDelay();
    final token = await tokenStorage.readRefreshToken();
    if (token == null) {
      return const AuthResult.failed(
        SessionExpiredFailure('Tidak ada sesi tersimpan.'),
      );
    }

    if (token.contains('tarogong')) {
      return const AuthResult.success(
        user: _tarogongKidulUser,
        accessToken: 'restored_token_tarogong',
      );
    } else if (token.contains('koni')) {
      return const AuthResult.success(
        user: _koniKabUser,
        accessToken: 'restored_token_koni',
      );
    } else {
      return const AuthResult.success(
        user: _garutKotaUser,
        accessToken: 'restored_token_garut_kota',
      );
    }
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

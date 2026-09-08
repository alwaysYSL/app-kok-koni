import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthTokenStorage {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  static const String _refreshTokenKey = 'v1_kok_refresh_token';

  final FlutterSecureStorage _storage;

  SecureAuthTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {}
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageException implements Exception {
  final String message;
  final Object? cause;

  const StorageException(this.message, [this.cause]);

  @override
  String toString() => cause != null ? '$message (Penyebab: $cause)' : message;
}

abstract class AuthTokenStorage {
  Future<String?> getRefreshToken() => readRefreshToken();
  Future<String?> readRefreshToken() => getRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  static const _keyRefreshToken = 'v1_kok_refresh_token';
  final FlutterSecureStorage _storage;

  const SecureAuthTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      throw StorageException('Gagal mengakses penyimpanan kredensial aman.', e);
    }
  }

  @override
  Future<String?> readRefreshToken() => getRefreshToken();

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      throw StorageException('Gagal menyimpan token ke penyimpanan aman.', e);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _keyRefreshToken);
    } catch (e) {
      throw StorageException('Gagal membersihkan token penyimpanan aman.', e);
    }
  }
}

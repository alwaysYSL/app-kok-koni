// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'secure_key_val_store.dart';

export 'secure_key_val_store.dart'
    show StorageException, SecureKeyValStore, FlutterSecureKeyValStore;

final class CorruptCredentialException extends StorageException {
  const CorruptCredentialException(super.message);
}

final class StoredCredential {
  const StoredCredential({
    required this.credentialId,
    required this.refreshToken,
  });

  final String credentialId;
  final String refreshToken;

  factory StoredCredential.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const CorruptCredentialException('Credential harus berupa object');
    }
    final id = value['credentialId'];
    final token = value['refreshToken'];
    if (id is! String || id.trim().isEmpty || id.length > 128) {
      throw const CorruptCredentialException('credentialId tidak valid');
    }
    if (token is! String || token.trim().isEmpty || token.length > 8192) {
      throw const CorruptCredentialException('refreshToken tidak valid');
    }
    return StoredCredential(credentialId: id, refreshToken: token);
  }

  Map<String, dynamic> toJson() => {
    'credentialId': credentialId,
    'refreshToken': refreshToken,
  };

  @override
  String toString() => 'StoredCredential([REDACTED])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredCredential &&
          runtimeType == other.runtimeType &&
          credentialId == other.credentialId &&
          refreshToken == other.refreshToken;

  @override
  int get hashCode => Object.hash(credentialId, refreshToken);
}

abstract interface class AuthTokenStorage {
  Future<StoredCredential?> read();
  Future<void> write(StoredCredential credential);
  Future<bool> clearIfOwnedBy(String credentialId);
  Future<void> forceClearForRecovery();
  Future<void> migrateLegacyStorage();

  // Compatibility getters / methods for intermediate compilation
  Future<String?> readRefreshToken();
  Future<String?> getRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage({
    required SecureKeyValStore store,
    required String key,
    String legacyKey = 'v1_kok_refresh_token',
  }) : _store = store,
       _key = key,
       _legacyKey = legacyKey;

  final SecureKeyValStore _store;
  final String _key;
  final String _legacyKey;

  @override
  Future<StoredCredential?> read() async {
    final raw = await _store.read(key: _key);
    if (raw == null) return null;
    if (raw.trim().isEmpty) {
      throw const CorruptCredentialException('Credential string kosong');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const CorruptCredentialException('Credential bukan JSON valid');
    }
    return StoredCredential.fromJson(decoded);
  }

  @override
  Future<void> write(StoredCredential credential) async {
    final jsonStr = jsonEncode(credential.toJson());
    await _store.write(key: _key, value: jsonStr);
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    final current = await read();
    if (current != null && current.credentialId == credentialId) {
      await _store.delete(key: _key);
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    await _store.delete(key: _key);
  }

  @override
  Future<void> migrateLegacyStorage() async {
    if (await _store.containsKey(key: _legacyKey)) {
      await _store.delete(key: _legacyKey);
    }
  }

  // Compatibility implementations
  @override
  Future<String?> readRefreshToken() async => (await read())?.refreshToken;

  @override
  Future<String?> getRefreshToken() => readRefreshToken();

  @override
  Future<void> saveRefreshToken(String token) =>
      write(StoredCredential(credentialId: 'legacy', refreshToken: token));

  @override
  Future<void> clear() => forceClearForRecovery();
}

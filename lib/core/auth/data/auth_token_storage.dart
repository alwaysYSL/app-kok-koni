// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'secure_key_val_store.dart';

export 'secure_key_val_store.dart'
    show StorageException, SecureKeyValStore, FlutterSecureKeyValStore;

final class CorruptCredentialException extends StorageException {
  const CorruptCredentialException(super.message);
}

final class StoredCredential {
  StoredCredential({required this.credentialId, required this.sessionToken}) {
    if (credentialId.trim().isEmpty || credentialId.length > 128) {
      throw const CorruptCredentialException('credentialId tidak valid');
    }
    if (sessionToken.trim().isEmpty || sessionToken.length > 8192) {
      throw const CorruptCredentialException('sessionToken tidak valid');
    }
  }

  final String credentialId;
  final String sessionToken;

  factory StoredCredential.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const CorruptCredentialException('Credential harus berupa object');
    }
    final id = value['credentialId'];
    final token = value['sessionToken'];
    if (id is! String) {
      throw const CorruptCredentialException('credentialId tidak valid');
    }
    if (token is! String) {
      throw const CorruptCredentialException('sessionToken tidak valid');
    }
    return StoredCredential(credentialId: id, sessionToken: token);
  }

  Map<String, dynamic> toJson() => {
    'credentialId': credentialId,
    'sessionToken': sessionToken,
  };

  @override
  String toString() => 'StoredCredential([REDACTED])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredCredential &&
          runtimeType == other.runtimeType &&
          credentialId == other.credentialId &&
          sessionToken == other.sessionToken;

  @override
  int get hashCode => Object.hash(credentialId, sessionToken);
}

abstract interface class AuthTokenStorage {
  Future<StoredCredential?> read();
  Future<void> write(StoredCredential credential);
  Future<bool> clearIfOwnedBy(String credentialId);
  Future<void> forceClearForRecovery();
  Future<void> migrateLegacyStorage();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage({
    required SecureKeyValStore store,
    required String key,
    List<String> legacyKeys = const [
      'v1_kok_refresh_token',
      'kok.auth.v2.credential',
      'kok.auth.v2.development.credential',
      'kok.auth.v2.staging.credential',
      'kok.auth.v2.production.credential',
    ],
    String? legacyKey,
  }) : _store = store,
       _key = key,
       _legacyKeys = legacyKey != null ? [legacyKey] : legacyKeys;

  final SecureKeyValStore _store;
  final String _key;
  final List<String> _legacyKeys;

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
    for (final legacyKey in _legacyKeys) {
      if (await _store.containsKey(key: legacyKey)) {
        await _store.delete(key: legacyKey);
      }
    }
  }
}

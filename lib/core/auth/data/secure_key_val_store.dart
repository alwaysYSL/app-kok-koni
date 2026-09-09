import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageException implements Exception {
  const StorageException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class SecureKeyValStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<bool> containsKey({required String key});
}

final class FlutterSecureKeyValStore implements SecureKeyValStore {
  const FlutterSecureKeyValStore(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw const StorageException('Gagal membaca secure storage');
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw const StorageException('Gagal menulis secure storage');
    }
  }

  @override
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw const StorageException('Gagal menghapus secure storage');
    }
  }

  @override
  Future<bool> containsKey({required String key}) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      throw const StorageException('Gagal memeriksa secure storage');
    }
  }
}

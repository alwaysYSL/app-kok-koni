import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingFlutterSecureStorage implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('Keystore hardware fault with sensitive token secret_123');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('Keystore write failed with sensitive data secret_123');
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('Keystore delete failed');
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('Keystore containsKey failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('Hardware keystore unavailable');
}

class FakeSecureKeyValStore implements SecureKeyValStore {
  final Map<String, String> data = {};
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;
  bool throwOnContainsKey = false;

  @override
  Future<String?> read({required String key}) async {
    if (throwOnRead) {
      throw const StorageException('Gagal membaca secure storage');
    }
    return data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (throwOnWrite) {
      throw const StorageException('Gagal menulis secure storage');
    }
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    if (throwOnDelete) {
      throw const StorageException('Gagal menghapus secure storage');
    }
    data.remove(key);
  }

  @override
  Future<bool> containsKey({required String key}) async {
    if (throwOnContainsKey) {
      throw const StorageException('Gagal memeriksa secure storage');
    }
    return data.containsKey(key);
  }
}

class FailingSharedPreferences implements SharedPreferences {
  FailingSharedPreferences({
    this.failSetString = false,
    this.failRemove = false,
    this.containsKeyResult = true,
  });

  final bool failSetString;
  final bool failRemove;
  final bool containsKeyResult;

  @override
  Future<bool> setString(String key, String value) async {
    if (failSetString) return false;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (failRemove) return false;
    return true;
  }

  @override
  bool containsKey(String key) => containsKeyResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemoryAuthTokenStorage implements AuthTokenStorage {
  StoredCredential? _credential;
  bool shouldThrow = false;

  @override
  Future<StoredCredential?> read() async {
    if (shouldThrow) {
      throw const StorageException('Keystore locked');
    }
    return _credential;
  }

  @override
  Future<void> write(StoredCredential credential) async {
    if (shouldThrow) {
      throw const StorageException('Keystore locked');
    }
    _credential = credential;
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (shouldThrow) {
      throw const StorageException('Keystore locked');
    }
    if (_credential != null && _credential!.credentialId == credentialId) {
      _credential = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    if (shouldThrow) {
      throw const StorageException('Keystore locked');
    }
    _credential = null;
  }

  @override
  Future<void> migrateLegacyStorage() async {
    if (shouldThrow) {
      throw const StorageException('Keystore locked');
    }
  }
}

void main() {
  const testKey = 'kok.auth.v2.test.credential';
  const legacyKey = 'v1_kok_refresh_token';

  group('StorageException & CorruptCredentialException', () {
    test('does not leak token or underlying cause in toString()', () {
      const ex = StorageException('Gagal membaca secure storage');
      expect(ex.toString(), 'Gagal membaca secure storage');
      expect(ex.toString(), isNot(contains('secret')));

      const corrupt = CorruptCredentialException('credentialId tidak valid');
      expect(corrupt, isA<StorageException>());
      expect(corrupt.toString(), 'credentialId tidak valid');
    });
  });

  group('FlutterSecureKeyValStore', () {
    final store = FlutterSecureKeyValStore(FailingFlutterSecureStorage());

    test(
      'read catches platform exceptions and maps to StorageException without leakage',
      () async {
        try {
          await store.read(key: testKey);
          fail('Expected StorageException');
        } on StorageException catch (e) {
          expect(e.message, 'Gagal membaca secure storage');
          expect(e.toString(), isNot(contains('secret_123')));
          expect(e.toString(), isNot(contains('hardware fault')));
        }
      },
    );

    test(
      'write catches platform exceptions and maps to StorageException without leakage',
      () async {
        try {
          await store.write(key: testKey, value: 'sensitive_token');
          fail('Expected StorageException');
        } on StorageException catch (e) {
          expect(e.message, 'Gagal menulis secure storage');
          expect(e.toString(), isNot(contains('secret_123')));
        }
      },
    );

    test(
      'delete catches platform exceptions and maps to StorageException without leakage',
      () async {
        try {
          await store.delete(key: testKey);
          fail('Expected StorageException');
        } on StorageException catch (e) {
          expect(e.message, 'Gagal menghapus secure storage');
        }
      },
    );

    test(
      'containsKey catches platform exceptions and maps to StorageException without leakage',
      () async {
        try {
          await store.containsKey(key: testKey);
          fail('Expected StorageException');
        } on StorageException catch (e) {
          expect(e.message, 'Gagal memeriksa secure storage');
        }
      },
    );
  });

  group('StoredCredential', () {
    test('direct construction rejects invalid IDs and refresh tokens', () {
      for (final id in ['', '   ', 'x' * 129]) {
        expect(
          () => StoredCredential(credentialId: id, refreshToken: 'valid-token'),
          throwsA(isA<CorruptCredentialException>()),
        );
      }
      for (final token in ['', ' \t\n', 'x' * 8193]) {
        expect(
          () => StoredCredential(credentialId: 'valid-id', refreshToken: token),
          throwsA(isA<CorruptCredentialException>()),
        );
      }
    });

    test('direct construction and JSON accept exact maximum lengths', () {
      final credential = StoredCredential(
        credentialId: 'i' * 128,
        refreshToken: 't' * 8192,
      );
      expect(credential.credentialId.length, 128);
      expect(credential.refreshToken.length, 8192);
      expect(StoredCredential.fromJson(credential.toJson()), credential);
    });

    test('redacts toString() completely', () {
      final cred = StoredCredential(
        credentialId: 'user-cred-id-123',
        refreshToken: 'super_secret_refresh_token_xyz',
      );
      expect(cred.toString(), 'StoredCredential([REDACTED])');
      expect(cred.toString(), isNot(contains('user-cred-id-123')));
      expect(
        cred.toString(),
        isNot(contains('super_secret_refresh_token_xyz')),
      );
    });

    test('toJson produces expected structure', () {
      final cred = StoredCredential(
        credentialId: 'cid-1',
        refreshToken: 'token-1',
      );
      expect(cred.toJson(), {
        'credentialId': 'cid-1',
        'refreshToken': 'token-1',
      });
    });

    test('fromJson parses valid credential', () {
      final cred = StoredCredential.fromJson({
        'credentialId': 'valid-cred-id',
        'refreshToken': 'valid-refresh-token',
      });
      expect(cred.credentialId, 'valid-cred-id');
      expect(cred.refreshToken, 'valid-refresh-token');
    });

    test('fromJson rejects non-map values', () {
      expect(
        () => StoredCredential.fromJson('not_a_map'),
        throwsA(isA<CorruptCredentialException>()),
      );
      expect(
        () => StoredCredential.fromJson(123),
        throwsA(isA<CorruptCredentialException>()),
      );
      expect(
        () => StoredCredential.fromJson([1, 2]),
        throwsA(isA<CorruptCredentialException>()),
      );
    });

    test(
      'fromJson rejects invalid credentialId (empty, whitespace, non-string, >128 chars)',
      () {
        expect(
          () => StoredCredential.fromJson({
            'credentialId': '',
            'refreshToken': 'valid_token',
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
        expect(
          () => StoredCredential.fromJson({
            'credentialId': '   ',
            'refreshToken': 'valid_token',
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
        expect(
          () => StoredCredential.fromJson({
            'credentialId': 123,
            'refreshToken': 'valid_token',
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
        expect(
          () => StoredCredential.fromJson({
            'credentialId': 'a' * 129,
            'refreshToken': 'valid_token',
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
      },
    );

    test(
      'fromJson rejects invalid refreshToken (empty, whitespace, non-string, >8192 chars)',
      () {
        expect(
          () => StoredCredential.fromJson({
            'credentialId': 'valid_id',
            'refreshToken': '',
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
        expect(
          () => StoredCredential.fromJson({
            'credentialId': 'valid_id',
            'refreshToken': '   ',
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
        expect(
          () => StoredCredential.fromJson({
            'credentialId': 'valid_id',
            'refreshToken': 999,
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
        expect(
          () => StoredCredential.fromJson({
            'credentialId': 'valid_id',
            'refreshToken': 't' * 8193,
          }),
          throwsA(isA<CorruptCredentialException>()),
        );
      },
    );
  });

  group('SecureAuthTokenStorage', () {
    late FakeSecureKeyValStore store;
    late SecureAuthTokenStorage storage;

    setUp(() {
      store = FakeSecureKeyValStore();
      storage = SecureAuthTokenStorage(
        store: store,
        key: testKey,
        legacyKey: legacyKey,
      );
    });

    test('read() returns null when key is absent', () async {
      expect(await storage.read(), isNull);
    });

    test(
      'read() throws CorruptCredentialException on empty or whitespace string',
      () async {
        store.data[testKey] = '';
        expect(
          () => storage.read(),
          throwsA(isA<CorruptCredentialException>()),
        );

        store.data[testKey] = '   ';
        expect(
          () => storage.read(),
          throwsA(isA<CorruptCredentialException>()),
        );
      },
    );

    test('read() throws CorruptCredentialException on invalid JSON', () async {
      store.data[testKey] = '{not_valid_json';
      expect(() => storage.read(), throwsA(isA<CorruptCredentialException>()));
    });

    test(
      'read() throws CorruptCredentialException when credential structure is invalid',
      () async {
        store.data[testKey] = jsonEncode({'credentialId': ''});
        expect(
          () => storage.read(),
          throwsA(isA<CorruptCredentialException>()),
        );
      },
    );

    test('read() and write() round-trip preserves stored credential', () async {
      final cred = StoredCredential(
        credentialId: 'cred-pak-asep',
        refreshToken: 'rf-pak-asep-secret',
      );
      await storage.write(cred);

      final readCred = await storage.read();
      expect(readCred, isNotNull);
      expect(readCred!.credentialId, 'cred-pak-asep');
      expect(readCred.refreshToken, 'rf-pak-asep-secret');
    });

    test(
      'read() has no side effects and does not delete or migrate anything',
      () async {
        store.data[legacyKey] = 'old_token';
        store.data[testKey] = jsonEncode({
          'credentialId': 'cred-1',
          'refreshToken': 'tok-1',
        });

        final cred = await storage.read();
        expect(cred?.credentialId, 'cred-1');
        expect(store.data[legacyKey], 'old_token');
      },
    );

    test(
      'fault injection: read throws StorageException when store read fails',
      () async {
        store.throwOnRead = true;
        expect(() => storage.read(), throwsA(isA<StorageException>()));
      },
    );

    test(
      'fault injection: write throws StorageException when store write fails',
      () async {
        store.throwOnWrite = true;
        expect(
          () => storage.write(
            StoredCredential(credentialId: 'cred-1', refreshToken: 'tok-1'),
          ),
          throwsA(isA<StorageException>()),
        );
      },
    );

    test(
      'clearIfOwnedBy returns true and deletes if credentialId matches',
      () async {
        await storage.write(
          StoredCredential(
            credentialId: 'cred-owner-A',
            refreshToken: 'token-A',
          ),
        );
        expect(store.data[testKey], isNotNull);

        final deleted = await storage.clearIfOwnedBy('cred-owner-A');
        expect(deleted, isTrue);
        expect(store.data[testKey], isNull);
      },
    );

    test(
      'clearIfOwnedBy returns false and does not delete if credentialId does not match',
      () async {
        await storage.write(
          StoredCredential(
            credentialId: 'cred-owner-B',
            refreshToken: 'token-B',
          ),
        );
        expect(store.data[testKey], isNotNull);

        final deleted = await storage.clearIfOwnedBy('cred-owner-A');
        expect(deleted, isFalse);
        expect(store.data[testKey], isNotNull);
      },
    );

    test('clearIfOwnedBy returns false if store is empty', () async {
      final deleted = await storage.clearIfOwnedBy('cred-owner-A');
      expect(deleted, isFalse);
    });

    test('forceClearForRecovery unconditionally deletes key', () async {
      await storage.write(
        StoredCredential(credentialId: 'cred-any', refreshToken: 'token-any'),
      );
      expect(store.data[testKey], isNotNull);

      await storage.forceClearForRecovery();
      expect(store.data[testKey], isNull);
    });

    test(
      'migrateLegacyStorage deletes legacy key and never writes to new key or restores',
      () async {
        store.data[legacyKey] = 'legacy_refresh_token_data';
        expect(store.data[testKey], isNull);

        await storage.migrateLegacyStorage();

        expect(store.data[legacyKey], isNull);
        expect(store.data[testKey], isNull);
      },
    );

    test('migrateLegacyStorage does nothing if legacy key absent', () async {
      await storage.migrateLegacyStorage();
      expect(store.data[legacyKey], isNull);
    });
  });

  group('RememberedSkStore', () {
    const rememberedSkKey = 'kok.auth.v2.test.remembered_sk';

    test('menyimpan dan membaca nomor SK dari SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedSkStore(prefs: prefs, key: rememberedSkKey);

      expect(await store.readSk(), isNull);
      await store.saveSk('DEMO-001');
      expect(await store.readSk(), 'DEMO-001');
      await store.clear();
      expect(await store.readSk(), isNull);
    });

    test(
      'saveSk throws MetadataStorageException when setString fails',
      () async {
        final store = RememberedSkStore(
          prefs: FailingSharedPreferences(failSetString: true),
          key: rememberedSkKey,
        );
        expect(
          () => store.saveSk('DEMO-001'),
          throwsA(isA<MetadataStorageException>()),
        );
      },
    );

    test(
      'clear throws MetadataStorageException when remove fails and key still exists',
      () async {
        final store = RememberedSkStore(
          prefs: FailingSharedPreferences(
            failRemove: true,
            containsKeyResult: true,
          ),
          key: rememberedSkKey,
        );
        expect(() => store.clear(), throwsA(isA<MetadataStorageException>()));
      },
    );
  });

  group('UserPrincipal & AuthState', () {
    test('UserPrincipal memeriksa permissions dengan benar', () {
      final user = UserPrincipal(
        id: 'usr-1',
        skNumber: 'DEMO-001',
        fullName: 'Pak Asep',
        roleTitle: 'Koordinator',
        scope: const AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        ),
        permissions: {'sports:read', 'reports:export'},
      );

      expect(user.hasPermission('sports:read'), isTrue);
      expect(user.hasPermission('clubs:delete'), isFalse);
    });

    test('AuthState instansiasi berjalan semestinya', () {
      const state = AuthBootstrapping();
      expect(state, isA<AuthState>());
    });
  });
}

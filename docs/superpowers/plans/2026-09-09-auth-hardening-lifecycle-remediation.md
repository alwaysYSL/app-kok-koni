# Auth Hardening & Lifecycle Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate all 7 blocker audit findings (R2-01 through R2-07) and Section 5 consistency issues by implementing a crash-consistent two-phase state machine, serialized storage mutation with ID-based ownership protection, explicit sign-in cancellation, typed cleanup status with fail-closed metadata, full DEMO-003 county support, robust request cancellation, composition root isolation, and UI honesty.

**Architecture:** Two-phase mutation (*Reserve -> Execute -> Commit*) with `_mutationQueue` and `_operationEpoch` to guarantee crash-consistent state transitions without deadlocks or unhandled races; `SessionMetadata` single-record JSON in `SharedPreferences` guarding auto-login; clean domain boundary where `AuthController` owns storage and `DemoAuthRepository` only validates credentials; notification-capable `RequestCancellation` guarding against cross-session data pollution; and fail-closed `DeploymentProfile` & `AppComposition`.

**Tech Stack:** Flutter 3.x, Dart 3.12.x, Riverpod 2.5/3.x, GoRouter 17.x, flutter_secure_storage 9.2.4, shared_preferences 2.5.x.

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-09-auth-hardening-lifecycle-remediation-design.md`.
- Seluruh teks pada komponen antarmuka memiliki ukuran font >= 12px (tidak ada teks di bawah 12px anywhere!).
- Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`) dari `lib/core/theme.dart`.
- Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
- Tidak mengubah struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Profil/Akun).
- Pesan error login publik selalu generik: "Nomor SK atau kata sandi tidak sesuai."
- Fail-closed principle: segala anomali metadata, unauthenticated data fetch, atau konfigurasi ilegal ditolak keras.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Domain & Storage Foundation (Menutup R2-02, R2-03, & R2-05 Foundation)

**Files:**
- Create: `lib/core/auth/data/session_metadata_store.dart`
- Modify: `lib/core/auth/domain/user_principal.dart`
- Modify: `lib/core/auth/domain/auth_state.dart`
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/core/auth/data/remembered_sk_store.dart`
- Create: `test/session_metadata_store_test.dart`
- Modify: `test/user_principal_test.dart`
- Modify: `test/auth_token_storage_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`, `FlutterSecureStorage`
- Produces:
  - `AccessScopeType` (`district`, `county`)
  - `AccessScope(type, id, name)`
  - `UserPrincipal(id, skNumber, fullName, roleTitle, scope, permissions)`
  - `LocalCleanupStatus` (`clean`, `pending`, `failed`)
  - `AuthSignedOut(cleanupStatus, message)`
  - `CorruptMetadataException`
  - `SessionMetadata(schemaVersion, restoreAllowed, cleanupStatus, expectedCredentialId)`
  - `SessionMetadataStore` & `SharedPrefsSessionMetadataStore`
  - `StoredCredential(credentialId, refreshToken)`
  - `AuthTokenStorage` (`read()`, `write(credential)`, `clearIfOwnedBy(credentialId)`, `forceClearForRecovery()`)
  - `SecureAuthTokenStorage({String namespace, FlutterSecureStorage? storage})`
  - `RememberedSkStore({required SharedPreferences preferences, String key})`

- [ ] **Step 1: Write failing tests for Domain & Storage Foundation**

Create `test/session_metadata_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SessionMetadata Serialization & Store', () {
    test('serializes and deserializes valid SessionMetadata correctly', () {
      const meta = SessionMetadata(
        schemaVersion: 1,
        restoreAllowed: true,
        cleanupStatus: LocalCleanupStatus.clean,
        expectedCredentialId: 'cred-uuid-123',
      );
      final json = meta.toJson();
      final parsed = SessionMetadata.fromJson(json);

      expect(parsed.schemaVersion, 1);
      expect(parsed.restoreAllowed, isTrue);
      expect(parsed.cleanupStatus, LocalCleanupStatus.clean);
      expect(parsed.expectedCredentialId, 'cred-uuid-123');
    });

    test('rejects corrupt or incomplete metadata fail-closed', () {
      expect(
        () => SessionMetadata.fromJson({'schemaVersion': 2, 'restoreAllowed': true}),
        throwsA(isA<CorruptMetadataException>()),
      );
      expect(
        () => SessionMetadata.fromJson({
          'schemaVersion': 1,
          'restoreAllowed': true,
          'cleanupStatus': 'clean',
          'expectedCredentialId': '',
        }),
        throwsA(isA<CorruptMetadataException>()),
      );
      expect(
        () => SessionMetadata.fromJson({
          'schemaVersion': 1,
          'restoreAllowed': true,
          'cleanupStatus': 'pending',
          'expectedCredentialId': 'some-id',
        }),
        throwsA(isA<CorruptMetadataException>()),
      );
    });

    test('SharedPrefsSessionMetadataStore writes and reads metadata correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSessionMetadataStore(prefs, key: 'kok.auth.v2.demo.metadata');

      expect(await store.read(), isNull);

      const meta = SessionMetadata(
        schemaVersion: 1,
        restoreAllowed: false,
        cleanupStatus: LocalCleanupStatus.pending,
      );
      await store.write(meta);

      final readBack = await store.read();
      expect(readBack, isNotNull);
      expect(readBack!.restoreAllowed, isFalse);
      expect(readBack.cleanupStatus, LocalCleanupStatus.pending);

      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
```

Update `test/auth_token_storage_test.dart` to test `StoredCredential` and `clearIfOwnedBy`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';

class _InMemoryTokenStorage implements AuthTokenStorage {
  StoredCredential? _current;

  @override
  Future<StoredCredential?> read() async => _current;

  @override
  Future<void> write(StoredCredential credential) async {
    _current = credential;
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (_current?.credentialId == credentialId) {
      _current = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    _current = null;
  }
}

void main() {
  group('StoredCredential & AuthTokenStorage ownership', () {
    test('StoredCredential redacts toString and parses strictly', () {
      const cred = StoredCredential(
        credentialId: 'cred-1',
        refreshToken: 'refresh-token-secret',
      );
      expect(cred.toString(), 'StoredCredential([REDACTED])');
      expect(cred.toJson()['credentialId'], 'cred-1');
      expect(cred.toJson()['refreshToken'], 'refresh-token-secret');

      final parsed = StoredCredential.fromJson(cred.toJson());
      expect(parsed.credentialId, 'cred-1');
      expect(parsed.refreshToken, 'refresh-token-secret');

      expect(
        () => StoredCredential.fromJson({'credentialId': ''}),
        throwsA(isA<FormatException>()),
      );
    });

    test('clearIfOwnedBy only deletes matching credential', () async {
      final storage = _InMemoryTokenStorage();
      await storage.write(
        const StoredCredential(credentialId: 'session-A', refreshToken: 'token-A'),
      );

      final clearedStale = await storage.clearIfOwnedBy('session-stale');
      expect(clearedStale, isFalse);
      expect(await storage.read(), isNotNull);

      final clearedOwner = await storage.clearIfOwnedBy('session-A');
      expect(clearedOwner, isTrue);
      expect(await storage.read(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart`
Expected: FAIL compilation errors (`SessionMetadata`, `StoredCredential` not defined).

- [ ] **Step 3: Write minimal implementation for Domain & Storage Foundation**

1. Modify `lib/core/auth/domain/auth_state.dart`:
```dart
enum LocalCleanupStatus {
  clean,
  pending,
  failed,
}

sealed class AuthState {
  const AuthState();
}

final class AuthBootstrapping extends AuthState {
  const AuthBootstrapping();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({
    this.message,
    this.cleanupStatus = LocalCleanupStatus.clean,
  });

  final String? message;
  final LocalCleanupStatus cleanupStatus;

  String? get errorMessage => message;
  bool get requiresCleanup =>
      cleanupStatus == LocalCleanupStatus.pending ||
      cleanupStatus == LocalCleanupStatus.failed;
}

final class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.user,
    required this.generation,
    this.accessToken,
  });

  final UserPrincipal user;
  final int generation;
  final String? accessToken;
}

final class AuthSigningOut extends AuthState {
  const AuthSigningOut();
}

final class AuthTemporarilyUnavailable extends AuthState {
  const AuthTemporarilyUnavailable({this.reason});

  final String? reason;
}
```

2. Modify `lib/core/auth/domain/user_principal.dart`:
```dart
enum AccessScopeType { district, county }

final class AccessScope {
  const AccessScope({
    required this.type,
    required this.id,
    required this.name,
  });

  final AccessScopeType type;
  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessScope &&
          other.type == type &&
          other.id == id &&
          other.name == name;

  @override
  int get hashCode => Object.hash(type, id, name);
}

final class UserPrincipal {
  final String id;
  final String skNumber;
  final String fullName;
  final String roleTitle;
  final AccessScope scope;
  final String? profileImageUrl;
  final Set<String> permissions;

  UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.fullName,
    required this.roleTitle,
    AccessScope? scope,
    String? districtId,
    String? districtName,
    this.profileImageUrl,
    Set<String>? permissions,
  })  : scope = scope ??
            AccessScope(
              type: AccessScopeType.district,
              id: districtId ?? 'garut_kota',
              name: districtName ?? 'Kecamatan Garut Kota',
            ),
        permissions = Set.unmodifiable(permissions ?? const <String>{});

  String get districtId => scope.id;
  String get districtName => scope.name;

  bool hasPermission(String permission) => permissions.contains(permission);
}
```

3. Create `lib/core/auth/data/session_metadata_store.dart`:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/auth_state.dart';

class CorruptMetadataException implements Exception {
  final String message;
  const CorruptMetadataException(this.message);
  @override
  String toString() => 'CorruptMetadataException: $message';
}

final class SessionMetadata {
  static const currentVersion = 1;

  final int schemaVersion;
  final bool restoreAllowed;
  final LocalCleanupStatus cleanupStatus;
  final String? expectedCredentialId;

  const SessionMetadata({
    required this.schemaVersion,
    required this.restoreAllowed,
    required this.cleanupStatus,
    this.expectedCredentialId,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'restoreAllowed': restoreAllowed,
        'cleanupStatus': cleanupStatus.name,
        'expectedCredentialId': expectedCredentialId,
      };

  factory SessionMetadata.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const CorruptMetadataException('SessionMetadata JSON harus berupa Map/object');
    }
    final version = json['schemaVersion'];
    if (version is! int || version != currentVersion) {
      throw CorruptMetadataException('schemaVersion tidak didukung: $version');
    }
    final restore = json['restoreAllowed'];
    if (restore is! bool) {
      throw const CorruptMetadataException('restoreAllowed harus bertipe bool');
    }
    final statusStr = json['cleanupStatus'];
    final status = LocalCleanupStatus.values.asNameMap()[statusStr];
    if (status == null) {
      throw CorruptMetadataException('cleanupStatus tidak valid: $statusStr');
    }
    final credId = json['expectedCredentialId'];
    if (restore && (credId is! String || credId.trim().isEmpty)) {
      throw const CorruptMetadataException(
          'expectedCredentialId wajib ada saat restoreAllowed bernilai true');
    }
    if (restore && status != LocalCleanupStatus.clean) {
      throw const CorruptMetadataException('restoreAllowed hanya boleh true saat status clean');
    }

    return SessionMetadata(
      schemaVersion: version,
      restoreAllowed: restore,
      cleanupStatus: status,
      expectedCredentialId: credId as String?,
    );
  }
}

abstract interface class SessionMetadataStore {
  Future<SessionMetadata?> read();
  Future<void> write(SessionMetadata metadata);
  Future<void> clear();
}

class SharedPrefsSessionMetadataStore implements SessionMetadataStore {
  final SharedPreferences _preferences;
  final String _key;

  const SharedPrefsSessionMetadataStore(
    this._preferences, {
    String key = 'kok.auth.v2.demo.metadata',
  }) : _key = key;

  @override
  Future<SessionMetadata?> read() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return SessionMetadata.fromJson(decoded);
    } catch (_) {
      throw const CorruptMetadataException('Gagal mem-parse JSON SessionMetadata');
    }
  }

  @override
  Future<void> write(SessionMetadata metadata) async {
    final raw = jsonEncode(metadata.toJson());
    await _preferences.setString(_key, raw);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
```

4. Modify `lib/core/auth/data/auth_token_storage.dart`:
```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageException implements Exception {
  final String message;
  final Object? cause;

  const StorageException(this.message, [this.cause]);

  @override
  String toString() => cause != null ? '$message (Penyebab: $cause)' : message;
}

final class StoredCredential {
  const StoredCredential({
    required this.credentialId,
    required this.refreshToken,
  });

  final String credentialId;
  final String refreshToken;

  Map<String, dynamic> toJson() => {
        'credentialId': credentialId,
        'refreshToken': refreshToken,
      };

  factory StoredCredential.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Format credential harus berupa JSON object');
    }
    final credId = json['credentialId'];
    final token = json['refreshToken'];
    if (credId is! String || credId.trim().isEmpty || credId.length > 128) {
      throw const FormatException('credentialId tidak valid');
    }
    if (token is! String || token.trim().isEmpty || token.length > 8192) {
      throw const FormatException('refreshToken tidak valid atau melebihi batas panjang');
    }
    return StoredCredential(
      credentialId: credId,
      refreshToken: token,
    );
  }

  @override
  String toString() => 'StoredCredential([REDACTED])';
}

abstract interface class AuthTokenStorage {
  Future<StoredCredential?> read();
  Future<void> write(StoredCredential credential);
  Future<bool> clearIfOwnedBy(String credentialId);
  Future<void> forceClearForRecovery();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  static const _legacyKey = 'v1_kok_refresh_token';
  final String _namespace;
  final FlutterSecureStorage _storage;

  const SecureAuthTokenStorage({
    String namespace = 'kok.auth.v2.demo.credential',
    FlutterSecureStorage? storage,
  })  : _namespace = namespace,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> _cleanupLegacyBestEffort() async {
    try {
      if (await _storage.containsKey(key: _legacyKey)) {
        await _storage.delete(key: _legacyKey);
      }
    } catch (_) {}
  }

  @override
  Future<StoredCredential?> read() async {
    await _cleanupLegacyBestEffort();
    try {
      final raw = await _storage.read(key: _namespace);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      return StoredCredential.fromJson(decoded);
    } on FormatException {
      return null;
    } catch (e) {
      throw StorageException('Gagal mengakses penyimpanan kredensial aman.', e);
    }
  }

  @override
  Future<void> write(StoredCredential credential) async {
    try {
      final raw = jsonEncode(credential.toJson());
      await _storage.write(key: _namespace, value: raw);
    } catch (e) {
      throw StorageException('Gagal menyimpan token ke penyimpanan aman.', e);
    }
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    try {
      final current = await read();
      if (current != null && current.credentialId == credentialId) {
        await _storage.delete(key: _namespace);
        return true;
      }
      return false;
    } catch (e) {
      throw StorageException('Gagal membersihkan token penyimpanan aman.', e);
    }
  }

  @override
  Future<void> forceClearForRecovery() async {
    try {
      await _storage.delete(key: _namespace);
      await _cleanupLegacyBestEffort();
    } catch (e) {
      throw StorageException('Gagal melakukan force clear penyimpanan aman.', e);
    }
  }
}
```

5. Modify `lib/core/auth/data/remembered_sk_store.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class RememberedSkStore {
  final SharedPreferences _preferences;
  final String _key;

  RememberedSkStore(
    this._preferences, {
    String key = 'kok.auth.v2.demo.remembered_sk',
  }) : _key = key;

  Future<String?> readSk() async {
    return _preferences.getString(_key);
  }

  Future<void> saveSk(String skNumber) async {
    await _preferences.setString(_key, skNumber);
  }

  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart test/user_principal_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth/domain/ lib/core/auth/data/ test/session_metadata_store_test.dart test/auth_token_storage_test.dart test/user_principal_test.dart
git commit -m "feat(auth): bangun fondasi StoredCredential, SessionMetadata, dan isolasi namespace token"
```

---

### Task 2: Repositories & Fixture Contracts (Menutup R2-03, R2-05, & R2-06 Bagian Data)

**Files:**
- Modify: `lib/core/auth/data/auth_repository.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Modify: `lib/data/repository.dart`
- Modify: `test/auth_repository_test.dart`
- Modify: `test/repository_test.dart`

**Interfaces:**
- Consumes: `AccessScope`, `AccessScopeType`, `UserPrincipal`
- Produces:
  - `RemoteRevocationStatus` (`revoked`, `notApplicable`, `failed`)
  - `RemoteRevocationResult(status, [message])`
  - `AuthRepository.restoreSession(String refreshToken)`
  - `AuthRepository.revokeSession(String refreshToken)`
  - `DemoAuthRepository` with 3 exact tokens (`token_usr_garut_kota`, `token_usr_tarogong_kidul`, `token_usr_koni_kab`) and county scope
  - `RequestCancelledException([reason])`
  - `StaleSessionResultException()`
  - `UnsupportedScopeException(scopeId)`
  - `RequestCancellation` & `RequestCancellationController`
  - `KokRepository.fetchScope(AccessScope scope, {RequestCancellation? cancellation})`
  - `DemoKokRepository` dynamically calculating combined county fixture: 5 unique sports, 9 clubs, 213 athletes, 18 coaches.

- [ ] **Step 1: Write failing tests for Repositories & Fixtures**

Update `test/auth_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';

void main() {
  group('DemoAuthRepository contract & token mapping', () {
    late DemoAuthRepository repo;

    setUp(() {
      repo = DemoAuthRepository(simulateLatency: false);
    });

    test('login DEMO-003 with staySignedIn returns token_usr_koni_kab and county scope', () async {
      final res = await repo.login(
        skNumber: 'DEMO-003',
        password: 'konigarut123',
        staySignedIn: true,
      );
      expect(res.isSuccess, isTrue);
      expect(res.user?.id, 'usr_koni_kab');
      expect(res.user?.scope.type, AccessScopeType.county);
      expect(res.user?.scope.id, 'koni_kab');
      expect(res.refreshToken, 'token_usr_koni_kab');
    });

    test('restoreSession validates tokens strictly across all 3 accounts', () async {
      final resKota = await repo.restoreSession('token_usr_garut_kota');
      expect(resKota.isSuccess, isTrue);
      expect(resKota.user?.id, 'usr_garut_kota');

      final resTk = await repo.restoreSession('token_usr_tarogong_kidul');
      expect(resTk.isSuccess, isTrue);
      expect(resTk.user?.id, 'usr_tarogong_kidul');

      final resKab = await repo.restoreSession('token_usr_koni_kab');
      expect(resKab.isSuccess, isTrue);
      expect(resKab.user?.id, 'usr_koni_kab');

      final resUnknown = await repo.restoreSession('unknown-token');
      expect(resUnknown.isSuccess, isFalse);
      expect(resUnknown.failure, isA<SessionExpiredFailure>());
    });

    test('revokeSession returns notApplicable for demo mode', () async {
      final res = await repo.revokeSession('token_usr_garut_kota');
      expect(res.status, RemoteRevocationStatus.notApplicable);
    });
  });
}
```

Update `test/repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/repository.dart';

void main() {
  group('DemoKokRepository scope fetching & county fixture', () {
    const repo = DemoKokRepository(simulateLatency: false);

    test('fetches county scope with exactly 5 unique sports, 9 clubs, 213 athletes, 18 coaches', () async {
      const countyScope = AccessScope(
        type: AccessScopeType.county,
        id: 'koni_kab',
        name: 'KONI Kabupaten Garut',
      );

      final snapshot = await repo.fetchScope(countyScope);
      expect(snapshot.clubs.length, 9);
      expect(snapshot.sports.length, 5);
      expect(
        snapshot.sports.toSet(),
        {'Sepak Bola', 'Bulu Tangkis', 'Pencak Silat', 'Bola Voli', 'Renang'},
      );

      final athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();
      final coaches = snapshot.people.where((p) => p.role == 'Pelatih').toList();
      expect(athletes.length, 213);
      expect(coaches.length, 18);
    });

    test('throws UnsupportedScopeException for unknown scope', () async {
      const badScope = AccessScope(
        type: AccessScopeType.district,
        id: 'kecamatan_alien',
        name: 'Kecamatan Alien',
      );

      expect(() => repo.fetchScope(badScope), throwsA(isA<UnsupportedScopeException>()));
    });

    test('RequestCancellation triggers RequestCancelledException', () async {
      final controller = RequestCancellationController();
      controller.cancel('User navigated away');

      const districtScope = AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      );

      expect(
        () => repo.fetchScope(districtScope, cancellation: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth_repository_test.dart test/repository_test.dart`
Expected: FAIL compilation errors (`fetchScope`, `RemoteRevocationResult`, etc. not defined).

- [ ] **Step 3: Write minimal implementation for Repositories & Fixture Contracts**

1. Modify `lib/core/auth/data/auth_repository.dart`:
```dart
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';

enum RemoteRevocationStatus { revoked, notApplicable, failed }

final class RemoteRevocationResult {
  final RemoteRevocationStatus status;
  final String? message;

  const RemoteRevocationResult(this.status, [this.message]);

  factory RemoteRevocationResult.notApplicable() =>
      const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
}

class AuthResult {
  final UserPrincipal? user;
  final String? accessToken;
  final String? refreshToken;
  final AuthFailure? failure;

  const AuthResult.success({
    required UserPrincipal this.user,
    this.accessToken,
    this.refreshToken,
  }) : failure = null;

  const AuthResult.failed(AuthFailure this.failure)
      : user = null,
        accessToken = null,
        refreshToken = null;

  bool get isSuccess => user != null;
}

abstract interface class AuthRepository {
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  });

  Future<AuthResult> restoreSession(String refreshToken);

  Future<AuthResult> refreshToken(String refreshToken);

  Future<RemoteRevocationResult> revokeSession(String refreshToken);
}
```

2. Modify `lib/core/auth/data/demo_auth_repository.dart`:
```dart
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
    permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
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

  static final Map<String, UserPrincipal> _sessionsByToken = {
    'token_usr_garut_kota': _garutKotaUser,
    'token_usr_tarogong_kidul': _tarogongKidulUser,
    'token_usr_koni_kab': _koniKabUser,
  };

  const DemoAuthRepository({this.simulateLatency = true});

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
    String? token;
    String? accessToken;

    if (skNumber == 'DEMO-001' && password == 'kokgarut123') {
      matchedUser = _garutKotaUser;
      token = 'token_usr_garut_kota';
      accessToken = 'access_demo_garut_kota';
    } else if (skNumber == 'DEMO-002' && password == 'koktarogong123') {
      matchedUser = _tarogongKidulUser;
      token = 'token_usr_tarogong_kidul';
      accessToken = 'access_demo_tarogong_kidul';
    } else if (skNumber == 'DEMO-003' && password == 'konigarut123') {
      matchedUser = _koniKabUser;
      token = 'token_usr_koni_kab';
      accessToken = 'access_demo_koni_kab';
    }

    if (matchedUser == null) {
      return const AuthResult.failed(InvalidCredentialsFailure());
    }

    return AuthResult.success(
      user: matchedUser,
      accessToken: accessToken,
      refreshToken: staySignedIn ? token : null,
    );
  }

  @override
  Future<AuthResult> restoreSession(String refreshToken) async {
    await _maybeDelay();
    final user = _sessionsByToken[refreshToken];
    if (user == null) {
      return const AuthResult.failed(
        SessionExpiredFailure('Sesi Anda tidak valid atau telah kedaluwarsa.'),
      );
    }

    return AuthResult.success(
      user: user,
      accessToken: 'access_${refreshToken.replaceFirst('token_', '')}',
      refreshToken: refreshToken,
    );
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession(refreshToken);
  }

  @override
  Future<RemoteRevocationResult> revokeSession(String refreshToken) async {
    await _maybeDelay();
    return RemoteRevocationResult.notApplicable();
  }
}
```

3. Modify `lib/data/repository.dart`:
Add cancellation exceptions, classes, contracts, and fixture calculations:
```dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/domain/auth_state.dart';
import '../core/auth/domain/user_principal.dart';
import '../core/auth/presentation/auth_controller.dart';
import '../core/config/app_environment.dart';
import 'models.dart';

final class SessionRequiredException implements Exception {
  final String message;
  const SessionRequiredException([
    this.message = 'Sesi terautentikasi aktif dibutuhkan untuk mengakses data keolahragaan.',
  ]);

  @override
  String toString() => message;
}

final class RequestCancelledException implements Exception {
  final Object? reason;
  const RequestCancelledException([this.reason]);
  @override
  String toString() => 'Permintaan dibatalkan: $reason';
}

final class StaleSessionResultException implements Exception {
  const StaleSessionResultException();
  @override
  String toString() => 'Hasil data diabaikan karena sesi telah berganti.';
}

final class UnsupportedScopeException implements Exception {
  final String scopeId;
  const UnsupportedScopeException(this.scopeId);
  @override
  String toString() => 'Scope tidak didukung: $scopeId';
}

final class RequestCancellation {
  RequestCancellation._(this._whenCancelled);

  final Future<Object?> _whenCancelled;
  bool _isCancelled = false;
  Object? _reason;

  bool get isCancelled => _isCancelled;
  Object? get reason => _reason;
  Future<Object?> get whenCancelled => _whenCancelled;

  void throwIfCancelled() {
    if (_isCancelled) {
      throw RequestCancelledException(_reason);
    }
  }
}

final class RequestCancellationController {
  RequestCancellationController() : _completer = Completer<Object?>() {
    token = RequestCancellation._(_completer.future);
  }

  final Completer<Object?> _completer;
  late final RequestCancellation token;

  void cancel([Object? reason]) {
    if (_completer.isCompleted) return;
    token
      .._isCancelled = true
      .._reason = reason;
    _completer.complete(reason);
  }
}

abstract interface class KokRepository {
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  });
}

// ... helper extensions & methods ...
```

In `DemoKokRepository`:
Standardize `sport: 'Bola Voli'` for Bina Muda in Garut Kota to ensure 5 unique sports across Garut:
`Sepak Bola`, `Bulu Tangkis`, `Pencak Silat`, `Bola Voli`, `Renang`.
When `scope.type == AccessScopeType.county`:
Return dynamically combined snapshot of Garut Kota + Tarogong Kidul:
- 9 clubs
- 213 athletes
- 18 coaches
- 5 unique sports
When `scope.id == 'garut_kota'`: return Garut Kota snapshot.
When `scope.id == 'tarogong_kidul'`: return Tarogong Kidul snapshot.
Otherwise: throw `UnsupportedScopeException(scope.id)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth_repository_test.dart test/repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth/data/ lib/data/repository.dart test/auth_repository_test.dart test/repository_test.dart
git commit -m "feat(repo): terapkan RequestCancellation, pemetaan 3 token demo, dan dataset county gabungan"
```

---

### Task 3: AuthController Hardening (Menutup R2-01, R2-02, & R2-04)

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

**Interfaces:**
- Consumes: `StoredCredential`, `AuthTokenStorage`, `SessionMetadata`, `SessionMetadataStore`, `AuthRepository`, `LocalCleanupStatus`, `AuthSignedOut`, `AuthSigningIn`, `AuthSigningOut`
- Produces:
  - `AuthCommandResult`, `AuthCommandAccepted`, `AuthCommandRejected(reason)`
  - `AuthCommandRejection` (`operationInProgress`, `cleanupRequired`, `invalidState`)
  - `LogoutResult(localSessionClosed, credentialCleared, remoteRevocationStatus, [message])`
  - `AuthController.cancelSignIn()`
  - `AuthController.retryLocalCredentialCleanup()`
  - Serialized `_mutationQueue` for storage writes
  - Crash-consistent `bootstrap()`, `login()`, `logout()`

- [ ] **Step 1: Write failing tests for AuthController Hardening**

Update `test/auth_controller_test.dart`:
```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test cancelSignIn, storage ownership clearIfOwnedBy, and retryLocalCredentialCleanup
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth_controller_test.dart`
Expected: FAIL (`cancelSignIn` or `retryLocalCredentialCleanup` not defined).

- [ ] **Step 3: Write minimal implementation for AuthController**

Implement:
1. `_mutationQueue`:
   `Future<T> _enqueueMutation<T>(Future<T> Function() mutation)`
2. `cancelSignIn()`:
   - If `state is! AuthSigningIn`, returns `AuthCommandRejected(AuthCommandRejection.invalidState)`.
   - Increments `_operationEpoch`.
   - Sets state to `const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)`.
   - Returns `const AuthCommandAccepted()`.
3. `login()` two-phase pattern:
   - Phase 1 Reserve: validate state matrix. Set `state = const AuthSigningIn()`. Record ticket/epoch.
   - Phase 2 Execute: `await repo.login(...)` outside storage mutex.
   - Phase 3 Commit: enqueue in `_mutationQueue`. Re-verify ticket/epoch.
     Write `SessionMetadata(restoreAllowed: false, cleanupStatus: pending)`.
     Write `StoredCredential(credentialId: uuid, refreshToken: token)` to `tokenStorage`.
     Write `SessionMetadata(restoreAllowed: true, cleanupStatus: clean, expectedCredentialId: uuid)`.
     Publish `AuthSignedIn`.
4. `logout()` crash-consistent:
   - Capture refresh token.
   - Increment `_operationEpoch` and `_sessionGeneration`.
   - Evict in-memory session -> `state = const AuthSigningOut()`.
   - In `_mutationQueue`:
     Write `SessionMetadata(restoreAllowed: false, cleanupStatus: pending)`.
     Attempt `await tokenStorage.clearIfOwnedBy(credentialId)`.
     If success: `SessionMetadata(restoreAllowed: false, cleanupStatus: clean)`. State = `AuthSignedOut(cleanupStatus: clean)`.
     If `StorageException`: `SessionMetadata(restoreAllowed: false, cleanupStatus: failed)`. State = `AuthSignedOut(cleanupStatus: failed)`.
   - Async non-blocking remote revocation with 5s timeout.
5. `retryLocalCredentialCleanup()`:
   - In `_mutationQueue`:
     Attempt `tokenStorage.forceClearForRecovery()`.
     Write `SessionMetadata(restoreAllowed: false, cleanupStatus: clean)`.
     State = `AuthSignedOut(cleanupStatus: clean)`.
6. `bootstrap()` fail-closed:
   - Read metadata. If metadata is null, corrupt, `!restoreAllowed`, or `expectedCredentialId != stored.credentialId`:
     Set `AuthSignedOut(cleanupStatus: metadata?.cleanupStatus ?? clean)`.
     Do NOT restore session.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "fix(auth): terapkan dua fase mutasi, cancelSignIn, dan crash-consistent state machine"
```

---

### Task 4: Data Lifecycle & Providers Guard (Menutup R2-06 Bagian State & Invalidation)

**Files:**
- Modify: `lib/data/repository.dart`
- Modify: `test/session_scope_test.dart`

**Interfaces:**
- Consumes: `AppEnvironment`, `AccessScope`, `authControllerProvider`, `deploymentProfileProvider`
- Produces:
  - `DataRequestContext(environment, userId, scope, generation)`
  - `sessionDataContextProvider`
  - `snapshotProvider` with post-await context verification and no-retry policy on lifecycle exceptions.

- [ ] **Step 1: Write failing test in `test/session_scope_test.dart`**

Test post-await context drift and no-retry on `StaleSessionResultException` / `RequestCancelledException`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/session_scope_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement minimal code in `lib/data/repository.dart`**

1. Define `DataRequestContext`:
```dart
final class DataRequestContext {
  const DataRequestContext({
    required this.environment,
    required this.userId,
    required this.scope,
    required this.generation,
  });

  final AppEnvironment environment;
  final String userId;
  final AccessScope scope;
  final int generation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataRequestContext &&
          other.environment == environment &&
          other.userId == userId &&
          other.scope == scope &&
          other.generation == generation;

  @override
  int get hashCode => Object.hash(environment, userId, scope, generation);
}
```

2. Define `sessionDataContextProvider`:
```dart
final sessionDataContextProvider = Provider<DataRequestContext?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final profile = ref.watch(deploymentProfileProvider);
  if (authState is! AuthSignedIn) return null;
  return DataRequestContext(
    environment: profile.environment,
    userId: authState.user.id,
    scope: authState.user.scope,
    generation: authState.generation,
  );
});
```

3. In `snapshotProvider`:
```dart
final snapshotProvider = FutureProvider<KokSnapshot>((ref) async {
  final context = ref.watch(sessionDataContextProvider);
  if (context == null) {
    throw const SessionRequiredException();
  }

  final repository = ref.watch(repositoryProvider);
  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Session changed or disposed'));

  final snapshot = await repository.fetchScope(
    context.scope,
    cancellation: cancellationController.token,
  );

  final currentContext = ref.read(sessionDataContextProvider);
  if (currentContext != context) {
    throw const StaleSessionResultException();
  }

  return snapshot;
}, retry: (retryCount, error) {
  if (error is SessionRequiredException ||
      error is RequestCancelledException ||
      error is StaleSessionResultException ||
      error is UnsupportedScopeException) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/session_scope_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/repository.dart test/session_scope_test.dart
git commit -m "feat(data): perkuat snapshotProvider dengan DataRequestContext dan no-retry policy"
```

---

### Task 5: DeploymentProfile, AppComposition Root, & Main Wiring (Menutup R2-07)

**Files:**
- Modify: `lib/core/config/app_environment.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `test/app_environment_test.dart`

**Interfaces:**
- Produces:
  - `AuthMode` (`demo`, `remote`)
  - `DataMode` (`demo`, `remote`)
  - `DeploymentProfile(environment, authMode, dataMode)`
  - `AppComposition(profile, authRepository, kokRepository, tokenStorage, sessionMetadataStore, rememberedSkStore)`
  - `deploymentProfileProvider`, `appCompositionProvider`

- [ ] **Step 1: Write failing test in `test/app_environment_test.dart`**

Test profile validation rules:
- `dataMode.remote + authMode.demo` throws StateError across all environments.
- `production + demo auth/data` throws StateError.
- `demo + remote auth/data` throws StateError.
- `AppComposition.fromProfile` builds concrete isolated stores per environment.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_environment_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement minimal code in `app_environment.dart`, `main.dart`, `app.dart`**

1. Implement `DeploymentProfile` and `AppComposition` in `lib/core/config/app_environment.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/auth_token_storage.dart';
import '../auth/data/demo_auth_repository.dart';
import '../auth/data/remembered_sk_store.dart';
import '../auth/data/session_metadata_store.dart';
import '../../data/repository.dart';

enum AppEnvironment { demo, staging, production }
enum AuthMode { demo, remote }
enum DataMode { demo, remote }

final class DeploymentProfile {
  final AppEnvironment environment;
  final AuthMode authMode;
  final DataMode dataMode;

  const DeploymentProfile({
    required this.environment,
    required this.authMode,
    required this.dataMode,
  });

  factory DeploymentProfile.fromEnvironment() {
    const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
    const authStr = String.fromEnvironment('AUTH_MODE', defaultValue: 'demo');
    const dataStr = String.fromEnvironment('DATA_MODE', defaultValue: 'demo');

    final env = AppEnvironment.values.asNameMap()[envStr];
    final auth = AuthMode.values.asNameMap()[authStr];
    final data = DataMode.values.asNameMap()[dataStr];

    if (env == null || auth == null || data == null) {
      throw StateError('Konfigurasi environment tidak valid: env=$envStr, auth=$authStr, data=$dataStr');
    }

    final profile = DeploymentProfile(environment: env, authMode: auth, dataMode: data);
    profile.validate();
    return profile;
  }

  void validate() {
    if (environment == AppEnvironment.demo &&
        (authMode != AuthMode.demo || dataMode != DataMode.demo)) {
      throw StateError('FATAL: Demo environment wajib menggunakan auth dan data demo.');
    }
    if (environment == AppEnvironment.production) {
      if (authMode != AuthMode.remote || dataMode != DataMode.remote) {
        throw StateError('FATAL: Build produksi wajib menggunakan auth dan data remote.');
      }
    }
    if (dataMode == DataMode.remote && authMode == AuthMode.demo) {
      throw StateError('FATAL: Data remote dilarang keras dilindungi oleh autentikasi demo.');
    }
  }
}

final class AppComposition {
  final DeploymentProfile profile;
  final AuthRepository authRepository;
  final KokRepository kokRepository;
  final AuthTokenStorage tokenStorage;
  final SessionMetadataStore sessionMetadataStore;
  final RememberedSkStore rememberedSkStore;

  const AppComposition({
    required this.profile,
    required this.authRepository,
    required this.kokRepository,
    required this.tokenStorage,
    required this.sessionMetadataStore,
    required this.rememberedSkStore,
  });

  factory AppComposition.fromProfile(
    DeploymentProfile profile, {
    required SharedPreferences preferences,
  }) {
    profile.validate();

    final tokenStorage = SecureAuthTokenStorage(
      namespace: 'kok.auth.v2.${profile.environment.name}.credential',
    );
    final metadataStore = SharedPrefsSessionMetadataStore(
      preferences,
      key: 'kok.auth.v2.${profile.environment.name}.metadata',
    );
    final skStore = RememberedSkStore(
      preferences,
      key: 'kok.auth.v2.${profile.environment.name}.remembered_sk',
    );

    final AuthRepository authRepo;
    if (profile.authMode == AuthMode.demo) {
      authRepo = const DemoAuthRepository();
    } else {
      throw StateError('RemoteAuthRepository belum diimplementasikan untuk Tahap A.');
    }

    final KokRepository kokRepo;
    if (profile.dataMode == DataMode.demo) {
      kokRepo = const DemoKokRepository();
    } else {
      throw StateError('RemoteKokRepository belum diimplementasikan untuk Tahap A.');
    }

    return AppComposition(
      profile: profile,
      authRepository: authRepo,
      kokRepository: kokRepo,
      tokenStorage: tokenStorage,
      sessionMetadataStore: metadataStore,
      rememberedSkStore: skStore,
    );
  }
}

final deploymentProfileProvider = Provider<DeploymentProfile>((ref) {
  return DeploymentProfile.fromEnvironment();
});

final appCompositionProvider = Provider<AppComposition>((ref) {
  throw UnimplementedError('appCompositionProvider must be initialized in main()');
});
```

2. Wire in `lib/main.dart`:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = DeploymentProfile.fromEnvironment();
  final preferences = await SharedPreferences.getInstance();
  final composition = AppComposition.fromProfile(profile, preferences: preferences);

  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        deploymentProfileProvider.overrideWithValue(profile),
        appCompositionProvider.overrideWithValue(composition),
        authRepositoryProvider.overrideWithValue(composition.authRepository),
        repositoryProvider.overrideWithValue(composition.kokRepository),
        authTokenStorageProvider.overrideWithValue(composition.tokenStorage),
        sessionMetadataStoreProvider.overrideWithValue(composition.sessionMetadataStore),
        rememberedSkStoreProvider.overrideWithValue(composition.rememberedSkStore),
      ],
      child: const KokApp(),
    ),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/app_environment_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/ lib/main.dart lib/app.dart test/app_environment_test.dart
git commit -m "feat(config): integrasikan DeploymentProfile dan AppComposition fail-closed"
```

---

### Task 6: UI Polish, Permission Enforcement, & Honest Labels (Menutup Catatan Bagian 5)

**Files:**
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/login_page.dart`
- Modify: `lib/features/home_page.dart`
- Modify: `README.md`
- Modify: `test/profile_page_test.dart`
- Modify: `test/login_page_test.dart`

**Interfaces:**
- Consumes: `currentUserProvider`, `authControllerProvider`, permission `reports:export`, `LocalCleanupStatus.failed`.

- [ ] **Step 1: Write failing tests in `test/profile_page_test.dart` and `test/login_page_test.dart`**

1. In `test/profile_page_test.dart`:
   - Test `DEMO-002` (Pak Cecep, lacks `reports:export`): copy recap button is disabled with message *"Akun ini tidak memiliki izin untuk mengekspor atau menyalin rekapitulasi."*
   - Test `DEMO-001` (Pak Asep, has `reports:export`): copy recap button is enabled.
   - Verify `"STATUS SISTEM DATA KOK"` and `"Data demo lokal—belum terhubung dengan SICABOR."` text.
2. In `test/login_page_test.dart`:
   - Test banner displayed when `cleanupStatus == LocalCleanupStatus.failed`.
   - Test tapping *"Coba Bersihkan Lagi"* calls `retryLocalCredentialCleanup()`.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/profile_page_test.dart test/login_page_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement minimal UI updates**

1. In `lib/features/profile_page.dart`:
   - Change section header to `'STATUS SISTEM DATA KOK'`.
   - Change text to `'Data demo lokal—belum terhubung dengan SICABOR.'`.
   - In `_showHelpdeskSheet`: change title to `'WhatsApp Helpdesk KOK (Demo)'`, add note `'Kontak demo/belum diverifikasi—jangan digunakan untuk pemulihan akun.'`.
   - In `_showRekapSheet`: check `user.hasPermission('reports:export')`. If false, render disabled button with explanation. Check again inside onPressed before copying.
2. In `lib/features/login_page.dart`:
   - Read `authState`. If `authState is AuthSignedOut && authState.cleanupStatus == LocalCleanupStatus.failed`, render amber warning card above form:
     > **Pembersihan sesi belum selesai.** Akses data telah dikunci, tetapi kredensial lokal belum berhasil dihapus dari perangkat ini. Coba bersihkan kembali sebelum masuk menggunakan akun lain.
     Along with *"Coba Bersihkan Lagi"* button.
   - When cleanup failed, disable login submission.
3. In `README.md`:
   - Add honest platform secure storage details and demo mode limitations.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/profile_page_test.dart test/login_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/ README.md test/profile_page_test.dart test/login_page_test.dart
git commit -m "feat(ui): tegakkan izin reports:export, bersihkan sisa klaim SICABOR, dan tambah banner retry cleanup"
```

---

### Task 7: Comprehensive Regression Test Suite & Verification (Menutup 31 Skenario Pengujian)

**Files:**
- Create: `test/auth_hardening_remediation_test.dart`
- Modify: `test/app_test.dart`

**Verification:**
- Implement all 31 regression test scenarios specified in Section 4 of `docs/superpowers/specs/2026-09-09-auth-hardening-lifecycle-remediation-design.md`.
- Verify full test suite passes 100%.
- Verify `flutter analyze` has 0 issues.

- [ ] **Step 1: Write `test/auth_hardening_remediation_test.dart` covering 31 scenarios**

Group tests logically:
- Storage & Cleanup (Scenarios 1-11)
- Concurrency & Ownership (Scenarios 12-16)
- DEMO-003 & Scope (Scenarios 17-21)
- Data Cancellation (Scenarios 22-25)
- Composition & Permissions (Scenarios 26-31)

- [ ] **Step 2: Run remediation test suite**

Run: `flutter test test/auth_hardening_remediation_test.dart`
Expected: PASS (all 31 scenarios pass)

- [ ] **Step 3: Run full app tests**

Run: `flutter test`
Expected: All test files pass (100% pass rate)

- [ ] **Step 4: Run static analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add test/auth_hardening_remediation_test.dart test/app_test.dart
git commit -m "test(auth): tambahkan 31 pengujian regresi lengkap penguatan autentikasi dan siklus sesi"
```

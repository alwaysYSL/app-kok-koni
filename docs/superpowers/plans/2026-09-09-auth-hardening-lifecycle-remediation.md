# Auth Hardening & Lifecycle Remediation Implementation Plan (v2 Deterministic)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup seluruh 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan Bagian 5 dari `docs/audit-auth-review-tahap1-kedua.md` dengan mengimplementasikan crash-consistent state machine, serialisasi mutasi storage via ID ownership guard, pembatalan login eksplisit `cancelSignIn()`, metadata fail-closed `SessionMetadata`, pemetaan 3 akun demo konsisten (termasuk DEMO-003 county 5 cabor unik), request cancellation end-to-end, composition root bebas cycle, dan audit kejujuran UI.

**Architecture:** Dua fase mutasi (*Reserve -> Execute -> Commit*) dengan `_mutationQueue` dan `_operationEpoch` untuk menjamin konsistensi state tanpa race condition; `SessionMetadata` single-record JSON di `SharedPreferences` mengunci status pembersihan; controller memiliki kepemilikan mutlak atas storage sementara repository hanya memvalidasi kredensial/token; `RequestCancellation` guarding data snapshot dari pencemaran antar-sesi; dan composition root modular bebas dependency cycle (`core/config/`, `core/composition/`, `data/`).

**Tech Stack:** Flutter 3.x, Dart 3.12.x, flutter_riverpod 3.4.3 (pinned), go_router 17.1.0, flutter_secure_storage 9.2.4, shared_preferences 2.5.0.

## Global Constraints

- Sesuai dengan spesifikasi final `docs/superpowers/specs/2026-09-09-auth-hardening-lifecycle-remediation-design.md`.
- Seluruh teks pada komponen antarmuka memiliki ukuran font >= 12px (diaudit ketat di Task 8 & 9).
- Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`) dari `lib/core/theme.dart`.
- Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
- Tidak mengubah struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Profil/Akun).
- Pesan error login publik selalu generik: "Nomor SK atau kata sandi tidak sesuai."
- Fail-closed principle: segala anomali metadata, unauthenticated data fetch, atau konfigurasi ilegal ditolak keras.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 0: Baseline, Branch, Versi Dependency, & Test/Analyzer Awal

**Files:**
- Read/Verify: `pubspec.yaml`, `pubspec.lock`
- Run: baseline test suite dan static analysis

**Interfaces:**
- Memastikan environment kerja bersih dan seluruh dependensi sesuai versi pinned (`flutter_riverpod: 3.4.3`, `flutter_secure_storage: 9.2.4`).

- [ ] **Step 1: Jalankan static analysis awal**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Jalankan full test suite awal**

Run: `flutter test`
Expected: Seluruh test suite (168 tests) lulus 100%.

- [ ] **Step 3: Commit baseline confirmation jika ada file staging**

Run: `git status`
Expected: clean working directory.

---

### Task 1: Pure Domain Models, Scope Tanpa Fallback, & CredentialIdGenerator

**Files:**
- Modify: `lib/core/auth/domain/user_principal.dart`
- Modify: `lib/core/auth/domain/auth_state.dart`
- Create: `lib/core/auth/domain/credential_id_generator.dart`
- Modify: `test/user_principal_test.dart`
- Create: `test/credential_id_generator_test.dart`

**Interfaces:**
- Consumes: None (Pure Dart Domain Layer)
- Produces:
  - `AccessScopeType` (`district`, `county`)
  - `AccessScope(type, id, name)` dengan equality & hashCode berbasis `(type, id)`
  - `UserPrincipal(id, skNumber, fullName, roleTitle, scope, permissions)` — `scope` WAJIB tanpa default fallback
  - `LocalCleanupStatus` (`clean`, `pending`, `failed`)
  - `AuthSignedOut(cleanupStatus, message)`
  - `AuthSignedIn(user, generation)` — `accessToken` DIHAPUS dari state publik
  - `CredentialIdGenerator` interface, `UuidCredentialIdGenerator`, dan `DeterministicCredentialIdGenerator`

- [ ] **Step 1: Tulis failing test di `test/credential_id_generator_test.dart` dan `test/user_principal_test.dart`**

Create `test/credential_id_generator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';

void main() {
  group('CredentialIdGenerator', () {
    test('UuidCredentialIdGenerator generates valid RFC 4122 v4 UUIDs', () {
      const generator = UuidCredentialIdGenerator();
      final id1 = generator.generate();
      final id2 = generator.generate();

      expect(id1, isNot(equals(id2)));
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(id1), isTrue);
      expect(uuidRegex.hasMatch(id2), isTrue);
    });

    test('DeterministicCredentialIdGenerator generates predictable sequence', () {
      final generator = DeterministicCredentialIdGenerator('test-session');
      expect(generator.generate(), 'test-session-1');
      expect(generator.generate(), 'test-session-2');
    });
  });
}
```

Update `test/user_principal_test.dart` to verify `AccessScope` equality by `(type, id)` and strict mandatory `scope`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';

void main() {
  group('AccessScope & UserPrincipal Pure Domain', () {
    test('AccessScope equality is based strictly on (type, id)', () {
      const scopeA = AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      );
      const scopeB = AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Label Berbeda Tapi ID Sama',
      );
      const scopeC = AccessScope(
        type: AccessScopeType.county,
        id: 'koni_kab',
        name: 'KONI Kabupaten Garut',
      );

      expect(scopeA, equals(scopeB));
      expect(scopeA.hashCode, equals(scopeB.hashCode));
      expect(scopeA, isNot(equals(scopeC)));
    });

    test('UserPrincipal requires mandatory scope and provides districtId/districtName getters', () {
      const user = UserPrincipal(
        id: 'usr_garut_kota',
        skNumber: 'DEMO-001',
        fullName: 'Pak Asep',
        roleTitle: 'Koordinator',
        scope: AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        ),
      );

      expect(user.districtId, 'garut_kota');
      expect(user.districtName, 'Kecamatan Garut Kota');
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/credential_id_generator_test.dart test/user_principal_test.dart`
Expected: FAIL compilation errors (`UuidCredentialIdGenerator` not found).

- [ ] **Step 3: Implementasikan kode minimal Task 1**

1. Create `lib/core/auth/domain/credential_id_generator.dart`:
```dart
import 'dart:math';

abstract interface class CredentialIdGenerator {
  String generate();
}

class UuidCredentialIdGenerator implements CredentialIdGenerator {
  const UuidCredentialIdGenerator();

  @override
  String generate() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}

class DeterministicCredentialIdGenerator implements CredentialIdGenerator {
  int _counter = 0;
  final String prefix;
  DeterministicCredentialIdGenerator([this.prefix = 'cred']);

  @override
  String generate() => '$prefix-${++_counter}';
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
      other is AccessScope && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'AccessScope($type, $id, $name)';
}

final class UserPrincipal {
  final String id;
  final String skNumber;
  final String fullName;
  final String roleTitle;
  final AccessScope scope;
  final String? profileImageUrl;
  final Set<String> permissions;

  const UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.fullName,
    required this.roleTitle,
    required this.scope,
    this.profileImageUrl,
    this.permissions = const <String>{},
  });

  String get districtId => scope.id;
  String get districtName => scope.name;

  bool hasPermission(String permission) => permissions.contains(permission);
}
```

3. Modify `lib/core/auth/domain/auth_state.dart`:
```dart
import 'user_principal.dart';

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
  });

  final UserPrincipal user;
  final int generation;
}

final class AuthSigningOut extends AuthState {
  const AuthSigningOut();
}

final class AuthTemporarilyUnavailable extends AuthState {
  const AuthTemporarilyUnavailable({this.reason});

  final String? reason;
}
```

- [ ] **Step 4: Jalankan test dan static analysis Task 1**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/domain/ test/credential_id_generator_test.dart test/user_principal_test.dart
flutter test test/credential_id_generator_test.dart test/user_principal_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/core/auth/domain/ test/credential_id_generator_test.dart test/user_principal_test.dart
git commit -m "feat(auth): definisikan pure domain models, AccessScope tanpa fallback, dan CredentialIdGenerator"
```

---

### Task 2: Storage Adapters, Parser Ketat, Namespace, Adapter Abstraction, & Migrasi Eksplisit (Menutup SC-09, SC-14, SC-20, SC-21)

**Files:**
- Create: `lib/core/auth/data/secure_key_val_store.dart`
- Create: `lib/core/auth/data/session_metadata_store.dart`
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/core/auth/data/remembered_sk_store.dart`
- Create: `test/session_metadata_store_test.dart`
- Modify: `test/auth_token_storage_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`, `FlutterSecureStorage`
- Produces:
  - `StorageException`, `CorruptCredentialException`, `MetadataStorageException`, `CorruptMetadataException`
  - `SecureKeyValStore` interface dan `FlutterSecureKeyValStore` implementation
  - `StoredCredential(credentialId, refreshToken)` dengan batas 128/8192 chars
  - `AuthTokenStorage` (`read()`, `write()`, `clearIfOwnedBy()`, `forceClearForRecovery()`, `migrateLegacyStorage()`)
  - `SecureAuthTokenStorage({required String namespace, required SecureKeyValStore secureStore})` tanpa default
  - `SessionMetadataStore` & `SharedPrefsSessionMetadataStore({required SharedPreferences preferences, required String key})`
  - `RememberedSkStore({required SharedPreferences preferences, required String key})`

- [ ] **Step 1: Tulis failing test di `test/session_metadata_store_test.dart` dan `test/auth_token_storage_test.dart`**

Test cases meliputi:
- `SC-09`: Metadata corrupt (schemaVersion beda, tipe salah, field hilang, expectedCredentialId kosong saat restoreAllowed) melempar `CorruptMetadataException`.
- `SC-14`: Ownership guard `clearIfOwnedBy(credentialA)` pada credential B mengembalikan `false` dan tidak menghapus credential B.
- `SC-20`: `migrateLegacyStorage()` menghapus key `v1_kok_refresh_token` secara eksplisit tanpa side effect pada `read()`.
- `SC-21`: `StoredCredential` memvalidasi batas panjang 128 dan 8192 chars.
- Fault-injection pada `FakeSecureKeyValStore` (simulasi exception read/write/delete).

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 2**

1. Create `lib/core/auth/data/secure_key_val_store.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<bool> containsKey({required String key});
}

class FlutterSecureKeyValStore implements SecureKeyValStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyValStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<bool> containsKey({required String key}) => _storage.containsKey(key: key);
}
```

2. Modify `lib/core/auth/data/auth_token_storage.dart`:
Implementasikan `StoredCredential` dengan batas 128/8192, `StorageException` tanpa membocorkan cause, `SecureAuthTokenStorage` dengan `migrateLegacyStorage()` eksplisit, dan `clearIfOwnedBy()`.

3. Create `lib/core/auth/data/session_metadata_store.dart`:
Implementasikan `SessionMetadata` dengan validasi strict (schemaVersion == 1) dan `SharedPrefsSessionMetadataStore` yang memeriksa hasil boolean `setString` dan `remove`.

4. Modify `lib/core/auth/data/remembered_sk_store.dart`:
Wajibkan parameter `key` (tanpa default hardcoded demo).

- [ ] **Step 4: Jalankan test dan static analyzer Task 2**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/data/ test/session_metadata_store_test.dart test/auth_token_storage_test.dart
flutter analyze
flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 2**

```bash
git add lib/core/auth/data/ test/session_metadata_store_test.dart test/auth_token_storage_test.dart
git commit -m "feat(auth): implementasikan SecureKeyValStore, StoredCredential, SessionMetadataStore ketat, dan migrasi eksplisit"
```

---

### Task 3: Repository Auth, Session Handle, & Dataset Demo Kabupaten (Menutup SC-17, SC-18, SC-19, SC-22)

**Files:**
- Modify: `lib/core/auth/data/auth_repository.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Create: `lib/data/kok_repository.dart`
- Create: `lib/data/demo_kok_repository.dart`
- Modify: `test/auth_repository_test.dart`
- Modify: `test/repository_test.dart`

**Interfaces:**
- Consumes: `AccessScope`, `UserPrincipal`
- Produces:
  - `RemoteRevocationStatus` (`revoked`, `notApplicable`, `failed`)
  - `RemoteRevocationResult`
  - `AuthRepository.restoreSession(String refreshToken)`
  - `AuthRepository.revokeSession(String refreshToken)`
  - `DemoAuthRepository` 3-token table (`token_usr_garut_kota`, `token_usr_tarogong_kidul`, `token_usr_koni_kab`)
  - `KokRepository.fetchScope(AccessScope scope, {RequestCancellation? cancellation})`
  - `DemoKokRepository` dataset county 5 cabor unik (`Sepak Bola`, `Bulu Tangkis`, `Pencak Silat`, `Bola Voli`, `Renang`), 9 klub, 213 atlet, 18 pelatih dihitung dinamis.

- [ ] **Step 1: Tulis failing test di `test/auth_repository_test.dart` dan `test/repository_test.dart`**

Test cases meliputi:
- `SC-17`: Pemetaan `DEMO-003` mengembalikan `usr_koni_kab` dengan scope county dan token `token_usr_koni_kab`.
- `SC-18`: Snapshot kabupaten menghasilkan 5 cabor unik, 9 klub, 213 atlet, 18 pelatih.
- `SC-19`: Unknown scope melempar `UnsupportedScopeException`.
- `SC-22`: `RequestCancellation` idempoten.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_repository_test.dart test/repository_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 3**

1. Modify `lib/core/auth/data/auth_repository.dart` dan `lib/core/auth/data/demo_auth_repository.dart`.
2. Create `lib/data/kok_repository.dart` dan `lib/data/demo_kok_repository.dart`.
3. Standarisasi nama cabang olahraga `'Bola Voli'` pada seluruh fixture.

- [ ] **Step 4: Jalankan test dan static analyzer Task 3**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/data/ lib/data/ test/auth_repository_test.dart test/repository_test.dart
flutter analyze
flutter test test/auth_repository_test.dart test/repository_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 3**

```bash
git add lib/core/auth/data/ lib/data/ test/auth_repository_test.dart test/repository_test.dart
git commit -m "feat(repo): terapkan kontrak murni AuthRepository & KokRepository, serta dataset kabupaten gabungan"
```

---

### Task 4: Mutation Queue, Truth Table Bootstrap, & Fail-Closed Auto-Login (Menutup SC-03, SC-08, SC-09, SC-15, SC-20)

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

**Interfaces:**
- Consumes: `SessionMetadataStore`, `AuthTokenStorage`, `AuthRepository`, `CredentialIdGenerator`
- Produces:
  - Serialized `_enqueueMutation` yang kebal error tanpa deadlock
  - Truth table bootstrap fail-closed (`bootstrap()`)
  - Migrasi eksplisit storage legacy saat bootstrap

- [ ] **Step 1: Tulis failing test di `test/auth_controller_test.dart` untuk Queue & Bootstrap**

Test cases meliputi:
- `SC-15`: Exception pada antrean mutasi melepaskan lock tanpa deadlock untuk operasi berikutnya.
- Truth table bootstrap:
  - Metadata null + token null $\rightarrow$ `AuthSignedOut(clean)`
  - Metadata null + token ada $\rightarrow$ `AuthSignedOut(failed)` (orphaned token)
  - Metadata corrupt $\rightarrow$ `AuthSignedOut(failed)`
  - Metadata pending $\rightarrow$ `AuthSignedOut(failed)`
  - Metadata mismatch ID $\rightarrow$ `AuthSignedOut(failed)`
  - Metadata clean + ID cocok $\rightarrow$ memanggil `repo.restoreSession(token)`
  - Restore ditolak repository $\rightarrow$ cleanup token milik sesi $\rightarrow$ `AuthSignedOut(clean)`

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_controller_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 4 di `auth_controller.dart`**

Implementasikan `_enqueueMutation`, `_runBootstrap()` sesuai truth table, dan pemanggilan `tokenStorage.migrateLegacyStorage()`.

- [ ] **Step 4: Jalankan test dan static analyzer Task 4**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/presentation/ test/auth_controller_test.dart
flutter analyze
flutter test test/auth_controller_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 4**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "feat(auth): terapkan mutation queue serial dan truth table bootstrap fail-closed"
```

---

### Task 5: Persistent Login, Rollback, cancelSignIn, Logout, & Recovery (Menutup SC-01, SC-02, SC-04, SC-05, SC-06, SC-07, SC-10, SC-11, SC-12, SC-13, SC-16)

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

**Interfaces:**
- Produces:
  - `login()` dua fase dengan rollback storage
  - `cancelSignIn()` eksplisit
  - `logout()` crash-consistent dengan awaiting revocation ber-timeout
  - `retryLocalCredentialCleanup()` idempoten
  - `LogoutResult`

- [ ] **Step 1: Tulis failing test di `test/auth_controller_test.dart` untuk Login, Cancel, Logout, & Recovery**

Test cases: `SC-01`, `SC-02`, `SC-04`, `SC-05`, `SC-06`, `SC-07`, `SC-10`, `SC-11`, `SC-12`, `SC-13`, `SC-16`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_controller_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 5 di `auth_controller.dart`**

Implementasikan:
- `login()`: Phase 1 Reserve $\rightarrow$ Phase 2 Execute $\rightarrow$ Phase 3 Commit dengan rollback `clearIfOwnedBy` jika epoch berubah.
- `cancelSignIn()`: increment epoch, state $\rightarrow$ `AuthSignedOut(clean)`.
- `logout()`: write pending metadata $\rightarrow$ `clearIfOwnedBy` di queue $\rightarrow$ publish state $\rightarrow$ await `repo.revokeSession` dengan timeout 5s $\rightarrow$ return `LogoutResult`.
- `retryLocalCredentialCleanup()`: force clear storage di queue $\rightarrow$ update metadata clean $\rightarrow$ state `AuthSignedOut(clean)`.

- [ ] **Step 4: Jalankan test dan static analyzer Task 5**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/presentation/ test/auth_controller_test.dart
flutter analyze
flutter test test/auth_controller_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 5**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "feat(auth): terapkan dua fase login, cancelSignIn, logout crash-consistent, dan recovery cleanup"
```

---

### Task 6: Data Request Lifecycle, RequestCancellation, Stale-Result Guard, & No-Retry Policy (Menutup SC-23, SC-24, SC-25)

**Files:**
- Create: `lib/data/providers/snapshot_provider.dart`
- Modify: `lib/data/repository.dart` (re-export atau delegasi bersih)
- Modify: `test/session_scope_test.dart`

**Interfaces:**
- Consumes: `KokRepository`, `authControllerProvider`, `deploymentProfileProvider`
- Produces:
  - `DataRequestContext(environment, userId, scope, generation)`
  - `sessionDataContextProvider`
  - `snapshotProvider` dengan post-await guard dan no-retry policy untuk lifecycle exceptions.

- [ ] **Step 1: Tulis failing test di `test/session_scope_test.dart`**

Test cases:
- `SC-23`: Request A in-flight dibatalkan ketika session switch ke B; data B tidak tercemar.
- `SC-24`: Post-await guard melempar `StaleSessionResultException` jika konteks berubah tanpa pembatalan transport.
- `SC-25`: `snapshotProvider` tidak melakukan auto-retry untuk `SessionRequiredException`, `RequestCancelledException`, `StaleSessionResultException`, dan `UnsupportedScopeException`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/session_scope_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 6**

Create `lib/data/providers/snapshot_provider.dart` dan perbarui `lib/data/repository.dart`.

- [ ] **Step 4: Jalankan test dan static analyzer Task 6**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/data/ test/session_scope_test.dart
flutter analyze
flutter test test/session_scope_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 6**

```bash
git add lib/data/ test/session_scope_test.dart
git commit -m "feat(data): terapkan DataRequestContext guard, pembatalan request end-to-end, dan no-retry policy"
```

---

### Task 7: Deployment Profile & Composition Root Bebas Cycle (Menutup SC-26, SC-27, SC-28, SC-29)

**Files:**
- Create: `lib/core/config/deployment_profile.dart`
- Create: `lib/core/composition/app_composition.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `test/app_environment_test.dart`

**Interfaces:**
- Produces:
  - `DeploymentProfile(environment, authMode, dataMode)`
  - `AppComposition(profile, authRepository, kokRepository, tokenStorage, sessionMetadataStore, rememberedSkStore)`
  - Fail-closed composition validation
  - Inisialisasi bersih di `main.dart` tanpa circular imports

- [ ] **Step 1: Tulis failing test di `test/app_environment_test.dart`**

Test cases:
- `SC-26`: Production tanpa remote adapter melempar `StateError`.
- `SC-27`: `dataMode.remote + authMode.demo` ditolak keras di semua env.
- `SC-28`: Demo env wajib adapter demo.
- `SC-29`: Namespace storage credential, metadata, remembered SK terisolasi antar-env.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/app_environment_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 7**

1. Create `lib/core/config/deployment_profile.dart`.
2. Create `lib/core/composition/app_composition.dart`.
3. Update `lib/main.dart` dan `lib/app.dart`.

- [ ] **Step 4: Jalankan test dan static analyzer Task 7**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/ lib/main.dart lib/app.dart test/app_environment_test.dart
flutter analyze
flutter test test/app_environment_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 7**

```bash
git add lib/core/config/ lib/core/composition/ lib/main.dart lib/app.dart test/app_environment_test.dart
git commit -m "feat(composition): integrasikan DeploymentProfile dan AppComposition root bebas circular dependency"
```

---

### Task 8: UI Polish, Permission Enforcement, Awaited Actions, & Honest Labels (Menutup SC-30, SC-31)

**Files:**
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/login_page.dart`
- Modify: `lib/core/auth/presentation/session_unavailable_page.dart`
- Modify: `lib/features/home_page.dart`
- Modify: `README.md`
- Modify: `test/profile_page_test.dart`
- Modify: `test/login_page_test.dart`
- Modify: `test/session_pages_test.dart`
- Modify: `test/home_page_test.dart`

**Interfaces:**
- Consumes: `currentUserProvider`, `authControllerProvider`
- Produces:
  - Seluruh tombol logout di-`await` dan visual dinonaktifkan saat busy
  - Tombol retry / logout mencegah double tap
  - Penegakan izin `reports:export` pada ekspor rekapitulasi (Pak Cecep / DEMO-002 disabled)
  - Banner peringatan cleanup failed dan tombol "Coba Bersihkan Lagi" di `LoginPage`
  - Pembersihan seluruh klaim SICABOR pada UI
  - Teks akurat keamanan platform pada `README.md`

- [ ] **Step 1: Tulis failing test di `test/profile_page_test.dart`, `test/login_page_test.dart`, `test/session_pages_test.dart`**

Test cases:
- `SC-30`: DEMO-002 (tanpa `reports:export`) tombol rekap disabled + handler double-check memblokir copy.
- `SC-31`: Verifikasi hilangnya teks SICABOR di profil dan beranda.
- Banner cleanup failed & tombol coba bersihkan lagi di `LoginPage`.
- Awaited logout di `SessionUnavailablePage` dan disabled state saat busy.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan perbaikan UI Task 8**

Update `profile_page.dart`, `login_page.dart`, `session_unavailable_page.dart`, `home_page.dart`, dan `README.md`.

- [ ] **Step 4: Jalankan test dan static analyzer Task 8**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/features/ lib/core/auth/presentation/ README.md test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart
flutter analyze
flutter test test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit Task 8**

```bash
git add lib/features/ lib/core/auth/presentation/ README.md test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart
git commit -m "feat(ui): tegakkan izin reports:export, awaited logout, banner retry cleanup, dan hapus klaim SICABOR"
```

---

### Task 9: Cross-Layer Regression (SC-01 s/d SC-31), UI Audit, & Final Verification

**Files:**
- Create: `test/auth_hardening_remediation_test.dart`
- Modify: `test/app_test.dart`
- Audit Script: audit tipografi $\ge 12\text{px}$, warna `KokColors.cardTitle`, dan tombol kembali `Icons.chevron_left`

**Interfaces:**
- Eksekusi menyeluruh 31 skenario regresi `SC-01` s/d `SC-31`
- Verifikasi E2E siklus multi-akun DEMO-001, DEMO-002, DEMO-003
- Audit compliance UI global constraints

- [ ] **Step 1: Buat `test/auth_hardening_remediation_test.dart` yang merangkum seluruh SC-01 s/d SC-31**

Pastikan seluruh 31 skenario dari tabel spesifikasi diuji secara formal dengan test name ber-prefix ID:
`[SC-01] Logout clear berhasil ...`
`[SC-02] Logout clear gagal ...`
...
`[SC-31] Bebas klaim palsu SICABOR ...`

- [ ] **Step 2: Jalankan suite remediasi komprehensif**

Run: `flutter test test/auth_hardening_remediation_test.dart`
Expected: Seluruh 31 skenario PASS.

- [ ] **Step 3: Jalankan full test suite aplikasi**

Run: `flutter test`
Expected: 100% tests passing (semua file test hijau).

- [ ] **Step 4: Audit tipografi $\ge 12\text{px}$ dan komponen UI global**

Lakukan pemeriksaan statis:
- Pastikan tidak ada `fontSize` di bawah 12 di seluruh `lib/`.
- Pastikan tombol kembali konsisten `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.

- [ ] **Step 5: Jalankan static analysis akhir**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit Task 9**

```bash
git add test/auth_hardening_remediation_test.dart test/app_test.dart
git commit -m "test(auth): selesaikan 31 skenario regresi komprehensif SC-01 s/d SC-31 dan verifikasi final"
```

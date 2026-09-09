# Auth Hardening & Lifecycle Remediation Implementation Plan (v3 Deterministic)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup seluruh 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan Bagian 5 dari `docs/audit-auth-review-tahap1-kedua.md` dengan mengimplementasikan crash-resilient state machine, serialisasi mutasi storage via ID ownership guard, pembatalan login `cancelSignIn()` dengan `SignInPhase`, metadata fail-closed `SessionMetadata` berbasis `restoreAllowed`, pemetaan 3 akun demo konsisten (termasuk DEMO-003 county 5 cabor unik), request cancellation end-to-end, composition root bebas cycle, dan audit kejujuran UI.

**Architecture:** Dua fase mutasi (*Reserve -> Execute -> Commit*) dengan `_mutationQueue` dan `SignInPhase` untuk mencegah race condition commit/clear; `SessionMetadata` single-record JSON di `SharedPreferences` mengunci status pembersihan dan verifikasi `restoreAllowed`; controller memiliki kepemilikan mutlak atas storage sementara repository menghasilkan `RemoteSessionHandle` privat; `RequestCancellation` guarding data snapshot; dan composition root modular bebas dependency cycle (`core/config/`, `core/composition/`, `data/`).

**Tech Stack:** Flutter 3.x, Dart 3.12.x, flutter_riverpod 3.4.3 (pinned di `pubspec.lock`), go_router 17.5.0 (pinned di `pubspec.lock`), shared_preferences 2.5.5 (pinned di `pubspec.lock`), flutter_secure_storage 9.2.4 (pinned di `pubspec.lock`).

## Global Constraints

- Sesuai dengan spesifikasi final `docs/superpowers/specs/2026-09-09-auth-hardening-lifecycle-remediation-design.md`.
- Setiap task commit **wajib menjaga repository tetap hijau** (`flutter analyze` 0 issues dan test suite task terkait lulus 100%).
- Seluruh teks pada komponen antarmuka memiliki ukuran font >= 12px (diaudit ketat di Task 8 & 9).
- Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`) dari `lib/core/theme.dart`.
- Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
- Tidak mengubah struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Profil/Akun).
- Pesan error login publik selalu generik: "Nomor SK atau kata sandi tidak sesuai."
- Fail-closed principle: segala anomali metadata, unauthenticated data fetch, atau konfigurasi ilegal ditolak keras.

---

### Task 0: Baseline Verification & Environment Lock

**Files:**
- Read/Verify: `pubspec.yaml`, `pubspec.lock`

**Interfaces:**
- Memastikan environment kerja bersih dan mencatat baseline aktual test suite dan analyzer.

- [ ] **Step 1: Jalankan static analysis awal**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Jalankan full test suite awal dan catat baseline**

Run: `flutter test`
Expected: Seluruh test suite baseline lulus 100% (168 tests lulus).

- [ ] **Step 3: Pastikan working directory bersih**

Run: `git status`
Expected: `nothing to commit, working tree clean`.

---

### Task 1: Pure Domain Models, Defensive Permissions, & CredentialIdGenerator

**Files:**
- Modify: `lib/core/auth/domain/user_principal.dart`
- Modify: `lib/core/auth/domain/auth_state.dart`
- Create: `lib/core/auth/domain/credential_id_generator.dart`
- Modify (Sweep): `lib/core/auth/data/demo_auth_repository.dart`
- Modify (Sweep): `lib/core/auth/presentation/auth_controller.dart`
- Modify (Sweep): `lib/data/repository.dart`
- Modify: `test/user_principal_test.dart`
- Create: `test/credential_id_generator_test.dart`
- Modify (Sweep): `test/auth_token_storage_test.dart`, `test/auth_hardening_test.dart`, `test/profile_page_test.dart`, `test/auth_controller_test.dart`, `test/home_page_test.dart`

**Interfaces:**
- Consumes: None (Pure Dart Domain Layer)
- Produces:
  - `AccessScopeType` (`district`, `county`)
  - `AccessScope(type, id, name)` dengan equality & hashCode berbasis `(type, id)`
  - `UserPrincipal(id, skNumber, fullName, roleTitle, scope, permissions)` — `scope` WAJIB tanpa default fallback, `permissions` dibungkus `Set.unmodifiable()`
  - `LocalCleanupStatus` (`clean`, `pending`, `failed`)
  - `AuthSignedOut(cleanupStatus, message)`
  - `AuthSignedIn(user, generation)` — `accessToken` DIHAPUS dari state publik
  - `CredentialIdGenerator` interface, `UuidCredentialIdGenerator` (RFC 4122 v4 dengan `Random.secure()`), dan `DeterministicCredentialIdGenerator`

- [ ] **Step 1: Tulis failing test di `test/credential_id_generator_test.dart` dan `test/user_principal_test.dart`**

Di `test/credential_id_generator_test.dart`:
- `UuidCredentialIdGenerator` menghasilkan UUID RFC 4122 v4 yang valid dan tidak tabrakan.
- `DeterministicCredentialIdGenerator` menghasilkan sequence terprediksi.

Di `test/user_principal_test.dart`:
- `AccessScope` equality berbasis `(type, id)`.
- `UserPrincipal` mewajibkan `scope` tanpa default fallback.
- Defensive copy test: mutasi pada Set sumber tidak mengubah `UserPrincipal.permissions`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/credential_id_generator_test.dart test/user_principal_test.dart`
Expected: FAIL compilation error.

- [ ] **Step 3: Implementasikan kode Task 1**

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
Definisikan `AccessScopeType`, `AccessScope`, dan `UserPrincipal` dengan `permissions = Set.unmodifiable(permissions)`.

3. Modify `lib/core/auth/domain/auth_state.dart`:
Definisikan `LocalCleanupStatus`, `AuthSignedOut`, dan hapus `accessToken` dari `AuthSignedIn`.

- [ ] **Step 4: Migration Sweep Task 1 (Menjaga Repository Tetap Hijau)**

Perbarui seluruh pemanggil constructor `UserPrincipal` dan `AuthSignedIn` di:
- `lib/core/auth/data/demo_auth_repository.dart`
- `lib/core/auth/presentation/auth_controller.dart` (hapus `, accessToken: ...` pada instansiasi `AuthSignedIn`)
- `lib/data/repository.dart`
- Seluruh test file yang memakai `districtId:` pada `UserPrincipal`:
  `test/user_principal_test.dart`, `test/auth_token_storage_test.dart`, `test/auth_hardening_test.dart`, `test/profile_page_test.dart`, `test/auth_controller_test.dart`, `test/home_page_test.dart`.

Verifikasi sweep:
```bash
git grep "districtId:" lib/core/auth/domain/
```
Expected: nol kemunculan di domain model.

- [ ] **Step 5: Jalankan formatter, analyzer, dan test Task 1**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/domain/ test/credential_id_generator_test.dart test/user_principal_test.dart
flutter analyze
flutter test test/credential_id_generator_test.dart test/user_principal_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 6: Commit Task 1**

```bash
git add lib/core/auth/domain/ lib/core/auth/data/ lib/core/auth/presentation/auth_controller.dart lib/data/repository.dart test/
git commit -m "feat(auth): definisikan AccessScope murni, UserPrincipal defensif, CredentialIdGenerator, dan sweep konsumen"
```

---

### Task 2: Storage Adapters, Parser Ketat, Namespace, & Migrasi Eksplisit (Menutup SC-09, SC-14, SC-20, SC-21)

**Files:**
- Create: `lib/core/auth/data/secure_key_val_store.dart`
- Create: `lib/core/auth/data/session_metadata_store.dart`
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/core/auth/data/remembered_sk_store.dart`
- Create: `test/session_metadata_store_test.dart`
- Modify: `test/auth_token_storage_test.dart`
- Modify (Sweep): `lib/core/auth/presentation/auth_controller.dart`, `test/login_page_test.dart`

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
- `[SC-09]`: Metadata corrupt (schemaVersion beda, tipe salah, field hilang, expectedCredentialId dilarang saat restoreAllowed == false) melempar `CorruptMetadataException`.
- `[SC-14]`: Ownership guard `clearIfOwnedBy(credentialA)` pada credential B mengembalikan `false` dan tidak menghapus credential B.
- `[SC-20]`: `migrateLegacyStorage()` menghapus key `v1_kok_refresh_token` secara eksplisit tanpa side effect pada `read()`.
- `[SC-21]`: `StoredCredential` memvalidasi batas panjang 128 dan 8192 chars. Melebihi batas melempar `CorruptCredentialException`.
- Fault injection pada `FakeSecureKeyValStore` (simulasi error read/write/delete).

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 2**

1. Create `lib/core/auth/data/secure_key_val_store.dart`.
2. Modify `lib/core/auth/data/auth_token_storage.dart`.
3. Create `lib/core/auth/data/session_metadata_store.dart`.
4. Modify `lib/core/auth/data/remembered_sk_store.dart`.

- [ ] **Step 4: Migration Sweep Task 2 (Menjaga Repository Tetap Hijau)**

Perbarui instansiasi `SecureAuthTokenStorage` dan `RememberedSkStore` di `lib/core/auth/presentation/auth_controller.dart` dan `test/login_page_test.dart` agar memberikan parameter `namespace:` dan `key:` secara eksplisit:
```dart
final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return const SecureAuthTokenStorage(
    namespace: 'kok.auth.v2.demo.credential',
    secureStore: FlutterSecureKeyValStore(),
  );
});
```
Verifikasi sweep:
```bash
git grep "RememberedSkStore()" lib test
git grep "SecureAuthTokenStorage()" lib test
```
Expected: nol kemunculan tanpa argumen.

- [ ] **Step 5: Jalankan formatter, analyzer, dan test Task 2**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/data/ test/session_metadata_store_test.dart test/auth_token_storage_test.dart
flutter analyze
flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 6: Commit Task 2**

```bash
git add lib/core/auth/data/ lib/core/auth/presentation/auth_controller.dart test/session_metadata_store_test.dart test/auth_token_storage_test.dart test/login_page_test.dart
git commit -m "feat(auth): terapkan SecureKeyValStore, SessionMetadataStore strict fail-closed, dan migrasi sweep storage"
```

---

### Task 3: Repository Auth, RemoteSessionHandle, & Dataset Demo Kabupaten (Menutup SC-17, SC-18, SC-19, SC-22)

**Files:**
- Modify: `lib/core/auth/data/auth_repository.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Create: `lib/data/kok_repository.dart`
- Create: `lib/data/demo_kok_repository.dart`
- Modify: `lib/data/models.dart` (tambahkan `AccessScope scope` ke `KokSnapshot` dan re-run build_runner)
- Modify: `test/auth_repository_test.dart`
- Modify: `test/repository_test.dart`
- Modify (Sweep 11 files): `test/sports_page_test.dart`, `test/sport_detail_test.dart`, `test/search_page_test.dart`, `test/profile_page_test.dart`, `test/home_page_test.dart`, `test/committee_page_test.dart`, `test/attention_page_test.dart`, `test/athlete_detail_test.dart`, `test/auth_hardening_test.dart`

**Interfaces:**
- Consumes: `AccessScope`, `UserPrincipal`
- Produces:
  - `RemoteSessionHandle(revocationToken)`
  - `RemoteRevocationStatus` (`revoked`, `notApplicable`, `failed`)
  - `RemoteRevocationResult`
  - `AuthRepository.restoreSession(String refreshToken)`
  - `AuthRepository.revokeSession(RemoteSessionHandle session)`
  - `DemoAuthRepository` 3-token table (`token_usr_garut_kota`, `token_usr_tarogong_kidul`, `token_usr_koni_kab`)
  - `KokSnapshot(scope, clubs, people, committee, loadedAt)`
  - `KokRepository.fetchScope(AccessScope scope, {RequestCancellation? cancellation})`
  - `DemoKokRepository` dataset county 5 cabor unik (`Sepak Bola`, `Bulu Tangkis`, `Pencak Silat`, `Bola Voli`, `Renang`), 9 klub, 213 atlet, 18 pelatih dihitung dinamis.

- [ ] **Step 1: Tulis failing test di `test/auth_repository_test.dart` dan `test/repository_test.dart`**

Test cases meliputi:
- `[SC-17]`: Pemetaan `DEMO-003` mengembalikan `usr_koni_kab` dengan scope county dan token `token_usr_koni_kab`.
- `[SC-18]`: Snapshot kabupaten menghasilkan 5 cabor unik, 9 klub, 213 atlet, 18 pelatih dengan `snapshot.scope.id == 'koni_kab'`.
- `[SC-19]`: Unknown scope melempar `UnsupportedScopeException`.
- `[SC-22]`: `RequestCancellation` idempoten.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_repository_test.dart test/repository_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 3**

1. Modify `lib/core/auth/data/auth_repository.dart` & `lib/core/auth/data/demo_auth_repository.dart`.
2. Update `KokSnapshot` di `lib/data/models.dart` untuk menambahkan `required AccessScope scope` dan jalankan `dart run build_runner build --delete-conflicting-outputs`.
3. Create `lib/data/kok_repository.dart` dan `lib/data/demo_kok_repository.dart`.
4. Standarisasi nama cabang olahraga `'Bola Voli'` pada seluruh fixture.

- [ ] **Step 4: Migration Sweep Task 3 (Menjaga Repository Tetap Hijau)**

Migrasikan seluruh pemanggilan legacy `fetch()` dan `fetchDistrict()` di 11 test files:
- `test/sports_page_test.dart`
- `test/sport_detail_test.dart`
- `test/search_page_test.dart`
- `test/profile_page_test.dart`
- `test/home_page_test.dart`
- `test/committee_page_test.dart`
- `test/attention_page_test.dart`
- `test/athlete_detail_test.dart`
- `test/auth_hardening_test.dart`
- `test/auth_repository_test.dart`
- `test/repository_test.dart`

Ganti ke `fetchScope(const AccessScope(type: AccessScopeType.district, id: 'garut_kota', name: 'Kecamatan Garut Kota'))` atau scope terkait.
Verifikasi sweep:
```bash
git grep "\.fetch(" lib test
git grep "fetchDistrict" lib test
```
Expected: nol pemanggilan legacy API.

- [ ] **Step 5: Jalankan formatter, analyzer, dan test Task 3**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/data/ lib/data/ test/
flutter analyze
flutter test test/auth_repository_test.dart test/repository_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 6: Commit Task 3**

```bash
git add lib/core/auth/data/ lib/data/ test/
git commit -m "feat(repo): terapkan RemoteSessionHandle, KokSnapshot scoped, dataset kabupaten 5 cabor, dan sweep test callers"
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
  - Truth table bootstrap fail-closed berbasis `restoreAllowed == true`
  - Migrasi eksplisit storage legacy saat bootstrap

- [ ] **Step 1: Tulis failing test di `test/auth_controller_test.dart` untuk Queue & Bootstrap**

Test cases meliputi:
- `[SC-15]`: Exception pada antrean mutasi melepaskan lock tanpa deadlock untuk operasi berikutnya.
- `[SC-03]`: Restart setelah clear gagal (`restoreAllowed: false, cleanupStatus: failed`) menolak auto-login dan set state `AuthSignedOut(failed)`.
- `[SC-08]`: Crash sebelum `restoreAllowed = true` (`restoreAllowed: false, cleanupStatus: pending`) menolak auto-login.
- `[SC-20]`: Migrasi legacy storage dijalankan saat bootstrap.
- Truth table lengkap bootstrap (11 kondisi sesuai spesifikasi Bagian 3.4 B).

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_controller_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 4 di `auth_controller.dart`**

Implementasikan `_enqueueMutation`, `_runBootstrap()` sesuai truth table lengkap yang memeriksa `metadata.restoreAllowed == true`, dan eksekusi `tokenStorage.migrateLegacyStorage()`.

- [ ] **Step 4: Jalankan formatter, analyzer, dan test Task 4**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/presentation/ test/auth_controller_test.dart
flutter analyze
flutter test test/auth_controller_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 5: Commit Task 4**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "feat(auth): terapkan mutation queue serial, truth table bootstrap berbasis restoreAllowed, dan migrasi legacy"
```

---

### Task 5: Persistent Login, Rollback, cancelSignIn, Logout, & Recovery (Menutup SC-01, SC-02, SC-04, SC-05, SC-06, SC-07, SC-10, SC-11, SC-12, SC-13, SC-16)

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

**Interfaces:**
- Produces:
  - `SignInPhase` (`idle`, `executing`, `waitingForCommit`, `committing`)
  - `login()` dua fase dengan rollback storage
  - `cancelSignIn()` eksplisit berbasis `SignInPhase`
  - `logout()` crash-resilient dengan awaiting timeout revocation (5s) untuk sesi persisten & nonpersisten
  - `retryLocalCredentialCleanup()` idempoten
  - `LogoutResult`

- [ ] **Step 1: Tulis failing test di `test/auth_controller_test.dart` untuk Login, Cancel, Logout, & Recovery**

Test cases:
- `[SC-01]`: Logout clear berhasil $\rightarrow$ state signed-out bersih, token kosong, metadata `restoreAllowed = false, cleanupStatus = clean`.
- `[SC-02]`: Logout clear gagal $\rightarrow$ data terkunci, `cleanupStatus == failed`, metadata `restoreAllowed = false, cleanupStatus = failed`.
- `[SC-04]`: `retryLocalCredentialCleanup()` berhasil $\rightarrow$ force clear storage, metadata bersih, login diaktifkan kembali.
- `[SC-05]`: `retryLocalCredentialCleanup()` gagal $\rightarrow$ status tetap failed.
- `[SC-06]`: Double logout tap $\rightarrow$ hanya satu operasi cleanup storage dijalankan.
- `[SC-07]`: Percobaan login saat cleanup berlangsung $\rightarrow$ ditolak `AuthCommandRejected(cleanupRequired)`.
- `[SC-10]`: Local cleanup tetap tuntas dan state signed-out ketika remote revocation timeout (5s).
- `[SC-11]`: `LogoutResult`: status `notApplicable` terbedakan dari `failed` atau `revoked`.
- `[SC-12]`: `cancelSignIn()` saat execute jaringan menggantung $\rightarrow$ state kembali ke `AuthSignedOut(clean)`.
- `[SC-13]`: Revalidasi tiket operasi pasca-antrean commit $\rightarrow$ commit ditolak jika epoch berubah.
- `[SC-16]`: `cancelSignIn()` ketika phase `committing` ditolak dengan `AuthCommandRejected(operationInProgress)`.
- Persistence failure matrix tests (8 skenario kegagalan storage).

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_controller_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 5 di `auth_controller.dart`**

Implementasikan `SignInPhase`, `login()` dua fase dengan rollback, `cancelSignIn()`, `logout()`, dan `retryLocalCredentialCleanup()`.

- [ ] **Step 4: Jalankan formatter, analyzer, dan test Task 5**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/auth/presentation/ test/auth_controller_test.dart
flutter analyze
flutter test test/auth_controller_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 5: Commit Task 5**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "feat(auth): integrasikan SignInPhase, cancelSignIn, rollback storage, dan logout ber-timeout"
```

---

### Task 6: Data Request Lifecycle, RequestCancellation, Stale-Result Guard, & No-Retry Policy (Menutup SC-23, SC-24, SC-25)

**Files:**
- Create: `lib/data/providers/snapshot_provider.dart`
- Modify: `lib/data/repository.dart` (re-export sementara)
- Modify: `test/session_scope_test.dart`

**Interfaces:**
- Consumes: `KokRepository`, `authControllerProvider`, `deploymentProfileProvider`
- Produces:
  - `DataRequestContext(environment, userId, scope, generation)`
  - `sessionDataContextProvider`
  - `snapshotProvider` dengan post-await cancellation check dan no-retry policy untuk error siklus sesi.

- [ ] **Step 1: Tulis failing test di `test/session_scope_test.dart`**

Test cases:
- `[SC-23]`: Request A in-flight dibatalkan ketika session switch ke B; data B tidak tercemar.
- `[SC-24]`: Post-await context guard melempar `StaleSessionResultException` jika context berubah saat request berjalan.
- `[SC-25]`: `snapshotProvider` menonaktifkan retry untuk lifecycle exceptions (`SessionRequiredException`, `RequestCancelledException`, `StaleSessionResultException`, `UnsupportedScopeException`) dan meneruskan error lainnya ke `ProviderContainer.defaultRetry`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/session_scope_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 6**

Create `lib/data/providers/snapshot_provider.dart` dan update `lib/data/repository.dart`.

- [ ] **Step 4: Jalankan formatter, analyzer, dan test Task 6**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/data/ test/session_scope_test.dart
flutter analyze
flutter test test/session_scope_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 5: Commit Task 6**

```bash
git add lib/data/ test/session_scope_test.dart
git commit -m "feat(data): bangun snapshotProvider dengan DataRequestContext guard, post-await cancellation, dan no-retry policy"
```

---

### Task 7: Deployment Profile & Composition Root Bebas Cycle (Menutup SC-26, SC-27, SC-28, SC-29)

**Files:**
- Create: `lib/core/config/deployment_profile.dart`
- Create: `lib/core/composition/app_composition.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `test/app_environment_test.dart`
- Prune/Cleanup: Hapus compatibility barrel `lib/core/config/app_environment.dart` dan `lib/data/repository.dart` setelah migrasi import tuntas.

**Interfaces:**
- Produces:
  - `DeploymentProfile(environment, authMode, dataMode)`
  - `AppComposition.fromProfile(profile, preferences: ..., secureStore: ..., credentialIdGenerator: ...)`
  - Inisialisasi bersih di `main.dart` tanpa circular imports

- [ ] **Step 1: Tulis failing test di `test/app_environment_test.dart`**

Test cases:
- `[SC-26]`: Production tanpa remote adapter melempar `StateError`.
- `[SC-27]`: `dataMode.remote + authMode.demo` ditolak keras di semua env.
- `[SC-28]`: Demo env wajib adapter demo.
- `[SC-29]`: Namespace storage credential, metadata, remembered SK terisolasi antar-env.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/app_environment_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan kode Task 7**

1. Create `lib/core/config/deployment_profile.dart`.
2. Create `lib/core/composition/app_composition.dart`.
3. Update `lib/main.dart` dan `lib/app.dart`.
4. Migrasikan seluruh import di `lib/` dan `test/` yang masih merujuk ke file lama, lalu bersihkan barrel sementara.

- [ ] **Step 4: Jalankan formatter, analyzer, dan test Task 7**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/core/ lib/main.dart lib/app.dart test/app_environment_test.dart
flutter analyze
flutter test test/app_environment_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 5: Commit Task 7**

```bash
git add lib/ test/
git commit -m "feat(composition): implementasikan AppComposition root bebas cycle dan bersihkan compatibility barrels"
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
  - Seluruh tombol logout di-`await` dan tombol dinonaktifkan saat busy
  - Tombol retry / logout mencegah double tap
  - Penegakan izin `reports:export` pada ekspor rekapitulasi (Pak Cecep / DEMO-002 disabled)
  - Banner peringatan cleanup failed dan tombol "Coba Bersihkan Lagi" di `LoginPage`
  - Pembersihan klaim aktif SICABOR dan penyajian teks jujur: `'Data demo lokal—belum terhubung dengan SICABOR.'`
  - Teks akurat keamanan platform pada `README.md`

- [ ] **Step 1: Tulis failing test di `test/profile_page_test.dart`, `test/login_page_test.dart`, `test/session_pages_test.dart`, `test/home_page_test.dart`**

Test cases:
- `[SC-30]`: DEMO-002 (tanpa `reports:export`) tombol rekap disabled + handler double-check memblokir copy.
- `[SC-31]`: Bebas dari klaim `SINKRONISASI DATA SICABOR`, `tersinkronisasi dengan SICABOR`, `data SICABOR aktif`; menyajikan kalimat jujur `Data demo lokal—belum terhubung dengan SICABOR.`
- Banner cleanup failed & tombol coba bersihkan lagi di `LoginPage`.
- Awaited logout di `SessionUnavailablePage` dan disabled state saat busy.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart test/home_page_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementasikan perbaikan UI Task 8**

Update `profile_page.dart`, `login_page.dart`, `session_unavailable_page.dart`, `home_page.dart`, dan `README.md`.
*(Catatan: format hanya folder `lib` dan `test`, jangan menyertakan `README.md` pada perintah `dart format`).*

- [ ] **Step 4: Jalankan formatter, analyzer, dan test Task 8**

Run:
```bash
dart format --output=none --set-exit-if-changed lib/features/ lib/core/auth/presentation/ test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart test/home_page_test.dart
flutter analyze
flutter test test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart test/home_page_test.dart
```
Expected: PASS dan `flutter analyze` 0 issues!

- [ ] **Step 5: Commit Task 8**

```bash
git add lib/features/ lib/core/auth/presentation/ README.md test/profile_page_test.dart test/login_page_test.dart test/session_pages_test.dart test/home_page_test.dart
git commit -m "feat(ui): tegakkan izin reports:export, awaited logout, banner retry cleanup, dan teks jujur demo"
```

---

### Task 9: Cross-Layer Regression (SC-01 s/d SC-31), UI Audit, & Final Verification

**Files:**
- Create: `test/auth_hardening_remediation_test.dart` (cross-layer flows)
- Modify: `test/app_test.dart` (E2E multi-akun)

**Interfaces:**
- Agregasi eksekusi menyeluruh 31 skenario `[SC-01]` s/d `[SC-31]`
- Audit compliance UI global constraints (fontSize $\ge 12\text{px}$, back button Icons.chevron_left size 28 KokColors.cardTitle, cardTitle #141414)
- Platform verification: `flutter build apk --debug`

- [ ] **Step 1: Buat `test/auth_hardening_remediation_test.dart` untuk verifikasi cross-layer flow**

- [ ] **Step 2: Jalankan full test suite aplikasi**

Run: `flutter test`
Expected: 100% tests passing across all test files.

- [ ] **Step 3: Audit tipografi $\ge 12\text{px}$ dan komponen UI global**

Pemeriksaan statis:
- Pastikan tidak ada `fontSize` di bawah 12 di seluruh `lib/`.
- Pastikan tombol kembali konsisten `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.

- [ ] **Step 4: Jalankan static analysis akhir**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Jalankan platform build verification**

Run: `flutter build apk --debug`
Expected: Gradle build succeeds.

- [ ] **Step 6: Commit Task 9**

```bash
git add test/auth_hardening_remediation_test.dart test/app_test.dart
git commit -m "test(auth): selesaikan pengujian regresi komprehensif SC-01 s/d SC-31, UI audit, dan build verification"
```

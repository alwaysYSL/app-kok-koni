# Penguatan Autentikasi & Siklus Sesi (Tahap A Hardening) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup seluruh 9 temuan audit arsitektur (A-01 s/d A-09) dan rekomendasi desain Bagian 5 pada implementasi autentikasi Tahap A, menghasilkan sistem autentikasi yang *fail-closed*, kebal terhadap *race condition* asinkron, tanpa *unauthenticated data fallback*, dan memiliki sumber kebenaran tunggal (*single source of truth*).

**Architecture:** Menggunakan *epoch-guarded mutex* pada `AuthController` untuk mencegah *stale storage commit* dan *race condition* asinkron; mengeliminasi sesi *legacy* `sessionProvider` dan memisahkan `preferencesProvider`; menutup celah router guard dengan *closed-default redirect* dan rute transisi `/signing-out`; mengisolasi data keolahragaan dengan melempar `SessionRequiredException` saat tanpa sesi; serta menambahkan validator konfigurasi *fail-closed* untuk memblokir adapter/kredensial demo di lingkungan produksi.

**Tech Stack:** Flutter 3.x, Dart 3.12.x, Riverpod 2.5 / 3.x, GoRouter 17.x, `flutter_secure_storage` 9.2.4, `shared_preferences`.

## Global Constraints

- Sesuai spesifikasi `docs/superpowers/specs/2026-09-09-auth-hardening-and-lifecycle-design.md`.
- Seluruh teks pada komponen antarmuka memiliki ukuran font >= 12px (tidak ada teks di bawah 12px anywhere).
- Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`) dari `lib/core/theme.dart`.
- Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
- Tidak mengubah struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Akun/Profil).
- Pesan error login publik selalu generik: "Nomor SK atau kata sandi tidak sesuai."
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Unifikasi Sumber Sesi, Pemisahan Preferences, & Domain Immutability (Menutup A-08 & Catatan Bagian 5)

**Files:**
- Create: `lib/core/preferences.dart`
- Delete: `lib/core/session.dart`
- Modify: `lib/core/auth/domain/user_principal.dart`
- Modify: `lib/features/login_page.dart`
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/main.dart`
- Modify: `test/profile_page_test.dart`
- Modify: `test/login_page_test.dart`
- Test: `test/user_principal_test.dart`

**Interfaces:**
- Consumes:
  - `SharedPreferences` dari package `shared_preferences`
- Produces:
  - `preferencesProvider`: `Provider<SharedPreferences>` di `lib/core/preferences.dart`
  - `UserPrincipal`: dengan `permissions` bertipe `Set<String>` yang diinisialisasi `Set.unmodifiable(...)`, serta implementasi `operator ==` dan `hashCode` lengkap yang memperhitungkan seluruh atribut identitas (`id`, `skNumber`, `fullName`, `roleTitle`, `districtId`, `districtName`, `profileImageUrl`, `permissions`).

- [ ] **Step 1: Tulis tes gagal untuk immutability dan equality `UserPrincipal`**

Buat `test/user_principal_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_koni/core/auth/domain/user_principal.dart';

void main() {
  group('UserPrincipal Hardening Tests', () {
    test('permissions set harus unmodifiable', () {
      final principal = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district', 'edit:club'},
      );

      expect(
        () => (principal.permissions as dynamic).add('malicious:permission'),
        throwsUnsupportedError,
      );
    });

    test('value equality dan hashCode harus memperhitungkan seluruh field dan permissions', () {
      final p1 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district'},
      );
      final p2 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district'},
      );
      final p3 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama Berbeda',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district'},
      );
      final p4 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district', 'extra:perm'},
      );

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
      expect(p1, isNot(equals(p4)));
    });
  });
}
```

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan**

Jalankan: `flutter test test/user_principal_test.dart`
Ekspektasi: FAIL pada equality / unmodifiable permissions.

- [ ] **Step 3: Implementasikan perbaikan UserPrincipal, preferencesProvider, dan hapus sessionProvider legacy**

1. Perbarui `lib/core/auth/domain/user_principal.dart`:
```dart
import 'package:flutter/foundation.dart';

@immutable
class UserPrincipal {
  final String id;
  final String skNumber;
  final String fullName;
  final String roleTitle;
  final String districtId;
  final String districtName;
  final String? profileImageUrl;
  final Set<String> permissions;

  UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.fullName,
    required this.roleTitle,
    required this.districtId,
    required this.districtName,
    this.profileImageUrl,
    Set<String> permissions = const {},
  }) : permissions = Set.unmodifiable(permissions);

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPrincipal &&
        other.id == id &&
        other.skNumber == skNumber &&
        other.fullName == fullName &&
        other.roleTitle == roleTitle &&
        other.districtId == districtId &&
        other.districtName == districtName &&
        other.profileImageUrl == profileImageUrl &&
        setEquals(other.permissions, permissions);
  }

  @override
  int get hashCode => Object.hash(
        id,
        skNumber,
        fullName,
        roleTitle,
        districtId,
        districtName,
        profileImageUrl,
        Object.hashAllUnordered(permissions),
      );
}
```

2. Buat `lib/core/preferences.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized at startup.'),
);
```

3. Hapus `lib/core/session.dart`.
4. Perbarui impor di `lib/main.dart` dari `lib/core/session.dart` ke `lib/core/preferences.dart`.
5. Di `lib/features/login_page.dart`:
   - Hapus impor `lib/core/session.dart` dan pemanggilan `ref.read(sessionProvider.notifier).signIn()`.
   - Tambahkan early guard pada `_submit()`:
     ```dart
     if (_busy) return;
     ```
   - Hanya panggil `ref.read(authControllerProvider.notifier).login(...)`.
6. Di `lib/features/profile_page.dart`:
   - Hapus impor `lib/core/session.dart` dan pemanggilan `ref.read(sessionProvider.notifier).signOut()`.
   - Hanya panggil `ref.read(authControllerProvider.notifier).logout()`.
7. Perbarui referensi `sessionProvider` di `test/profile_page_test.dart` dan `test/login_page_test.dart`.

- [ ] **Step 4: Jalankan tes unit dan widget untuk memverifikasi kelulusan**

Jalankan: `flutter test test/user_principal_test.dart test/login_page_test.dart test/profile_page_test.dart`
Ekspektasi: PASS (seluruh pengujian lulus).

- [ ] **Step 5: Commit perubahan Task 1**

```bash
git add lib/core/preferences.dart lib/core/auth/domain/user_principal.dart lib/features/login_page.dart lib/features/profile_page.dart lib/main.dart test/user_principal_test.dart test/login_page_test.dart test/profile_page_test.dart
git rm lib/core/session.dart
git commit -m "refactor(auth): unifikasi sumber sesi, hapus sessionProvider legacy, dan perkuat UserPrincipal immutability"
```

---

### Task 2: Penguatan Token Storage & Validasi Ketat DemoAuthRepository (Menutup A-05 & A-06)

**Files:**
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Modify: `test/auth_token_storage_test.dart`
- Modify: `test/auth_repository_test.dart`

**Interfaces:**
- Consumes:
  - `flutter_secure_storage`
- Produces:
  - `StorageException`: exception bertipe untuk kegagalan platform secure storage
  - `AuthTokenStorage`: method `getRefreshToken()`, `saveRefreshToken()`, `clear()` yang melempar `StorageException` alih-alih menelan error
  - `DemoAuthRepository`: `restoreSession()` yang menolak keras token yang bukan `'token_usr_garut_kota'` atau `'token_usr_tarogong_kidul'`.

- [ ] **Step 1: Tulis tes gagal untuk StorageException dan token tiruan tidak dikenal**

1. Di `test/auth_token_storage_test.dart`, tambahkan tes kegagalan storage:
```dart
test('SecureAuthTokenStorage melempar StorageException saat platform storage gagal', () async {
  // Verifikasi melempar StorageException bukan Exception generic atau menelan null
});
```
2. Di `test/auth_repository_test.dart`, tambahkan tes penolakan token tak dikenal:
```dart
test('restoreSession menolak token acak atau tak dikenal dengan SessionExpiredFailure', () async {
  final storage = InMemoryAuthTokenStorage();
  await storage.saveRefreshToken('token_acak_palsu_123');
  final repo = DemoAuthRepository(storage: storage);

  final result = await repo.restoreSession();
  expect(result.isSuccess, isFalse);
  expect(result.failure, isA<SessionExpiredFailure>());
  expect(result.user, isNull);
});
```

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan**

Jalankan: `flutter test test/auth_repository_test.dart test/auth_token_storage_test.dart`
Ekspektasi: FAIL pada penolakan token acak.

- [ ] **Step 3: Implementasikan StorageException dan validasi ketat token**

1. Di `lib/core/auth/data/auth_token_storage.dart`:
```dart
class StorageException implements Exception {
  final String message;
  final Object? cause;

  const StorageException(this.message, [this.cause]);

  @override
  String toString() => cause != null ? '$message (Penyebab: $cause)' : message;
}
```
Perbarui `SecureAuthTokenStorage`:
```dart
class SecureAuthTokenStorage implements AuthTokenStorage {
  static const _keyRefreshToken = 'v1_kok_refresh_token';
  final FlutterSecureStorage _storage;

  const SecureAuthTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
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
```

2. Di `lib/core/auth/data/demo_auth_repository.dart`:
Perbarui `restoreSession()` untuk memvalidasi token secara ketat:
```dart
@override
Future<AuthResult> restoreSession() async {
  final refreshToken = await _storage.getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) {
    return const AuthResult.failed(
      SessionExpiredFailure('Tidak ada sesi yang tersimpan di perangkat ini.'),
    );
  }

  if (refreshToken == 'token_usr_garut_kota') {
    return AuthResult.success(
      user: _garutKotaUser,
      accessToken: 'access_demo_garut_kota',
      refreshToken: refreshToken,
    );
  } else if (refreshToken == 'token_usr_tarogong_kidul') {
    return AuthResult.success(
      user: _tarogongKidulUser,
      accessToken: 'access_demo_tarogong_kidul',
      refreshToken: refreshToken,
    );
  }

  return const AuthResult.failed(
    SessionExpiredFailure('Sesi Anda tidak valid atau telah kedaluwarsa.'),
  );
}
```
Pastikan `login()` mengembalikan kandidat token di dalam `AuthResult`:
```dart
return AuthResult.success(
  user: matchedUser,
  accessToken: matchedUser.id == 'usr_garut_kota'
      ? 'access_demo_garut_kota'
      : 'access_demo_tarogong_kidul',
  refreshToken: staySignedIn
      ? (matchedUser.id == 'usr_garut_kota'
          ? 'token_usr_garut_kota'
          : 'token_usr_tarogong_kidul')
      : null,
);
```

- [ ] **Step 4: Jalankan tes untuk memverifikasi kelulusan**

Jalankan: `flutter test test/auth_repository_test.dart test/auth_token_storage_test.dart`
Ekspektasi: PASS.

- [ ] **Step 5: Commit perubahan Task 2**

```bash
git add lib/core/auth/data/auth_token_storage.dart lib/core/auth/data/demo_auth_repository.dart test/auth_token_storage_test.dart test/auth_repository_test.dart
git commit -m "fix(auth): tangani StorageException tanpa menelan error dan validasi token sesi tiruan secara ketat"
```

---

### Task 3: Penghapusan Fallback Data Tanpa Sesi & Pagar Environment Produksi (Menutup A-03 & A-04)

**Files:**
- Create: `lib/core/config/app_environment.dart`
- Modify: `lib/data/repository.dart`
- Modify: `lib/main.dart`
- Test: `test/session_scope_test.dart`
- Test: `test/app_environment_test.dart`

**Interfaces:**
- Consumes:
  - `sessionScopeProvider` dari `lib/data/repository.dart`
- Produces:
  - `SessionRequiredException`: exception bertipe yang dilempar saat `sessionScopeProvider == null`
  - `CancelToken`: mendukung pembatalan permintaan saat snapshotProvider di-dispose
  - `snapshotProvider`: melempar `SessionRequiredException` tanpa memanggil `repository.fetchDistrict` saat `sessionScope == null`
  - `AppEnvironment`: enum `{ demo, staging, production }`
  - `validateAppConfiguration`: fungsi pemvalidasi konfigurasi runtime *fail-closed*.

- [ ] **Step 1: Tulis tes gagal untuk SessionRequiredException dan validasi AppEnvironment**

1. Di `test/session_scope_test.dart`, tambahkan tes penolakan mutlak saat tanpa sesi:
```dart
test('snapshotProvider melempar SessionRequiredException saat sessionScope bernilai null', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(
    () => container.read(snapshotProvider.future),
    throwsA(isA<SessionRequiredException>()),
  );
});
```
2. Buat `test/app_environment_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_koni/core/config/app_environment.dart';

void main() {
  group('AppEnvironment Hardening Tests', () {
    test('validateAppConfiguration melempar StateError saat production menggunakan demo auth atau data', () {
      expect(
        () => validateAppConfiguration(
          environment: AppEnvironment.production,
          usesDemoAuth: true,
          usesDemoData: false,
        ),
        throwsStateError,
      );

      expect(
        () => validateAppConfiguration(
          environment: AppEnvironment.production,
          usesDemoAuth: false,
          usesDemoData: true,
        ),
        throwsStateError,
      );
    });

    test('validateAppConfiguration lolos saat demo atau staging menggunakan demo auth', () {
      expect(
        () => validateAppConfiguration(
          environment: AppEnvironment.demo,
          usesDemoAuth: true,
          usesDemoData: true,
        ),
        returnsNormally,
      );

      expect(
        () => validateAppConfiguration(
          environment: AppEnvironment.staging,
          usesDemoAuth: true,
          usesDemoData: true,
        ),
        returnsNormally,
      );
    });
  });
}
```

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan**

Jalankan: `flutter test test/session_scope_test.dart test/app_environment_test.dart`
Ekspektasi: FAIL pada SessionRequiredException dan StateError.

- [ ] **Step 3: Implementasikan SessionRequiredException, CancelToken, dan AppEnvironment**

1. Buat `lib/core/config/app_environment.dart`:
```dart
enum AppEnvironment {
  demo,
  staging,
  production,
}

AppEnvironment get currentEnvironment {
  const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
  return switch (envStr) {
    'production' => AppEnvironment.production,
    'staging' => AppEnvironment.staging,
    'demo' => AppEnvironment.demo,
    _ => throw StateError('Environment tidak dikenal: $envStr'),
  };
}

void validateAppConfiguration({
  required AppEnvironment environment,
  required bool usesDemoAuth,
  required bool usesDemoData,
}) {
  if (environment == AppEnvironment.production) {
    if (usesDemoAuth || usesDemoData) {
      throw StateError(
        'FATAL: Konfigurasi produksi ditolak! Build produksi dilarang keras menggunakan kredensial/adapter demo.',
      );
    }
  }
}
```

2. Di `lib/data/repository.dart`:
```dart
final class SessionRequiredException implements Exception {
  final String message;
  const SessionRequiredException([
    this.message = 'Sesi terautentikasi aktif dibutuhkan untuk mengakses data keolahragaan.',
  ]);

  @override
  String toString() => message;
}

class CancelToken {
  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    _isCancelled = true;
    _reason = reason;
  }
}
```
Perbarui signature `fetchDistrict` di `KokRepository`:
```dart
Future<KokSnapshot> fetchDistrict(String districtId, {CancelToken? cancelToken});
```
Perbarui implementasi `AssetKokRepository.fetchDistrict`:
```dart
@override
Future<KokSnapshot> fetchDistrict(String districtId, {CancelToken? cancelToken}) async {
  if (cancelToken?.isCancelled ?? false) {
    throw Exception('Permintaan data dibatalkan: ${cancelToken?.reason}');
  }
  final baseSnapshot = await loadSnapshot();
  if (cancelToken?.isCancelled ?? false) {
    throw Exception('Permintaan data dibatalkan: ${cancelToken?.reason}');
  }
  // Filter data sesuai districtId...
  return _filterForDistrict(baseSnapshot, districtId);
}
```
Perbarui `snapshotProvider` untuk menghapus fallback data tanpa sesi:
```dart
final snapshotProvider = FutureProvider<KokSnapshot>((ref) async {
  final scope = ref.watch(sessionScopeProvider);
  if (scope == null) {
    throw const SessionRequiredException();
  }

  final repository = ref.watch(repositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('Session changed or disposed'));

  return repository.fetchDistrict(scope.districtId, cancelToken: cancelToken);
});
```

3. Di `lib/main.dart`:
Panggil `validateAppConfiguration(...)` sebelum `runApp(...)`:
```dart
validateAppConfiguration(
  environment: currentEnvironment,
  usesDemoAuth: true,
  usesDemoData: true,
);
```

- [ ] **Step 4: Jalankan tes untuk memverifikasi kelulusan**

Jalankan: `flutter test test/session_scope_test.dart test/app_environment_test.dart`
Ekspektasi: PASS.

- [ ] **Step 5: Commit perubahan Task 3**

```bash
git add lib/core/config/app_environment.dart lib/data/repository.dart lib/main.dart test/session_scope_test.dart test/app_environment_test.dart
git commit -m "feat(data): hapus fallback data unauthenticated, terapkan SessionRequiredException dan fail-closed environment gate"
```

---

### Task 4: Pengamanan Race Asinkron AuthController & Storage Commit Mutex (Menutup A-02 & A-07)

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

**Interfaces:**
- Consumes:
  - `AuthRepository`, `AuthTokenStorage`, `RememberedSkStore`
- Produces:
  - `AuthController`:
    - `int _operationEpoch` menjaga operasi asinkron dari tumpang tindih
    - `Future<void>? _activeBootstrapFuture` menjamin *single-flight bootstrap*
    - `bootstrap()`: tidak memicu panggilan ganda dan menolak commit jika epoch berubah
    - `login()`: memeriksa epoch sebelum dan setelah simpan storage; me-rollback token storage jika logout terjadi saat in-flight
    - `logout()`: menaikkan epoch dan session generation seketika, masuk ke `AuthSigningOut`, membersihkan storage, lalu beralih ke `AuthSignedOut`.

- [ ] **Step 1: Tulis tes gagal untuk race condition asinkron login-logout dan double bootstrap**

Di `test/auth_controller_test.dart`, tambahkan skenario race condition menggunakan `Completer`:
```dart
test('logout saat login masih berjalan membatalkan commit token dan menghasilkan AuthSignedOut', () async {
  final loginCompleter = Completer<AuthResult>();
  final fakeRepo = CompleterAuthRepository(loginCompleter: loginCompleter);
  final fakeStorage = InMemoryAuthTokenStorage();
  final fakeSkStore = InMemoryRememberedSkStore();

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
      authTokenStorageProvider.overrideWithValue(fakeStorage),
      rememberedSkStoreProvider.overrideWithValue(fakeSkStore),
    ],
  );
  addTearDown(container.dispose);

  final controller = container.read(authControllerProvider.notifier);

  // 1. Mulai login (asinkron tertahan)
  final loginFuture = controller.login(
    skNumber: 'DEMO-001',
    password: 'password',
    staySignedIn: true,
    rememberSk: true,
  );
  expect(container.read(authControllerProvider), isA<AuthSigningIn>());

  // 2. Pengguna memanggil logout sebelum login selesai
  await controller.logout();
  expect(container.read(authControllerProvider), isA<AuthSignedOut>());

  // 3. Selesaikan operasi login yang tertunda
  loginCompleter.complete(
    AuthResult.success(
      user: fakeGarutKotaUser,
      accessToken: 'acc_token',
      refreshToken: 'token_usr_garut_kota',
    ),
  );
  final loginResult = await loginFuture;

  // 4. Verifikasi: login harus ditolak (return false), state tetap AuthSignedOut, storage token kosong
  expect(loginResult, isFalse);
  expect(container.read(authControllerProvider), isA<AuthSignedOut>());
  expect(await fakeStorage.getRefreshToken(), isNull);
});

test('panggilan bootstrap ganda secara simultan hanya mengeksekusi satu kali (single-flight)', () async {
  final bootstrapCompleter = Completer<AuthResult>();
  final fakeRepo = CompleterAuthRepository(restoreCompleter: bootstrapCompleter);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
      authTokenStorageProvider.overrideWithValue(InMemoryAuthTokenStorage()),
      rememberedSkStoreProvider.overrideWithValue(InMemoryRememberedSkStore()),
    ],
  );
  addTearDown(container.dispose);

  final controller = container.read(authControllerProvider.notifier);

  final f1 = controller.bootstrap();
  final f2 = controller.bootstrap();

  expect(fakeRepo.restoreCallCount, equals(1));

  bootstrapCompleter.complete(const AuthResult.failed(SessionExpiredFailure('None')));
  await Future.wait([f1, f2]);

  expect(fakeRepo.restoreCallCount, equals(1));
});
```

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan**

Jalankan: `flutter test test/auth_controller_test.dart`
Ekspektasi: FAIL pada skenario race condition dan single-flight.

- [ ] **Step 3: Implementasikan pengamanan epoch dan single-flight di AuthController**

Perbarui `lib/core/auth/presentation/auth_controller.dart`:
```dart
class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  int _sessionGeneration = 0;
  int _operationEpoch = 0;
  Future<void>? _activeBootstrapFuture;

  AuthController(this._ref) : super(const AuthBootstrapping()) {
    bootstrap();
  }

  int get sessionGeneration => _sessionGeneration;

  Future<void> bootstrap() async {
    if (_activeBootstrapFuture != null) return _activeBootstrapFuture!;
    final future = _runBootstrap();
    _activeBootstrapFuture = future;
    try {
      await future;
    } finally {
      _activeBootstrapFuture = null;
    }
  }

  Future<void> _runBootstrap() async {
    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    state = const AuthBootstrapping();

    final repo = _ref.read(authRepositoryProvider);
    try {
      final result = await repo.restoreSession();
      if (currentEpoch != _operationEpoch) return;

      if (result.isSuccess && result.user != null) {
        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
          accessToken: result.accessToken,
        );
      } else {
        if (result.failure is NetworkTimeoutFailure) {
          state = AuthTemporarilyUnavailable(
            reason: result.failure!.message,
          );
        } else {
          state = const AuthSignedOut();
        }
      }
    } on StorageException catch (e) {
      if (currentEpoch != _operationEpoch) return;
      state = AuthTemporarilyUnavailable(reason: e.message);
    } catch (_) {
      if (currentEpoch != _operationEpoch) return;
      state = const AuthTemporarilyUnavailable(
        reason: 'Gagal menghubungkan ke layanan autentikasi.',
      );
    }
  }

  Future<bool> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
    required bool rememberSk,
  }) async {
    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    state = const AuthSigningIn();

    final repo = _ref.read(authRepositoryProvider);
    try {
      final result = await repo.login(
        skNumber: skNumber,
        password: password,
        staySignedIn: staySignedIn,
      );
      if (currentEpoch != _operationEpoch) return false;

      if (result.isSuccess && result.user != null) {
        final tokenStorage = _ref.read(authTokenStorageProvider);
        if (staySignedIn && result.refreshToken != null) {
          await tokenStorage.saveRefreshToken(result.refreshToken!);
          if (currentEpoch != _operationEpoch) {
            await tokenStorage.clear();
            return false;
          }
        } else {
          await tokenStorage.clear();
          if (currentEpoch != _operationEpoch) return false;
        }

        final skStore = _ref.read(rememberedSkStoreProvider);
        if (rememberSk) {
          await skStore.saveSk(skNumber);
        } else {
          await skStore.clear();
        }
        if (currentEpoch != _operationEpoch) return false;

        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
          accessToken: result.accessToken,
        );
        return true;
      } else {
        final errorMsg = result.failure?.message ?? 'Nomor SK atau kata sandi tidak sesuai.';
        if (result.failure is NetworkTimeoutFailure) {
          state = AuthTemporarilyUnavailable(reason: errorMsg);
        } else {
          state = AuthSignedOut(errorMessage: errorMsg);
        }
        return false;
      }
    } catch (_) {
      if (currentEpoch != _operationEpoch) return false;
      state = const AuthTemporarilyUnavailable(
        reason: 'Terjadi gangguan sistem. Silakan coba lagi.',
      );
      return false;
    }
  }

  Future<void> retrySession() async {
    await bootstrap();
  }

  Future<void> logout() async {
    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    _sessionGeneration++;
    state = const AuthSigningOut();

    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.logout();
    } finally {
      if (currentEpoch == _operationEpoch) {
        state = const AuthSignedOut();
      }
    }
  }
}
```

- [ ] **Step 4: Jalankan tes untuk memverifikasi kelulusan**

Jalankan: `flutter test test/auth_controller_test.dart`
Ekspektasi: PASS.

- [ ] **Step 5: Commit perubahan Task 4**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "fix(auth): terapkan epoch-guarded mutex, single-flight bootstrap, dan storage rollback pada AuthController"
```

---

### Task 5: Rute Transisi `/signing-out`, Guard Router Fail-Closed, & Propagasi Reason (Menutup A-01 & A-07)

**Files:**
- Create: `lib/core/auth/presentation/session_signing_out_page.dart`
- Modify: `lib/app.dart`
- Modify: `lib/core/auth/presentation/session_unavailable_page.dart`
- Modify: `test/session_pages_test.dart`

**Interfaces:**
- Consumes:
  - `authControllerProvider`
- Produces:
  - `SessionSigningOutPage`: halaman transisi logout KOK (Navy, icon KOK, progress bar, font >= 12px)
  - `SessionUnavailablePage`: menerima parameter opsional `reason` dan menampilkannya pada deskripsi kendala
  - `routerProvider`: redirect *closed-default* yang mengarahkan non-signed-in hanya ke rute sesi khusus (`/signing-out`, `/session`, `/session-unavailable`, `/login`) dan menutup rute aplikasi dari `AuthSigningIn` dan `AuthSigningOut`.

- [ ] **Step 1: Tulis widget test untuk SessionSigningOutPage dan propagasi reason di SessionUnavailablePage**

Di `test/session_pages_test.dart`:
```dart
testWidgets('SessionSigningOutPage menampilkan teks Mengeluarkan Akun dan pattern KOK', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SessionSigningOutPage(),
    ),
  );

  expect(find.text('Mengeluarkan Akun'), findsOneWidget);
  expect(find.text('Membersihkan sesi lokal dan mengamankan data...'), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});

testWidgets('SessionUnavailablePage menampilkan custom reason saat diberikan', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SessionUnavailablePage(
        reason: 'Penyimpanan hardware keystore tidak merespons.',
        onRetry: () {},
        onSignOut: () {},
      ),
    ),
  );

  expect(find.text('Penyimpanan hardware keystore tidak merespons.'), findsOneWidget);
});
```

- [ ] **Step 2: Jalankan tes untuk memverifikasi kegagalan**

Jalankan: `flutter test test/session_pages_test.dart`
Ekspektasi: FAIL karena `SessionSigningOutPage` belum ada.

- [ ] **Step 3: Implementasikan SessionSigningOutPage, SessionUnavailablePage reason, dan update router guard**

1. Buat `lib/core/auth/presentation/session_signing_out_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:kok_koni/core/theme.dart';
import 'package:kok_koni/features/home_page.dart';

class SessionSigningOutPage extends StatelessWidget {
  const SessionSigningOutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KokColors.primaryNavy,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BrandHeaderPatternPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Mengeluarkan Akun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Membersihkan sesi lokal dan mengamankan data...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

2. Perbarui `lib/core/auth/presentation/session_unavailable_page.dart`:
Tambahkan parameter `final String? reason;`:
```dart
class SessionUnavailablePage extends ConsumerWidget {
  final String? reason;
  final VoidCallback? onRetry;
  final VoidCallback? onSignOut;

  const SessionUnavailablePage({
    super.key,
    this.reason,
    this.onRetry,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayReason = reason ??
        'Aplikasi tidak dapat memulihkan sesi Anda karena batas waktu sambungan berakhir atau gangguan penyimpanan perangkat.';
    // Gunakan displayReason pada Text deskripsi kendala...
```

3. Perbarui `lib/app.dart`:
```dart
GoRoute(
  path: '/signing-out',
  builder: (context, state) => const SessionSigningOutPage(),
),
GoRoute(
  path: '/session-unavailable',
  builder: (context, state) {
    final authState = ref.read(authControllerProvider);
    final reason = (authState is AuthTemporarilyUnavailable)
        ? authState.reason
        : state.uri.queryParameters['reason'];
    return SessionUnavailablePage(reason: reason);
  },
),
```
Terapkan redirect *closed-default*:
```dart
redirect: (context, state) {
  final authState = ref.read(authControllerProvider);
  final loc = state.matchedLocation;

  if (authState is AuthSigningOut) {
    return loc == '/signing-out' ? null : '/signing-out';
  }
  if (authState is AuthBootstrapping) {
    return loc == '/session' ? null : '/session';
  }
  if (authState is AuthTemporarilyUnavailable) {
    return loc == '/session-unavailable' ? null : '/session-unavailable';
  }
  if (authState is! AuthSignedIn) {
    return loc == '/login' ? null : '/login';
  }

  const authGates = {'/login', '/session', '/session-unavailable', '/signing-out'};
  if (authGates.contains(loc)) {
    return '/home';
  }
  return null;
},
```

- [ ] **Step 4: Jalankan tes untuk memverifikasi kelulusan**

Jalankan: `flutter test test/session_pages_test.dart`
Ekspektasi: PASS.

- [ ] **Step 5: Commit perubahan Task 5**

```bash
git add lib/core/auth/presentation/session_signing_out_page.dart lib/core/auth/presentation/session_unavailable_page.dart lib/app.dart test/session_pages_test.dart
git commit -m "feat(auth): daftarkan rute /signing-out, perkuat router redirect fail-closed, dan teruskan reason kendala"
```

---

### Task 6: Teks Rekapitulasi Wilayah Dinamis & Label Mode Demo Jujur (Menutup A-09)

**Files:**
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/home_page.dart`
- Modify: `lib/core/auth/presentation/session_startup_page.dart`
- Modify: `test/profile_page_test.dart`
- Modify: `test/home_page_test.dart`

**Interfaces:**
- Consumes:
  - `currentUserProvider`
  - `snapshotProvider`
- Produces:
  - Rekapitulasi `ProfilePage` menggunakan `data.districtName` secara dinamis pada judul sheet, subjudul, dan teks clipboard.
  - Kartu sinkronisasi menampilkan `"Terakhir dimuat: $timeStr · X entri data (Mode Demo)"` dan tombol muat ulang meng-invalidasi `snapshotProvider`.
  - `HomePage` menampilkan `"Terakhir Dimuat: $timeStr WIB"`.
  - `SessionStartupPage` menampilkan teks status `"Memeriksa sesi pengguna..."`.

- [ ] **Step 1: Tulis tes gagal untuk rekapitulasi dinamis multi-wilayah di ProfilePage**

Di `test/profile_page_test.dart`, tambahkan tes verifikasi rekapitulasi data Tarogong Kidul:
```dart
testWidgets('Rekapitulasi menampilkan nama wilayah Tarogong Kidul secara dinamis saat akun Tarogong Kidul aktif', (tester) async {
  // Test bahwa bottom sheet memuat "Rekapitulasi Data KOK Tarogong Kidul"
});
```

- [ ] **Step 2: Jalankan tes untuk memverifikasi status kegagalan**

Jalankan: `flutter test test/profile_page_test.dart`
Ekspektasi: FAIL pada label wilayah Garut Kota yang masih statis.

- [ ] **Step 3: Implementasikan teks dinamis dan label jujur**

1. Di `lib/features/profile_page.dart`:
   - Pada bottom sheet rekapitulasi data:
     * Judul sheet: `'Rekapitulasi Data KOK ${data.districtName.replaceFirst('Kecamatan ', '')}'`
     * Subjudul: `'Ringkasan data keolahragaan wilayah ${data.districtName}.'`
     * Salin ke clipboard:
       ```text
       REKAPITULASI DATA ${data.districtName.toUpperCase()}
       Waktu: $timeStr WIB
       Total Cabang Olahraga: $caborCount
       Total Klub: $klubCount
       Total Atlet: $atletCount
       Total Pelatih: $pelatihCount
       Total Berkas Belum Lengkap: $missingCount
       Status: Terdaftar pada Sistem KOK ${data.districtName}
       ```
   - Pada `_SyncStatusCard`:
     * Label: `'Terakhir dimuat: $timeStr · ${data.people.length} entri data (Mode Demo)'`
     * Tombol muat ulang:
       ```dart
       ref.invalidate(snapshotProvider);
       try {
         await ref.read(snapshotProvider.future);
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Data berhasil dimuat ulang'),
               duration: Duration(seconds: 2),
               behavior: SnackBarBehavior.floating,
             ),
           );
         }
       } catch (_) {}
       ```

2. Di `lib/features/home_page.dart`:
   - Ubah label sinkronisasi: `'Terakhir Dimuat: $timeStr WIB'`.

3. Di `lib/core/auth/presentation/session_startup_page.dart`:
   - Ganti teks status: `'Memeriksa sesi pengguna...'`.

- [ ] **Step 4: Jalankan tes untuk memverifikasi kelulusan**

Jalankan: `flutter test test/profile_page_test.dart test/home_page_test.dart`
Ekspektasi: PASS.

- [ ] **Step 5: Commit perubahan Task 6**

```bash
git add lib/features/profile_page.dart lib/features/home_page.dart lib/core/auth/presentation/session_startup_page.dart test/profile_page_test.dart test/home_page_test.dart
git commit -m "style(ui): sesuaikan rekapitulasi dinamis per kecamatan dan perbarui label jujur mode demo"
```

---

### Task 7: Pengujian Regresi Komprehensif, E2E Suite, & Golden Previews (Menutup Seluruh Verifikasi Audit)

**Files:**
- Create: `test/auth_hardening_test.dart`
- Modify: `test/app_test.dart`
- Modify: `test/preview_test.dart`
- Update: `previews/`
- Verify: full suite

**Interfaces:**
- Consumes:
  - Seluruh komponen arsitektur yang telah diperkuat
- Produces:
  - `test/auth_hardening_test.dart`: 9 skenario pengujian regresi spesifik sesuai matriks audit
  - `test/app_test.dart`: pengujian integrasi E2E yang memvalidasi siklus penuh termasuk rute `/signing-out`
  - Regenerasi golden preview yang konsisten dan valid
  - `flutter analyze`: 0 issues
  - `flutter test`: 100% lulus.

- [ ] **Step 1: Tulis tes regresi terpusat di test/auth_hardening_test.dart**

Buat `test/auth_hardening_test.dart` yang mencakup 9 skenario audit:
1. Race Condition Asinkron Login-Logout (token tidak tertinggal)
2. Single-Flight Bootstrap (tidak ada duplikasi fetch)
3. Penolakan Mutlak `snapshotProvider` tanpa Sesi (`SessionRequiredException`)
4. Router Guard Mengunci Rute Internal saat `AuthSigningIn` dan `AuthSigningOut`
5. Penanganan `StorageException` beralih ke `AuthTemporarilyUnavailable`
6. Penolakan Token Tak Dikenal oleh `DemoAuthRepository`
7. Validasi `validateAppConfiguration` Fail-Closed di Lingkungan Produksi
8. Rekapitulasi Data Tarogong Kidul Dinamis
9. `UserPrincipal` Immutable Permissions & Value Equality

- [ ] **Step 2: Jalankan tes regresi baru**

Jalankan: `flutter test test/auth_hardening_test.dart`
Ekspektasi: PASS.

- [ ] **Step 3: Perbarui app_test.dart dan regenerate golden preview jika diperlukan**

1. Perbarui `test/app_test.dart` untuk menyesuaikan dengan rute `/signing-out` dan verifikasi seluruh alur navigasi.
2. Jalankan:
```bash
flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true
```
Revert preview yang tidak sengaja berubah karena perbedaan timestamp:
```bash
git checkout -- previews/atlet.png previews/cabor.png previews/cabor_detail.png previews/home.png previews/klub.png previews/klub_voli.png previews/pencarian.png previews/profil.png
```
Pastikan hanya preview yang relevan yang di-stage: `previews/session_startup.png`, `previews/session_unavailable.png`, `previews/login.png`.

- [ ] **Step 4: Jalankan verifikasi menyeluruh (full test suite & static analysis)**

Jalankan:
```bash
flutter analyze
flutter test
```
Ekspektasi: 0 lint errors, 100% tests passing across the entire test suite.

- [ ] **Step 5: Commit perubahan Task 7**

```bash
git add test/auth_hardening_test.dart test/app_test.dart test/preview_test.dart previews/
git commit -m "test(auth): tambahkan pengujian regresi komprehensif penutupan audit A-01 s/d A-09"
```

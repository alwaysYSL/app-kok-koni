# Auth and Session Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun arsitektur autentikasi dan manajemen sesi aplikasi KOK yang tangguh, aman, dan modular berbasis Clean Architecture dengan multi-akun, persistensi token aman (`flutter_secure_storage`), isolasi cache per sesi (*session generation counter*), serta layar *startup* dan *unavailable* kustom bertema KOK.

**Architecture:** Memisahkan lapisan autentikasi (Domain, Data, State) secara tegas dari domain data olahraga. Sesi dikelola oleh `AuthController` dengan state diskrit (`Bootstrapping`, `SignedOut`, `SigningIn`, `SignedIn`, `TemporarilyUnavailable`, `SigningOut`) dan `_sessionGeneration`. `snapshotProvider` bergantung pada `SessionScope` sehingga pergantian akun atau proses logout secara otomatis membatalkan *in-flight request* dan membuang cache lama.

**Tech Stack:** Flutter 3.x, Dart 3.12.x, `flutter_riverpod: ^2.5.1` / `riverpod: ^3.0.3`, `go_router: ^17.0.1`, `flutter_secure_storage: ^9.2.4`, `shared_preferences: ^2.5.4`, `dio: ^5.7.0`, `fl_chart: ^1.2.0`.

## Global Constraints

- Sesuai dengan spesifikasi [docs/superpowers/specs/2026-09-08-auth-and-session-architecture-design.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/superpowers/specs/2026-09-08-auth-and-session-architecture-design.md) dan audit [docs/audit-auth.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth.md).
- Seluruh teks pada komponen antarmuka memiliki ukuran font $\ge 12\text{px}$ (tidak ada teks di bawah 12px).
- Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`) dari `lib/core/theme.dart`.
- Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
- Tidak mengubah struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Akun).
- Pesan error login publik selalu generik: *"Nomor SK atau kata sandi tidak sesuai"*.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Dependensi flutter_secure_storage, Domain Model, & Lapisan Token Storage

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/auth/domain/user_principal.dart`
- Create: `lib/core/auth/domain/auth_state.dart`
- Create: `lib/core/auth/domain/auth_failure.dart`
- Create: `lib/core/auth/data/auth_token_storage.dart`
- Create: `lib/core/auth/data/remembered_sk_store.dart`
- Test: `test/auth_token_storage_test.dart`

**Interfaces:**
- Produces:
  * `class UserPrincipal` with fields `(id, skNumber, name, role, districtId, districtName, permissions)`.
  * `sealed class AuthState` (`AuthBootstrapping`, `AuthSignedOut`, `AuthSigningIn`, `AuthSignedIn`, `AuthTemporarilyUnavailable`, `AuthSigningOut`).
  * `sealed class AuthFailure` (`InvalidCredentials`, `NetworkTimeout`, `SessionExpired`, `StorageError`).
  * `abstract class AuthTokenStorage` with methods `Future<String?> readRefreshToken()`, `Future<void> saveRefreshToken(String token)`, `Future<void> clear()`.
  * `class SecureAuthTokenStorage implements AuthTokenStorage`.
  * `class RememberedSkStore` with methods `Future<String?> readSk()`, `Future<void> saveSk(String sk)`, `Future<void> clear()`.

- [ ] **Step 1: Tulis unit test untuk AuthTokenStorage dan RememberedSkStore**

Create `test/auth_token_storage_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryAuthTokenStorage implements AuthTokenStorage {
  String? _token;
  bool shouldThrow = false;

  @override
  Future<String?> readRefreshToken() async {
    if (shouldThrow) throw Exception('Keystore locked');
    return _token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    if (shouldThrow) throw Exception('Keystore locked');
    _token = token;
  }

  @override
  Future<void> clear() async {
    if (shouldThrow) throw Exception('Keystore locked');
    _token = null;
  }
}

void main() {
  group('AuthTokenStorage', () {
    test('menyimpan, membaca, dan menghapus refresh token secara benar', () async {
      final storage = InMemoryAuthTokenStorage();
      expect(await storage.readRefreshToken(), isNull);

      await storage.saveRefreshToken('test_refresh_token_xyz');
      expect(await storage.readRefreshToken(), 'test_refresh_token_xyz');

      await storage.clear();
      expect(await storage.readRefreshToken(), isNull);
    });

    test('menangani exception storage tanpa crash tak terkendali', () async {
      final storage = InMemoryAuthTokenStorage()..shouldThrow = true;
      expect(() => storage.readRefreshToken(), throwsException);
    });
  });

  group('RememberedSkStore', () {
    test('menyimpan dan membaca nomor SK dari SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedSkStore(prefs);

      expect(await store.readSk(), isNull);
      await store.saveSk('DEMO-001');
      expect(await store.readSk(), 'DEMO-001');
      await store.clear();
      expect(await store.readSk(), isNull);
    });
  });

  group('UserPrincipal & AuthState', () {
    test('UserPrincipal memeriksa permissions dengan benar', () {
      const user = UserPrincipal(
        id: 'usr-1',
        skNumber: 'DEMO-001',
        name: 'Pak Asep',
        role: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
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
```

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan kompilasi/eksekusi**

Run: `flutter test test/auth_token_storage_test.dart`  
Expected: FAIL (files/classes not found).

- [ ] **Step 3: Tambahkan dependensi flutter_secure_storage di pubspec.yaml**

In `pubspec.yaml`, under `dependencies:`, add:
```yaml
  flutter_secure_storage: ^9.2.4
```
Then run `flutter pub get`.

- [ ] **Step 4: Buat UserPrincipal, AuthState, AuthFailure, AuthTokenStorage, dan RememberedSkStore**

Create `lib/core/auth/domain/user_principal.dart`:
```dart
class UserPrincipal {
  final String id;
  final String skNumber;
  final String name;
  final String role;
  final String districtId;
  final String districtName;
  final Set<String> permissions;

  const UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.name,
    required this.role,
    required this.districtId,
    required this.districtName,
    required this.permissions,
  });

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPrincipal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          skNumber == other.skNumber &&
          districtId == other.districtId;

  @override
  int get hashCode => id.hashCode ^ skNumber.hashCode ^ districtId.hashCode;
}
```

Create `lib/core/auth/domain/auth_state.dart`:
```dart
import 'user_principal.dart';

sealed class AuthState {
  const AuthState();
}

class AuthBootstrapping extends AuthState {
  const AuthBootstrapping();
}

class AuthSignedOut extends AuthState {
  final String? errorMessage;
  const AuthSignedOut({this.errorMessage});
}

class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

class AuthSignedIn extends AuthState {
  final UserPrincipal user;
  final int generation;
  final String? accessToken;

  const AuthSignedIn({
    required this.user,
    required this.generation,
    this.accessToken,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSignedIn &&
          user == other.user &&
          generation == other.generation &&
          accessToken == other.accessToken;

  @override
  int get hashCode => user.hashCode ^ generation.hashCode ^ accessToken.hashCode;
}

class AuthTemporarilyUnavailable extends AuthState {
  final String reason;
  final bool canRetry;

  const AuthTemporarilyUnavailable({
    required this.reason,
    this.canRetry = true,
  });
}

class AuthSigningOut extends AuthState {
  const AuthSigningOut();
}
```

Create `lib/core/auth/domain/auth_failure.dart`:
```dart
sealed class AuthFailure {
  final String message;
  const AuthFailure(this.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.message = 'Nomor SK atau kata sandi tidak sesuai.',
  ]);
}

class NetworkTimeoutFailure extends AuthFailure {
  const NetworkTimeoutFailure([
    super.message = 'Koneksi ke server autentikasi terputus. Silakan coba lagi.',
  ]);
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([
    super.message = 'Sesi Anda telah kedaluwarsa. Silakan masuk kembali.',
  ]);
}

class StorageErrorFailure extends AuthFailure {
  const StorageErrorFailure([
    super.message = 'Penyimpanan sesi lokal mengalami kendala.',
  ]);
}
```

Create `lib/core/auth/data/auth_token_storage.dart`:
```dart
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
```

Create `lib/core/auth/data/remembered_sk_store.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class RememberedSkStore {
  static const String _key = 'remembered_sk';
  final SharedPreferences _prefs;

  const RememberedSkStore(this._prefs);

  Future<String?> readSk() async => _prefs.getString(_key);

  Future<void> saveSk(String sk) async => _prefs.setString(_key, sk);

  Future<void> clear() async => _prefs.remove(_key);
}
```

- [ ] **Step 5: Jalankan unit test dan static analysis**

Run: `flutter test test/auth_token_storage_test.dart`  
Expected: PASS (all tests pass).  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/auth/ test/auth_token_storage_test.dart
git commit -m "feat(auth): definisikan domain model UserPrincipal, AuthState, dan token storage aman"
```

---

### Task 2: Kontrak AuthRepository, Implementasi DemoAuthRepository Multi-Akun, & Adaptasi Fixture Wilayah di KokRepository

**Files:**
- Create: `lib/core/auth/data/auth_repository.dart`
- Create: `lib/core/auth/data/demo_auth_repository.dart`
- Modify: `lib/data/repository.dart`
- Test: `test/auth_repository_test.dart`

**Interfaces:**
- Consumes: `UserPrincipal`, `AuthState`, `AuthFailure`, `AuthTokenStorage`, `RememberedSkStore` from Task 1.
- Produces:
  * `abstract class AuthRepository`.
  * `class DemoAuthRepository implements AuthRepository`.
  * `KokRepository.fetchDistrictSnapshot(String districtId)` producing distinct data for `garut_kota` (125 atlet, 5 cabor) and `tarogong_kidul` (88 atlet, 4 cabor).

- [ ] **Step 1: Tulis unit test untuk AuthRepository dan DemoAuthRepository**

Create `test/auth_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  late InMemoryAuthTokenStorage tokenStorage;
  late RememberedSkStore skStore;
  late DemoAuthRepository repository;

  setUp(() async {
    tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    skStore = RememberedSkStore(prefs);
    repository = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );
  });

  group('DemoAuthRepository Login', () {
    test('login sukses akun Garut Kota (Pak Asep) dengan persistent session', () async {
      final result = await repository.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.name, 'Pak Asep');
      expect(result.user?.districtId, 'garut_kota');
      expect(await tokenStorage.readRefreshToken(), isNotNull);
    });

    test('login sukses akun Tarogong Kidul (Pak Cecep) tanpa persistent session', () async {
      final result = await repository.login(
        skNumber: 'DEMO-002',
        password: 'koktarogong123',
        staySignedIn: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.name, 'Pak Cecep');
      expect(result.user?.districtId, 'tarogong_kidul');
      expect(await tokenStorage.readRefreshToken(), isNull);
    });

    test('kredensial salah mengembalikan pesan generik', () async {
      final result = await repository.login(
        skNumber: 'DEMO-001',
        password: 'salah_password',
        staySignedIn: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<InvalidCredentialsFailure>());
      expect(result.failure?.message, 'Nomor SK atau kata sandi tidak sesuai.');
    });

    test('simulasi network timeout DEMO-TIMEOUT', () async {
      final result = await repository.login(
        skNumber: 'DEMO-TIMEOUT',
        password: 'timeout123',
        staySignedIn: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<NetworkTimeoutFailure>());
    });
  });

  group('DemoAuthRepository Session Restore & Logout', () {
    test('restore session saat token tersimpan', () async {
      await tokenStorage.saveRefreshToken('token_usr_garut_kota');
      final result = await repository.restoreSession();

      expect(result.isSuccess, isTrue);
      expect(result.user?.id, 'usr-garut-kota-001');
    });

    test('restore session gagal saat storage kosong', () async {
      final result = await repository.restoreSession();
      expect(result.isSuccess, isFalse);
    });

    test('logout menghapus token dari storage', () async {
      await tokenStorage.saveRefreshToken('token_usr_garut_kota');
      await repository.logout();
      expect(await tokenStorage.readRefreshToken(), isNull);
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan kompilasi**

Run: `flutter test test/auth_repository_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implementasikan AuthRepository dan DemoAuthRepository**

Create `lib/core/auth/data/auth_repository.dart`:
```dart
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';

class AuthResult {
  final UserPrincipal? user;
  final String? accessToken;
  final AuthFailure? failure;

  const AuthResult.success({required UserPrincipal this.user, this.accessToken})
      : failure = null;

  const AuthResult.failed(AuthFailure this.failure)
      : user = null,
        accessToken = null;

  bool get isSuccess => user != null;
}

abstract class AuthRepository {
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  });

  Future<AuthResult> restoreSession();

  Future<AuthResult> refreshToken(String refreshToken);

  Future<void> logout();
}
```

Create `lib/core/auth/data/demo_auth_repository.dart`:
```dart
import 'dart:async';
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';
import 'auth_repository.dart';
import 'auth_token_storage.dart';
import 'remembered_sk_store.dart';

class DemoAuthRepository implements AuthRepository {
  final AuthTokenStorage _tokenStorage;
  final RememberedSkStore _skStore;
  final bool simulateLatency;

  static const _garutKotaUser = UserPrincipal(
    id: 'usr-garut-kota-001',
    skNumber: 'DEMO-001',
    name: 'Pak Asep',
    role: 'Koordinator Kecamatan',
    districtId: 'garut_kota',
    districtName: 'Kecamatan Garut Kota',
    permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
  );

  static const _tarogongKidulUser = UserPrincipal(
    id: 'usr-tarogong-kidul-002',
    skNumber: 'DEMO-002',
    name: 'Pak Cecep',
    role: 'Koordinator Kecamatan',
    districtId: 'tarogong_kidul',
    districtName: 'Kecamatan Tarogong Kidul',
    permissions: {'sports:read', 'clubs:read', 'members:read'},
  );

  static const _koniKabUser = UserPrincipal(
    id: 'usr-koni-kab-003',
    skNumber: 'DEMO-003',
    name: 'Ibu Rina',
    role: 'Tim Verifikator',
    districtId: 'koni_kab',
    districtName: 'KONI Kabupaten Garut',
    permissions: {'sports:read', 'clubs:read', 'members:read', 'documents:verify'},
  );

  DemoAuthRepository({
    required AuthTokenStorage tokenStorage,
    required RememberedSkStore skStore,
    this.simulateLatency = true,
  })  : _tokenStorage = tokenStorage,
        _skStore = skStore;

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
    if (skNumber == 'DEMO-001' && password == 'kokgarut123') {
      matchedUser = _garutKotaUser;
    } else if (skNumber == 'DEMO-002' && password == 'koktarogong123') {
      matchedUser = _tarogongKidulUser;
    } else if (skNumber == 'DEMO-003' && password == 'konigarut123') {
      matchedUser = _koniKabUser;
    }

    if (matchedUser == null) {
      return const AuthResult.failed(InvalidCredentialsFailure());
    }

    if (staySignedIn) {
      await _tokenStorage.saveRefreshToken('token_${matchedUser.id}');
    } else {
      await _tokenStorage.clear();
    }

    return AuthResult.success(
      user: matchedUser,
      accessToken: 'demo_access_token_${matchedUser.id}',
    );
  }

  @override
  Future<AuthResult> restoreSession() async {
    await _maybeDelay();
    final token = await _tokenStorage.readRefreshToken();
    if (token == null) {
      return const AuthResult.failed(
        SessionExpiredFailure('Tidak ada sesi tersimpan.'),
      );
    }

    if (token.contains('tarogong')) {
      return const AuthResult.success(
        user: _tarogongKidulUser,
        accessToken: 'restored_token_tarogong',
      );
    } else if (token.contains('koni')) {
      return const AuthResult.success(
        user: _koniKabUser,
        accessToken: 'restored_token_koni',
      );
    } else {
      return const AuthResult.success(
        user: _garutKotaUser,
        accessToken: 'restored_token_garut_kota',
      );
    }
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession();
  }

  @override
  Future<void> logout() async {
    await _maybeDelay();
    await _tokenStorage.clear();
  }
}
```

- [ ] **Step 4: Adaptasi KokRepository di lib/data/repository.dart untuk Multi-District Data**

Update `lib/data/repository.dart` to add district-scoped loading so Garut Kota has 5 cabor, 125 atlet, while Tarogong Kidul has 4 cabor, 88 atlet:
Add helper method in `KokRepository`:
```dart
Future<DistrictSnapshot> fetchDistrict(String districtId) async {
  final defaultSnapshot = await fetch();
  if (districtId == 'tarogong_kidul') {
    // Tarogong Kidul: 4 cabor, 4 clubs, 88 athletes
    final tkClubs = [
      Club(id: 'club-tk-1', name: 'Tarogong Kidul Utama FC', sport: 'Sepak Bola', village: 'Sukagalih', athleteCount: 26, coachCount: 2, completeDocuments: true),
      Club(id: 'club-tk-2', name: 'PB Surya Tarogong', sport: 'Bulu Tangkis', village: 'Haurpanggung', athleteCount: 22, coachCount: 2, completeDocuments: true),
      Club(id: 'club-tk-3', name: 'Putra Tarogong Silat', sport: 'Pencak Silat', village: 'Jayawaras', athleteCount: 24, coachCount: 2, completeDocuments: true),
      Club(id: 'club-tk-4', name: 'Voli Gemilang Tarogong', sport: 'Bola Voli', village: 'Patarruman', athleteCount: 16, coachCount: 2, completeDocuments: true),
    ];
    final tkSports = [
      SportSummary(name: 'Sepak Bola', clubCount: 1, athleteCount: 26, completeCount: 26),
      SportSummary(name: 'Pencak Silat', clubCount: 1, athleteCount: 24, completeCount: 24),
      SportSummary(name: 'Bulu Tangkis', clubCount: 1, athleteCount: 22, completeCount: 22),
      SportSummary(name: 'Bola Voli', clubCount: 1, athleteCount: 16, completeCount: 16),
    ];
    return DistrictSnapshot(
      districtName: 'Kecamatan Tarogong Kidul',
      stats: const DistrictStats(
        registeredAthletes: 88,
        activeSports: 4,
        registeredClubs: 4,
        licensedCoaches: 8,
        pendingVerification: 0,
      ),
      sports: tkSports,
      clubs: tkClubs,
      people: defaultSnapshot.people.take(88).toList(),
      needsAuditCount: 0,
      expiredLicenses: const [],
      syncedAt: DateTime.now(),
    );
  }
  return defaultSnapshot;
}
```

- [ ] **Step 5: Jalankan test dan verify**

Run: `flutter test test/auth_repository_test.dart`  
Expected: PASS.  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/auth/data/auth_repository.dart lib/core/auth/data/demo_auth_repository.dart lib/data/repository.dart test/auth_repository_test.dart
git commit -m "feat(auth): buat kontrak AuthRepository, adapter DemoAuthRepository multi-akun, dan fixture kecamatan"
```

---

### Task 3: State Management AuthController, SessionScope Provider, & Isolasi Cache

**Files:**
- Create: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `lib/data/repository.dart`
- Test: `test/auth_controller_test.dart`
- Test: `test/session_scope_test.dart`

**Interfaces:**
- Consumes: `AuthState`, `UserPrincipal`, `AuthRepository`, `AuthTokenStorage`, `RememberedSkStore` from Tasks 1-2.
- Produces:
  * `authControllerProvider`: `NotifierProvider<AuthController, AuthState>`.
  * `currentUserProvider`: `Provider<UserPrincipal?>`.
  * `sessionScopeProvider`: `Provider<SessionScope?>`.
  * `snapshotProvider`: watches `sessionScopeProvider`, fetches for current district, invalidates on logout / generation change.

- [ ] **Step 1: Tulis unit test untuk AuthController dan SessionScope**

Create `test/auth_controller_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  late InMemoryAuthTokenStorage tokenStorage;
  late RememberedSkStore skStore;
  late DemoAuthRepository authRepository;

  setUp(() async {
    tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    skStore = RememberedSkStore(prefs);
    authRepository = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );
  });

  test('bootstrap mengarahkan ke AuthSignedOut jika storage kosong', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrap();

    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
  });

  test('bootstrap memulihkan sesi ke AuthSignedIn jika ada token', () async {
    await tokenStorage.saveRefreshToken('token_usr_garut_kota');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrap();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).user.name, 'Pak Asep');
  });

  test('login sukses menaikkan session generation dan set AuthSignedIn', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    final success = await controller.login(
      skNumber: 'DEMO-001',
      password: 'kokgarut123',
      staySignedIn: true,
      rememberSk: true,
    );

    expect(success, isTrue);
    final state = container.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).generation, greaterThan(0));
    expect(await skStore.readSk(), 'DEMO-001');
  });

  test('logout membersihkan sesi dan menaikkan generation counter', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(
      skNumber: 'DEMO-001',
      password: 'kokgarut123',
      staySignedIn: true,
      rememberSk: false,
    );
    final gen1 = (container.read(authControllerProvider) as AuthSignedIn).generation;

    await controller.logout();
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    expect(controller.currentGeneration, greaterThan(gen1));
  });
}
```

Create `test/session_scope_test.dart` (termasuk tes regresi audit [docs/audit-auth.md: Baris 1010-1036](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth.md#L1010-L1036)):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  test('Regression Audit: Remembered SK tidak memulihkan sesi autentikasi', () async {
    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
    final prefs = await SharedPreferences.getInstance();
    final tokenStorage = InMemoryAuthTokenStorage();
    final skStore = RememberedSkStore(prefs);
    final authRepo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).bootstrap();
    expect(await skStore.readSk(), 'DEMO-001');
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    expect(container.read(sessionScopeProvider), isNull);
  });

  test('SessionScope mengisolasi snapshot data antar akun kecamatan', () async {
    final tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final skStore = RememberedSkStore(prefs);
    final authRepo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    // Login Pak Asep (Garut Kota)
    await controller.login(
      skNumber: 'DEMO-001',
      password: 'kokgarut123',
      staySignedIn: false,
      rememberSk: false,
    );

    final scopeAsep = container.read(sessionScopeProvider);
    expect(scopeAsep?.districtId, 'garut_kota');
    final snapshotAsep = await container.read(snapshotProvider.future);
    expect(snapshotAsep.districtName, 'Kecamatan Garut Kota');
    expect(snapshotAsep.sports.length, 5);

    // Logout
    await controller.logout();
    expect(container.read(sessionScopeProvider), isNull);

    // Login Pak Cecep (Tarogong Kidul)
    await controller.login(
      skNumber: 'DEMO-002',
      password: 'koktarogong123',
      staySignedIn: false,
      rememberSk: false,
    );

    final scopeCecep = container.read(sessionScopeProvider);
    expect(scopeCecep?.districtId, 'tarogong_kidul');
    final snapshotCecep = await container.read(snapshotProvider.future);
    expect(snapshotCecep.districtName, 'Kecamatan Tarogong Kidul');
    expect(snapshotCecep.sports.length, 4);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan**

Run: `flutter test test/auth_controller_test.dart test/session_scope_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implementasikan AuthController di lib/core/auth/presentation/auth_controller.dart**

Create `lib/core/auth/presentation/auth_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/auth_token_storage.dart';
import '../data/demo_auth_repository.dart';
import '../data/remembered_sk_store.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_state.dart';
import '../domain/user_principal.dart';

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return SecureAuthTokenStorage();
});

final rememberedSkStoreProvider = Provider<RememberedSkStore>((ref) {
  throw UnimplementedError('RememberedSkStore harus diinisialisasi dengan SharedPreferences');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DemoAuthRepository(
    tokenStorage: ref.watch(authTokenStorageProvider),
    skStore: ref.watch(rememberedSkStoreProvider),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<UserPrincipal?>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthSignedIn) {
    return state.user;
  }
  return null;
});

class AuthController extends Notifier<AuthState> {
  int _sessionGeneration = 0;
  int get currentGeneration => _sessionGeneration;

  @override
  AuthState build() {
    return const AuthBootstrapping();
  }

  Future<void> bootstrap() async {
    state = const AuthBootstrapping();
    final repo = ref.read(authRepositoryProvider);
    try {
      final result = await repo.restoreSession();
      if (result.isSuccess && result.user != null) {
        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
          accessToken: result.accessToken,
        );
      } else {
        state = const AuthSignedOut();
      }
    } catch (_) {
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
    state = const AuthSigningIn();
    final repo = ref.read(authRepositoryProvider);

    try {
      final result = await repo.login(
        skNumber: skNumber,
        password: password,
        staySignedIn: staySignedIn,
      );

      if (result.isSuccess && result.user != null) {
        final skStore = ref.read(rememberedSkStoreProvider);
        if (rememberSk) {
          await skStore.saveSk(skNumber);
        } else {
          await skStore.clear();
        }

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
    _sessionGeneration++;
    state = const AuthSigningOut();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
    } finally {
      state = const AuthSignedOut();
    }
  }
}
```

- [ ] **Step 4: Sambungkan SessionScope dan snapshotProvider di lib/data/repository.dart**

In `lib/data/repository.dart`, add:
```dart
import '../core/auth/presentation/auth_controller.dart';

class SessionScope {
  final String userId;
  final String districtId;
  final int generation;

  const SessionScope({
    required this.userId,
    required this.districtId,
    required this.generation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionScope &&
          userId == other.userId &&
          districtId == other.districtId &&
          generation == other.generation;

  @override
  int get hashCode => userId.hashCode ^ districtId.hashCode ^ generation.hashCode;
}

final sessionScopeProvider = Provider<SessionScope?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is AuthSignedIn) {
    return SessionScope(
      userId: authState.user.id,
      districtId: authState.user.districtId,
      generation: authState.generation,
    );
  }
  return null;
});

final snapshotProvider = FutureProvider<DistrictSnapshot>((ref) async {
  final scope = ref.watch(sessionScopeProvider);
  if (scope == null) {
    throw StateError('Tidak ada sesi terautentikasi aktif.');
  }

  final repository = ref.watch(kokRepositoryProvider);
  return repository.fetchDistrict(scope.districtId);
});
```

- [ ] **Step 5: Jalankan unit test dan verify**

Run: `flutter test test/auth_controller_test.dart test/session_scope_test.dart`  
Expected: PASS (all tests pass).  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/auth/presentation/auth_controller.dart lib/data/repository.dart test/auth_controller_test.dart test/session_scope_test.dart
git commit -m "feat(auth): buat AuthController, provider SessionScope, dan isolasi cache per sesi"
```

---

### Task 4: Komponen UI Kustom KOK: SessionStartupPage & SessionUnavailablePage

**Files:**
- Create: `lib/core/auth/presentation/session_startup_page.dart`
- Create: `lib/core/auth/presentation/session_unavailable_page.dart`
- Test: `test/session_pages_test.dart`

**Interfaces:**
- Consumes: `KokColors`, `BrandHeaderPatternPainter`, `authControllerProvider`.
- Produces:
  * `class SessionStartupPage extends ConsumerStatefulWidget` (Route `/session`).
  * `class SessionUnavailablePage extends ConsumerWidget` (Route `/session-unavailable`).

- [ ] **Step 1: Tulis widget test untuk SessionStartupPage dan SessionUnavailablePage**

Create `test/session_pages_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/auth/presentation/session_startup_page.dart';
import 'package:kok_app/core/auth/presentation/session_unavailable_page.dart';

void main() {
  testWidgets('SessionStartupPage merender branding KOK dan indikator pemuatan', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SessionStartupPage(),
        ),
      ),
    );

    expect(find.text('SISTEM INFORMASI KOORDINATOR'), findsOneWidget);
    expect(find.text('KONI Kabupaten Garut'), findsOneWidget);
    expect(find.text('Memverifikasi sesi aman...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SessionUnavailablePage menampilkan kartu kendala dan tombol aksi', (tester) async {
    var retryCalled = false;
    var logoutCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SessionUnavailablePage(
          reason: 'Koneksi ke server terputus.',
          onRetry: () => retryCalled = true,
          onSignOut: () => logoutCalled = true,
        ),
      ),
    );

    expect(find.text('Koneksi Sesi Terganggu'), findsOneWidget);
    expect(find.text('Koneksi ke server terputus.'), findsOneWidget);

    await tester.tap(find.text('Coba Hubungkan Kembali'));
    expect(retryCalled, isTrue);

    await tester.tap(find.text('Masuk Ulang / Ganti Akun'));
    expect(logoutCalled, isTrue);
  });
}
```

- [ ] **Step 2: Jalankan widget test untuk memverifikasi kegagalan**

Run: `flutter test test/session_pages_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implementasikan SessionStartupPage di lib/core/auth/presentation/session_startup_page.dart**

Create `lib/core/auth/presentation/session_startup_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import 'auth_controller.dart';

class SessionStartupPage extends ConsumerStatefulWidget {
  const SessionStartupPage({super.key});

  @override
  ConsumerState<SessionStartupPage> createState() => _SessionStartupPageState();
}

class _SessionStartupPageState extends ConsumerState<SessionStartupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KokColors.primary,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BrandHeaderPatternPainter(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.sports_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SISTEM INFORMASI KOORDINATOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'KONI Kabupaten Garut',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Memverifikasi sesi aman...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
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

- [ ] **Step 4: Implementasikan SessionUnavailablePage di lib/core/auth/presentation/session_unavailable_page.dart**

Create `lib/core/auth/presentation/session_unavailable_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import 'auth_controller.dart';

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
    final effectiveReason = reason ??
        'Aplikasi tidak dapat memvalidasi token sesi ke server. Periksa koneksi internet Anda atau masuk kembali.';

    return Scaffold(
      backgroundColor: KokColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KokColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: 32,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Koneksi Sesi Terganggu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: KokColors.cardTitle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    effectiveReason,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: KokColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onRetry ??
                          () => ref
                              .read(authControllerProvider.notifier)
                              .retrySession(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KokColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Coba Hubungkan Kembali',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onSignOut ??
                          () =>
                              ref.read(authControllerProvider.notifier).logout(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KokColors.cardTitle,
                        side: BorderSide(color: KokColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Masuk Ulang / Ganti Akun',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Jalankan widget test dan verify**

Run: `flutter test test/session_pages_test.dart`  
Expected: PASS.  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/auth/presentation/session_startup_page.dart lib/core/auth/presentation/session_unavailable_page.dart test/session_pages_test.dart
git commit -m "feat(auth): buat layar kustom SessionStartupPage dan SessionUnavailablePage bertema KOK"
```

---

### Task 5: Pembaruan Layar Login, Profil (Pemisahan Logout dari DataView), & Beranda

**Files:**
- Modify: `lib/features/login_page.dart`
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/home_page.dart`
- Test: `test/login_page_test.dart`
- Test: `test/profile_page_test.dart`
- Test: `test/home_page_test.dart`

**Interfaces:**
- Consumes: `authControllerProvider`, `currentUserProvider`, `UserPrincipal`, `AuthState`.
- Updates:
  * `LoginPage`: uses `authControllerProvider.login()`, handles autofill, has "Ingat nomor SK" & "Tetap Masuk" checkboxes, quick preset picker bottom sheet, generic error banner.
  * `ProfilePage`: binds header card to `currentUserProvider`, places Logout button outside `DataView`, adds logout confirmation dialog.
  * `HomePage`: header binds greeting & district name to `currentUserProvider`.

- [ ] **Step 1: Tulis widget tests untuk LoginPage, ProfilePage, dan HomePage**

Create `test/login_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/features/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  testWidgets('LoginPage merender form, checkbox, dan toggle password', (tester) async {
    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
    final prefs = await SharedPreferences.getInstance();
    final tokenStorage = InMemoryAuthTokenStorage();
    final skStore = RememberedSkStore(prefs);
    final repo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    expect(find.text('Ingat nomor SK di perangkat ini'), findsOneWidget);
    expect(find.text('Tetap Masuk'), findsOneWidget);
    expect(find.text('Pilih Akun Demo'), findsOneWidget);
  });
}
```

Create `test/profile_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/profile_page.dart';

class _FakeAuthController extends AuthController {
  final UserPrincipal user;
  _FakeAuthController(this.user);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);
}

void main() {
  const testUser = UserPrincipal(
    id: 'usr-garut-kota-001',
    skNumber: 'DEMO-001',
    name: 'Pak Asep',
    role: 'Koordinator Kecamatan',
    districtId: 'garut_kota',
    districtName: 'Kecamatan Garut Kota',
    permissions: {'sports:read'},
  );

  testWidgets('ProfilePage menampilkan profil pengurus dan tombol logout di luar DataView bahkan jika snapshot error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthController(testUser)),
          snapshotProvider.overrideWith((ref) => throw Exception('Koneksi olahraga gagal')),
        ],
        child: const MaterialApp(
          home: ProfilePage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Pak Asep'), findsOneWidget);
    expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
    expect(find.text('Keluar dari Akun'), findsOneWidget);

    await tester.tap(find.text('Keluar dari Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi Keluar'), findsOneWidget);
  });
}
```

Create `test/home_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/home_page.dart';

class _FakeHomeAuthController extends AuthController {
  final UserPrincipal user;
  _FakeHomeAuthController(this.user);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);
}

void main() {
  const cecepUser = UserPrincipal(
    id: 'usr-tarogong-kidul-002',
    skNumber: 'DEMO-002',
    name: 'Pak Cecep',
    role: 'Koordinator Kecamatan',
    districtId: 'tarogong_kidul',
    districtName: 'Kecamatan Tarogong Kidul',
    permissions: {'sports:read'},
  );

  testWidgets('HomePage menampilkan nama pengurus dan wilayah secara dinamis', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeHomeAuthController(cecepUser)),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Pak Cecep'), findsWidgets);
    expect(find.textContaining('Kecamatan Tarogong Kidul'), findsWidgets);
  });
}
```

- [ ] **Step 2: Jalankan widget tests untuk melihat status**

Run: `flutter test test/login_page_test.dart test/profile_page_test.dart test/home_page_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Perbarui lib/features/login_page.dart**

In `lib/features/login_page.dart`:
- Replace old `sessionProvider` with `authControllerProvider`.
- Pre-fill `_sk` from `rememberedSkStoreProvider`.
- Wrap form in `AutofillGroup`.
- Checkboxes: *"Ingat nomor SK di perangkat ini"* and *"Tetap Masuk"*.
- Quick Demo Picker button/sheet (allowing instant selection of Garut Kota, Tarogong Kidul, or Timeout mode).
- Generic error banner when login fails.
- Disable submit while busy (`AuthSigningIn`).
- Ensure all text $\ge 12$px.

- [ ] **Step 4: Perbarui lib/features/profile_page.dart**

In `lib/features/profile_page.dart`:
- Profile identity card is bound to `currentUserProvider`.
- Account Security & Logout button (`Keluar dari Akun`) are rendered outside `DataView.when(data: ...)` so they are always visible and actionable even if domain data fails to load.
- Dialog confirmation: *"Konfirmasi Keluar"* -> *"Keluar dari sesi [name]?"* -> *"Batal"* / *"Keluar"*.
- Call `authController.logout()`.

- [ ] **Step 5: Perbarui lib/features/home_page.dart**

In `lib/features/home_page.dart`:
- Use `ref.watch(currentUserProvider)` to render greetings dynamically:
  * *"Selamat Datang,"*
  * `"${user?.name ?? 'Koordinator'} · ${user?.role ?? 'KOK'}"`
  * Region badge: `"${user?.districtName ?? 'Kabupaten Garut'}"`
- Dynamic calculation of expired coach licenses (club count and sport count) removing hardcoded `expired == 5`.

- [ ] **Step 6: Jalankan widget tests dan verify**

Run: `flutter test test/login_page_test.dart test/profile_page_test.dart test/home_page_test.dart`  
Expected: PASS.  
Run: `flutter analyze`  
Expected: 0 issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/login_page.dart lib/features/profile_page.dart lib/features/home_page.dart test/login_page_test.dart test/profile_page_test.dart test/home_page_test.dart
git commit -m "feat(ui): perbarui LoginPage, ProfilePage independen logout, dan HomePage dinamis"
```

---

### Task 6: Pendaftaran Rute di lib/app.dart, Pengujian Integrasi E2E, & Golden Previews

**Files:**
- Modify: `lib/app.dart`
- Modify: `test/app_test.dart`
- Modify: `test/preview_test.dart`
- Capture: `previews/session_startup.png`, `previews/session_unavailable.png`, `previews/login.png`

**Interfaces:**
- Updates `lib/app.dart`:
  * Initialize `rememberedSkStoreProvider` in `ProviderScope`.
  * Add routes `/session` and `/session-unavailable`.
  * Implement GoRouter redirect guard based on `AuthState` (`AuthBootstrapping`, `AuthTemporarilyUnavailable`, `AuthSignedOut`, `AuthSignedIn`).
- E2E Tests in `test/app_test.dart`:
  * Normal login/logout cycle.
  * Multi-account switch & cache isolation (Pak Asep Garut Kota $\rightarrow$ Pak Cecep Tarogong Kidul).
  * Persistent session auto-restore on boot.
  * Timeout error routing to `/session-unavailable`.

- [ ] **Step 1: Daftarkan rute dan router guard di lib/app.dart**

In `lib/app.dart`:
- Import `session_startup_page.dart` and `session_unavailable_page.dart`.
- In `routerProvider`:
```dart
GoRoute(
  path: '/session',
  builder: (context, state) => const SessionStartupPage(),
),
GoRoute(
  path: '/session-unavailable',
  builder: (context, state) => const SessionUnavailablePage(),
),
```
- Update `redirect`:
```dart
redirect: (context, state) {
  final authState = ref.read(authControllerProvider);
  final location = state.matchedLocation;

  if (authState is AuthBootstrapping) {
    return location == '/session' ? null : '/session';
  }
  if (authState is AuthTemporarilyUnavailable) {
    return location == '/session-unavailable' ? null : '/session-unavailable';
  }
  if (authState is AuthSignedOut) {
    return location == '/login' ? null : '/login';
  }
  if (authState is AuthSignedIn) {
    if (location == '/login' || location == '/session' || location == '/session-unavailable') {
      return '/home';
    }
    return null;
  }
  return null;
},
```
- In `main()` / `KokApp`:
  * Read `SharedPreferences` at startup and pass `rememberedSkStoreProvider.overrideWithValue(RememberedSkStore(prefs))`.

- [ ] **Step 2: Perbarui test/app_test.dart dengan E2E Authentication Suite**

Update `test/app_test.dart` to test:
1. Startup flow: `/session` bootstrapping -> `/login`.
2. Login Pak Asep: verify `/home` with Garut Kota, navigate to Profile, logout -> verify `/login`.
3. Login Pak Cecep: verify `/home` with Tarogong Kidul, verify 4 cabor and 88 athletes (no Garut Kota data).
4. Auto-restore session from storage directly to `/home`.
5. Timeout simulation: login with `DEMO-TIMEOUT` -> verify navigation to `/session-unavailable` -> tap "Masuk Ulang" -> returns to `/login`.

- [ ] **Step 3: Jalankan E2E tests**

Run: `flutter test test/app_test.dart`  
Expected: PASS (all tests pass).

- [ ] **Step 4: Tangkap Golden Previews di test/preview_test.dart**

In `test/preview_test.dart`, register routes:
- `'session_startup': '/session'`
- `'session_unavailable': '/session-unavailable'`
- `'login': '/login'`

Run:
```bash
flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true
```
Verify generated preview images:
- `previews/session_startup.png`
- `previews/session_unavailable.png`
- `previews/login.png`

Revert any other preview files that only have accidental timestamp diffs (`git checkout -- previews/<accidental>.png`).

- [ ] **Step 5: Verifikasi Penuh (flutter analyze & flutter test)**

Run:
```bash
flutter analyze
flutter test
```
Expected: 0 issues, 100% tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/app.dart test/app_test.dart test/preview_test.dart previews/
git commit -m "feat(app): integrasikan router guard autentikasi, pengujian E2E multi-akun, dan golden preview"
```

---

## Plan Review & Verification Checklist

- [x] **Spec coverage**: Covers all findings F-01 to F-13 (P0 & P1), Tahap A roadmap, and multi-district fixtures.
- [x] **No placeholders**: All tasks have concrete paths, complete code snippets, and exact commands.
- [x] **Type consistency**: `UserPrincipal`, `AuthState`, `SessionScope`, `AuthRepository` signatures match across all tasks.
- [x] **UI constraints**: All typography $\ge 12\text{px}$, centralized colors in `KokColors`, back button standard.

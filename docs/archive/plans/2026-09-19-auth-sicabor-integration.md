# Auth SICABOR + Profile Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the KOK mobile app with the official SICABOR REST API starting with the single 24-hour token authentication lifecycle and profile validation (`login` → `GET /profile` → persistent session save → app restart / restore → `logout` / 401 invalidation).

**Architecture:** Replace the legacy dual-token (access + refresh) protocol with SICABOR's single 24-hour token contract while preserving defensive architectural guarantees (Riverpod state machine, route guards, secure storage with schema v3, mutation queue, credential ownership, generation counter, stale-response rejection). Unify user identification from `skNumber` to `username`, enforce server-authoritative subdistrict scope verification via `GET /profile`, and convert HTTP 401 responses into clean centralized session invalidations.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), Dio, `flutter_secure_storage`, `shared_preferences`, GoRouter (`go_router`).

## Global Constraints

- **Single token model:** No refresh token and no remote token extension endpoint. Token lasts 24 hours.
- **Login endpoint:** `POST /api/auth` with `application/x-www-form-urlencoded` and envelope `{ status: true, data: { ... }, token: "..." }`.
- **KOK Profile endpoint:** `GET /api/v1/kok/profile` with `Authorization: Bearer <token>` and envelope `{ success: true, scope: { ... }, data: { ... } }`.
- **Role gate:** Only `data.type == "admin_kok"` may enter the application.
- **Scope mapping:** `scope.subdistrict_id` (integer) maps to internal kecamatan scope ID (`AccessScopeType.district`, id as string).
- **Naming & storage migration:** All `skNumber` naming updated to `username`. Secure storage upgraded to schema key `v3` (`kok.auth.v3.<env>.*`), purging legacy keys on bootstrap.
- **Error handling:** 401 immediately invalidates session without retry; 403 with `MEMBER_NOT_FOUND` / `MEMBER_INACTIVE` / `NOT_KOK` forces logout; 403 `NO_SUBDISTRICT` blocks data access without logout; offline/timeout transitions to `AuthTemporarilyUnavailable` preserving stored credentials.

---

### Task 1: Domain & Failure Layer Updates (`AuthFailure`, `UserPrincipal`, `RememberedUsernameStore`)

**Files:**
- Modify: `lib/core/auth/domain/auth_failure.dart:1-30`
- Modify: `lib/core/auth/domain/user_principal.dart:1-142`
- Delete: `lib/core/auth/data/remembered_sk_store.dart`
- Create: `lib/core/auth/data/remembered_username_store.dart`
- Test: `test/user_principal_test.dart`
- Create: `test/remembered_username_store_test.dart`

**Interfaces:**
- Consumes: None (base domain layer).
- Produces:
  - `UserPrincipal` with `username` property (renamed from `skNumber`).
  - `AuthFailure` subclasses: `InvalidCredentialsFailure`, `NetworkTimeoutFailure`, `SessionExpiredFailure`, `StorageErrorFailure`, `AccountNotKokFailure`, `AccountInactiveFailure`, `NoSubdistrictFailure`, `MemberNotFoundFailure`, `ProfileFetchFailedFailure`.
  - `RememberedUsernameStore`: `Future<String?> readUsername()`, `Future<void> saveUsername(String username)`, `Future<void> clear()`.

- [ ] **Step 1: Write the failing tests for updated `UserPrincipal` and `RememberedUsernameStore`**

```dart
// test/user_principal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_garut/core/auth/domain/user_principal.dart';

void main() {
  group('UserPrincipal', () {
    test('serializes and deserializes with username correctly', () {
      final user = UserPrincipal(
        id: '560',
        username: 'kt.bllimbangan',
        fullName: 'ADMIN KONTINGEN BL.LIMBANGAN',
        roleTitle: 'Koordinator Kecamatan',
        scope: const AccessScope(
          type: AccessScopeType.district,
          id: '1714',
          name: 'Blubur Limbangan',
        ),
        permissions: const {},
      );

      final json = user.toJson();
      expect(json['username'], equals('kt.bllimbangan'));
      expect(json.containsKey('skNumber'), isFalse);

      final deserialized = UserPrincipal.fromJson(json);
      expect(deserialized, equals(user));
      expect(deserialized.username, equals('kt.bllimbangan'));
    });
  });
}
```

```dart
// test/remembered_username_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kok_garut/core/auth/data/remembered_username_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RememberedUsernameStore', () {
    test('saves, reads, and clears username in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedUsernameStore(prefs: prefs, key: 'test_username_key');

      expect(await store.readUsername(), isNull);

      await store.saveUsername('kt.garutkota');
      expect(await store.readUsername(), equals('kt.garutkota'));

      await store.clear();
      expect(await store.readUsername(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/user_principal_test.dart test/remembered_username_store_test.dart`
Expected: FAIL with compilation errors (missing `username` / missing `remembered_username_store.dart`).

- [ ] **Step 3: Implement `auth_failure.dart`, `user_principal.dart`, and `remembered_username_store.dart`**

Update `lib/core/auth/domain/auth_failure.dart`:
```dart
sealed class AuthFailure {
  final String message;
  const AuthFailure(this.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.message = 'Username atau kata sandi tidak sesuai.',
  ]);
}

class NetworkTimeoutFailure extends AuthFailure {
  const NetworkTimeoutFailure([
    super.message =
        'Koneksi ke server autentikasi terputus. Silakan coba lagi.',
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

class AccountNotKokFailure extends AuthFailure {
  const AccountNotKokFailure([
    super.message = 'Akun ini bukan akun KOK dan tidak memiliki akses.',
  ]);
}

class AccountInactiveFailure extends AuthFailure {
  const AccountInactiveFailure([
    super.message = 'Akun Anda berstatus non-aktif. Hubungi admin SICABOR.',
  ]);
}

class NoSubdistrictFailure extends AuthFailure {
  const NoSubdistrictFailure([
    super.message = 'Akun belum memiliki kecamatan yang terdaftar. Hubungi admin.',
  ]);
}

class MemberNotFoundFailure extends AuthFailure {
  const MemberNotFoundFailure([
    super.message = 'Data akun anggota tidak ditemukan pada sistem SICABOR.',
  ]);
}

class ProfileFetchFailedFailure extends AuthFailure {
  const ProfileFetchFailedFailure([
    super.message = 'Gagal memuat data profil akun dari server.',
  ]);
}
```

Update `lib/core/auth/domain/user_principal.dart`:
Replace all instances of `skNumber` with `username`.

Create `lib/core/auth/data/remembered_username_store.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

final class RememberedUsernameStore {
  RememberedUsernameStore({required SharedPreferences prefs, required String key})
      : _prefs = prefs,
        _key = key;

  final SharedPreferences _prefs;
  final String _key;

  Future<String?> readUsername() async {
    final val = _prefs.getString(_key);
    if (val == null || val.trim().isEmpty) return null;
    return val.trim();
  }

  Future<void> saveUsername(String username) async {
    await _prefs.setString(_key, username.trim());
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/user_principal_test.dart test/remembered_username_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/auth/domain/ lib/core/auth/data/remembered_username_store.dart test/user_principal_test.dart test/remembered_username_store_test.dart
git commit -m "feat(auth): update domain entities to username and add SICABOR auth failures"
```

---

### Task 2: Auth Contracts & Storage Schema v3 (`AuthRepository`, `AuthResult`, `AuthTokenStorage`)

**Files:**
- Modify: `lib/core/auth/data/auth_repository.dart:1-87`
- Modify: `lib/core/auth/data/auth_token_storage.dart:1-126`
- Modify: `lib/core/auth/data/demo_auth_repository.dart:1-165`
- Test: `test/auth_token_storage_test.dart`
- Test: `test/auth_repository_test.dart`

**Interfaces:**
- Consumes: `UserPrincipal`, `AuthFailure`.
- Produces:
  - `AuthResult.success({required UserPrincipal user, String? accessToken, String? sessionToken, RemoteSessionHandle? sessionHandle, RemoteSessionHandle? remoteHandle})`.
  - `AuthRepository`: `login({required String username, required String password, required bool staySignedIn})`, `restoreSession(String sessionToken)`, `revokeSession(RemoteSessionHandle session)`.
  - `StoredCredential({required String credentialId, required String sessionToken})` with JSON `{"credentialId": "...", "sessionToken": "..."}`.
  - `AuthTokenStorage.migrateLegacyStorage()` to purge `v1` and `v2` legacy keys.

- [ ] **Step 1: Write failing tests for `AuthTokenStorage` schema v3 and `AuthRepository`**

Update `test/auth_token_storage_test.dart` to verify `sessionToken` field and migration of legacy keys.
Update `test/auth_repository_test.dart` to verify `login(username: ...)` and `restoreSession(sessionToken)`.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/auth_token_storage_test.dart test/auth_repository_test.dart`
Expected: FAIL with compilation errors.

- [ ] **Step 3: Implement `auth_repository.dart`, `auth_token_storage.dart`, and `demo_auth_repository.dart`**

Update `lib/core/auth/data/auth_repository.dart`:
- Change `AuthResult` properties from `refreshToken` to `sessionToken`.
- Update `AuthRepository` interface:
  ```dart
  abstract interface class AuthRepository {
    Future<AuthResult> login({
      required String username,
      required String password,
      required bool staySignedIn,
    });

    Future<AuthResult> restoreSession(String sessionToken);

    Future<RemoteRevocationResult> revokeSession(RemoteSessionHandle session);
  }
  ```

Update `lib/core/auth/data/auth_token_storage.dart`:
- `StoredCredential`: field `sessionToken` (replaces `refreshToken`), validation, JSON serialization (`'sessionToken'`).
- `SecureAuthTokenStorage`: constructor default legacy keys to remove both `v1_kok_refresh_token` and `v2` keys if detected.

Update `lib/core/auth/data/demo_auth_repository.dart`:
- Rename parameters and credentials to match new `AuthRepository` interface.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth_token_storage_test.dart test/auth_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/auth/data/auth_repository.dart lib/core/auth/data/auth_token_storage.dart lib/core/auth/data/demo_auth_repository.dart test/auth_token_storage_test.dart test/auth_repository_test.dart
git commit -m "feat(auth): adapt auth repository contract and secure storage to session token schema v3"
```

---

### Task 3: SICABOR DTOs & Mapper

**Files:**
- Create: `lib/core/auth/data/dto/sicabor_login_response.dart`
- Create: `lib/core/auth/data/dto/sicabor_profile_response.dart`
- Create: `lib/core/auth/data/dto/sicabor_error_response.dart`
- Create: `lib/core/auth/data/mapper/sicabor_auth_mapper.dart`
- Create: `test/sicabor_dto_test.dart`
- Create: `test/sicabor_auth_mapper_test.dart`

**Interfaces:**
- Consumes: Raw JSON maps from HTTP responses.
- Produces:
  - `SicaborLoginResponse.fromJson(Map<String, dynamic> json)`.
  - `SicaborProfileResponse.fromJson(Map<String, dynamic> json)`.
  - `SicaborErrorResponse.fromJson(Map<String, dynamic> json)`.
  - `SicaborAuthMapper.mapProfileToUserPrincipal({required SicaborLoginData loginData, required SicaborProfileResponse profileResponse}) -> UserPrincipal`.
  - `SicaborAuthMapper.mapProfileOnlyToUserPrincipal({required SicaborProfileResponse profileResponse}) -> UserPrincipal`.
  - `SicaborAuthMapper.mapErrorCodeToFailure({String? errorCode, String? message}) -> AuthFailure`.

- [ ] **Step 1: Write the failing tests for DTO parsing and Auth Mapper**

```dart
// test/sicabor_dto_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_garut/core/auth/data/dto/sicabor_login_response.dart';
import 'package:kok_garut/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_garut/core/auth/data/dto/sicabor_error_response.dart';

void main() {
  group('SicaborLoginResponse', () {
    test('parses login envelope with status and token', () {
      final json = {
        'status': true,
        'message': 'LOGIN SUCCESSFULLY',
        'data': {
          'id': '578',
          'username': 'kt.garutkota',
          'name': 'ADMIN KONTINGEN GARUT KOTA',
          'email': null,
          'type': 'admin_kok',
        },
        'token': 'mock_jwt_token_123',
      };
      final res = SicaborLoginResponse.fromJson(json);
      expect(res.status, isTrue);
      expect(res.token, equals('mock_jwt_token_123'));
      expect(res.data?.type, equals('admin_kok'));
      expect(res.data?.username, equals('kt.garutkota'));
    });
  });

  group('SicaborProfileResponse', () {
    test('parses profile envelope with scope, member, summary, and data_notes', () {
      final json = {
        'success': true,
        'message': 'Berhasil mengambil data.',
        'scope': {
          'subdistrict_id': 1714,
          'subdistrict_name': 'Blubur Limbangan',
          'district_id': 126,
          'district_name': 'Garut',
        },
        'data': {
          'member': {
            'id': 560,
            'username': 'kt.bllimbangan',
            'name': 'ADMIN KONTINGEN BL.LIMBANGAN',
            'email': null,
            'type': 'admin_kok',
            'status': 1,
            'status_label': 'Aktif',
          },
          'kontingen': {'id': 3, 'code': 'KGPK-0044', 'name': 'Balubur Limbangan'},
          'summary': {
            'total_cabor': 17,
            'total_cabor_from_club': 0,
            'total_cabor_from_athlete': 17,
            'total_club': 0,
            'total_athlete': 159,
            'total_athlete_without_club': 159,
          },
          'data_notes': ['Catatan batasan data 1'],
        },
      };

      final res = SicaborProfileResponse.fromJson(json);
      expect(res.success, isTrue);
      expect(res.scope.subdistrictId, equals(1714));
      expect(res.scope.subdistrictName, equals('Blubur Limbangan'));
      expect(res.data.member.id, equals(560));
      expect(res.data.summary.totalCabor, equals(17));
      expect(res.data.dataNotes, contains('Catatan batasan data 1'));
    });
  });

  group('SicaborErrorResponse', () {
    test('parses error envelope with error_code', () {
      final json = {
        'success': false,
        'message': 'Endpoint ini hanya dapat diakses oleh akun KOK.',
        'error_code': 'NOT_KOK',
      };
      final res = SicaborErrorResponse.fromJson(json);
      expect(res.success, isFalse);
      expect(res.errorCode, equals('NOT_KOK'));
    });
  });
}
```

```dart
// test/sicabor_auth_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_garut/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_garut/core/auth/data/mapper/sicabor_auth_mapper.dart';
import 'package:kok_garut/core/auth/domain/auth_failure.dart';
import 'package:kok_garut/core/auth/domain/user_principal.dart';

void main() {
  group('SicaborAuthMapper', () {
    test('maps profile response to UserPrincipal with subdistrict as district scope', () {
      final profile = SicaborProfileResponse(
        success: true,
        message: 'OK',
        scope: const SicaborScope(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
        ),
        data: const SicaborProfileData(
          member: SicaborMember(
            id: 578,
            username: 'kt.garutkota',
            name: 'ADMIN KONTINGEN GARUT KOTA',
            email: null,
            type: 'admin_kok',
            status: 1,
            statusLabel: 'Aktif',
          ),
          kontingen: null,
          summary: SicaborSummary(
            totalCabor: 10,
            totalCaborFromClub: 2,
            totalCaborFromAthlete: 8,
            totalClub: 5,
            totalAthlete: 40,
            totalAthleteWithoutClub: 10,
          ),
          dataNotes: [],
        ),
      );

      final user = SicaborAuthMapper.mapProfileOnlyToUserPrincipal(profileResponse: profile);

      expect(user.id, equals('578'));
      expect(user.username, equals('kt.garutkota'));
      expect(user.fullName, equals('ADMIN KONTINGEN GARUT KOTA'));
      expect(user.roleTitle, equals('Koordinator Kecamatan'));
      expect(user.scope.type, equals(AccessScopeType.district));
      expect(user.scope.id, equals('1728'));
      expect(user.scope.name, equals('Garut Kota'));
    });

    test('maps error codes to appropriate AuthFailure types', () {
      expect(
        SicaborAuthMapper.mapErrorCodeToFailure(errorCode: 'NOT_KOK', message: 'Not KOK'),
        isA<AccountNotKokFailure>(),
      );
      expect(
        SicaborAuthMapper.mapErrorCodeToFailure(errorCode: 'MEMBER_INACTIVE', message: 'Inactive'),
        isA<AccountInactiveFailure>(),
      );
      expect(
        SicaborAuthMapper.mapErrorCodeToFailure(errorCode: 'NO_SUBDISTRICT', message: 'No subdistrict'),
        isA<NoSubdistrictFailure>(),
      );
      expect(
        SicaborAuthMapper.mapErrorCodeToFailure(errorCode: 'MEMBER_NOT_FOUND', message: 'Not found'),
        isA<MemberNotFoundFailure>(),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/sicabor_dto_test.dart test/sicabor_auth_mapper_test.dart`
Expected: FAIL with compilation errors (classes not found).

- [ ] **Step 3: Implement DTOs and Mapper**

Create:
- `lib/core/auth/data/dto/sicabor_login_response.dart`
- `lib/core/auth/data/dto/sicabor_profile_response.dart`
- `lib/core/auth/data/dto/sicabor_error_response.dart`
- `lib/core/auth/data/mapper/sicabor_auth_mapper.dart`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/sicabor_dto_test.dart test/sicabor_auth_mapper_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/auth/data/dto/ lib/core/auth/data/mapper/ test/sicabor_dto_test.dart test/sicabor_auth_mapper_test.dart
git commit -m "feat(auth): implement SICABOR login/profile DTOs and domain mapper"
```

---

### Task 4: Network Layer Simplification & Error Code Parsing (`ApiException`, `ApiClient`, `AuthSessionTokens`)

**Files:**
- Modify: `lib/core/network/api_exceptions.dart:1-41`
- Modify: `lib/core/network/auth_session_tokens.dart:1-18`
- Modify: `lib/core/network/api_client.dart:1-188`
- Test: `test/api_client_test.dart`

**Interfaces:**
- Consumes: `Dio`, `AuthSessionTokens`.
- Produces:
  - `UnauthorizedException([String message, {String? errorCode, String? serverMessage}])`.
  - `ForbiddenException([String message, {String? errorCode, String? serverMessage}])`.
  - `ApiClient.request<T>(...)`: attaches Bearer token, on 401/403 extracts `error_code` and throws immediately without retry/refresh.

- [ ] **Step 1: Write failing tests for simplified `ApiClient` and error code extraction**

Update `test/api_client_test.dart`:
- Verify 401 throws `UnauthorizedException` immediately.
- Verify 403 parses `error_code` from JSON body.
- Verify non-JSON error response doesn't crash JSON parser.
- Verify cancellation still operates cleanly.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/api_client_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `api_exceptions.dart`, `auth_session_tokens.dart`, and `api_client.dart`**

Update `lib/core/network/api_exceptions.dart`:
Add `errorCode` and `serverMessage` optional parameters to `UnauthorizedException` and `ForbiddenException`.

Update `lib/core/network/auth_session_tokens.dart`:
```dart
final class AuthSessionTokens {
  String? _accessToken;
  String? _sessionToken;

  String? get accessToken => _accessToken;
  String? get sessionToken => _sessionToken;

  void replace({String? accessToken, String? sessionToken}) {
    _accessToken = accessToken;
    _sessionToken = sessionToken;
  }

  void clear() {
    _accessToken = null;
    _sessionToken = null;
  }
}
```

Update `lib/core/network/api_client.dart`:
- Remove `RefreshSession` typedef and refresh loop.
- Extract `error_code` / `message` from response data in `DioException` error handling.
- Throw appropriate `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `BadRequestException`, etc.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/api_client_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/network/ test/api_client_test.dart
git commit -m "refactor(network): remove refresh token retry loop and parse SICABOR error codes"
```

---

### Task 5: Remote Auth Repository Implementation (`RemoteAuthRepository`)

**Files:**
- Modify: `lib/core/auth/data/remote_auth_repository.dart:1-33`
- Create: `test/remote_auth_repository_test.dart`

**Interfaces:**
- Consumes: `Dio`, `DeploymentProfile`, `SicaborLoginResponse`, `SicaborProfileResponse`, `SicaborAuthMapper`.
- Produces: `RemoteAuthRepository implements AuthRepository`.

- [ ] **Step 1: Write failing tests for `RemoteAuthRepository`**

```dart
// test/remote_auth_repository_test.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_garut/core/auth/data/remote_auth_repository.dart';
import 'package:kok_garut/core/auth/domain/auth_failure.dart';
import 'package:kok_garut/core/config/deployment_profile.dart';

void main() {
  group('RemoteAuthRepository', () {
    late Dio dio;
    late DeploymentProfile profile;
    late RemoteAuthRepository repository;

    setUp(() {
      dio = Dio();
      profile = const DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
        apiBaseUrl: 'https://sicabor.test/api/v1/kok',
      );
      // Setup mock adapter on dio for tests
    });

    test('login succeeds when credentials valid and profile succeeds', () async {
      // Mock POST /api/auth -> 200 with admin_kok and token
      // Mock GET /api/v1/kok/profile -> 200 with scope and member
      // Assert AuthResult.isSuccess is true with UserPrincipal and sessionToken
    });

    test('login fails when account type is not admin_kok', () async {
      // Mock POST /api/auth -> 200 with type 'cabor'
      // Assert AuthResult.failure is AccountNotKokFailure
    });

    test('restoreSession succeeds when token valid and profile returns 200', () async {
      // Mock GET /api/v1/kok/profile -> 200
      // Assert AuthResult.isSuccess is true
    });

    test('restoreSession returns SessionExpiredFailure on 401', () async {
      // Mock GET /api/v1/kok/profile -> 401
      // Assert AuthResult.failure is SessionExpiredFailure
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/remote_auth_repository_test.dart`
Expected: FAIL (methods throw `UnimplementedError`).

- [ ] **Step 3: Implement `RemoteAuthRepository`**

Implement `lib/core/auth/data/remote_auth_repository.dart`:
- Derive auth endpoint URL (`/api/auth`) from `profile.apiBaseUrl` origin.
- Form-urlencoded `POST /api/auth` with `username` and `password`.
- Validate `data.type == 'admin_kok'`.
- Call `GET /profile` using `Bearer <token>`.
- Map response to `UserPrincipal` via `SicaborAuthMapper`.
- Implement `restoreSession(sessionToken)` using `GET /profile`.
- Implement `revokeSession` returning `RemoteRevocationResult(RemoteRevocationStatus.notApplicable)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/remote_auth_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/auth/data/remote_auth_repository.dart test/remote_auth_repository_test.dart
git commit -m "feat(auth): implement RemoteAuthRepository for SICABOR login and profile validation"
```

---

### Task 6: Auth Controller & Session Lifecycle (`AuthController`)

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart:1-978`
- Test: `test/auth_controller_test.dart`
- Test: `test/auth_hardening_test.dart`
- Test: `test/auth_hardening_remediation_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthTokenStorage`, `SessionMetadataStore`, `RememberedUsernameStore`, `AuthSessionTokens`.
- Produces: `AuthController` with updated persistent session commit, restore via session token, and centralized 401 handling.

- [ ] **Step 1: Update failing tests for `AuthController`**

Update `test/auth_controller_test.dart`, `test/auth_hardening_test.dart`, `test/auth_hardening_remediation_test.dart`:
- Rename `skNumber` -> `username`.
- Rename `rememberSk` -> `rememberUsername`.
- Replace `refreshToken` checks with `sessionToken`.
- Add test for 401 unauthorized triggering clean single-flight logout.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/auth_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `AuthController` implementation**

In `lib/core/auth/presentation/auth_controller.dart`:
- Replace `RememberedSkStore` with `RememberedUsernameStore`.
- In `login(...)`:
  - Update parameters to `username` and `rememberUsername`.
  - Validate `result.sessionToken` on persistent login.
  - Write `StoredCredential(credentialId: credId, sessionToken: sessionToken)`.
  - Save or clear `RememberedUsernameStore`.
- In `bootstrap()`:
  - Call `repo.restoreSession(credential.sessionToken)`.
- In `handleUnauthorizedSession()` (or listener):
  - Trigger single-flight logout if current state is `AuthSignedIn`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth_controller_test.dart test/auth_hardening_test.dart test/auth_hardening_remediation_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart test/auth_hardening_test.dart test/auth_hardening_remediation_test.dart
git commit -m "feat(auth): update AuthController for SICABOR session token lifecycle and centralized 401 handling"
```

---

### Task 7: App Composition, Config, Android Manifest & UI (`AppComposition`, `DeploymentProfile`, `LoginPage`, `AndroidManifest.xml`)

**Files:**
- Modify: `lib/core/composition/app_composition.dart:1-115`
- Modify: `lib/core/config/deployment_profile.dart:1-143`
- Modify: `lib/features/login_page.dart:1-885`
- Modify: `android/app/src/main/AndroidManifest.xml:1-46`
- Test: `test/login_page_test.dart`
- Test: `test/app_environment_test.dart`
- Test: `test/app_test.dart`

**Interfaces:**
- Consumes: All core and feature layers.
- Produces: Complete working application with updated UI and composition.

- [ ] **Step 1: Write/update tests for `LoginPage`, `AppComposition`, and `DeploymentProfile`**

Update `test/login_page_test.dart`, `test/app_environment_test.dart`, and `test/app_test.dart` to verify username form fields, remembered username checkbox, and composition wiring.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/login_page_test.dart test/app_environment_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `app_composition.dart`, `deployment_profile.dart`, `login_page.dart`, and `AndroidManifest.xml`**

In `lib/core/composition/app_composition.dart`:
- Set storage keys to schema v3 (`kok.auth.v3.$envName.*`).
- Wire `RememberedUsernameStore`.
- Construct `RemoteAuthRepository` passing Dio instance and profile.

In `lib/core/config/deployment_profile.dart`:
- Enforce HTTPS for production.

In `lib/features/login_page.dart`:
- Rename `_sk` controller to `_usernameController`.
- Update field label to "Username", hint to "Masukkan username", validation message to "Username wajib diisi".
- Checkbox label: "Ingat username".
- Wire to `rememberedUsernameStoreProvider`.

In `android/app/src/main/AndroidManifest.xml`:
- Add `<uses-permission android:name="android.permission.INTERNET"/>` before `<application>`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/login_page_test.dart test/app_environment_test.dart test/app_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/composition/ lib/core/config/ lib/features/login_page.dart android/app/src/main/AndroidManifest.xml test/login_page_test.dart test/app_environment_test.dart test/app_test.dart
git commit -m "feat(ui): update login page labels, composition wiring v3, and Android internet permission"
```

---

### Task 8: Full Verification & Static Analysis

**Files:**
- Entire codebase

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass (0 failures).

- [ ] **Step 3: Verify APK debug build succeeds**

Run: `flutter build apk --debug`
Expected: Build APK succeeds.

- [ ] **Step 4: Final commit and summary**

```bash
git status
```

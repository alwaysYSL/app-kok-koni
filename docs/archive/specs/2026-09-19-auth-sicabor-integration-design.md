# Auth SICABOR + Profile — Desain Integrasi

**Milestone pertama:** Login → `/profile` → simpan sesi → buka ulang aplikasi → logout.

**Kontrak API:** [api-kok-sicabor.md](../api/api-kok-sicabor.md)
**Baseline arsitektur:** [authentication-current.md](../architecture/authentication-current.md)

---

## 1. Konteks masalah

Arsitektur auth saat ini mengasumsikan **access token + refresh token** dengan kemampuan refresh otomatis pada 401. SICABOR menerbitkan **satu token berlaku 24 jam tanpa refresh dan tanpa endpoint perpanjangan**. Token kedaluwarsa = login ulang.

Fondasinya — state machine, route guard, secure storage, ownership credential, mutation queue, generation counter, stale-response guard — **dipertahankan**. Yang berubah adalah **asumsi protokolnya**.

## 2. Keputusan desain yang sudah ditetapkan

| # | Keputusan | Pilihan |
|---|-----------|---------|
| 1 | Storage token persisten | `StoredCredential` menyimpan `sessionToken` (bukan `refreshToken`). Schema key naik ke `v3`. |
| 2 | Naming | `skNumber` → `username` di seluruh kontrak (6 lapisan). |
| 3 | `ApiClient` pada 401 | Hapus mekanisme refresh. 401 → throw `UnauthorizedException` → logout terpusat. |
| 4 | Login + profil | Dua langkah dalam satu `login()`. `AuthSignedIn` baru setelah `GET /profile` sukses. |
| 5 | Demo mode | Dipertahankan. Hanya rename field + sesuaikan kontrak. |
| 6 | Error mapping | `AuthFailure` baru spesifik per `error_code` SICABOR. |
| 7 | Restore sesi | `restoreSession(sessionToken)` memanggil `GET /profile`. Timeout/offline ≠ expired. |

## 3. Alur auth target

### 3.1 Login

```
┌─────────────┐   username/password    ┌──────────────────┐
│  LoginPage   │ ──────────────────────▶│  AuthController   │
└─────────────┘                        │   .login()        │
                                       └────────┬─────────┘
                                                │
                                    ┌───────────▼───────────┐
                                    │ RemoteAuthRepository   │
                                    │   .login()             │
                                    └───────────┬───────────┘
                                                │
                              ┌─────────────────▼─────────────────┐
                              │  Langkah 1: POST /api/auth         │
                              │  Content-Type: x-www-form-urlencoded│
                              │  body: username=...&password=...    │
                              └─────────────────┬─────────────────┘
                                                │
                              ┌─────────────────▼─────────────────┐
                              │  Validasi respons login:           │
                              │  • status == true                  │
                              │  • token != null && !empty         │
                              │  • data.type == "admin_kok"        │
                              └─────────────────┬─────────────────┘
                                                │
                              ┌─────────────────▼─────────────────┐
                              │  Langkah 2: GET /api/v1/kok/profile│
                              │  Authorization: Bearer <token>     │
                              └─────────────────┬─────────────────┘
                                                │
                              ┌─────────────────▼─────────────────┐
                              │  Bangun UserPrincipal dari profil: │
                              │  • id ← member.id (int → string)  │
                              │  • username ← member.username      │
                              │  • fullName ← member.name          │
                              │  • scope ← subdistrict_id/name     │
                              │    (→ AccessScopeType.district)    │
                              │  • roleTitle ← "Koordinator        │
                              │    Kecamatan" (dari type)          │
                              └─────────────────┬─────────────────┘
                                                │
                              ┌─────────────────▼─────────────────┐
                              │  Kembalikan AuthResult.success      │
                              │  • user: principal                 │
                              │  • accessToken: token              │
                              │  • sessionToken: token (sama)      │
                              │  • sessionHandle: null (no revoke) │
                              └─────────────────────────────────────┘
```

**Catatan penting:** Pada SICABOR, access token dan session token adalah objek yang sama. Satu token dipakai untuk request HTTP (sebagai access token di memori) sekaligus untuk persistence (sebagai session token di secure storage).

### 3.2 Commit sesi persisten

Saat `staySignedIn == true`, controller:

1. Menulis `SessionMetadata.cleanupPending()`.
2. Menulis `StoredCredential(credentialId: uuid, sessionToken: token)` ke secure storage.
3. Memverifikasi operation epoch.
4. Menulis `SessionMetadata.restoreEnabled(credentialId)`.
5. Mengganti token di `AuthSessionTokens`.
6. Menerbitkan `AuthSignedIn`.

**Perubahan dari sekarang:** Controller tidak lagi memeriksa `result.refreshToken`, melainkan `result.sessionToken` (yang untuk SICABOR = access token itu sendiri). AuthResult perlu field baru atau rename.

### 3.3 Restore sesi (buka ulang aplikasi)

```
┌─────────────────────┐
│  bootstrap()         │
│  ↓                   │
│  Baca metadata       │
│  Baca credential     │
│  ↓                   │
│  restoreSession(     │
│    sessionToken)     │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ GET /api/v1/kok/     │
│   profile            │
│ Authorization:       │
│   Bearer <token>     │
└──────────┬──────────┘
           │
     ┌─────┼─────────┐
     │     │         │
   200   401    timeout/
     │     │    offline
     │     │         │
  Bangun  Hapus   Temporarily
  principal cred.  Unavailable
  ↓        ↓      (token
  Signed  Signed   tetap
  In      Out      tersimpan)
```

**Perbedaan kunci dari sekarang:** Restore tidak "menukar" token lama dengan token baru. Restore hanya memvalidasi token lama masih sah. Token yang sama tetap dipakai sampai kedaluwarsa.

### 3.4 Logout

Sama seperti sekarang, minus remote revocation:

1. Naikkan epoch + generation.
2. Bersihkan `AuthSessionTokens`.
3. State → `AuthSigningOut`.
4. Hapus credential dari secure storage (ownership check).
5. State → `AuthSignedOut`.
6. **Tidak ada** panggilan `revokeSession()` — endpoint revoke SICABOR belum didokumentasikan.

### 3.5 Invalidasi sesi oleh 401

Saat request data apapun menerima 401:

1. `ApiClient` langsung throw `UnauthorizedException` (tanpa refresh/retry).
2. Interceptor atau listener pada `AuthController` menangkap exception ini.
3. Controller memicu `logout()` terpusat — satu kali meskipun beberapa request 401 datang bersamaan (single-flight).
4. Pengguna dikembalikan ke layar login.

### 3.6 Penanganan 403 mid-session

SICABOR mengecek ulang akun dari database pada **setiap request**. Akun bisa dinonaktifkan atau dipindahkan kecamatan kapan saja.

| `error_code` | Tindakan |
|---|---|
| `MEMBER_NOT_FOUND` | Paksa logout, pesan "Akun tidak ditemukan" |
| `MEMBER_INACTIVE` | Paksa logout, tampilkan `message` dari API |
| `NOT_KOK` | Paksa logout, pesan "Akun ini bukan akun KOK" |
| `NO_SUBDISTRICT` | Blok akses data, pesan + arahan hubungi admin. **Jangan logout** — akunnya sah, hanya belum punya kecamatan |

## 4. Perubahan per komponen

### 4.1 Domain — `lib/core/auth/domain/`

#### `auth_state.dart`
- Tidak ada perubahan struktural.
- `AuthSignedIn.accessToken` tetap dipertahankan.

#### `user_principal.dart`
- **Rename** `skNumber` → `username` (field, constructor, `toJson`, `fromJson`).
- `AccessScopeType.district` tetap = kecamatan. Tidak perlu enum baru.
- `AccessScope.id` menerima string (SICABOR `subdistrict_id` = integer, konversi `toString()` di mapper).
- **Permissions:** Biarkan `Set<String>` kosong dari SICABOR (API tidak mengembalikan daftar permission). `admin_kok` menjadi dasar akses. Kebijakan `reports:export` diputuskan terpisah.

#### `auth_failure.dart`
- **Tambahkan** varian baru:
  ```dart
  factory AuthFailure.accountNotKok({String? message});
  factory AuthFailure.accountInactive({String? message});
  factory AuthFailure.noSubdistrict({String? message});
  factory AuthFailure.memberNotFound({String? message});
  factory AuthFailure.profileFetchFailed({String? message});
  ```

### 4.2 Data auth — `lib/core/auth/data/`

#### `auth_repository.dart`
- **Rename** parameter `skNumber` → `username` di `login()`.
- **Rename** `refreshToken` → `sessionToken` di `restoreSession()`.
- **Hapus** `refreshToken()` method — tidak relevan untuk SICABOR.
- `AuthResult`:
  - Rename field `refreshToken` → `sessionToken`.
  - `AuthResult.success` menerima `sessionToken` sebagai pengganti `refreshToken`.
- `revokeSession` tetap ada di kontrak tapi implementasi SICABOR mengembalikan `notApplicable`.

#### `auth_token_storage.dart`
- `StoredCredential`:
  - **Rename** field `refreshToken` → `sessionToken`.
  - JSON key berubah: `{"credentialId": "...", "sessionToken": "..."}`.
- **Storage key** naik ke `v3`:
  ```
  kok.auth.v3.<environment>.credential
  kok.auth.v3.<environment>.metadata
  kok.auth.v3.<environment>.remembered_username
  ```
- `migrateLegacyStorage()` diperluas: hapus key `v2` lama selain `v1` yang sudah ditangani.

#### `remembered_sk_store.dart`
- **Rename** file → `remembered_username_store.dart`.
- **Rename** class → `RememberedUsernameStore`.
- Method: `readUsername()`, `saveUsername()`, `clear()`.
- Key: `kok.auth.v3.<env>.remembered_username`.

#### `remote_auth_repository.dart`
- **Implementasi `login()`:**
  1. `POST /api/auth` dengan `application/x-www-form-urlencoded`.
  2. Parse respons login (envelope `status`).
  3. Validasi: `status == true`, `token` ada, `data.type == "admin_kok"`.
  4. Dengan token sementara, panggil `GET /api/v1/kok/profile`.
  5. Parse profil (envelope `success`).
  6. Bangun `UserPrincipal` dari gabungan data login + profil.
  7. Kembalikan `AuthResult.success(user: principal, accessToken: token, sessionToken: token)`.
- **Implementasi `restoreSession(sessionToken)`:**
  1. Panggil `GET /api/v1/kok/profile` dengan `Bearer <sessionToken>`.
  2. Jika 200: bangun principal, kembalikan sukses.
  3. Jika 401: kembalikan `AuthFailure.expiredSession`.
  4. Jika 403 (`NOT_KOK`, `MEMBER_INACTIVE`, dll): kembalikan failure spesifik.
  5. Jika timeout/offline: kembalikan `AuthFailure.serviceUnavailable`.
- **Hapus** `refreshToken()` — throw `UnsupportedError` atau hapus dari implementasi.
- **`revokeSession()`:** Kembalikan `RemoteRevocationResult(status: notApplicable)`.

#### [NEW] `dto/sicabor_login_response.dart`
- DTO untuk parsing respons `POST /api/auth`:
  ```dart
  class SicaborLoginResponse {
    final bool status;
    final String message;
    final SicaborLoginData? data;
    final String? token;
  }
  class SicaborLoginData {
    final String id;       // String di API
    final String username;
    final String name;
    final String? email;
    final String type;
  }
  ```

#### [NEW] `dto/sicabor_profile_response.dart`
- DTO untuk parsing respons `GET /api/v1/kok/profile`:
  ```dart
  class SicaborProfileResponse {
    final bool success;
    final String message;
    final SicaborScope scope;
    final SicaborProfileData data;
  }
  class SicaborScope {
    final int subdistrictId;
    final String subdistrictName;
    final int districtId;
    final String districtName;
  }
  class SicaborProfileData {
    final SicaborMember member;
    final SicaborKontingen? kontingen;
    final SicaborSummary summary;
    final List<String> dataNotes;
  }
  // ... sub-classes
  ```

#### [NEW] `dto/sicabor_error_response.dart`
- DTO untuk parsing respons error KOK:
  ```dart
  class SicaborErrorResponse {
    final bool success;
    final String message;
    final String? errorCode;
  }
  ```

#### [NEW] `mapper/sicabor_auth_mapper.dart`
- Mapper yang mengubah DTO ke domain model:
  ```dart
  UserPrincipal mapProfileToUserPrincipal({
    required SicaborLoginData loginData,
    required SicaborProfileResponse profile,
  });

  AuthFailure mapErrorCodeToFailure(String? errorCode, String? message);
  ```
- Mapping ID: `member.id` (int di profil, string di login) → `UserPrincipal.id` (string). Gunakan ID dari profil (`int → toString()`).
- Mapping scope: `scope.subdistrict_id` → `AccessScope(type: district, id: '$subdistrictId', name: subdistrictName)`.

### 4.3 Presentation — `lib/core/auth/presentation/`

#### `auth_controller.dart`
- **Rename** `skNumber` → `username` di `login()`.
- **Ubah persistent login check:**
  ```dart
  // SEBELUM:
  final refreshToken = result.refreshToken;
  if (refreshToken == null || refreshToken.trim().isEmpty || ...) {
    return _failPersistentCredential(...);
  }

  // SESUDAH:
  final sessionToken = result.sessionToken;
  if (sessionToken == null || sessionToken.trim().isEmpty || ...) {
    return _failPersistentCredential(...);
  }
  ```
- **Ubah `StoredCredential` construction:**
  ```dart
  StoredCredential(credentialId: credId, sessionToken: sessionToken)
  ```
- **Ubah `bootstrap()`:**
  - `repo.restoreSession(credential.sessionToken)` (bukan `refreshToken`).
- **Tambahkan listener 401 terpusat:**
  - Mekanisme untuk menangkap `UnauthorizedException` dari data layer dan memicu `logout()`.
  - Single-flight: jika logout sudah berjalan, 401 berikutnya tidak memulai logout kedua.
- **Ubah `_activeRemoteHandle`:**
  - Selalu null untuk SICABOR. Revocation path tetap ada tapi tidak aktif.

### 4.4 Network — `lib/core/network/`

#### `api_client.dart`
- **Hapus refresh logic:**
  - Hapus `_refreshFlight`, `_refreshAccessToken()`, retry-after-refresh.
  - 401 → langsung throw `UnauthorizedException`.
- **Hapus** `RefreshSession` typedef dan parameter dari constructor.
- **Pertahankan:**
  - Bearer token injection dari `AuthSessionTokens`.
  - Error mapping (401, 403, 404, 5xx, timeout, offline).
- **Tambahkan:**
  - Parsing `error_code` dari body JSON sebelum throw, agar exception membawa `errorCode`.
  - Pengecekan `Content-Type: application/json` sebelum parse body (jebakan integrasi: URL typo menghasilkan HTML).

#### `auth_session_tokens.dart`
- **Rename** `refreshToken` → `sessionToken` di getter dan `replace()`.
- Atau: hapus session token dari bridge sepenuhnya karena tidak dipakai untuk refresh. `ApiClient` hanya membutuhkan `accessToken`.

#### `api_exceptions.dart`
- **Tambahkan** field `errorCode` pada `ForbiddenException`:
  ```dart
  class ForbiddenException extends ApiException {
    final String? errorCode; // e.g. 'NOT_KOK', 'MEMBER_INACTIVE'
    final String? serverMessage;
  }
  ```
- Idem untuk `UnauthorizedException`:
  ```dart
  class UnauthorizedException extends ApiException {
    final String? errorCode; // e.g. 'INVALID_TOKEN'
  }
  ```

### 4.5 Composition — `lib/core/composition/`

#### `app_composition.dart`
- **Update storage keys** ke `v3`.
- **Update `RememberedSkStore`** → `RememberedUsernameStore`.
- **Hapus** `refreshSession` callback dari `ApiClient` constructor.
- **Ubah** wiring `RemoteAuthRepository`:
  - `login()` butuh akses HTTP langsung untuk `POST /api/auth` (di luar base URL KOK).
  - Berikan Dio instance atau base URL auth terpisah.

### 4.6 Config

#### `deployment_profile.dart`
- `apiBaseUrl` tetap menunjuk ke `https://sicabor.test/api/v1/kok` (atau produksi).
- `RemoteAuthRepository` meng-derive auth URL: ambil origin dari base URL, lalu append `/api/auth`. Contoh: `https://sicabor.test/api/v1/kok` → `https://sicabor.test/api/auth`.
- Tidak perlu field konfigurasi tambahan — kedua endpoint selalu berada di server yang sama.

### 4.7 UI

#### `login_page.dart`
- Label "Nomor SK" → "Username".
- Hint "Masukkan nomor SK" → "Masukkan username".
- Validasi "Nomor SK wajib diisi" → "Username wajib diisi".
- Checkbox "Ingat nomor SK" → "Ingat username".
- Parameter `skNumber` → `username` saat memanggil controller.
- `RememberedSkStore` → `RememberedUsernameStore`.
- Tombol demo account tetap tampil saat `authMode == demo`.

### 4.8 Test

**Test yang perlu diadaptasi (bukan dibuang):**

| Test file | Perubahan |
|---|---|
| `auth_controller_test.dart` | Rename `skNumber` → `username`. Ganti refresh-based persistent ke session-token-based. Hapus test refresh rotation. Pertahankan: mutation queue, ownership, race, cancellation, cleanup. |
| `auth_hardening_test.dart` | Sesuaikan race login/logout. Hapus asumsi refresh. |
| `auth_hardening_remediation_test.dart` | Sesuaikan persistent restore ke session token. |
| `auth_repository_test.dart` | Rename. Demo repo menyesuaikan kontrak baru. |
| `auth_token_storage_test.dart` | `sessionToken` menggantikan `refreshToken`. Key `v3`. |
| `session_metadata_store_test.dart` | Key `v3`. |
| `api_client_test.dart` | **Hapus** test refresh/retry. **Tambah** test 401 → langsung throw. Test `error_code` parsing. |

**Test baru yang perlu dibuat:**

| Test | Cakupan |
|---|---|
| `sicabor_auth_mapper_test.dart` | Mapping DTO → domain: tipe admin_kok vs lainnya, ID int→string, scope mapping, error codes. |
| `sicabor_login_response_test.dart` | Parsing JSON login (envelope `status`), missing fields, empty token. |
| `sicabor_profile_response_test.dart` | Parsing JSON profil (envelope `success`), kontingen null, data_notes. |
| `remote_auth_repository_test.dart` | Login 2-langkah: sukses, non-KOK ditolak, profil gagal, restore via profil, 401/403/timeout handling. |

## 5. Scope perubahan dan apa yang TIDAK berubah

### Berubah
- Kontrak `AuthRepository` (4 method).
- `StoredCredential` (rename field + schema v3).
- `RememberedSkStore` → `RememberedUsernameStore`.
- `UserPrincipal` (rename `skNumber` → `username`).
- `AuthFailure` (varian baru).
- `AuthController` (persistent login check, bootstrap restore, 401 handling).
- `ApiClient` (hapus refresh, tambah error_code parsing).
- `ApiException` subclasses (tambah `errorCode`).
- `AppComposition` (wiring baru).
- Login UI (label dan field).
- ~10 test files.
- 4 file baru (3 DTO + 1 mapper).

### TIDAK berubah
- State machine (`AuthState` sealed hierarchy).
- Route guard.
- Mutation queue dan ownership credential.
- Generation counter dan stale-response guard.
- `DataRequestContext` dan `snapshotProvider`.
- `DemoKokRepository` (data layer demo).
- Semua feature UI kecuali login page.
- Arsitektur Riverpod.

## 6. Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Server `sicabor.test` tidak bisa diakses dari perangkat Android | Konfigurasi DNS/hosts di perangkat. Atau gunakan IP langsung. Jangan nonaktifkan sertifikat di release. |
| Respons login gagal belum ada contohnya | Desain error handling berdasarkan kode error yang sudah didokumentasikan. Test dengan mock terlebih dahulu. |
| Token 24 jam kedaluwarsa di tengah penggunaan | 401 → logout terpusat sudah ditangani. UX: tampilkan pesan "Sesi berakhir, silakan login kembali." |
| Scope berubah di server (akun dipindah kecamatan) | 403 mid-session ditangani. Pada restore, scope dari profil terbaru menggantikan scope tersimpan. |
| Android release belum punya izin internet | Tambahkan `<uses-permission android:name="android.permission.INTERNET"/>` di main manifest. |
| Production masih menerima HTTP plaintext | Perketat `DeploymentProfile.validate()`: production wajib HTTPS. |

## 7. Urutan implementasi

1. **Kontrak dan domain** (~½ hari)
   - Rename `skNumber` → `username` di domain + kontrak.
   - `StoredCredential` → `sessionToken`, schema v3.
   - `AuthFailure` varian baru.
   - `RememberedUsernameStore`.
   - Fix semua compile error dari rename.

2. **DTO + mapper** (~½ hari)
   - 3 DTO files + 1 mapper.
   - Unit test untuk setiap DTO dan mapper.

3. **`ApiClient` simplifikasi** (~½ hari)
   - Hapus refresh logic.
   - Tambah `error_code` parsing.
   - Update test.

4. **`AuthController` penyesuaian** (~1 hari)
   - Persistent login → session token.
   - Bootstrap → restore via session token.
   - 401 → logout terpusat.
   - Update semua controller test.

5. **`RemoteAuthRepository` implementasi** (~1 hari)
   - Login 2-langkah.
   - Restore via profil.
   - Revoke → not applicable.
   - Integration test dengan mock HTTP.

6. **Composition + config + UI** (~½ hari)
   - Wiring baru di `AppComposition`.
   - `DeploymentProfile` → auth URL.
   - Login page rename.
   - Android internet permission.

7. **End-to-end verification** (~½ hari)
   - `flutter test` hijau.
   - `flutter analyze` bersih.
   - Build APK debug.
   - Manual test login → profil → restart → logout (jika server tersedia).

**Total estimasi: 4–5 hari kerja.**

## 8. Kriteria selesai milestone ini

- [ ] Login dengan username/password → menerima token + profil → dashboard tampil
- [ ] Akun bukan `admin_kok` ditolak dengan pesan yang jelas
- [ ] "Tetap masuk" → buka ulang app → sesi ter-restore dari profil
- [ ] Token kedaluwarsa → 401 → logout bersih → tampil layar login
- [ ] Offline saat restore → "sementara tidak tersedia" → bisa retry
- [ ] Logout → credential terhapus → tidak bisa restore
- [ ] Semua test hijau
- [ ] Demo mode tetap berfungsi
- [ ] `flutter analyze` bersih
- [ ] Build APK debug berhasil

## 9. Apa yang BELUM termasuk milestone ini

- Dashboard mengambil data dari `/profile` summary (milestone 2).
- Integrasi cabor, klub, atlet (milestone 3+).
- Permission enforcement dari server (belum ada dari API).
- Pengurus KOK, helpdesk, riwayat prestasi (belum ada dari API).
- Fitur verifikasi/kelengkapan dokumen (belum ada dari API).
- Scope change detection mid-session (bisa ditambahkan di milestone 2).
- Logging/observability (bisa ditambahkan paralel).

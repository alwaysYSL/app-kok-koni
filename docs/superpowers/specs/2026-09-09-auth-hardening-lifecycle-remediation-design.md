# Desain Remediasi Penguatan Arsitektur Autentikasi & Siklus Sesi (Tahap A Patch 2)

Tanggal: 2026-09-09  
Status: Approved for Implementation Planning (Sinkronisasi Final v2)  
Penulis: Pengembang & Reviewer Teknis  
Dokumen Rujukan: `docs/audit-auth-review-tahap1-kedua.md` (Temuan R2-01 s/d R2-07, Temuan Bagian 5)  

---

## 1. Latar Belakang & Sasaran Remediasi

Berdasarkan hasil audit tahap kedua pada `docs/audit-auth-review-tahap1-kedua.md`, temuan A-01 (Guard State Transisi) dan A-08 (Dua Sumber Sesi Ganda) telah ditandai tertutup pada review statis sebelumnya. Dokumen ini menetapkan target *robustness* dan kesiapan integrasi guna menyelesaikan 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan konsistensi Bagian 5 secara tuntas dan deterministik:

1. **R2-01 (Race Commit/Clear Token & Ownership):** Operasi login *stale* dilarang menjalankan pembersihan global. Penulisan dan penghapusan storage diserialisasi via `_mutationQueue`, dan kepemilikan credential dilindungi dengan ID unik per sesi (`credentialId`).
2. **R2-02 (Logout Storage Failure & Penanganan State):** Kegagalan menghapus token memiliki status bertipe `LocalCleanupStatus`, dipersistensikan sebagai *single-record crash-consistent* `SessionMetadata` nonrahasia di `SharedPreferences`, dan UI meng-`await` seluruh proses logout tanpa unhandled Future. Remote revocation di-`await` dengan timeout terbatas setelah state lokal dipublikasikan.
3. **R2-03 (Konsistensi Akun DEMO-003):** Akun `DEMO-003` (Ibu Rina · KONI Kab) memiliki token persisten exact (`token_usr_koni_kab`), scope kabupaten terpisah (`AccessScopeType.county`), dan fixture gabungan 5 cabang olahraga unik se-Kabupaten Garut (Sepak Bola, Bulu Tangkis, Pencak Silat, Bola Voli, Renang).
4. **R2-04 (Mutasi Auth Paralel & Matriks Transisi):** Controller menerapkan matriks transisi state legal dengan operasi pembatalan eksplisit `cancelSignIn()` dan pemisahan dua fase (*Reserve -> Execute -> Commit*).
5. **R2-05 (Rekursi Interface Storage & Namespace Kanonis):** `AuthTokenStorage` disederhanakan tanpa rekursi, menggunakan namespace terversi per environment (`kok.auth.v2.<env>.credential`, `metadata`, `remembered_sk`) tanpa nilai default implisit, serta memisahkan migrasi legacy menjadi operasi bootstrap eksplisit.
6. **R2-06 (Kontrak Repository & Cancellation End-to-End):** Abstraksi `RequestCancellation` dengan notifikasi dan pengecekan pasca-`await`, peniadaan `fetch()` tanpa scope, dan verifikasi generasi pasca-`await` via `DataRequestContext` dengan no-retry policy untuk error siklus sesi.
7. **R2-07 (Composition Root Bebas Dependency Cycle):** `DeploymentProfile` memisahkan konfigurasi environment, auth mode, dan data mode secara independen; dependency terstruktur modular tanpa cycle (`core/config/`, `core/composition/`, `data/`); `main()` hanya meng-override composition dan platform storage dasar.
8. **Bagian 5 (Sisa Klaim SICABOR & Penegakan Izin):** Pembersihan sisa klaim SICABOR pada UI, perbaikan deskripsi platform pada README, penegakan izin `reports:export` pada aksi ekspor rekapitulasi, serta audit UI tipografi $\ge 12\text{px}$ dan tombol kembali konsisten.

---

## 2. Batasan Global & Target Penerimaan (Global Constraints & Acceptance Targets)

- **Ukuran Tipografi:** Seluruh teks pada komponen antarmuka berukuran font $\ge 12\text{px}$ (diaudit ketat di Task 8 & 9).
- **Warna & Aksen:** Warna judul kartu utama konsisten menggunakan `KokColors.cardTitle` (`#141414`).
- **Navigasi:** Tombol kembali menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`. Struktur 5 tab navigasi bawah tetap utuh.
- **Fail-Closed Principle:** Segala bentuk anomali metadata, konfigurasi produksi tidak sah, atau pembacaan data tanpa sesi aktif ditolak keras (*fail-closed*).
- **Token Privacy:** Raw access token/session material tidak diekspos dalam `AuthSignedIn` publik, melainkan dikelola secara privat di dalam controller/coordinator.
- **Nilai Wajib Tanpa Default:** Seluruh konfigurasi key/namespace storage bersifat wajib tanpa fallback default ke environment demo.
- **Target Penerimaan:** `flutter analyze` 0 issues dan 100% test suite lulus (mencakup 31 skenario `SC-01` s/d `SC-31`).

---

## 3. Rincian Teknis Arsitektur & Remediasi

### 3.1 Domain Model Murni, Scope Tanpa Fallback, & CredentialIdGenerator (Menutup R2-03 & R2-05 Foundation)

#### A. `AccessScope` dan `UserPrincipal` Murni
Identity `AccessScope` ditentukan secara unik oleh `(type, id)`. Property `name` bertindak sebagai display label. Fallback otomatis ke Garut Kota dihapus total:
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

Standarisasi Nama Tampilan Scope:
- Garut Kota: `type: AccessScopeType.district`, `id: 'garut_kota'`, `name: 'Kecamatan Garut Kota'`
- Tarogong Kidul: `type: AccessScopeType.district`, `id: 'tarogong_kidul'`, `name: 'Kecamatan Tarogong Kidul'`
- KONI Kabupaten: `type: AccessScopeType.county`, `id: 'koni_kab'`, `name: 'KONI Kabupaten Garut'`

#### B. State Publik Bersih
Hapus `accessToken` dari state publik `AuthSignedIn`. Material sesi disimpan secara privat di dalam controller:
```dart
final class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.user,
    required this.generation,
  });

  final UserPrincipal user;
  final int generation;
}
```

#### C. Interface `CredentialIdGenerator`
Guna mendukung ID unik per sesi yang deterministik pada pengujian dan acak aman pada produksi:
```dart
abstract interface class CredentialIdGenerator {
  String generate();
}

class UuidCredentialIdGenerator implements CredentialIdGenerator {
  const UuidCredentialIdGenerator();

  @override
  String generate() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
```

---

### 3.2 Storage Semantics, Parser Ketat, & Abstraksi Secure Storage (Menutup R2-01 & R2-05)

#### A. Typed Exceptions & Semantik Kegagalan
```dart
class StorageException implements Exception {
  final String message;
  const StorageException(this.message);

  @override
  String toString() => message; // Tidak mengekspos underlying cause/stack
}

class CorruptCredentialException extends StorageException {
  const CorruptCredentialException(super.message);
}

class MetadataStorageException implements Exception {
  final String message;
  const MetadataStorageException(this.message);

  @override
  String toString() => message;
}

class CorruptMetadataException implements Exception {
  final String message;
  const CorruptMetadataException(this.message);

  @override
  String toString() => message;
}
```

Aturan:
- Nilai storage `null` = kredensial/metadata tidak ada (*absent*).
- Nilai kosong `""`, whitespace, JSON invalid, atau schema tidak cocok = *corrupt*, melempar `CorruptCredentialException` atau `CorruptMetadataException`.
- Seluruh penulisan SharedPreferences (`setString`, `remove`) memeriksa hasil return boolean. Jika `false`, melempar `MetadataStorageException`.

#### B. `StoredCredential` Model
Batas maksimum: `credentialId` 128 karakter, `refreshToken` 8192 karakter:
```dart
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
      throw const CorruptCredentialException('Format credential harus berupa JSON object');
    }
    final credId = json['credentialId'];
    final token = json['refreshToken'];
    if (credId is! String || credId.trim().isEmpty || credId.length > 128) {
      throw const CorruptCredentialException('credentialId tidak valid atau melebihi batas 128 karakter');
    }
    if (token is! String || token.trim().isEmpty || token.length > 8192) {
      throw const CorruptCredentialException('refreshToken tidak valid atau melebihi batas 8192 karakter');
    }
    return StoredCredential(
      credentialId: credId,
      refreshToken: token,
    );
  }

  @override
  String toString() => 'StoredCredential([REDACTED])';
}
```

#### C. Abstraksi `SecureKeyValStore` & `AuthTokenStorage`
Untuk memungkinkan pengujian fault-injection sungguhan pada `SecureAuthTokenStorage`:
```dart
abstract interface class SecureKeyValStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<bool> containsKey({required String key});
}

abstract interface class AuthTokenStorage {
  Future<StoredCredential?> read();
  Future<void> write(StoredCredential credential);
  Future<bool> clearIfOwnedBy(String credentialId);
  Future<void> forceClearForRecovery();
  Future<void> migrateLegacyStorage();
}
```
`migrateLegacyStorage()` adalah operasi migrasi eksplisit yang hanya dijalankan saat bootstrap awal, menghapus key lama `v1_kok_refresh_token` secara best-effort tanpa side effect pada pemanggilan `read()`.

#### D. `SessionMetadata` & `SessionMetadataStore`
```dart
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
      throw const CorruptMetadataException('expectedCredentialId wajib ada saat restoreAllowed bernilai true');
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
```

---

### 3.3 Kontrak Repository & Dataset Demo Kabupaten (Menutup R2-03 & R2-05)

#### A. Kontrak `AuthRepository` & Session Handle
Repository selalu mengembalikan session handle privat (`accessToken`) pada login berhasil, terlepas dari opsi `staySignedIn`. Opsi `staySignedIn` hanya menentukan ketersediaan `refreshToken`:
```dart
enum RemoteRevocationStatus { revoked, notApplicable, failed }

final class RemoteRevocationResult {
  final RemoteRevocationStatus status;
  final String? message;

  const RemoteRevocationResult(this.status, [this.message]);

  factory RemoteRevocationResult.notApplicable() =>
      const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
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

#### B. Pemetaan 3 Akun Demo & Fixture Gabungan Kabupaten
`DemoAuthRepository` memetakan exact 3 token:
- `'token_usr_garut_kota'` $\rightarrow$ Pak Asep (`usr_garut_kota`, `garut_kota`)
- `'token_usr_tarogong_kidul'` $\rightarrow$ Pak Cecep (`usr_tarogong_kidul`, `tarogong_kidul`)
- `'token_usr_koni_kab'` $\rightarrow$ Ibu Rina (`usr_koni_kab`, `koni_kab`)

`DemoKokRepository` mengembalikan data gabungan Kabupaten Garut:
- 5 cabor unik: `Sepak Bola`, `Bulu Tangkis`, `Pencak Silat`, `Bola Voli`, `Renang` (nama cabor distandarisasi `'Bola Voli'`).
- 9 klub terdaftar (5 Garut Kota + 4 Tarogong Kidul).
- 213 atlet (125 Garut Kota + 88 Tarogong Kidul).
- 18 pelatih (10 Garut Kota + 8 Tarogong Kidul).
- Seluruh angka dihitung dinamis dari fixture. Unknown scope melempar `UnsupportedScopeException(scope.id)`.

---

### 3.4 Hardening AuthController: Dua Fase, Truth Table, & Alur Crash-Consistent (Menutup R2-01, R2-02, & R2-04)

#### A. Serialisasi `_mutationQueue`
Seluruh penulisan/penghapusan storage lokal dimasukkan ke antrean serial `_mutationQueue`. Jika operasi sebelumnya gagal/melempar exception, antrean tetap berlanjut tanpa deadlock:
```dart
Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
  final previous = _mutationQueue;
  final completer = Completer<T>();
  _mutationQueue = previous.then((_) async {
    try {
      final res = await mutation();
      completer.complete(res);
    } catch (e, st) {
      completer.completeError(e, st);
    }
  });
  return completer.future;
}
```

#### B. Truth Table Bootstrap
| Metadata Store | Token Storage | Status Metadata | Match ID? | Tindakan Bootstrap | State Akhir |
|---|---|---|---|---|---|
| Null / Tidak Ada | Null / Tidak Ada | - | - | Sesi baru bersih | `AuthSignedOut(clean)` |
| Null / Tidak Ada | Ada Credential | - | - | Orphaned token (anomali) $\rightarrow$ force clear | `AuthSignedOut(failed)` |
| Corrupt / Exception | - | - | - | Metadata rusak $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata | - | `pending` | - | Crash saat mutasi sebelumnya $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata | - | `failed` | - | Sesi gagal dibersihkan $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata (`clean`) | Null / Tidak Ada | `clean` | - | Credential hilang | `AuthSignedOut(clean)` |
| Ada Metadata (`clean`) | Ada Credential | `clean` | ID Berbeda | Mismatch ID $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata (`clean`) | Ada Credential | `clean` | ID Cocok | Panggil `repo.restoreSession(token)` | `AuthSignedIn` jika valid |
| Ada Metadata (`clean`) | Ada Credential | `clean` | ID Cocok | `repo.restoreSession` kedaluwarsa/gagal $\rightarrow$ cleanup credential | `AuthSignedOut(clean)` |

#### C. Dua Fase Login & Rollback
1. **Fase 1: Reserve**
   - Validasi matriks: hanya boleh dipanggil saat `AuthSignedOut(clean)`.
   - Naikkan `_operationEpoch`.
   - Set state sinkron $\rightarrow$ `const AuthSigningIn()`.
   - Catat `ticket = _operationEpoch`.
2. **Fase 2: Execute (Di Luar Lock)**
   - Panggil `await repo.login(...)`. Network call tidak menahan antrean storage.
3. **Fase 3: Commit (Di Dalam `_mutationQueue`)**
   - Masuk `_enqueueMutation`.
   - Revalidasi: jika `ticket != _operationEpoch`, batalkan commit dan jangan ubah storage.
   - Tulis metadata awal: `restoreAllowed = false, cleanupStatus = pending`.
   - Buat `credentialId` via `credentialIdGenerator.generate()`.
   - Tulis `StoredCredential` jika `staySignedIn == true`.
   - Periksa ulang `ticket == _operationEpoch`. Jika berubah, lakukan rollback: `await tokenStorage.clearIfOwnedBy(credentialId)`.
   - Tulis metadata final: `restoreAllowed = staySignedIn, cleanupStatus = clean, expectedCredentialId = credentialId`.
   - Simpan session handle privat.
   - Publikasikan `AuthSignedIn`.

#### D. Operasi `cancelSignIn()`
```dart
Future<AuthCommandResult> cancelSignIn() async {
  if (state is! AuthSigningIn) {
    return const AuthCommandRejected(AuthCommandRejection.invalidState);
  }
  _operationEpoch++;
  state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean);
  return const AuthCommandAccepted();
}
```
Jika request jaringan login selesai setelah `cancelSignIn()`, saat mencoba masuk fase Commit, validasi `ticket != _operationEpoch` menolak commit.

#### E. Urutan Logout & Remote Revocation yang Benar
1. Tangkap remote session handle / refresh token secara privat.
2. Naikkan `_operationEpoch` dan `_sessionGeneration`.
3. Eviksi session handle in-memory.
4. Set state sinkron $\rightarrow$ `const AuthSigningOut()`.
5. Di dalam `_mutationQueue`:
   - Tulis metadata: `restoreAllowed = false, cleanupStatus = pending`.
   - Lakukan `await tokenStorage.clearIfOwnedBy(activeCredentialId)`.
   - Jika berhasil:
     - Tulis metadata: `restoreAllowed = false, cleanupStatus = clean`.
     - Set state: `AuthSignedOut(cleanupStatus: clean)`.
     - Tandai `localCleared = true`.
   - Jika melempar `StorageException`:
     - Tulis metadata: `restoreAllowed = false, cleanupStatus = failed`.
     - Set state: `AuthSignedOut(cleanupStatus: failed)`.
     - Tandai `localCleared = false`.
6. Di luar queue, jalankan remote revocation jika refreshToken ada:
   ```dart
   RemoteRevocationStatus remoteStatus = RemoteRevocationStatus.notApplicable;
   if (refreshToken != null) {
     try {
       final res = await repo.revokeSession(refreshToken).timeout(const Duration(seconds: 5));
       remoteStatus = res.status;
     } catch (_) {
       remoteStatus = RemoteRevocationStatus.failed;
     }
   }
   ```
7. Kembalikan `LogoutResult(localSessionClosed: true, credentialCleared: localCleared, remoteRevocationStatus: remoteStatus)`.

#### F. Operasi Recovery `retryLocalCredentialCleanup()`
Di dalam `_mutationQueue`:
- Panggil `await tokenStorage.forceClearForRecovery()`.
- Tulis metadata `restoreAllowed = false, cleanupStatus = clean, expectedCredentialId = null`.
- Set state `AuthSignedOut(cleanupStatus: clean)`.

---

### 3.5 Kontrak Data & Stale Guard Pasca-Await (Menutup R2-06)

#### A. Kontrak `KokRepository` Murni
Metode `fetch()` tanpa scope dihapus permanen:
```dart
abstract interface class KokRepository {
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  });
}
```

#### B. Abstraksi `RequestCancellation` Ber-notifikasi
```dart
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
```

#### C. `DataRequestContext` & Post-Await Guard di `snapshotProvider`
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

  // Verifikasi pasca-await: jika konteks berubah saat request berjalan, buang hasil
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
    return null; // Stop auto-retry untuk exception siklus sesi
  }
  return null;
});
```

---

### 3.6 Arsitektur Composition Root Tanpa Cycle (Menutup R2-07)

Struktur file:
- `lib/core/config/deployment_profile.dart`: `AppEnvironment`, `AuthMode`, `DataMode`, `DeploymentProfile`.
- `lib/core/composition/app_composition.dart`: `AppComposition` factory yang menyusun repository dan storage tanpa cycle.
- `lib/data/kok_repository.dart`: model `KokSnapshot`, `KokRepository`, exception data, `RequestCancellation`.
- `lib/data/demo_kok_repository.dart`: implementasi `DemoKokRepository`.
- `lib/data/providers/snapshot_provider.dart`: `sessionDataContextProvider`, `snapshotProvider`.

`main()` hanya meng-override composition dan platform storage dasar:
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
        appCompositionProvider.overrideWithValue(composition),
      ],
      child: const KokApp(),
    ),
  );
}
```
Seluruh provider turunan (`authRepositoryProvider`, `repositoryProvider`, `authTokenStorageProvider`, `sessionMetadataStoreProvider`, `rememberedSkStoreProvider`) membaca dari `ref.watch(appCompositionProvider)`.

---

## 4. Rencana Verifikasi & Matriks 31 Skenario Pengujian Tetap (SC-01 s/d SC-31)

| ID | Kategori | Skenario Pengujian | Task Terkait | File Test |
|---|---|---|---|---|
| **SC-01** | Storage & Cleanup | Logout clear berhasil $\rightarrow$ state signed-out bersih, token kosong, metadata `restoreAllowed = false, cleanupStatus = clean`. | Task 5 | `test/auth_controller_test.dart` |
| **SC-02** | Storage & Cleanup | Logout clear gagal (`StorageException`) $\rightarrow$ data terkunci, `cleanupStatus == failed`, metadata `restoreAllowed = false, cleanupStatus = failed`, token tidak dipakai auto-login. | Task 5 | `test/auth_controller_test.dart` |
| **SC-03** | Storage & Cleanup | Restart setelah clear gagal $\rightarrow$ bootstrap membaca metadata `cleanupStatus == failed`, menolak auto-login, menyajikan banner retry di `LoginPage`. | Task 4 & 8 | `test/auth_controller_test.dart`, `test/login_page_test.dart` |
| **SC-04** | Storage & Cleanup | `retryLocalCredentialCleanup()` berhasil $\rightarrow$ force clear storage, metadata bersih, login diaktifkan kembali. | Task 5 | `test/auth_controller_test.dart` |
| **SC-05** | Storage & Cleanup | `retryLocalCredentialCleanup()` gagal $\rightarrow$ status tetap failed, auto-restore & login baru tetap diblokir. | Task 5 | `test/auth_controller_test.dart` |
| **SC-06** | Storage & Cleanup | Double logout / concurrent logout tap $\rightarrow$ hanya satu operasi cleanup storage dijalankan, tidak terjadi race. | Task 5 | `test/auth_controller_test.dart` |
| **SC-07** | Storage & Cleanup | Percobaan login saat cleanup berlangsung $\rightarrow$ ditolak dengan `AuthCommandRejected(cleanupRequired)`. | Task 5 | `test/auth_controller_test.dart` |
| **SC-08** | Storage & Cleanup | Crash sebelum `restoreAllowed = true` saat login $\rightarrow$ token orphaned tidak dipakai auto-login pada startup berikutnya. | Task 4 & 5 | `test/auth_controller_test.dart` |
| **SC-09** | Storage & Cleanup | Metadata fail-closed: field hilang, tipe salah, unknown schemaVersion, atau `expectedCredentialId` kosong/mismatch ditolak keras $\rightarrow$ status failed. | Task 2 & 4 | `test/session_metadata_store_test.dart`, `test/auth_controller_test.dart` |
| **SC-10** | Storage & Cleanup | Local cleanup tetap tuntas dan state signed-out ketika remote revocation mengalami timeout (5s). | Task 5 | `test/auth_controller_test.dart` |
| **SC-11** | Storage & Cleanup | `LogoutResult`: status `notApplicable` terbedakan dari `failed` atau `revoked`. | Task 5 | `test/auth_controller_test.dart` |
| **SC-12** | Concurrency & Ownership | `cancelSignIn()` saat execute jaringan menggantung $\rightarrow$ state kembali ke `AuthSignedOut(clean)`, respons login lama tidak pernah masuk commit. | Task 5 | `test/auth_controller_test.dart` |
| **SC-13** | Concurrency & Ownership | Revalidasi tiket operasi pasca-antrean commit $\rightarrow$ commit ditolak jika epoch berubah saat menunggu antrean. | Task 5 | `test/auth_controller_test.dart` |
| **SC-14** | Concurrency & Ownership | Storage ownership guard: credential B tersimpan $\rightarrow$ `clearIfOwnedBy(credentialA.credentialId)` mengembalikan false $\rightarrow$ credential B tidak terhapus. | Task 2 | `test/auth_token_storage_test.dart` |
| **SC-15** | Concurrency & Ownership | Exception pada antrean mutasi storage $\rightarrow$ lock dilepas tanpa deadlock, operasi berikutnya tetap dapat diproses. | Task 4 | `test/auth_controller_test.dart` |
| **SC-16** | Concurrency & Ownership | `cancelSignIn()` ketika commit sudah mulai di bawah lock ditolak dengan `AuthCommandRejected(operationInProgress)`. | Task 5 | `test/auth_controller_test.dart` |
| **SC-17** | DEMO-003 & Scope | Login `DEMO-003` dengan Tetap Masuk $\rightarrow$ dispose container $\rightarrow$ bootstrap baru $\rightarrow$ identitas tetap Ibu Rina (`usr_koni_kab`), bukan akun lain. | Task 3 & 5 | `test/auth_repository_test.dart`, `test/auth_controller_test.dart` |
| **SC-18** | DEMO-003 & Scope | Snapshot `DEMO-003` memuat data gabungan kabupaten: 5 cabor unik (Sepak Bola, Bulu Tangkis, Pencak Silat, Bola Voli, Renang), 9 klub, 213 atlet, 18 pelatih dihitung dinamis. | Task 3 | `test/repository_test.dart` |
| **SC-19** | DEMO-003 & Scope | Unknown scope melempar `UnsupportedScopeException` tanpa fallback default ke Garut Kota. | Task 3 | `test/repository_test.dart` |
| **SC-20** | DEMO-003 & Scope | Migrasi eksplisit legacy key `v1_kok_refresh_token` fail-closed (menghapus legacy key tanpa auto-login). | Task 2 & 4 | `test/auth_token_storage_test.dart` |
| **SC-21** | DEMO-003 & Scope | Token panjang (hingga 8192 karakter) dan credentialId (hingga 128 karakter) diparsing dan divalidasi sukses; melebihi batas ditolak. | Task 2 | `test/auth_token_storage_test.dart` |
| **SC-22** | Data Cancellation | `RequestCancellation` idempoten (pembatalan berulang tidak melempar error dan reason awal dipertahankan). | Task 3 | `test/repository_test.dart` |
| **SC-23** | Data Cancellation | Delayed fetch A in-flight $\rightarrow$ switch akun ke user B $\rightarrow$ request A dibatalkan lewat cancellation token, data B tidak tercemar. | Task 6 | `test/session_scope_test.dart` |
| **SC-24** | Data Cancellation | Scope/generation/environment berubah tanpa transport membatalkan request $\rightarrow$ post-await context guard melempar `StaleSessionResultException`. | Task 6 | `test/session_scope_test.dart` |
| **SC-25** | Data Cancellation | Lifecycle exceptions (`SessionRequiredException`, `RequestCancelledException`, `StaleSessionResultException`, `UnsupportedScopeException`) tidak memicu auto-retry. | Task 6 | `test/session_scope_test.dart` |
| **SC-26** | Composition & Env | Production composition melempar `StateError` saat startup jika adapter remote belum tersedia (fail-closed). | Task 7 | `test/app_environment_test.dart` |
| **SC-27** | Composition & Env | Konfigurasi `dataMode.remote + authMode.demo` ditolak keras dengan `StateError` pada seluruh environment. | Task 7 | `test/app_environment_test.dart` |
| **SC-28** | Composition & Env | Demo environment mewajibkan authMode demo dan dataMode demo. | Task 7 | `test/app_environment_test.dart` |
| **SC-29** | Composition & Env | Namespace metadata, remembered SK, dan secure storage credential terisolasi penuh antar-environment. | Task 7 | `test/app_environment_test.dart` |
| **SC-30** | UI & Permissions | Pengguna tanpa izin `reports:export` (`DEMO-002` / Pak Cecep) melihat tombol salin rekapitulasi disabled dan double-check handler memblokir penyalinan. | Task 8 | `test/profile_page_test.dart` |
| **SC-31** | UI & Honesty | Seluruh codebase UI bebas dari klaim palsu "tersinkronisasi SICABOR", menampilkan teks status jujur dan catatan kontak demo. | Task 8 | `test/profile_page_test.dart`, `test/home_page_test.dart` |

---

## 5. Kriteria Selesai (Definition of Done)

- Seluruh 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan Bagian 5 tertutup tuntas.
- Mutasi storage diserialisasi penuh dengan token ownership guard berbasis ID via `_mutationQueue`.
- Kegagalan cleanup storage dipersistensikan sebagai `SessionMetadata` fail-closed dan memiliki recovery idempoten.
- Ketiga akun demo (`DEMO-001`, `DEMO-002`, `DEMO-003`) memiliki identitas, token, scope, dan dataset fixture yang konsisten.
- Kontrak data tidak memiliki backdoor tanpa scope dan kebal terhadap delayed responses.
- Composition root bebas dependency cycle dan menjamin isolasi konfigurasi produksi yang fail-closed.
- `flutter analyze` 0 issues dan seluruh pengujian (SC-01 s/d SC-31) lulus 100%.

# Desain Remediasi Penguatan Arsitektur Autentikasi & Siklus Sesi (Tahap A Patch 2)

Tanggal: 2026-09-09  
Status: Approved for Implementation Planning (Sinkronisasi Final v3 Deterministic)  
Penulis: Pengembang & Reviewer Teknis  
Dokumen Rujukan: `docs/audit-auth-review-tahap1-kedua.md` (Temuan R2-01 s/d R2-07, Temuan Bagian 5)  

---

## 1. Latar Belakang & Sasaran Remediasi

Berdasarkan hasil audit tahap kedua pada `docs/audit-auth-review-tahap1-kedua.md`, temuan A-01 (Guard State Transisi) dan A-08 (Dua Sumber Sesi Ganda) telah ditandai tertutup pada review statis sebelumnya. Dokumen ini menetapkan target *robustness* dan kesiapan integrasi guna menyelesaikan 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan konsistensi Bagian 5 secara tuntas, deterministik, dan tanpa breaking changes yang merusak kompilasi antar-task:

1. **R2-01 (Race Commit/Clear Token & Ownership):** Operasi login *stale* dilarang menjalankan pembersihan global. Penulisan dan penghapusan storage diserialisasi via `_mutationQueue`, kepemilikan credential dilindungi dengan ID unik per sesi (`credentialId`), dan fase internal `SignInPhase` membedakan execute jaringan dengan commit storage.
2. **R2-02 (Logout Storage Failure & Penanganan State):** Kegagalan menghapus token memiliki status bertipe `LocalCleanupStatus`, dipersistensikan sebagai *single-record crash-resilient* `SessionMetadata` di `SharedPreferences` yang memperhitungkan `restoreAllowed == true`. Seluruh proses logout di-`await` di UI, dan remote revocation di-`await` dengan timeout terbatas (5 detik) setelah state lokal dipublikasikan.
3. **R2-03 (Konsistensi Akun DEMO-003):** Akun `DEMO-003` (Ibu Rina · KONI Kab) memiliki token persisten exact (`token_usr_koni_kab`), scope kabupaten terpisah (`AccessScopeType.county`), dan fixture gabungan 5 cabang olahraga unik se-Kabupaten Garut (Sepak Bola, Bulu Tangkis, Pencak Silat, Bola Voli, Renang). `KokSnapshot` membawa identitas scope eksplisit tanpa inferensi ID klub.
4. **R2-04 (Mutasi Auth Paralel & Matriks Transisi):** Controller menerapkan matriks transisi state legal dengan operasi pembatalan eksplisit `cancelSignIn()`, membedakan pembatalan logis dan pembatalan transport via `Future.any()`.
5. **R2-05 (Rekursi Interface Storage & Namespace Kanonis):** `AuthTokenStorage` disederhanakan tanpa rekursi, menggunakan namespace terversi per environment (`kok.auth.v2.<env>.credential`, `metadata`, `remembered_sk`) tanpa nilai default implisit, memisahkan migrasi legacy menjadi operasi bootstrap eksplisit, dan membungkus `SecureKeyValStore` agar dapat diuji fault-injection.
6. **R2-06 (Kontrak Repository & Cancellation End-to-End):** Abstraksi `RequestCancellation` dengan notifikasi dan pengecekan pasca-`await`, peniadaan `fetch()` tanpa scope, dan verifikasi generasi pasca-`await` via `DataRequestContext` dengan no-retry policy untuk error siklus sesi.
7. **R2-07 (Composition Root Bebas Dependency Cycle):** `DeploymentProfile` memisahkan konfigurasi environment, auth mode, dan data mode secara independen; dependency terstruktur modular tanpa cycle (`core/config/`, `core/composition/`, `data/`); `main()` hanya meng-override composition dan platform storage dasar.
8. **Bagian 5 (Sisa Klaim SICABOR & Penegakan Izin):** Pembersihan sisa klaim SICABOR pada UI (melarang klaim aktif tersinkronisasi, mengizinkan penegasan bahwa data demo belum terhubung SICABOR), perbaikan deskripsi platform pada README, penegakan izin `reports:export` pada aksi ekspor rekapitulasi, serta audit UI tipografi $\ge 12\text{px}$ dan tombol kembali konsisten.

---

## 2. Batasan Global & Target Penerimaan (Global Constraints & Acceptance Targets)

- **Ukuran Tipografi:** Seluruh teks pada komponen antarmuka berukuran font $\ge 12\text{px}$ (diaudit ketat di Task 8 & 9).
- **Warna & Aksen:** Warna judul kartu utama konsisten menggunakan `KokColors.cardTitle` (`#141414`).
- **Navigasi:** Tombol kembali menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`. Struktur 5 tab navigasi bawah tetap utuh.
- **Fail-Closed Principle:** Segala bentuk anomali metadata, konfigurasi produksi tidak sah, atau pembacaan data tanpa sesi aktif ditolak keras (*fail-closed*).
- **Token Privacy:** Raw access token/session material tidak diekspos dalam `AuthSignedIn` publik, melainkan dikelola secara privat di dalam controller melalui `RemoteSessionHandle`.
- **Nilai Wajib Tanpa Default:** Seluruh konfigurasi key/namespace storage bersifat wajib tanpa fallback default ke environment demo.
- **Defensive Immutability:** Permission pada `UserPrincipal` dibungkus `Set.unmodifiable` secara defensif.
- **Target Penerimaan:** `flutter analyze` 0 issues, 100% test suite lulus (mencakup 31 skenario `SC-01` s/d `SC-31`), dan `flutter build apk --debug` berhasil.

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

  UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.fullName,
    required this.roleTitle,
    required this.scope,
    this.profileImageUrl,
    Set<String> permissions = const <String>{},
  }) : permissions = Set.unmodifiable(permissions);

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

class DeterministicCredentialIdGenerator implements CredentialIdGenerator {
  int _counter = 0;
  final String prefix;
  DeterministicCredentialIdGenerator([this.prefix = 'cred']);

  @override
  String generate() => '$prefix-${++_counter}';
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
  String toString() => message; // Tidak membocorkan underlying cause/stack
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
    if (!restore && credId != null && credId.trim().isNotEmpty) {
      throw const CorruptMetadataException('expectedCredentialId dilarang ada saat restoreAllowed bernilai false');
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

#### A. Kontrak `AuthRepository` & Typed `RemoteSessionHandle`
Repository selalu menghasilkan `RemoteSessionHandle` privat pada login berhasil terlepas dari opsi `staySignedIn`:
```dart
final class RemoteSessionHandle {
  final String revocationToken;
  const RemoteSessionHandle(this.revocationToken);

  @override
  String toString() => 'RemoteSessionHandle([REDACTED])';
}

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
  final RemoteSessionHandle? sessionHandle;
  final String? refreshToken;
  final AuthFailure? failure;

  const AuthResult.success({
    required UserPrincipal this.user,
    required RemoteSessionHandle this.sessionHandle,
    this.refreshToken,
  }) : failure = null;

  const AuthResult.failed(AuthFailure this.failure)
      : user = null,
        sessionHandle = null,
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
  Future<RemoteRevocationResult> revokeSession(RemoteSessionHandle session);
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

#### C. `KokSnapshot` Membawa Scope Eksplisit
```dart
final class KokSnapshot {
  const KokSnapshot({
    required this.scope,
    required this.clubs,
    required this.people,
    required this.loadedAt,
    this.committee = const [],
  });

  final AccessScope scope;
  final List<Club> clubs;
  final List<SportPerson> people;
  final DateTime loadedAt;
  final List<CommitteeMember> committee;

  List<String> get sports => clubs.map((c) => c.sport).toSet().toList();

  @Deprecated('Gunakan snapshot.scope.id')
  String get districtId => scope.id;

  @Deprecated('Gunakan snapshot.scope.name')
  String get districtName => scope.name;
}
```

---

### 3.4 Hardening AuthController: Dua Fase, Truth Table, & Alur Crash-Resilient (Menutup R2-01, R2-02, & R2-04)

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

#### B. Truth Table Bootstrap Lengkap dengan `restoreAllowed`
| Metadata Store | Token Storage | restoreAllowed | Cleanup Status | Match ID? | Tindakan Bootstrap | State Akhir |
|---|---|---|---|---|---|---|
| Null / Absent | Null / Absent | - | - | - | Sesi baru bersih | `AuthSignedOut(clean)` |
| Null / Absent | Ada Credential | - | - | - | Orphaned token $\rightarrow$ force clear | `AuthSignedOut(failed)` |
| Corrupt / Exception | - | - | - | - | Metadata corrupt $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata | - | `false` | `pending` | - | Crash saat mutasi $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata | - | `false` | `failed` | - | Sesi gagal dibersihkan $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata | Null / Absent | `false` | `clean` | - | Signed-out bersih normal | `AuthSignedOut(clean)` |
| Ada Metadata | Ada Credential | `false` | `clean` | - | Orphan token $\rightarrow$ force clear | `AuthSignedOut(failed)` |
| Ada Metadata | Null / Absent | `true` | `clean` | - | Credential hilang $\rightarrow$ normalisasi metadata | `AuthSignedOut(clean)` |
| Ada Metadata | Ada Credential | `true` | `clean` | ID Berbeda | Mismatch ID $\rightarrow$ tolak restore | `AuthSignedOut(failed)` |
| Ada Metadata | Ada Credential | `true` | `clean` | ID Cocok | Panggil `repo.restoreSession(token)` | `AuthSignedIn` jika valid |
| Ada Metadata | Ada Credential | `true` | `clean` | ID Cocok | `restoreSession` expired $\rightarrow$ cleanup sesi | `AuthSignedOut(clean)` |

#### C. Fase Internal `SignInPhase` & Operasi `cancelSignIn()`
```dart
enum SignInPhase {
  idle,
  executing,
  waitingForCommit,
  committing,
}
```
Aturan:
- `executing` atau `waitingForCommit` $\rightarrow$ `cancelSignIn()` diterima (`AuthCommandAccepted`). State kembali ke `AuthSignedOut(clean)`.
- `committing` $\rightarrow$ `cancelSignIn()` ditolak dengan `AuthCommandRejected(AuthCommandRejection.operationInProgress)`.
- Di dalam `login()`:
  - Phase 1 Reserve: set phase `executing`, state `AuthSigningIn()`.
  - Phase 2 Execute: `Future.any([repo.login(...), cancelTrigger.future])`.
  - Phase 3 Commit: di bawah `_mutationQueue`, ubah phase ke `committing`. Periksa `ticket == _operationEpoch`. Tulis credential (jika `staySignedIn == true`), tulis metadata final.
  - Selesai/Gagal: phase kembali ke `idle`.

#### D. Failure Matrix Persistence Controller
1. **Metadata pending write gagal:** abort, state `AuthTemporarilyUnavailable` atau `AuthSignedOut(failed)`.
2. **Secure credential write gagal (`StorageException`):** rollback metadata ke `clean` (`restoreAllowed: false`), state `AuthSignedOut(failed)`.
3. **Epoch berubah setelah credential ditulis:** rollback credential via `clearIfOwnedBy(credentialId)`.
4. **Metadata final write gagal:** rollback credential via `clearIfOwnedBy(credentialId)`.
5. **`clearIfOwnedBy()` mengembalikan `false`:** jika snapshot awal mendeteksi credential ada, tandai sebagai ownership mismatch.
6. **Restore gagal dan cleanup credential gagal:** state `AuthSignedOut(failed)`.
7. **Token berhasil dihapus tapi penulisan metadata clean gagal:** state `AuthSignedOut(failed)`.
8. **Force-clear berhasil tapi metadata recovery gagal:** state `AuthSignedOut(failed)`.

#### E. Urutan Logout & Remote Revocation yang Benar
1. Tangkap remote session handle dan refresh token secara privat.
2. Naikkan `_operationEpoch` dan `_sessionGeneration`.
3. Eviksi session handle in-memory.
4. Set state sinkron $\rightarrow$ `const AuthSigningOut()`.
5. Di dalam `_mutationQueue`:
   - Tulis metadata: `restoreAllowed = false, cleanupStatus = pending`.
   - Jika ada `activeCredentialId`: panggil `await tokenStorage.clearIfOwnedBy(activeCredentialId)`.
   - Jika tidak ada credential (sesi nonpersisten): tandai `localCleared = true`.
   - Jika berhasil:
     - Tulis metadata: `restoreAllowed = false, cleanupStatus = clean, expectedCredentialId = null`.
     - Set state: `AuthSignedOut(cleanupStatus: clean)`.
     - Tandai `localCleared = true`.
   - Jika melempar `StorageException`:
     - Tulis metadata: `restoreAllowed = false, cleanupStatus = failed`.
     - Set state: `AuthSignedOut(cleanupStatus: failed)`.
     - Tandai `localCleared = false`.
6. Di luar queue, jalankan remote revocation jika `sessionHandle != null`:
   ```dart
   RemoteRevocationStatus remoteStatus = RemoteRevocationStatus.notApplicable;
   if (sessionHandle != null) {
     try {
       final res = await repo.revokeSession(sessionHandle).timeout(const Duration(seconds: 5));
       remoteStatus = res.status;
     } catch (_) {
       remoteStatus = RemoteRevocationStatus.failed;
     }
   }
   ```
7. Kembalikan `LogoutResult(localSessionClosed: true, credentialCleared: localCleared, remoteRevocationStatus: remoteStatus)`.

---

### 3.5 Kontrak Data, Stale Guard, & No-Retry Policy (Menutup R2-06)

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

#### B. `snapshotProvider` Guard Pasca-Await
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

  // Cancellation check segera setelah await
  cancellationController.token.throwIfCancelled();

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
    return null; // Nonaktifkan retry untuk error siklus sesi
  }
  return ProviderContainer.defaultRetry(retryCount, error);
});
```

---

### 3.6 Arsitektur Composition Root Tanpa Cycle & Strategi Migrasi (Menutup R2-07)

Struktur file:
- `lib/core/config/deployment_profile.dart`: `AppEnvironment`, `AuthMode`, `DataMode`, `DeploymentProfile`.
- `lib/core/composition/app_composition.dart`: `AppComposition` factory yang menerima dependency testable:
  ```dart
  factory AppComposition.fromProfile(
    DeploymentProfile profile, {
    required SharedPreferences preferences,
    required SecureKeyValStore secureStore,
    required CredentialIdGenerator credentialIdGenerator,
  });
  ```
- `lib/data/kok_repository.dart`: `KokSnapshot`, `KokRepository`, exceptions data, `RequestCancellation`.
- `lib/data/demo_kok_repository.dart`: `DemoKokRepository`.
- `lib/data/providers/snapshot_provider.dart`: `sessionDataContextProvider`, `snapshotProvider`.

Strategi Migrasi Barrel:
- `lib/core/config/app_environment.dart` menjadi re-export sementara ke `deployment_profile.dart`.
- `lib/data/repository.dart` menjadi re-export barrel sementara ke `kok_repository.dart`, `demo_kok_repository.dart`, dan `snapshot_provider.dart`.
- Seluruh callsite di `lib/` dan `test/` dimigrasikan pada Task 7, kemudian barrel lama dibersihkan.

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
| **SC-09** | Storage & Cleanup | Metadata fail-closed: field hilang, tipe salah, unknown schemaVersion, atau `expectedCredentialId` dilarang saat `restoreAllowed == false` ditolak keras $\rightarrow$ status failed. | Task 2 & 4 | `test/session_metadata_store_test.dart`, `test/auth_controller_test.dart` |
| **SC-10** | Storage & Cleanup | Local cleanup tetap tuntas dan state signed-out ketika remote revocation mengalami timeout (5s). | Task 5 | `test/auth_controller_test.dart` |
| **SC-11** | Storage & Cleanup | `LogoutResult`: status `notApplicable` terbedakan dari `failed` atau `revoked`. | Task 5 | `test/auth_controller_test.dart` |
| **SC-12** | Concurrency & Ownership | `cancelSignIn()` saat execute jaringan menggantung $\rightarrow$ state kembali ke `AuthSignedOut(clean)`, respons login lama tidak pernah masuk commit. | Task 5 | `test/auth_controller_test.dart` |
| **SC-13** | Concurrency & Ownership | Revalidasi tiket operasi pasca-antrean commit $\rightarrow$ commit ditolak jika epoch berubah saat menunggu antrean. | Task 5 | `test/auth_controller_test.dart` |
| **SC-14** | Concurrency & Ownership | Storage ownership guard: credential B tersimpan $\rightarrow$ `clearIfOwnedBy(credentialA.credentialId)` mengembalikan false $\rightarrow$ credential B tidak terhapus. | Task 2 | `test/auth_token_storage_test.dart` |
| **SC-15** | Concurrency & Ownership | Exception pada antrean mutasi storage $\rightarrow$ lock dilepas tanpa deadlock, operasi berikutnya tetap dapat diproses. | Task 4 | `test/auth_controller_test.dart` |
| **SC-16** | Concurrency & Ownership | `cancelSignIn()` ketika commit sudah mulai di bawah lock (`SignInPhase.committing`) ditolak dengan `AuthCommandRejected(operationInProgress)`. | Task 5 | `test/auth_controller_test.dart` |
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
| **SC-31** | UI & Honesty | Seluruh codebase UI bebas dari klaim palsu (`SINKRONISASI DATA SICABOR`, `tersinkronisasi dengan SICABOR`, `data SICABOR aktif`), dan menyajikan teks jujur (`Data demo lokal—belum terhubung dengan SICABOR.`). | Task 8 | `test/profile_page_test.dart`, `test/home_page_test.dart` |

---

## 5. Kriteria Selesai (Definition of Done)

- Seluruh 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan Bagian 5 tertutup tuntas.
- Setiap task commit mempertahankan repository dalam kondisi dapat dianalisis dan dikompilasi (`flutter analyze` 0 issues).
- Mutasi storage diserialisasi penuh dengan token ownership guard berbasis ID via `_mutationQueue`.
- Kegagalan cleanup storage dipersistensikan sebagai `SessionMetadata` fail-closed dan memiliki recovery idempoten.
- Ketiga akun demo (`DEMO-001`, `DEMO-002`, `DEMO-003`) memiliki identitas, token, scope, dan dataset fixture yang konsisten.
- Kontrak data tidak memiliki backdoor tanpa scope dan kebal terhadap delayed responses.
- Composition root bebas dependency cycle dan menjamin isolasi konfigurasi produksi yang fail-closed.
- `flutter analyze` 0 issues, seluruh 31 skenario pengujian lulus 100%, dan `flutter build apk --debug` berhasil dikompilasi.

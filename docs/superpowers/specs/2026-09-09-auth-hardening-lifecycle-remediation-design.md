Tanggal: 2026-09-09
Status: **Approved for Implementation**
Penulis: Pengembang & Reviewer Teknis
Versi: Final v4 — deterministic, crash-resilient, testable

---

## 1. Latar Belakang & Sasaran Remediasi

Remediasi ini memperkuat autentikasi demo dan siklus sesi sebelum integrasi backend SICABOR. Targetnya bukan mengklaim keamanan backend produksi, melainkan membentuk batas domain, state machine, storage semantics, konfigurasi deployment, serta pengujian yang aman dan siap diganti adapter remote ketika kontrak backend tersedia.

1. **R2-01 — Race commit/clear dan ownership:** seluruh mutasi storage lokal diserialisasi; credential dilindungi `credentialId`; respons operasi stale tidak boleh menghapus credential sesi lain.
2. **R2-02 — Logout storage failure:** akses data ditutup segera, restore diblokir secara persisten, hasil cleanup bertipe, dan recovery bersifat idempoten.
3. **R2-03 — Konsistensi DEMO-003:** identitas, token, scope kabupaten, dan dataset DEMO-003 konsisten setelah restart.
4. **R2-04 — Mutasi autentikasi paralel:** matriks transisi legal, operation epoch, serta fase internal sign-in mencegah command tumpang tindih.
5. **R2-05 — Kontrak storage:** interface tunggal, parser ketat, namespace per environment, dan migrasi legacy eksplisit.
6. **R2-06 — Lifecycle data:** request dibatalkan secara logis, transport dibatalkan bila adapter mendukung, dan respons stale ditolak setelah `await`.
7. **R2-07 — Composition root:** environment, auth mode, dan data mode divalidasi fail-closed tanpa dependency cycle.
8. **Bagian 5 — UI dan permission:** klaim SICABOR dibuat jujur; aksi rekap dilindungi permission pada UI dan handler; batas client-side dinyatakan eksplisit.

---

## 2. Batasan Global & Target Penerimaan

- **Fail-closed:** metadata corrupt, credential corrupt, scope tidak dikenal, fetch tanpa sesi, dan profile deployment ilegal wajib ditolak.
- **Crash-resilient, bukan transaksi absolut:** `SessionMetadata` adalah single-record restore gate. SharedPreferences dan secure storage tetap dua subsistem berbeda tanpa transaksi lintas-storage.
- **Token privacy:** raw token tidak boleh berada dalam `AuthState`, log, pesan publik, `toString()`, analytics, atau clipboard.
- **Ownership tunggal:** hanya `AuthController`/session coordinator yang boleh mengakses `AuthTokenStorage`, `SessionMetadataStore`, dan `RememberedSkStore`.
- **Namespace wajib:** tidak ada key default implisit ke demo.
- **Scope wajib:** tidak ada fallback otomatis ke Garut Kota.
- **Repository hijau:** setiap task/commit harus lulus formatter, analyzer, dan test yang terdampak.
- **Target akhir:** `flutter analyze` 0 issues, seluruh test lulus, code generation bersih, dan `flutter build apk --debug` berhasil.
- **UI:** font eksplisit tidak boleh di bawah 12px; judul kartu memakai `KokColors.cardTitle`; tombol kembali memakai `Icons.chevron_left`, ukuran 28, dan warna yang sama; lima tab bawah tidak berubah.

---

## 3. Rincian Teknis Arsitektur

### 3.1 Domain Model Murni dan Scope Tanpa Fallback

#### A. `AccessScope`

Identitas scope ditentukan oleh `(type, id)`. `name` hanya label tampilan dan ikut diserialisasi, tetapi tidak menentukan equality.

```dart
import 'package:flutter/foundation.dart';

enum AccessScopeType { district, county }

@immutable
final class AccessScope {
  const AccessScope({
    required this.type,
    required this.id,
    required this.name,
  });

  final AccessScopeType type;
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
      };

  factory AccessScope.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('AccessScope harus berupa JSON object');
    }
    final rawType = value['type'];
    final rawId = value['id'];
    final rawName = value['name'];
    final type = rawType is String
        ? AccessScopeType.values.asNameMap()[rawType]
        : null;
    if (type == null ||
        rawId is! String || rawId.trim().isEmpty ||
        rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('AccessScope tidak valid');
    }
    return AccessScope(type: type, id: rawId, name: rawName);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessScope && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}
```

Scope kanonis:

| Akun | Type | ID | Name |
| --- | --- | --- | --- |
| DEMO-001 | `district` | `garut_kota` | Kecamatan Garut Kota |
| DEMO-002 | `district` | `tarogong_kidul` | Kecamatan Tarogong Kidul |
| DEMO-003 | `county` | `koni_kab` | KONI Kabupaten Garut |

#### B. `UserPrincipal`

```dart
@immutable
final class UserPrincipal {
  UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.fullName,
    required this.roleTitle,
    required this.scope,
    this.profileImageUrl,
    Set<String> permissions = const {},
  }) : permissions = Set.unmodifiable(permissions);

  final String id;
  final String skNumber;
  final String fullName;
  final String roleTitle;
  final AccessScope scope;
  final String? profileImageUrl;
  final Set<String> permissions;

  @Deprecated('Gunakan fullName')
  String get name => fullName;

  @Deprecated('Gunakan roleTitle')
  String get role => roleTitle;

  @Deprecated('Gunakan scope.id')
  String get districtId => scope.id;

  @Deprecated('Gunakan scope.name')
  String get districtName => scope.name;

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPrincipal &&
          other.id == id &&
          other.skNumber == skNumber &&
          other.fullName == fullName &&
          other.roleTitle == roleTitle &&
          other.scope == scope &&
          other.profileImageUrl == profileImageUrl &&
          setEquals(other.permissions, permissions);

  @override
  int get hashCode => Object.hash(
        id,
        skNumber,
        fullName,
        roleTitle,
        scope,
        profileImageUrl,
        Object.hashAllUnordered(permissions),
      );
}
```

Getter kompatibilitas hanya untuk menjaga commit migrasi tetap hijau dan harus dihapus setelah seluruh callsite memakai nama properti kanonis.

#### C. State publik dan credential ID

`AuthSignedIn` hanya membawa principal serta generation. Material sesi disimpan privat.

```dart
final class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.user, required this.generation});
  final UserPrincipal user;
  final int generation;
}

abstract interface class CredentialIdGenerator {
  String generate();
}
```

Implementasi production memakai UUID v4 berbasis `Random.secure()`; test memakai generator deterministik.

---

### 3.2 Storage Semantics, Parser Ketat, dan Namespace

#### A. Kontrak error

```dart
class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class CorruptCredentialException extends StorageException {
  const CorruptCredentialException(super.message);
}

class MetadataStorageException implements Exception {
  const MetadataStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class CorruptMetadataException extends MetadataStorageException {
  const CorruptMetadataException(super.message);
}
```

- `null` berarti absent.
- String kosong/whitespace, JSON invalid, tipe salah, atau schema tidak didukung berarti corrupt.
- Exception publik tidak boleh memuat token atau underlying cause.
- Return `false` dari `SharedPreferences.setString/remove` dipetakan ke `MetadataStorageException`.

#### B. Credential record

```dart
final class StoredCredential {
  const StoredCredential({
    required this.credentialId,
    required this.refreshToken,
  });

  final String credentialId;
  final String refreshToken;

  factory StoredCredential.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const CorruptCredentialException('Credential harus berupa object');
    }
    final id = value['credentialId'];
    final token = value['refreshToken'];
    if (id is! String || id.trim().isEmpty || id.length > 128) {
      throw const CorruptCredentialException('credentialId tidak valid');
    }
    if (token is! String || token.trim().isEmpty || token.length > 8192) {
      throw const CorruptCredentialException('refreshToken tidak valid');
    }
    return StoredCredential(credentialId: id, refreshToken: token);
  }

  Map<String, dynamic> toJson() => {
        'credentialId': credentialId,
        'refreshToken': refreshToken,
      };

  @override
  String toString() => 'StoredCredential([REDACTED])';
}
```

#### C. Storage interfaces

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

Key kanonis:

```
kok.auth.v2.<environment>.credential
kok.auth.v2.<environment>.metadata
kok.auth.v2.<environment>.remembered_sk
```

Semua key wajib diberikan constructor. `read()` tidak memiliki side effect migrasi. `migrateLegacyStorage()` hanya dipanggil saat bootstrap dan tidak pernah memakai token legacy untuk restore.

#### D. `SessionMetadata` dengan invariant construction

```dart
final class SessionMetadata {
  static const currentVersion = 1;

  const SessionMetadata._({
    required this.schemaVersion,
    required this.restoreAllowed,
    required this.cleanupStatus,
    required this.expectedCredentialId,
  });

  const SessionMetadata.signedOutClean()
      : this._(
          schemaVersion: currentVersion,
          restoreAllowed: false,
          cleanupStatus: LocalCleanupStatus.clean,
          expectedCredentialId: null,
        );

  const SessionMetadata.cleanupPending()
      : this._(
          schemaVersion: currentVersion,
          restoreAllowed: false,
          cleanupStatus: LocalCleanupStatus.pending,
          expectedCredentialId: null,
        );

  const SessionMetadata.cleanupFailed()
      : this._(
          schemaVersion: currentVersion,
          restoreAllowed: false,
          cleanupStatus: LocalCleanupStatus.failed,
          expectedCredentialId: null,
        );

  factory SessionMetadata.restoreEnabled(String credentialId) {
    if (credentialId.trim().isEmpty || credentialId.length > 128) {
      throw const CorruptMetadataException('expectedCredentialId tidak valid');
    }
    return SessionMetadata._(
      schemaVersion: currentVersion,
      restoreAllowed: true,
      cleanupStatus: LocalCleanupStatus.clean,
      expectedCredentialId: credentialId,
    );
  }

  final int schemaVersion;
  final bool restoreAllowed;
  final LocalCleanupStatus cleanupStatus;
  final String? expectedCredentialId;

  factory SessionMetadata.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const CorruptMetadataException('Metadata harus berupa object');
    }
    final version = value['schemaVersion'];
    final restore = value['restoreAllowed'];
    final rawStatus = value['cleanupStatus'];
    final rawId = value['expectedCredentialId'];
    if (version is! int || version != currentVersion || restore is! bool) {
      throw const CorruptMetadataException('Schema metadata tidak valid');
    }
    final status = rawStatus is String
        ? LocalCleanupStatus.values.asNameMap()[rawStatus]
        : null;
    if (status == null) {
      throw const CorruptMetadataException('cleanupStatus tidak valid');
    }
    if (rawId != null && rawId is! String) {
      throw const CorruptMetadataException(
        'expectedCredentialId harus string atau null',
      );
    }
    final id = rawId as String?;
    if (restore) {
      if (status != LocalCleanupStatus.clean ||
          id == null || id.trim().isEmpty || id.length > 128) {
        throw const CorruptMetadataException('Restore metadata tidak valid');
      }
      return SessionMetadata.restoreEnabled(id);
    }
    if (id != null) {
      throw const CorruptMetadataException(
        'expectedCredentialId wajib null ketika restore tidak diizinkan',
      );
    }
    return switch (status) {
      LocalCleanupStatus.clean => const SessionMetadata.signedOutClean(),
      LocalCleanupStatus.pending => const SessionMetadata.cleanupPending(),
      LocalCleanupStatus.failed => const SessionMetadata.cleanupFailed(),
    };
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'restoreAllowed': restoreAllowed,
        'cleanupStatus': cleanupStatus.name,
        'expectedCredentialId': expectedCredentialId,
      };
}
```

---

### 3.3 Repository Auth, Remote Session, dan Dataset Demo

#### A. Remote session contract

```dart
final class RemoteSessionHandle {
  const RemoteSessionHandle._(this.revocationToken);
  final String revocationToken;

  factory RemoteSessionHandle(String token) {
    if (token.trim().isEmpty || token.length > 8192) {
      throw const FormatException('Remote session handle tidak valid');
    }
    return RemoteSessionHandle._(token);
  }

  @override
  String toString() => 'RemoteSessionHandle([REDACTED])';
}

enum RemoteRevocationStatus { revoked, notApplicable, failed }

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

Login berhasil selalu menghasilkan `RemoteSessionHandle`. `staySignedIn` hanya menentukan apakah refresh token boleh disimpan. Repository tidak mengetahui storage.

#### B. Pemetaan akun demo

| Login | Password | User ID | Refresh token | Scope |
| --- | --- | --- | --- | --- |
| DEMO-001 | `kokgarut123` | `usr_garut_kota` | `token_usr_garut_kota` | Garut Kota |
| DEMO-002 | `koktarogong123` | `usr_tarogong_kidul` | `token_usr_tarogong_kidul` | Tarogong Kidul |
| DEMO-003 | `konigarut123` | `usr_koni_kab` | `token_usr_koni_kab` | Kabupaten Garut |

Unknown token menghasilkan typed session-expired failure. Unknown scope menghasilkan `UnsupportedScopeException`; tidak ada fallback.

#### C. `KokSnapshot` scoped dan serializable

Model aktual tetap memakai Freezed/JSON generation:

```dart
@freezed
abstract class KokSnapshot with _$KokSnapshot {
  const factory KokSnapshot({
    required AccessScope scope,
    required List<Club> clubs,
    required List<SportPerson> people,
    required List<CommitteeMember> committee,
    required DateTime loadedAt,
  }) = _KokSnapshot;

  factory KokSnapshot.fromJson(Map<String, dynamic> json) =>
      _$KokSnapshotFromJson(json);
}
```

`AccessScope.toJson/fromJson` wajib tersedia sebelum menjalankan build runner. Round-trip snapshot harus mempertahankan `scope.type`, `scope.id`, dan `scope.name`.

Fixture county menghitung dinamis:

- 5 cabor unik: Sepak Bola, Bulu Tangkis, Pencak Silat, Bola Voli, Renang;
- 9 klub;
- 213 atlet;
- 18 pelatih.

UI membaca nama wilayah dari `snapshot.scope.name`, bukan dari pola ID klub.

---

### 3.4 AuthController, Mutation Queue, dan State Machine

#### A. Mutation queue yang tetap hidup setelah error

```dart
Future<void> _mutationTail = Future<void>.value();

Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
  final run = _mutationTail
      .catchError((_) {})
      .then((_) => mutation());
  _mutationTail = run.then<void>(
    (_) {},
    onError: (_, __) {},
  );
  return run;
}
```

Seluruh operasi write/delete pada token, metadata, dan remembered SK melewati queue yang sama.

#### B. Bootstrap truth table

| Metadata | Credential | Tindakan | State |
| --- | --- | --- | --- |
| absent | absent | first run | signed-out clean |
| absent | ada | force clear + tulis clean | clean bila keduanya sukses; selain itu failed |
| corrupt/read error | apa pun | jangan restore | failed |
| restore false, pending/failed | apa pun | jangan restore | failed |
| restore false, clean | absent | normal | clean |
| restore false, clean | ada | force clear + normalisasi | clean bila sukses; selain itu failed |
| restore true, clean | absent | tulis signed-out clean | clean bila sukses; selain itu failed |
| restore true, clean | ID berbeda | jangan hapus credential yang bukan milik metadata | failed |
| restore true, clean | ID cocok | `restoreSession()` | signed-in bila valid |
| restore expired | ID cocok | `clearIfOwnedBy`  • metadata clean | clean bila keduanya sukses; selain itu failed |

Bootstrap menjalankan migrasi legacy terlebih dahulu, tetapi tidak pernah melakukan restore dari key legacy.

#### C. Sign-in phase dan logical cancellation

```dart
enum SignInPhase { idle, executing, waitingForCommit, committing }
```

- `executing`/`waitingForCommit`: cancel diterima, epoch dinaikkan, logical result dibatalkan, state kembali signed-out clean.
- `committing`: cancel ditolak `operationInProgress`.
- Fase berubah ke `committing` di dalam mutation queue sebelum write pertama.
- `Future.any()` hanya menjamin logical cancellation. Transport cancellation dilakukan hanya bila adapter remote menyediakannya.

```dart
final result = await Future.any<AuthResult>([
  repository.login(...),
  cancelTrigger.future.then<AuthResult>(
    (_) => throw const SignInCancelledException(),
  ),
]);
```

#### D. Persistent login ordering

1. Reserve: validasi `AuthSignedOut(clean)`, naikkan epoch, set `executing` dan `AuthSigningIn`.
2. Execute: login repository di luar queue.
3. Waiting: set `waitingForCommit`.
4. Commit di queue: validasi ulang ticket, set `committing`.
5. Jika nonpersisten: tulis metadata signed-out clean, simpan session handle hanya di memory, lalu publish signed-in.
6. Jika persisten: tulis metadata pending → generate credential ID → tulis credential → validasi epoch → tulis metadata restore-enabled → simpan private session → publish signed-in.
7. Semua jalur success/error/cancel mengembalikan phase ke `idle`.

#### E. Failure matrix persistence

| Failure | Tindakan final |
| --- | --- |
| Metadata pending gagal sebelum credential write | jangan tulis credential; state `AuthTemporarilyUnavailable`; retry melalui bootstrap |
| Credential write melempar/hasil ambigu | coba tulis metadata failed; state signed-out failed |
| Epoch berubah setelah credential write | `clearIfOwnedBy`; tulis metadata clean bila clear sukses; bila salah satu gagal → failed |
| Metadata final gagal | rollback credential; tulis metadata clean bila rollback sukses; bila salah satu gagal → failed |
| `clearIfOwnedBy` false saat credential awal diketahui ada | ownership mismatch; jangan global clear; state failed |
| Restore gagal dan cleanup gagal | state failed |
| Token terhapus tetapi metadata clean gagal | state failed |
| Force clear berhasil tetapi metadata recovery gagal | state failed |

#### F. Logout

1. Tangkap `RemoteSessionHandle` dan `activeCredentialId` ke variabel lokal.
2. Naikkan operation epoch dan session generation; eviksi principal serta material sesi dari memory; publish `AuthSigningOut`.
3. Di queue, coba tulis metadata pending. Jika gagal, catat local metadata failure tetapi lanjutkan token cleanup.
4. Jika ada active credential, panggil `clearIfOwnedBy`. `false` dengan credential awal yang diketahui ada adalah ownership mismatch. Untuk sesi nonpersisten, cleanup credential dianggap tidak diperlukan.
5. Jika credential aman dan metadata clean berhasil ditulis, publish signed-out clean. Selain itu publish signed-out failed.
6. Di luar queue, selalu `await` revocation bila session handle tersedia, dengan timeout 5 detik. Timeout/exception dipetakan ke `RemoteRevocationStatus.failed`.
7. Kembalikan `LogoutResult` dengan `localSessionClosed`, `credentialCleared`, `metadataClean`, dan `remoteRevocationStatus`.

#### G. Recovery

`retryLocalCredentialCleanup()` hanya legal dari signed-out failed. Operasi:

1. ubah state menjadi signed-out pending dan tolak retry/login paralel;
2. `forceClearForRecovery()` di queue;
3. tulis metadata signed-out clean;
4. bila keduanya berhasil → signed-out clean dan return `true`;
5. bila salah satu gagal → signed-out failed dan return `false`.

---

### 3.5 Data Request Lifecycle dan Stale Guard

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
}
```

`KokRepository` hanya menyediakan:

```dart
Future<KokSnapshot> fetchScope(
  AccessScope scope, {
  RequestCancellation? cancellation,
});
```

Aturan provider:

1. tolak bila sesi tidak signed-in;
2. buat cancellation controller per provider instance;
3. cancel pada `ref.onDispose`;
4. panggil repository dengan scope eksplisit;
5. setelah `await`, panggil `throwIfCancelled()` sebelum membaca `ref`;
6. cocokkan context terbaru dengan context awal;
7. lifecycle exceptions tidak di-retry; error lain mengikuti `ProviderContainer.defaultRetry`.

Transport yang mengabaikan cancellation tetap tidak boleh memublikasikan respons lama.

---

### 3.6 DeploymentProfile dan Composition Root

Kombinasi profile:

| Environment | Auth | Data | Validasi | Composition Tahap A |
| --- | --- | --- | --- | --- |
| demo | demo | demo | valid | tersedia |
| demo | remote | apa pun | invalid | ditolak |
| staging | demo | demo | valid | tersedia |
| staging | remote | demo | valid | fail-closed bila remote auth belum tersedia |
| staging | remote | remote | valid | fail-closed bila adapter belum tersedia |
| staging | demo | remote | invalid | ditolak |
| production | remote | remote | valid | fail-closed sampai kedua adapter tersedia |
| production | selain remote/remote | invalid | ditolak |  |

Struktur:

```
lib/core/config/deployment_profile.dart
lib/core/composition/app_composition.dart
lib/data/kok_repository.dart
lib/data/demo_kok_repository.dart
lib/data/providers/snapshot_provider.dart
```

Factory composition menerima dependency testable:

```dart
AppComposition.fromProfile(
  profile,
  preferences: preferences,
  secureStore: secureStore,
  credentialIdGenerator: credentialIdGenerator,
  revocationTimeout: const Duration(seconds: 5),
);
```

`app_environment.dart` dan `repository.dart` boleh menjadi compatibility barrel sementara, lalu dihapus setelah seluruh import dimigrasikan. Provider turunan membaca dari `appCompositionProvider`; `main()` hanya meng-override composition serta dependency platform dasar.

---

### 3.7 UI, Permission, dan Klaim Produk

- Semua tombol logout/retry di-`await`, memiliki busy state, dan mencegah double tap.
- Ketika cleanup failed, login dinonaktifkan dan banner amber menampilkan tombol “Coba Bersihkan Lagi”.
- Tombol rekap untuk akun tanpa `reports:export` disabled; handler memeriksa ulang permission.
- Client-side permission adalah **UI affordance guard**, bukan security boundary. Backend wajib melakukan authorization ulang ketika endpoint remote tersedia.
- Klaim aktif seperti “SINKRONISASI DATA SICABOR”, “tersinkronisasi dengan SICABOR”, dan “data SICABOR aktif” dilarang.
- Kalimat yang digunakan: “Data demo lokal—belum terhubung dengan SICABOR.”
- Kontak demo diberi label belum diverifikasi dan tidak digunakan untuk pemulihan akun.

---

## 4. Matriks Pengujian Penerimaan

### 4.1 Skenario kanonis SC-01 s/d SC-31

| ID | Kategori | Skenario |
| --- | --- | --- |
| SC-01 | Cleanup | Logout sukses menghasilkan token absent dan metadata clean/restore false |
| SC-02 | Cleanup | Token clear gagal menghasilkan signed-out failed dan restore tetap diblokir |
| SC-03 | Cleanup | Restart setelah cleanup gagal menolak restore dan menampilkan recovery UI |
| SC-04 | Cleanup | Recovery sukses mengaktifkan login kembali |
| SC-05 | Cleanup | Recovery gagal tetap memblokir login/restore |
| SC-06 | Concurrency | Double logout menjalankan satu cleanup |
| SC-07 | Concurrency | Login selama cleanup ditolak `cleanupRequired` |
| SC-08 | Crash ordering | Crash sebelum restore-enabled tidak memulihkan orphan token |
| SC-09 | Parsing | Metadata field/type/schema/ID invalid ditolak typed |
| SC-10 | Logout | Revocation timeout tidak membatalkan local logout |
| SC-11 | Logout | `notApplicable`, `failed`, dan `revoked` terbedakan |
| SC-12 | Sign-in | Cancel saat execute selesai segera secara logis; respons lama tidak commit |
| SC-13 | Sign-in | Ticket stale saat menunggu queue tidak commit |
| SC-14 | Ownership | Clear credential A tidak menghapus credential B |
| SC-15 | Queue | Mutation error tidak mematikan operasi queue berikutnya |
| SC-16 | Sign-in | Cancel saat committing ditolak `operationInProgress` |
| SC-17 | Demo | DEMO-003 persistent restore tetap menjadi `usr_koni_kab` |
| SC-18 | Demo | County snapshot: 5 cabor, 9 klub, 213 atlet, 18 pelatih |
| SC-19 | Scope | Unknown scope melempar typed exception tanpa fallback |
| SC-20 | Migration | Legacy key tidak pernah dipakai restore dan dihapus best-effort |
| SC-21 | Parsing | Batas credential 128/8192 diterapkan |
| SC-22 | Cancellation | Cancel idempoten dan mempertahankan reason pertama |
| SC-23 | Data | Request A dibatalkan saat switch ke B; data B tidak tercemar |
| SC-24 | Data | Transport yang mengabaikan cancel tetap ditolak stale guard |
| SC-25 | Retry | Lifecycle exceptions tidak di-retry; error lain memakai default retry |
| SC-26 | Composition | Production gagal startup bila adapter remote belum tersedia |
| SC-27 | Composition | Demo auth + remote data selalu ditolak |
| SC-28 | Composition | Demo environment wajib demo/demo |
| SC-29 | Namespace | Credential, metadata, dan remembered SK terisolasi per environment |
| SC-30 | Permission | DEMO-002 tidak dapat menyalin/mengekspor rekap |
| SC-31 | Honesty | UI bebas klaim aktif SICABOR dan menampilkan disclaimer jujur |

### 4.2 Fault-injection wajib FT-01 s/d FT-08

| ID | Titik kegagalan | Hasil wajib |
| --- | --- | --- |
| FT-01 | Metadata pending login gagal | tidak ada credential baru; state unavailable |
| FT-02 | Credential write melempar | metadata/state failed |
| FT-03 | Epoch berubah setelah credential write | rollback owned credential |
| FT-04 | Metadata final gagal | rollback; clean hanya bila rollback+metadata sukses |
| FT-05 | `clearIfOwnedBy` false | credential lain tetap utuh; state failed |
| FT-06 | Restore expired dan cleanup gagal | state failed |
| FT-07 | Token clear sukses, metadata clean gagal | state failed |
| FT-08 | Force clear sukses, metadata recovery gagal | state failed |

Tambahan wajib: `AccessScope` dan `KokSnapshot` JSON round-trip; defensive permission copy; constructor namespace lengkap; logical-vs-transport cancellation; awaited UI action; serta platform secure-storage smoke test.

---

## 5. Definition of Done

- R2-01 s/d R2-07 dan catatan Bagian 5 memiliki test penerimaan yang dapat ditelusuri.
- Tidak ada pemanggilan legacy `fetch()`, `fetchDistrict()`, atau fallback district.
- Tidak ada raw token pada state/log/`toString()`.
- Semua storage key eksplisit dan environment-scoped.
- Setiap commit implementasi lulus analyzer dan test terdampak; commit akhir lulus full suite.
- Semua SC-01–SC-31 dan FT-01–FT-08 lulus.
- `dart run build_runner build --delete-conflicting-outputs` bersih.
- `flutter build apk --debug` berhasil.
- Smoke test perangkat memverifikasi persistent login, restart, logout, cleanup failure, dan recovery.
- Hasil runtime dicatat sebagai bukti; dokumen tidak mengklaim test/build lulus sebelum benar-benar dijalankan.
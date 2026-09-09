# Desain Remediasi Penguatan Arsitektur Autentikasi & Siklus Sesi (Tahap A Patch 2)

Tanggal: 2026-09-09  
Status: Approved for Implementation Planning  
Penulis: Pengembang & Reviewer Teknis  
Dokumen Rujukan: `docs/audit-auth-review-tahap1-kedua.md` (Temuan R2-01 s/d R2-07, Temuan Bagian 5)

---

## 1. Latar Belakang & Sasaran Remediasi

Berdasarkan hasil audit tahap kedua pada `docs/audit-auth-review-tahap1-kedua.md`, revisi sebelumnya telah berhasil menutup temuan A-01 (Guard State Transisi) dan A-08 (Dua Sumber Sesi Ganda) secara sempurna. Dokumen ini menetapkan target *robustness* dan kesiapan integrasi guna menyelesaikan 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan konsistensi Bagian 5:

1. **R2-01 (Race Commit/Clear Token & Ownership):** Operasi login *stale* dilarang menjalankan pembersihan global. Penulisan dan penghapusan storage diserialisasi, dan kepemilikan credential dilindungi dengan ID unik per sesi.
2. **R2-02 (Logout Storage Failure & Penanganan State):** Kegagalan menghapus token memiliki status bertipe `LocalCleanupStatus`, dipersistensikan sebagai record metadata nonrahasia `SessionMetadata`, dan UI menunggu proses logout tanpa unhandled Future.
3. **R2-03 (Konsistensi Akun DEMO-003):** Akun `DEMO-003` (Ibu Rina · KONI Kab) memiliki token persisten exact (`token_usr_koni_kab`), scope kabupaten terpisah (`AccessScopeType.county`), dan fixture gabungan 5 cabang olahraga se-Kabupaten Garut.
4. **R2-04 (Mutasi Auth Paralel & Matriks Transisi):** Controller menerapkan matriks transisi state legal dengan operasi eksplisit `cancelSignIn()`.
5. **R2-05 (Rekursi Interface Storage & Namespace Kanonis):** `AuthTokenStorage` disederhanakan tanpa rekursi, menggunakan namespace terversi per environment (`kok.auth.v2.<env>.credential`).
6. **R2-06 (Kontrak Repository & Cancellation End-to-End):** Abstraksi `RequestCancellation` dengan notifikasi, peniadaan `fetch()` tanpa scope, dan verifikasi generasi pasca-`await` via `DataRequestContext`.
7. **R2-07 (Composition Root & Deployment Profile):** `DeploymentProfile` memisahkan konfigurasi environment, auth mode, dan data mode, serta langsung menghasilkan dependency aktual melalui `AppComposition`.
8. **Bagian 5 (Sisa Klaim SICABOR & Penegakan Izin):** Pembersihan sisa klaim SICABOR pada UI, perbaikan deskripsi platform pada README, dan penegakan izin `reports:export` pada aksi penyalinan rekapitulasi.

---

## 2. Batasan Global & Target Penerimaan (Global Constraints & Acceptance Targets)

- **Ukuran Tipografi:** Seluruh teks pada komponen antarmuka berukuran font $\ge 12\text{px}$.
- **Warna & Aksen:** Warna judul kartu utama konsisten menggunakan `KokColors.cardTitle` (`#141414`).
- **Navigasi:** Tombol kembali menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`. Struktur 5 tab navigasi bawah tetap utuh.
- **Fail-Closed Principle:** Segala bentuk anomali metadata, konfigurasi produksi tidak sah, atau pembacaan data tanpa sesi aktif ditolak keras (*fail-closed*).
- **Target Penerimaan:** `flutter analyze` 0 issues dan seluruh test suite lulus 100%.

---

## 3. Rincian Teknis Arsitektur & Remediasi

### 3.1 Penanganan Kegagalan Logout, Crash-Consistent Sequences, & SessionMetadataStore (Menutup R2-02)

#### A. Status Cleanup Bertipe & State `AuthSignedOut`
```dart
enum LocalCleanupStatus {
  clean,
  pending,
  failed,
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({
    this.message,
    this.cleanupStatus = LocalCleanupStatus.clean,
  });

  final String? message;
  final LocalCleanupStatus cleanupStatus;

  bool get requiresCleanup =>
      cleanupStatus == LocalCleanupStatus.pending ||
      cleanupStatus == LocalCleanupStatus.failed;
}
```

#### B. `SessionMetadata` Tunggal & `SessionMetadataStore`
Metadata sesi nonrahasia diserialisasi sebagai satu record JSON utuh di `SharedPreferences`:
```dart
final class SessionMetadata {
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

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      restoreAllowed: json['restoreAllowed'] as bool? ?? false,
      cleanupStatus: LocalCleanupStatus.values.asNameMap()[json['cleanupStatus']] ?? LocalCleanupStatus.failed,
      expectedCredentialId: json['expectedCredentialId'] as String?,
    );
  }
}

abstract interface class SessionMetadataStore {
  Future<SessionMetadata?> read();
  Future<void> write(SessionMetadata metadata);
  Future<void> clear();
}
```

**Aturan Bootstrap Fail-Closed:**
Auto-login hanya diizinkan jika seluruh kondisi terpenuhi:
1. `metadata != null`
2. `metadata.restoreAllowed == true`
3. `metadata.cleanupStatus == LocalCleanupStatus.clean`
4. `storedCredential != null`
5. `metadata.expectedCredentialId == storedCredential.credentialId`
6. `storedCredential.refreshToken` berhasil divalidasi oleh repository.

Jika metadata tidak ada, rusak, tidak lengkap, atau `expectedCredentialId` tidak cocok dengan token di storage: **jangan lakukan auto-login**, set status ke `cleanupStatus: LocalCleanupStatus.failed`.

#### C. Urutan Logout Crash-Consistent
1. Simpan referensi internal session untuk remote revocation.
2. Naikkan `_operationEpoch` dan `_sessionGeneration`.
3. Eviksi token in-memory dan data principal.
4. Set state sinkron $\rightarrow$ `const AuthSigningOut()`.
5. Tulis metadata persisten: `restoreAllowed = false`, `cleanupStatus = LocalCleanupStatus.pending`, `expectedCredentialId = null` (**ditulis sebelum mencoba menghapus token di secure storage**).
6. Panggil `repo.revokeSession(remoteHandle)` (hasil pada mode demo: `RemoteRevocationResult.notApplicable`).
7. Eksekusi `tokenStorage.clearIfOwnedBy(credentialId)` melalui antrean mutasi storage.
8. Jika sukses: tulis metadata `cleanupStatus = LocalCleanupStatus.clean`, ubah state $\rightarrow$ `AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)`.
9. Jika gagal (`StorageException`): pertahankan `cleanupStatus = LocalCleanupStatus.failed`, ubah state $\rightarrow$ `AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)`.
10. Kembalikan `LogoutResult`:
    ```dart
    final class LogoutResult {
      const LogoutResult({
        required this.localSessionClosed,
        required this.credentialCleared,
        required this.remoteRevoked,
        this.message,
      });

      final bool localSessionClosed;
      final bool credentialCleared;
      final bool remoteRevoked;
      final String? message;
    }
    ```

#### D. Urutan Persistent Login Crash-Consistent
1. Tulis metadata: `restoreAllowed = false`, `cleanupStatus = LocalCleanupStatus.pending`.
2. Generate UUID acak `credentialId`.
3. Tulis `StoredCredential(credentialId: credentialId, refreshToken: token)` ke secure storage di bawah mutation lock.
4. Pastikan operation epoch masih sama.
5. Tulis metadata: `restoreAllowed = true`, `cleanupStatus = LocalCleanupStatus.clean`, `expectedCredentialId = credentialId`.
6. Publikasikan `AuthSignedIn`.

#### E. Perilaku UI & Tombol "Coba Bersihkan Lagi"
- Pada `ProfilePage` dan `SessionUnavailablePage`, seluruh pemanggilan logout menggunakan `await` dengan visual tombol dinonaktifkan.
- Pada `LoginPage`, jika `cleanupStatus == LocalCleanupStatus.failed`, tampilkan banner amber:
  > **Pembersihan sesi belum selesai.** Akses data telah dikunci, tetapi kredensial lokal belum berhasil dihapus dari perangkat ini. Coba bersihkan kembali sebelum masuk menggunakan akun lain.
- Tombol *"Coba Bersihkan Lagi"* memanggil operasi idempoten:
  ```dart
  Future<bool> retryLocalCredentialCleanup();
  ```
  Operasi ini berjalan di bawah mutation queue, memanggil `forceClearForRecovery()`, memperbarui metadata, dan mengaktifkan kembali login jika berhasil. Selama status failed, login akun lain dan auto-restore diblokir.

---

### 3.2 Dua Fase Mutasi, Matriks Transisi, & Token Ownership Guard (Menutup R2-01 & R2-04)

#### A. Pola Dua Fase Operasi
1. **Fase 1: Reserve**
   - Validasi matriks transisi state saat ini.
   - Set state sinkron sebelum `await` pertama (misal `AuthSigningIn`).
   - Buat tiket/epoch operasi.
2. **Fase 2: Execute (Di Luar Lock)**
   - Eksekusi request jaringan/kredensial (`repo.login`). Lock storage lokal **tidak ditahan** selama pemanggilan jaringan agar operasi `cancelSignIn()` atau `logout()` dapat segera memutus proses.
3. **Fase 3: Commit (Di Bawah Mutation Queue)**
   - Masuk antrean serial `_mutationQueue`.
   - Validasi ulang tiket dan epoch saat mendapatkan lock.
   - Tulis credential record dan metadata.
   - Publikasikan state akhir.

#### B. Matriks Transisi Legal, Pembatalan Login, & `AuthCommandResult`
```dart
sealed class AuthCommandResult {
  const AuthCommandResult();
}

final class AuthCommandAccepted extends AuthCommandResult {
  const AuthCommandAccepted();
}

final class AuthCommandRejected extends AuthCommandResult {
  const AuthCommandRejected(this.reason);
  final AuthCommandRejection reason;
}

enum AuthCommandRejection {
  operationInProgress,
  cleanupRequired,
  invalidState,
}
```

Operasi Pembatalan Sign-In Eksplisit:
```dart
Future<AuthCommandResult> cancelSignIn();
```
Alur:
- Naikkan `_operationEpoch`.
- Batalkan request jaringan bila memungkinkan.
- Ubah state kembali ke `AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)`.
- Respons login lama yang datang kemudian ditolak dan dilarang masuk fase commit.

Matriks Transisi:
- `AuthBootstrapping`: hanya penyelesaian internal; `login`/`logout` ditolak (`operationInProgress`).
- `AuthSignedOut(clean)`: menerima `login()`.
- `AuthSignedOut(failed)`: menolak `login()` (`cleanupRequired`); hanya menerima `retryLocalCredentialCleanup()`.
- `AuthSigningIn`: menerima `cancelSignIn()`; menolak login baru (`operationInProgress`).
- `AuthSignedIn`: menerima `logout()`; menolak `login()` (`invalidState`).
- `AuthSigningOut`: menolak seluruh `login()` atau `bootstrap()` (`operationInProgress`).
- `AuthTemporarilyUnavailable`: menerima `retrySession()` dan `logout()`.

#### C. Credential Record & Token Ownership Guard Berbasis ID
```dart
final class StoredCredential {
  const StoredCredential({
    required this.credentialId,
    required this.refreshToken,
  });

  final String credentialId; // UUID acak aman per persistent login
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
    if (token is! String || token.trim().isEmpty || token.length > 512) {
      throw const FormatException('refreshToken tidak valid');
    }
    return StoredCredential(
      credentialId: credId,
      refreshToken: token,
    );
  }

  @override
  String toString() => 'StoredCredential(credentialId: $credentialId, refreshToken: [PROTECTED])';
}
```
Kontrak Storage:
```dart
abstract interface class AuthTokenStorage {
  Future<StoredCredential?> read();
  Future<void> write(StoredCredential credential);
  Future<bool> clearIfOwnedBy(String credentialId);
  Future<void> forceClearForRecovery();
}
```

---

### 3.3 Interface Storage Bersih, Namespace Kanonis, & Konsistensi DEMO-003 (Menutup R2-03 & R2-05)

#### A. Namespace Kanonis & Versi Skema
Key secure storage diparameterkan:
```text
kok.auth.v2.demo.credential
kok.auth.v2.staging.credential
kok.auth.v2.production.credential
```
Migrasi fail-closed: key lama `v1_kok_refresh_token` dihapus secara *best-effort* saat startup tanpa melakukan auto-login.

#### B. Kepemilikan Storage oleh Controller & Revocation Kontrak
`AuthRepository` tidak lagi membaca secure storage atau metadataStore. Kontrak repositori:
```dart
enum RemoteRevocationStatus { revoked, notApplicable, failed }

final class RemoteRevocationResult {
  final RemoteRevocationStatus status;
  final String? message;
  const RemoteRevocationResult(this.status, [this.message]);
  factory RemoteRevocationResult.notApplicable() => const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
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

#### C. Pemetaan Presisi 3 Akun Demo & Scope Kabupaten
Tabel pemetaan eksklusif pada `DemoAuthRepository`:
```dart
final demoSessionsByToken = <String, UserPrincipal>{
  'token_usr_garut_kota': _garutKotaUser,
  'token_usr_tarogong_kidul': _tarogongKidulUser,
  'token_usr_koni_kab': _koniKabUser,
};
```
Abstraksi `AccessScope`:
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
```
Pemetaan Akun:
- `DEMO-001` $\rightarrow$ `usr_garut_kota` $\rightarrow$ token: `token_usr_garut_kota`, scope: `district` / `garut_kota` / `Kecamatan Garut Kota`.
- `DEMO-002` $\rightarrow$ `usr_tarogong_kidul` $\rightarrow$ token: `token_usr_tarogong_kidul`, scope: `district` / `tarogong_kidul` / `Kecamatan Tarogong Kidul`.
- `DEMO-003` $\rightarrow$ `usr_koni_kab` $\rightarrow$ token: `token_usr_koni_kab`, scope: `county` / `koni_kab` / `Kabupaten Garut`.

Dataset Kabupaten di `DemoKokRepository`:
Mengembalikan data gabungan keolahragaan tingkat Kabupaten Garut: **5 cabang olahraga unik** (Sepak Bola, Bola Voli, Bulu Tangkis, Bola Basket, Atletik), 9 klub, 213 atlet, dan 18 pelatih. Seluruh data dihitung dinamis dari fixture, bukan hardcode. Unknown scope melempar `UnsupportedScopeException(scope.id)`.

---

### 3.4 Kontrak Repository Data, RequestCancellation, & Delayed Fetch Guard (Menutup R2-06)

#### A. `RequestCancellation` & Controller Ber-notifikasi
```dart
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
```

#### B. Kontrak Repository Murni
Metode `fetch()` tanpa scope dihapus permanen. Kontrak murni:
```dart
abstract interface class KokRepository {
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  });
}
```

#### C. Context Guard Pasca-`await` di `snapshotProvider`
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
`snapshotProvider` tidak melakukan auto-retry untuk:
- `SessionRequiredException`
- `RequestCancelledException`
- `StaleSessionResultException`
- `UnsupportedScopeException`

---

### 3.5 `DeploymentProfile`, `AppComposition`, & Pembersihan Label SICABOR (Menutup R2-07 & Bagian 5)

#### A. Komposisi Dependensi Independen
```dart
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
    final metadataStore = SharedPrefsSessionMetadataStore(preferences);
    final skStore = SharedPrefsRememberedSkStore(preferences);

    final AuthRepository authRepo;
    if (profile.authMode == AuthMode.demo) {
      authRepo = DemoAuthRepository();
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
```

#### B. Penegakan Izin `reports:export` pada UI
Di `lib/features/profile_page.dart`:
- Tombol ekspor/salin rekapitulasi memeriksa `user.hasPermission('reports:export')`.
- Jika tidak memiliki izin (seperti Pak Cecep / `DEMO-002`): tombol ditampilkan dinonaktifkan (*disabled*) dengan teks keterangan netral:
  > *Akun ini tidak memiliki izin untuk mengekspor atau menyalin rekapitulasi.*
- Handler aksi memeriksa ulang permission saat tombol ditekan (*double-check*) guna mencegah bypass.

#### C. Pembersihan Label SICABOR & Perapian Teks
- `profile_page.dart:73`: `"SINKRONISASI DATA SICABOR"` diubah menjadi `"STATUS SISTEM DATA KOK"`.
- `profile_page.dart:775–776`: Diubah menjadi `"Data demo lokal—belum terhubung dengan SICABOR."`
- Kontak narahubung: Ditandai dengan keterangan `"Kontak demo/belum diverifikasi—jangan digunakan untuk pemulihan akun."`
- `README.md`: Diperbarui dengan deskripsi akurat per platform:
  > Opsi "Tetap Masuk" menyimpan token sesi demo sintetis melalui secure-storage adapter platform. Password tidak disimpan. Pemulihan sesi hanya dilakukan jika metadata mengizinkan restore, cleanup sebelumnya selesai, dan token demo berhasil divalidasi. Web secure storage tidak memiliki tingkat assurance yang sama dengan Keychain/Keystore dan tetap dibatasi untuk mode demo sampai strategi autentikasi web disepakati.

---

## 4. Rencana Verifikasi & Matriks Pengujian Regresi

Pengujian regresi ditempatkan di `test/auth_hardening_remediation_test.dart` dan pembaruan pada `test/app_test.dart`:

| Kategori | Skenario Pengujian |
|---|---|
| **Storage & Cleanup** | 1. Logout clear berhasil $\rightarrow$ state signed-out bersih, token kosong, metadata `restoreAllowed = false, cleanupStatus = clean`.<br>2. Logout clear gagal $\rightarrow$ data terkunci, `cleanupStatus == failed`, metadata `restoreAllowed = false, cleanupStatus = failed`, token tidak dipakai auto-login.<br>3. Restart setelah clear gagal $\rightarrow$ bootstrap membaca metadata `cleanupStatus == failed`, menolak auto-login, menampilkan peringatan di `LoginPage`.<br>4. `retryLocalCredentialCleanup()` berhasil $\rightarrow$ token terhapus, metadata bersih, login diaktifkan.<br>5. `retryLocalCredentialCleanup()` gagal $\rightarrow$ status tetap failed, auto-restore tetap diblokir.<br>6. Double logout tap $\rightarrow$ hanya satu operasi cleanup dijalankan.<br>7. Login saat cleanup berlangsung $\rightarrow$ ditolak dengan `AuthCommandRejected(cleanupRequired)`.<br>8. Crash sebelum `restoreAllowed = true` $\rightarrow$ token orphaned tidak dipakai auto-login. |
| **Concurrency & Ownership** | 9. `cancelSignIn()` memutus login jaringan yang menggantung $\rightarrow$ state kembali ke `AuthSignedOut(clean)`, respons login lama tidak pernah masuk commit.<br>10. Revalidasi tiket operasi pasca-antrean $\rightarrow$ commit ditolak jika epoch berubah.<br>11. Storage ownership test: credential B tersimpan $\rightarrow$ `clearIfOwnedBy(credentialA.credentialId)` mengembalikan false $\rightarrow$ credential B tetap utuh.<br>12. Exception pada antrean $\rightarrow$ lock dilepas tanpa deadlock. |
| **DEMO-003 & Scope** | 13. Login `DEMO-003` dengan Tetap Masuk $\rightarrow$ dispose container $\rightarrow$ bootstrap baru $\rightarrow$ identitas tetap Ibu Rina (`usr_koni_kab`), bukan Pak Cecep.<br>14. Snapshot `DEMO-003` memuat data kabupaten 5 cabor unik (9 klub, 213 atlet, 18 pelatih) yang dihitung dari fixture.<br>15. Unknown scope melempar `UnsupportedScopeException` tanpa fallback ke Garut Kota.<br>16. Migrasi legacy key `v1_kok_refresh_token` fail-closed (tidak auto-login). |
| **Data Cancellation** | 17. Cancellation idempotent (dua kali cancel tidak melempar dan reason pertama tetap berlaku).<br>18. Delayed fetch A tertahan $\rightarrow$ switch ke user B $\rightarrow$ request A dibatalkan, data B tidak tercemar.<br>19. Scope/generation berubah tanpa transport batal $\rightarrow$ stale-result guard menolak respons lama.<br>20. Cancellation, Stale, & UnsupportedScope exceptions tidak memicu retry otomatis. |
| **Composition & Permissions** | 21. Production composition menghasilkan adapter remote; jika belum ada $\rightarrow$ fail-closed saat startup.<br>22. `dataMode.remote + authMode.demo` ditolak pada seluruh environment.<br>23. Pengguna tanpa `reports:export` (DEMO-002) diblokir dari aksi salin rekap.<br>24. Seluruh codebase UI bebas dari klaim palsu "sudah tersinkronisasi SICABOR". |

---

## 5. Kriteria Selesai (Definition of Done)

- Seluruh 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan Bagian 5 tertutup tuntas.
- Mutasi storage lokal diserialisasi penuh dengan token ownership guard berbasis ID.
- Kegagalan cleanup storage dipersistensikan sebagai metadata `SessionMetadata` fail-closed dan memiliki alur retry yang aman.
- Ketiga akun demo (`DEMO-001`, `DEMO-002`, `DEMO-003`) memiliki identitas, token persisten, dan dataset yang konsisten setelah restart.
- Kontrak repository data tidak memiliki pintu belakang tanpa scope dan kebal terhadap *delayed cross-account responses*.
- `DeploymentProfile` dan `AppComposition` menjamin isolasi konfigurasi produksi yang fail-closed.
- `flutter analyze` 0 issues dan seluruh test suite lulus 100%.

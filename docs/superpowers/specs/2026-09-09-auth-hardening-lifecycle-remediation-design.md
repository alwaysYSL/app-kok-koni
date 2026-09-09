# Desain Remediasi Penguatan Arsitektur Autentikasi & Siklus Sesi (Tahap A Patch 2)

Tanggal: 2026-09-09  
Status: Proposed  
Penulis: Pair Programming (Antigravity & User)  
Dokumen Rujukan: [docs/audit-auth-review-tahap1-kedua.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth-review-tahap1-kedua.md) (Temuan R2-01 s/d R2-07, Temuan Bagian 5)

---

## 1. Latar Belakang & Sasaran Remediasi

Berdasarkan hasil audit tahap kedua pada `docs/audit-auth-review-tahap1-kedua.md`, revisi sebelumnya telah berhasil menutup temuan A-01 (Guard State Transisi) dan A-08 (Dua Sumber Sesi Ganda) secara sempurna, serta meletakkan fondasi awal untuk temuan lainnya. Namun, terdapat 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan konsistensi Bagian 5 yang harus diselesaikan tuntas agar Tahap A memenuhi standar keamanan enterprise dan *crash-consistency*:

1. **R2-01 (Race Commit/Clear Token & Ownership):** Operasi login *stale* yang mengeksekusi `clear()` global berisiko menghapus token milik login baru. Mutasi storage lokal belum diserialisasi dan masih terdapat pemeriksaan tipe runtime (`repo is DemoAuthRepository`).
2. **R2-02 (Logout Storage Failure & Penanganan State):** Kegagalan menghapus token saat logout tidak memiliki status bertipe dan dapat memicu *unhandled Future error*. Pada restart berikutnya, token yang gagal dihapus dapat secara diam-diam me-restore sesi pengguna (*silent re-login*).
3. **R2-03 (Konsistensi Akun DEMO-003):** Akun `DEMO-003` (Ibu Rina · KONI Kab) secara tidak sengaja dipetakan ke token Tarogong Kidul dan berubah menjadi Pak Cecep saat aplikasi di-restart. Scope kabupaten belum dibedakan dari scope kecamatan.
4. **R2-04 (Mutasi Auth Paralel & Matriks Transisi):** Controller belum memiliki matriks transisi state yang legal, sehingga pemanggilan login saat bootstrapping atau signing-out belum diblokir secara terstruktur.
5. **R2-05 (Rekursi Interface Storage & Namespace Key):** `AuthTokenStorage` memiliki mutual recursion default (`getRefreshToken` memanggil `readRefreshToken` dan sebaliknya) dan key storage belum memiliki namespace kanonis terversi per environment.
6. **R2-06 (Kontrak Repository & Cancellation End-to-End):** Nama `CancelToken` bentrok dengan Dio, metode `fetch()` tanpa scope masih terbuka di antarmuka repository, dan belum ada bukti pengujian delayed fetch lintas sesi (A $\rightarrow$ B).
7. **R2-07 (Composition Root & Deployment Profile):** Konfigurasi environment belum mengontrol komposisi dependensi aktual. Kombinasi mode auth dan data belum diatur secara independen.
8. **Bagian 5 (Sisa Klaim SICABOR & Penegakan Izin):** Masih tersisa klaim "SINKRONISASI DATA SICABOR" pada UI, kontak belum ditandai status verifikasinya, README belum akurat per platform, dan izin `reports:export` belum ditegakkan pada aksi penyalinan rekapitulasi.

---

## 2. Batasan Global (Global Constraints)

- **Ukuran Tipografi:** Seluruh teks pada komponen antarmuka berukuran font $\ge 12\text{px}$.
- **Warna & Aksen:** Warna judul kartu utama konsisten menggunakan `KokColors.cardTitle` (`#141414`).
- **Navigasi:** Tombol kembali menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`. Struktur 5 tab navigasi bawah tetap utuh.
- **Fail-Closed Principle:** Segala bentuk anomali metadata, konfigurasi produksi tidak sah, atau data tanpa sesi aktif ditolak keras (*fail-closed*).
- **Static Analysis & Testing:** `flutter analyze` 0 issues dan `flutter test` 100% lulus.

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

#### B. `SessionMetadataStore` (SharedPreferences Non-Rahasia)
Menyimpan penanda status restore dan cleanup secara persisten:
```dart
abstract interface class SessionMetadataStore {
  Future<bool> isRestoreAllowed();
  Future<bool> isCleanupPending();

  Future<void> blockRestoreForCleanup();
  Future<void> allowRestore();
  Future<void> markCleanupComplete();
}
```
Keys: `auth.restore_allowed` (bool) dan `auth.cleanup_pending` (bool).  
**Aturan Bootstrap Fail-Closed:** Auto-login hanya diizinkan jika:
`restore_allowed == true` AND `cleanup_pending == false` AND refresh token ada dan valid.  
Jika metadata tidak tersedia, rusak, atau bernilai tidak dikenal, auto-login langsung ditolak.

#### C. Urutan Logout Crash-Consistent
1. Catat referensi internal session/token untuk remote revocation.
2. Naikkan `_operationEpoch` dan `_sessionGeneration`.
3. Eviksi token in-memory dan data principal.
4. Set state sinkron $\rightarrow$ `const AuthSigningOut()`.
5. Tulis metadata persisten: `restore_allowed = false`, `cleanup_pending = true` (**sebelum** mencoba menghapus token fisik).
6. Eksekusi `tokenStorage.clearIfOwnedBy(...)` melalui antrean mutasi storage.
7. Jika sukses: `cleanup_pending = false`, state $\rightarrow$ `AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)`.
8. Jika gagal (`StorageException`): pertahankan `restore_allowed = false`, `cleanup_pending = true`, state $\rightarrow$ `AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)`.
9. Kembalikan `LogoutResult`:
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
     final bool remoteRevoked; // false pada mode demo
     final String? message;
   }
   ```

#### D. Urutan Persistent Login Crash-Consistent
1. Tulis metadata: `restore_allowed = false`.
2. Simpan refresh token ke secure storage di bawah mutation lock.
3. Pastikan operation epoch masih sama.
4. Tulis metadata: `cleanup_pending = false`, `restore_allowed = true`.
5. Publikasikan `AuthSignedIn`.

#### E. Perilaku UI & Tombol "Coba Bersihkan Lagi"
- Pada `ProfilePage` dan `SessionUnavailablePage`, `await ref.read(authControllerProvider.notifier).logout()` ditangani secara asinkron dengan visual tombol dinonaktifkan selama proses.
- Pada `LoginPage`, jika `cleanupStatus == LocalCleanupStatus.failed`, tampilkan banner amber ringkas:
  > **Pembersihan sesi belum selesai.** Akses data telah dikunci, tetapi kredensial lokal belum berhasil dihapus dari perangkat ini. Coba bersihkan kembali sebelum masuk menggunakan akun lain.
- Aksi tombol *"Coba Bersihkan Lagi"* memanggil operasi idempoten:
  ```dart
  Future<bool> retryLocalCredentialCleanup();
  ```
  Operasi ini dijalankan melalui mutation queue, menghapus token, memperbarui metadata, dan mengaktifkan kembali login jika sukses.
- Selama `cleanupStatus == failed`, auto-login, opsi "Tetap Masuk", dan login akun lain diblokir demi keamanan.

---

### 3.2 Dua Fase Mutasi, Matriks Transisi, & Token Ownership Guard (Menutup R2-01 & R2-04)

#### A. Pola Dua Fase Operasi
1. **Fase 1: Reserve**
   - Validasi matriks transisi state saat ini.
   - Ubah state secara sinkron (misal ke `AuthSigningIn`).
   - Buat ticket/epoch operasi.
2. **Fase 2: Execute (Di Luar Lock)**
   - Eksekusi request jaringan/kredensial (`repo.login` atau validasi remote). Lock storage **tidak ditahan** selama pemanggilan jaringan agar logout dapat segera memotong login lambat.
3. **Fase 3: Commit (Di Bawah Mutation Queue)**
   - Masuk antrean serial `_mutationQueue`.
   - Validasi ulang ticket dan epoch saat mendapatkan lock.
   - Tulis credential record / metadata.
   - Publikasikan state akhir.

#### B. Matriks Transisi Legal & `AuthCommandResult`
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

Aturan Transisi:
- `AuthBootstrapping` $\rightarrow$ hanya penyelesaian internal; `login`/`logout` ditolak (`operationInProgress`).
- `AuthSignedOut(clean)` $\rightarrow$ menerima `login()`.
- `AuthSignedOut(failed)` $\rightarrow$ menolak `login()` (`cleanupRequired`); hanya menerima `retryLocalCredentialCleanup()`.
- `AuthSigningIn` $\rightarrow$ menolak login baru (`operationInProgress`).
- `AuthSignedIn` $\rightarrow$ menerima `logout()`; menolak `login()` (`invalidState`).
- `AuthSigningOut` $\rightarrow$ menolak seluruh `login()` atau `bootstrap()` (`operationInProgress`).
- `AuthTemporarilyUnavailable` $\rightarrow$ menerima `retrySession()` dan `logout()`.

#### C. Credential Record & Token Ownership Guard Berbasis ID
Untuk mencegah operasi stale menghapus credential milik sesi baru:
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

  factory StoredCredential.fromJson(Map<String, dynamic> json) => StoredCredential(
    credentialId: json['credentialId'] as String,
    refreshToken: json['refreshToken'] as String,
  );
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
Jika Login A mendeteksi epoch berubah setelah menulis credential, Login A hanya memanggil `clearIfOwnedBy(credentialA.credentialId)`. Jika Login B sudah menimpa dengan `credentialB`, pemanggilan Login A tidak menghapus token B.

---

### 3.3 Interface Storage Bersih, Namespace Kanonis, & Konsistensi DEMO-003 (Menutup R2-03 & R2-05)

#### A. Namespace Kanonis & Versi Skema
Format key secure storage:
```text
kok.auth.v2.demo.credential
kok.auth.v2.staging.credential
kok.auth.v2.production.credential
```
Migrasi fail-closed: key lama `v1_kok_refresh_token` dihapus secara *best-effort* saat startup tanpa melakukan silent auto-login.

#### B. Kepemilikan Storage oleh Controller
`DemoAuthRepository` tidak lagi membaca secure storage sendiri. Kontrak repositori disederhanakan:
```dart
abstract interface class AuthRepository {
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  });

  Future<AuthResult> restoreSession(String refreshToken);

  Future<AuthResult> refreshToken(String refreshToken);

  Future<void> logout();
}
```
Controller membaca `StoredCredential` dari `AuthTokenStorage`, lalu meneruskan `credential.refreshToken` ke `repo.restoreSession(token)`. Seluruh pemeriksaan tipe runtime `repo is DemoAuthRepository` dihapus tuntas.

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
enum AccessScopeType {
  district,
  county,
}

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
Mengembalikan data 9 cabang olahraga (gabungan unik Garut Kota dan Tarogong Kidul), 9 klub, 213 atlet, dan 18 pelatih dengan ID unik dan integritas referensi klub valid. Unknown scope melempar `UnsupportedScopeException(scope.id)` tanpa fallback ke Garut Kota.

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

#### B. Kontrak Repository & Eliminasi Unscoped Fetch
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
    required this.userId,
    required this.scope,
    required this.generation,
  });

  final String userId;
  final AccessScope scope;
  final int generation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataRequestContext &&
          other.userId == userId &&
          other.scope == scope &&
          other.generation == generation;

  @override
  int get hashCode => Object.hash(userId, scope, generation);
}

final sessionDataContextProvider = Provider<DataRequestContext?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is! AuthSignedIn) return null;
  return DataRequestContext(
    userId: authState.user.id,
    scope: authState.user.scope,
    generation: authState.generation,
  );
});

final snapshotProvider = FutureProvider<KokSnapshot>((ref) async {
  final requestContext = ref.watch(sessionDataContextProvider);
  if (requestContext == null) {
    throw const SessionRequiredException();
  }

  final controller = RequestCancellationController();
  ref.onDispose(() => controller.cancel('Session changed or provider disposed'));

  final repository = ref.read(repositoryProvider);
  final result = await repository.fetchScope(
    requestContext.scope,
    cancellation: controller.token,
  );

  controller.token.throwIfCancelled();

  final currentContext = ref.read(sessionDataContextProvider);
  if (currentContext != requestContext) {
    throw const StaleSessionResultException();
  }

  return result;
});
```
`RequestCancelledException` dan `StaleSessionResultException` diperlakukan sebagai lifecycle normal (tidak memicu auto-retry dan tidak memicu notifikasi error jaringan).

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

  const AppComposition({
    required this.profile,
    required this.authRepository,
    required this.kokRepository,
    required this.tokenStorage,
  });

  factory AppComposition.fromProfile(DeploymentProfile profile, {SharedPreferences? prefs}) {
    final tokenStorage = SecureAuthTokenStorage(
      namespace: 'kok.auth.v2.${profile.environment.name}.credential',
    );

    final AuthRepository authRepo;
    if (profile.authMode == AuthMode.demo) {
      authRepo = DemoAuthRepository(
        metadataStore: prefs != null ? SharedPrefsSessionMetadataStore(prefs) : null,
      );
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
- Kontak narahubung: Ditandai dengan keterangan jujur `"Kontak demo/belum diverifikasi—jangan digunakan untuk pemulihan akun."`
- `README.md`: Diperbarui dengan deskripsi akurat mekanisme secure storage per platform (Android EncryptedSharedPreferences/Keystore, iOS Keychain, Web unencrypted fallback warning).

---

## 4. Rencana Verifikasi & Matriks Pengujian Regresi

Setiap komponen dilengkapi dengan pengujian regresi spesifik pada `test/auth_hardening_remediation_test.dart` dan pembaruan pada `test/app_test.dart`:

| Kategori | Skenario Pengujian |
|---|---|
| **Storage & Cleanup** | 1. Logout clear berhasil $\rightarrow$ state signed-out bersih, token kosong, restore diblokir.<br>2. Logout clear gagal $\rightarrow$ data langsung terkunci, `cleanupStatus == failed`, token tidak dipakai auto-login.<br>3. Restart setelah clear gagal $\rightarrow$ bootstrap membaca `cleanup_pending`, menolak auto-login, menampilkan peringatan di `LoginPage`.<br>4. `retryLocalCredentialCleanup()` berhasil $\rightarrow$ token terhapus, metadata bersih, login diaktifkan.<br>5. `retryLocalCredentialCleanup()` gagal $\rightarrow$ status tetap failed, auto-restore tetap diblokir.<br>6. Double logout tap $\rightarrow$ hanya satu operasi cleanup dijalankan.<br>7. Login saat cleanup berlangsung $\rightarrow$ ditolak dengan `AuthCommandRejected(cleanupRequired)`.<br>8. Crash sebelum `restore_allowed = true` $\rightarrow$ token orphaned tidak dipakai auto-login. |
| **Concurrency & Ownership** | 9. Logout memutus login jaringan yang menggantung tanpa menunggu lock.<br>10. Revalidasi tiket operasi pasca-antrean $\rightarrow$ commit ditolak jika epoch berubah.<br>11. Delayed token write A vs Login B $\rightarrow$ `clearIfOwnedBy(credentialA)` tidak menghapus token B.<br>12. Exception pada antrean $\rightarrow$ lock dilepas tanpa deadlock. |
| **DEMO-003 & Scope** | 13. Login `DEMO-003` dengan Tetap Masuk $\rightarrow$ dispose container $\rightarrow$ bootstrap baru $\rightarrow$ identitas tetap Ibu Rina (`usr_koni_kab`), bukan Pak Cecep.<br>14. Snapshot `DEMO-003` memuat data kabupaten 9 cabor (213 atlet, 18 pelatih) dengan ID unik.<br>15. Unknown scope melempar `UnsupportedScopeException` tanpa fallback ke Garut Kota.<br>16. Migrasi legacy key `v1_kok_refresh_token` fail-closed (tidak auto-login). |
| **Data Cancellation** | 17. Cancellation idempotent (dua kali cancel tidak melempar).<br>18. Delayed fetch A tertahan $\rightarrow$ switch ke user B $\rightarrow$ request A dibatalkan, data B tidak tercemar.<br>19. Scope/generation berubah tanpa transport batal $\rightarrow$ stale-result guard menolak respons lama.<br>20. Cancellation & Stale exceptions tidak memicu retry otomatis. |
| **Composition & Permissions** | 21. Production composition menghasilkan adapter remote; jika belum ada $\rightarrow$ fail-closed saat startup.<br>22. `dataMode.remote + authMode.demo` ditolak pada seluruh environment.<br>23. Pengguna tanpa `reports:export` (DEMO-002) diblokir dari aksi salin rekap.<br>24. Seluruh codebase UI bebas dari klaim palsu "sudah tersinkronisasi SICABOR". |

---

## 5. Kriteria Selesai (Definition of Done)

- Seluruh 7 temuan *blocker* (R2-01 s/d R2-07) dan catatan Bagian 5 tertutup tuntas.
- Mutasi storage lokal diserialisasi penuh dengan token ownership guard berbasis ID.
- Kegagalan cleanup storage dipersistensikan sebagai metadata fail-closed dan memiliki alur retry yang aman.
- Ketiga akun demo (`DEMO-001`, `DEMO-002`, `DEMO-003`) memiliki identitas, token persisten, dan dataset yang konsisten setelah restart.
- Kontrak repository data tidak memiliki pintu belakang tanpa scope dan kebal terhadap *delayed cross-account responses*.
- `DeploymentProfile` dan `AppComposition` menjamin isolasi konfigurasi produksi yang fail-closed.
- `flutter analyze` 0 issues dan seluruh pengujian (180+ tests) lulus 100%.

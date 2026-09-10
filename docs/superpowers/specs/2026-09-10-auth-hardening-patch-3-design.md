# Spesifikasi Desain: Remediasi Audit Review Tahap 1 Ketiga (Patch 3)

Tanggal: 2026-09-10  
Status: **Approved for Implementation**  
Dokumen Audit Rujukan: `docs/audit/auth/audit-auth-review-tahap1-ketiga.md`  

---

## 1. Sasaran & Ruang Lingkup

Patch 3 menyempurnakan kontrak arsitektural dan menutup seluruh temuan P1 (P1-01 s/d P1-08) dan catatan P2 (P2-01 s/d P2-07):
1. **P1-01 (SC-06):** Single-flight logout pada `AuthController` melalui `_activeLogoutFuture`.
2. **P1-02 (Storage Ownership):** Penghapusan mutlak method legacy pada `AuthTokenStorage` dan pelepasan storage dependency dari interface `AuthRepository`.
3. **P1-03 (SC-17):** Penyeragaman exact tiga akun demo (`usr_garut_kota`, `usr_tarogong_kidul`, `usr_koni_kab`), password `konigarut123`, dan pemberian izin `'reports:export'` pada DEMO-003.
4. **P1-04 (SC-30):** Penutupan celah export di `SportDetailPage` dengan proteksi izin `'reports:export'` dan eliminasi hardcoded `"Kecamatan Garut Kota"`.
5. **P1-05 (SC-31):** Pembersihan seluruh sisa klaim aktif SICABOR (`ID SICABOR`, `Data milik SICABOR`) di seluruh aplikasi.
6. **P1-06 (SC-07, SC-16):** Penambahan enum bertipe `AuthCommandRejection { cleanupRequired, operationInProgress, invalidState }` pada `AuthCommandResult`.
7. **P1-07 (SC-13, SC-16):** Pengujian regresi dengan barrier deterministik untuk ticket stale sebelum queue dan cancel saat committing.
8. **P1-08:** Penanganan try-catch non-kritis pada penyimpanan/penghapusan remembered SK agar kegagalan preferensi tidak membatalkan atau merusak autentikasi yang sah.
9. **P2-01 s/d P2-07:** Demo revocation mengembalikan `RemoteRevocationStatus.notApplicable`; `snapshotProvider` memvalidasi kesesuaian `snapshot.scope == context.scope`; `ProfilePage` menampilkan role dan badge scope dinamis; pembersihan compatibility layer.

---

## 2. Rincian Teknis Kontrak

### 2.1 Concurrency Controller & Typed Rejections (P1-01, P1-06, P1-08)

#### A. Typed Command Rejection
```dart
enum AuthCommandRejection { cleanupRequired, operationInProgress, invalidState }

final class AuthCommandResult {
  const AuthCommandResult({
    required this.status,
    this.rejection,
    this.errorMessage,
  });

  final AuthCommandStatus status;
  final AuthCommandRejection? rejection;
  final String? errorMessage;

  bool get isSuccess => status == AuthCommandStatus.success;
  bool get isRejected => status == AuthCommandStatus.rejected;
}
```

- Login ditolak saat `cleanupStatus != LocalCleanupStatus.clean` dengan `rejection: AuthCommandRejection.cleanupRequired`.
- Login ditolak saat state bukan `AuthSignedOut` dengan `rejection: AuthCommandRejection.invalidState`.
- `cancelSignIn()` ditolak saat `_signInPhase == SignInPhase.committing` dengan `rejection: AuthCommandRejection.operationInProgress`.
- `cancelSignIn()` ditolak saat `_signInPhase == SignInPhase.idle` dengan `rejection: AuthCommandRejection.invalidState`.

#### B. Single-Flight Logout
```dart
Future<LogoutResult>? _activeLogoutFuture;

Future<LogoutResult> logout({
  Duration revocationTimeout = const Duration(seconds: 5),
}) {
  final active = _activeLogoutFuture;
  if (active != null) return active;
  final run = _runLogout(revocationTimeout);
  _activeLogoutFuture = run;
  return run.whenComplete(() {
    if (identical(_activeLogoutFuture, run)) {
      _activeLogoutFuture = null;
    }
  });
}
```

#### C. Non-Critical Remembered SK
Dalam fase commit login (nonpersisten & persisten):
```dart
try {
  if (rememberSk) {
    await skStore.saveSk(skNumber);
  } else {
    await skStore.clear();
  }
} catch (_) {
  // Kegagalan storage preferensi non-kritis tidak membatalkan sesi yang sudah sah
}
```

---

### 2.2 Interface Bersih & Kontrak Akun Kanonis (P1-02, P1-03, P2-01)

#### A. Interface `AuthRepository` Murni
```dart
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
- Menghapus method `logout()`.
- `restoreSession` mewajibkan non-null `String refreshToken`.
- `DemoAuthRepository` tidak lagi menerima dependency `tokenStorage` atau `skStore`, dan getter `storage` dihapus.
- `revokeSession` di `DemoAuthRepository` mengembalikan `RemoteRevocationStatus.notApplicable`.

#### B. `AuthTokenStorage` Tanpa Compatibility Legacy
Hanya memuat method kanonis:
- `Future<StoredCredential?> read();`
- `Future<void> write(StoredCredential credential);`
- `Future<bool> clearIfOwnedBy(String credentialId);`
- `Future<void> forceClearForRecovery();`
- `Future<void> migrateLegacyStorage();`

Menghapus: `saveRefreshToken`, `readRefreshToken`, `getRefreshToken`, dan `clear()`.

#### C. Akun Demo Kanonis
- **DEMO-001:** `id: 'usr_garut_kota'`, `skNumber: 'DEMO-001'`, `fullName: 'Pak Asep'`, `roleTitle: 'Koordinator Kecamatan'`, `scope: AccessScope(type: AccessScopeType.district, id: 'garut_kota', name: 'Kecamatan Garut Kota')`, `permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'}`.
- **DEMO-002:** `id: 'usr_tarogong_kidul'`, `skNumber: 'DEMO-002'`, `fullName: 'Pak Cecep'`, `roleTitle: 'Koordinator Kecamatan'`, `scope: AccessScope(type: AccessScopeType.district, id: 'tarogong_kidul', name: 'Kecamatan Tarogong Kidul')`, `permissions: {'sports:read', 'clubs:read', 'members:read'}` (tanpa `reports:export`).
- **DEMO-003:** `id: 'usr_koni_kab'`, `skNumber: 'DEMO-003'`, `password: 'konigarut123'`, `fullName: 'Ibu Rina'`, `roleTitle: 'Tim Verifikator'`, `scope: AccessScope(type: AccessScopeType.county, id: 'koni_kab', name: 'KONI Kabupaten Garut')`, `permissions: {'sports:read', 'clubs:read', 'members:read', 'documents:verify', 'reports:export'}`.

---

### 2.3 UI Permission Guard & Honest Demo Labels (P1-04, P1-05, P2-04, P2-07)

#### A. Detail Cabor (`SportDetailPage`)
- Membaca user aktif (`currentUserProvider`) dan `snapshot.scope`.
- Tombol `Salin Rekapitulasi Cabor` dinonaktifkan (`onPressed: null`) jika `!user.hasPermission('reports:export')`.
- Method `_copySummary`:
  ```dart
  if (!(user?.hasPermission('reports:export') ?? false)) return;
  ```
  dan menggunakan nama wilayah dinamis:
  ```
  Wilayah         : ${snapshot.scope.name}
  ```

#### B. Penghapusan Seluruh Klaim SICABOR Aktif
- `athlete_detail_page.dart`: Ganti `'ID SICABOR · ATL-${person.id}'` menjadi `'ID DEMO · ATL-${person.id}'`.
- `club_people_tab.dart` & `club_document_tab.dart`: Ganti `'Data milik SICABOR.'` menjadi `'Data demo lokal—belum terhubung dengan SICABOR. Perubahan diajukan lewat pengurus klub.'`.

#### C. Role & Scope Dinamis di `ProfilePage`
- Kartu eksekutif profil menggunakan `user?.roleTitle` dan `user?.scope.name`.
- Badge menggunakan `user?.scope.type == AccessScopeType.county ? 'AKSES KABUPATEN' : 'AKSES READ-ONLY'`.

#### D. Validasi Scope pada `snapshotProvider`
- Setelah memanggil `repo.fetchScope(context.scope)`:
  ```dart
  if (snapshot.scope != context.scope) {
    throw StateError('Repository mengembalikan snapshot dengan scope tidak cocok: ${snapshot.scope} != ${context.scope}');
  }
  ```

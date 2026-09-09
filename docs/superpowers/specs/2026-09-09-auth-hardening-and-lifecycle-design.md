# Desain Arsitektur Penguatan Autentikasi & Siklus Sesi (Tahap A Hardening)

Tanggal: 2026-09-09  
Status: Proposed  
Penulis: Pair Programming (Antigravity & User)  
Dokumen Rujukan: [docs/audit-auth-review-tahap1.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth-review-tahap1.md) (Temuan A-01 s/d A-09, Catatan Desain Bagian 5)

---

## 1. Latar Belakang & Tujuan

Berdasarkan hasil review implementasi Tahap A pada `docs/audit-auth-review-tahap1.md`, fondasi modularisasi autentikasi (`UserPrincipal`, `AuthState`, `AuthRepository`, `SessionScope`, layar sesi, dan pemisahan tombol keluar dari `DataView`) telah terpasang dengan baik. Namun, review mengidentifikasi 9 area perbaikan (*hardening*) kritis sebelum sistem dapat dinyatakan siap menerima autentikasi nyata:

1. **A-01 (Guard State Transisi Bocor)**: Route terlindungi tidak terlindungi secara *fail-closed* saat `AuthSigningIn` dan `AuthSigningOut`.
2. **A-02 (Race Condition Asinkron & Storage Stale Commit)**: Nilai `_sessionGeneration` belum diperiksa sebelum dan sesudah `await`, sehingga operasi login yang lambat dapat menimpa hasil logout yang lebih cepat dan meninggalkan token di storage.
3. **A-03 (Fallback Data Tanpa Sesi)**: `snapshotProvider` masih memuat data Garut Kota saat `sessionScope == null` demi kompatibilitas pengujian/preview.
4. **A-04 (Boundary Environment Belum Fail-Closed)**: Kredensial dan adapter demo aktif secara otomatis tanpa validasi environment produksi.
5. **A-05 (Error Storage Ditelan)**: Kegagalan hardware keystore diubah menjadi `null` atau ditelan diam-diam.
6. **A-06 (Token Tiruan Terlalu Permisif)**: `DemoAuthRepository` menerima sembarang token acak dan mengembalikannya sebagai sesi Garut Kota.
7. **A-07 (Double Bootstrap & Penerusan Reason)**: Menekan tombol coba lagi memicu pemanggilan `bootstrap()` ganda, dan rute `/session-unavailable` belum membaca pesan alasan kendala.
8. **A-08 (Dua Sumber Sesi Ganda)**: `SessionController / sessionProvider` (boolean lama) masih dipertahankan di `lib/core/session.dart` dan dipanggil bersamaan di UI.
9. **A-09 (Teks & Metadata Multi-Wilayah)**: Rekapitulasi kecamatan di `ProfilePage` masih bertuliskan Garut Kota meskipun pengguna adalah Koordinator Tarogong Kidul, dan label sinkronisasi masih mengklaim SICABOR.

Dokumen ini mendefinisikan rancangan perbaikan tuntas untuk menutup seluruh temuan A-01 s/d A-09.

---

## 2. Batasan Global & Prinsip Desain

1. **Prinsip Keamanan Fail-Closed**:
   - Seluruh rute data dan navigasi internal tertutup rapat kecuali untuk state `AuthSignedIn`.
   - Tanpa sesi (`sessionScope == null`), data keolahragaan **sama sekali tidak diambil dari repository** dan melempar `SessionRequiredException`.
   - Build dengan environment `production` langsung menolak berjalan (*throw StateError*) jika mendeteksi penggunaan adapter/kredensial demo.
2. **Keamanan Asinkron (Epoch-Guarded Mutex)**:
   - Setiap operasi autentikasi (`login`, `bootstrap`, `logout`) menaikkan nilai `_operationEpoch`.
   - Hasil operasi diverifikasi setelah setiap baris `await`. Hasil yang tiba terlambat setelah pergantian epoch dibatalkan seketika, dan token stale tidak akan di-commit ke storage.
3. **Konsistensi UI & Tipografi**:
   - Seluruh ukuran font pada antarmuka baru maupun hasil modifikasi berukuran $\ge 12\text{px}$.
   - Warna judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`).
   - Tombol kembali menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
   - Struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Profil) tetap utuh.

---

## 3. Struktur Berkas & Modifikasi

```
lib/
  ├── core/
  │    ├── auth/
  │    │    ├── domain/
  │    │    │    ├── user_principal.dart           # Immutable permissions & full value equality
  │    │    │    ├── auth_state.dart
  │    │    │    └── auth_failure.dart
  │    │    ├── data/
  │    │    │    ├── auth_token_storage.dart       # Exception bertipe StorageException (no catch swallow)
  │    │    │    ├── remembered_sk_store.dart
  │    │    │    ├── auth_repository.dart
  │    │    │    └── demo_auth_repository.dart     # Penolakan token tak dikenal & 2 akun resmi
  │    │    └── presentation/
  │    │         ├── auth_controller.dart          # Epoch counter, single-flight bootstrap, storage mutex
  │    │         ├── session_startup_page.dart     # UI pemulihan sesi murni (label jujur)
  │    │         ├── session_signing_out_page.dart # [BARU] Layar transisi logout (/signing-out)
  │    │         └── session_unavailable_page.dart # Membaca reason & retry aman
  │    ├── config/
  │    │    └── app_environment.dart               # [BARU] Enum AppEnvironment & validator fail-closed
  │    ├── preferences.dart                        # [BARU] preferencesProvider mandiri
  │    ├── session.dart                            # [DIHAPUS] legacy SessionController / sessionProvider
  │    └── theme.dart
  ├── data/
  │    └── repository.dart                         # SessionRequiredException & CancelToken (tanpa fallback)
  ├── features/
  │    ├── login_page.dart                         # Early busy guard & single auth source
  │    ├── profile_page.dart                       # Rekapitulasi dinamis per kecamatan & label jujur
  │    └── home_page.dart                          # Label jujur & identitas dinamis
  ├── app.dart                                     # Closed-default router redirect & rute /signing-out
  └── main.dart                                    # Eksekusi validator environment sebelum runApp
```

---

## 4. Rincian Teknis Implementasi

### 4.1 Penyatuan Sumber Sesi & Pemisahan Preferences (Menutup A-08)

1. Buat `lib/core/preferences.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized at startup.'),
);
```
2. Hapus berkas `lib/core/session.dart`.
3. Di `lib/features/login_page.dart`:
   - Hapus seluruh dependensi dan pemanggilan ke `sessionProvider`.
   - Tambahkan early guard pada `_submit()`:
     ```dart
     if (_busy) return;
     ```
   - Hanya panggil `ref.read(authControllerProvider.notifier).login(...)`.
4. Di `lib/features/profile_page.dart`:
   - Hapus pemanggilan `ref.read(sessionProvider.notifier).signOut()`.
   - Hanya panggil `ref.read(authControllerProvider.notifier).logout()`.

---

### 4.2 Router Guard Tertutup & Rute `/signing-out` (Menutup A-01, A-07)

1. Buat `lib/core/auth/presentation/session_signing_out_page.dart`:
   - Stateless / pure ConsumerWidget (tanpa logika `bootstrap()` di `initState`).
   - Visual Navy KOK dengan `BrandHeaderPatternPainter`.
   - Teks: Judul *"Mengeluarkan Akun"* (16sp), subjudul *"Membersihkan sesi lokal dan mengamankan data..."* (13sp), progress indicator putih.
2. Di `lib/app.dart`:
   - Daftarkan rute `/signing-out` dengan `SessionSigningOutPage()`.
   - Perbarui rute `/session-unavailable` untuk membaca alasan:
     ```dart
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
   - Terapkan guard tertutup (*closed default*):
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

---

### 4.3 Pengamanan Race Condition & Error Storage (Menutup A-02, A-05)

1. Di `lib/core/auth/data/auth_token_storage.dart`:
   - Definisikan `StorageException`:
     ```dart
     class StorageException implements Exception {
       final String message;
       const StorageException(this.message);
       @override
       String toString() => message;
     }
     ```
   - Pada `SecureAuthTokenStorage`:
     * Jangan menelan error dengan `catch (_) { return null; }` atau `catch (_) {}`.
     * Bungkus exception platform ke dalam `StorageException`.
2. Di `lib/core/auth/data/demo_auth_repository.dart`:
   - `login()` tidak lagi langsung menulis token ke storage secara sepihak.
   - Kembalikan kandidat token di dalam `AuthResult.success(user: matchedUser, accessToken: ..., refreshToken: ...)`.
   - `restoreSession()`: Tolak token tak dikenal secara ketat:
     ```dart
     if (token == 'token_usr_garut_kota') {
       return AuthResult.success(user: _garutKotaUser, accessToken: ...);
     } else if (token == 'token_usr_tarogong_kidul') {
       return AuthResult.success(user: _tarogongKidulUser, accessToken: ...);
     }
     return const AuthResult.failed(
       SessionExpiredFailure('Sesi Anda tidak valid atau telah kedaluwarsa.'),
     );
     ```
   - Fokus pada 2 akun resmi: `DEMO-001` (Pak Asep · Garut Kota) dan `DEMO-002` (Pak Cecep · Tarogong Kidul).
3. Di `lib/core/auth/presentation/auth_controller.dart`:
   - Simpan `int _operationEpoch = 0` dan `Future<void>? _activeBootstrapFuture`.
   - **`bootstrap()` (Single-Flight & Epoch Check)**:
     ```dart
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

       final repo = ref.read(authRepositoryProvider);
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
     ```
   - **`login(...)` (Storage Commit Coordination)**:
     ```dart
     Future<bool> login({
       required String skNumber,
       required String password,
       required bool staySignedIn,
       required bool rememberSk,
     }) async {
       _operationEpoch++;
       final currentEpoch = _operationEpoch;
       state = const AuthSigningIn();

       final repo = ref.read(authRepositoryProvider);
       try {
         final result = await repo.login(
           skNumber: skNumber,
           password: password,
           staySignedIn: staySignedIn,
         );
         if (currentEpoch != _operationEpoch) return false;

         if (result.isSuccess && result.user != null) {
           final tokenStorage = ref.read(authTokenStorageProvider);
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

           final skStore = ref.read(rememberedSkStoreProvider);
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
     ```
   - **`logout()` (Immediate Epoch & Generation Bump)**:
     ```dart
     Future<void> logout() async {
       _operationEpoch++;
       final currentEpoch = _operationEpoch;
       _sessionGeneration++;
       state = const AuthSigningOut();

       try {
         final repo = ref.read(authRepositoryProvider);
         await repo.logout();
       } finally {
         if (currentEpoch == _operationEpoch) {
           state = const AuthSignedOut();
         }
       }
     }
     ```

---

### 4.4 Penghapusan Fallback Data & Pagar Konfigurasi (Menutup A-03, A-04)

1. Di `lib/data/repository.dart`:
   - Buat `SessionRequiredException`:
     ```dart
     final class SessionRequiredException implements Exception {
       final String message;
       const SessionRequiredException([
         this.message = 'Sesi terautentikasi aktif dibutuhkan untuk mengakses data keolahragaan.',
       ]);
       @override
       String toString() => message;
     }
     ```
   - Tambahkan signature `CancelToken? cancelToken` pada `fetchDistrict`:
     ```dart
     Future<KokSnapshot> fetchDistrict(String districtId, {CancelToken? cancelToken});
     ```
   - `snapshotProvider` menolak keras pembacaan tanpa sesi:
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
2. Buat `lib/core/config/app_environment.dart`:
   ```dart
   enum AppEnvironment { demo, staging, production }

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
3. Di `lib/main.dart`:
   Panggil `validateAppConfiguration(...)` sebelum `runApp(...)`.

---

### 4.5 Penyempurnaan Teks & Rekapitulasi Wilayah (Menutup A-09 & Bagian 5)

1. Di `lib/features/profile_page.dart`:
   - Rekapitulasi data menggunakan `data.districtName` secara dinamis:
     * Judul sheet: `"Rekapitulasi Data KOK ${data.districtName.replaceFirst('Kecamatan ', '')}"`
     * Subtitle: `"Ringkasan data keolahragaan wilayah ${data.districtName}."`
     * Teks salin clipboard:
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
     * Ubah label: `'Terakhir dimuat: $timeStr · ${data.people.length} entri data (Mode Demo)'`
     * Tombol refresh melakukan:
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
   - Ganti teks `'Terakhir Tersinkron SICABOR'` menjadi `'Terakhir Dimuat: $timeStr WIB'`.
3. Di `lib/core/auth/presentation/session_startup_page.dart`:
   - Ganti teks status menjadi: `'Memeriksa sesi pengguna...'`.
4. Di `lib/core/auth/domain/user_principal.dart`:
   - Bungkus `permissions = Set.unmodifiable(permissions)`.
   - Update `operator ==` dan `hashCode` untuk memperhitungkan seluruh properti identitas dan kesetaraan `permissions`.

---

## 5. Rencana Pengujian Regresi & Validasi

Sesuai tabel Bagian 7 pada [docs/audit-auth-review-tahap1.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth-review-tahap1.md):

1. **Test Race Asinkron Login-Logout**:
   - Menahan respons login menggunakan `Completer`, memanggil `logout()`, lalu menyelesaikan future login lama. Verifikasi: State tetap `AuthSignedOut` dan storage kosong (tidak ada token stale tertinggal).
2. **Test Double-Call Bootstrap / Retry**:
   - Memanggil `bootstrap()` ganda bersamaan atau menekan retry di layar unavailable. Verifikasi: Hanya terjadi 1 kali restore request.
3. **Test Penolakan Data Tanpa Sesi**:
   - Membaca `snapshotProvider` saat `sessionScopeProvider == null`. Verifikasi: Langsung melempar `SessionRequiredException` dan `repository.fetchDistrict` tidak dipanggil.
4. **Test Guard State Transisi**:
   - Memasuki `/club/garuda` saat state `AuthSigningIn` atau `AuthSigningOut`. Verifikasi: Guard mengunci ke `/login` atau `/signing-out`, data klub tidak pernah terbuka.
5. **Test Token Storage Error**:
   - Storage wrapper melempar `StorageException`. Verifikasi: Bootstrap beralih ke `AuthTemporarilyUnavailable` (bukan signed-out kredensial salah).
6. **Test Token Tiruan Ketat**:
   - Token acak/kosong di storage saat startup. Verifikasi: Ditolak, tidak fallback ke Garut Kota.
7. **Test Konfigurasi Produksi Fail-Closed**:
   - `validateAppConfiguration(environment: AppEnvironment.production, usesDemoAuth: true, usesDemoData: true)`. Verifikasi: Melempar `StateError`.
8. **Test Rekapitulasi Tarogong Kidul**:
   - Login Pak Cecep $\rightarrow$ buka profil $\rightarrow$ buka rekap. Verifikasi: Menampilkan "Tarogong Kidul" pada sheet dan teks clipboard.
9. **Analisis Statik & Test Suite Penuh**:
   - `flutter analyze`: 0 issues.
   - `flutter test`: 100% lulus.

---

## 6. Kriteria Selesai (Definition of Done)

- Seluruh temuan A-01 s/d A-09 tertutup tuntas.
- Sumber kebenaran sesi tunggal murni di `authControllerProvider` (tidak ada lagi `sessionProvider` boolean lama).
- Seluruh rute non-signed-in tertutup rapat (*fail-closed*).
- Respons asinkron lama tidak dapat menghidupkan kembali sesi setelah logout.
- Data keolahragaan tidak pernah diambil tanpa sesi aktif.
- Konfigurasi produksi salah langsung ditolak saat startup.
- `flutter analyze` 0 issues dan seluruh test lulus 100%.

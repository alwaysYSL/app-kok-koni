# Plan: Remediasi Audit Review Tahap 1 Ketiga (Patch 3)

Tanggal: 2026-09-10  
Status: **Approved for Implementation**  
Spesifikasi Acuan: `docs/superpowers/specs/2026-09-10-auth-hardening-patch-3-design.md`  

---

## Global Constraints
- Seluruh teks pada komponen antarmuka memiliki ukuran font >= 12px.
- Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (#141414).
- Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan ukuran 28 dan warna kontras sesuai surface.
- Struktur 5 tab navigasi bawah (Beranda, Cabor, Klub, Anggota, Akun/Profil) tidak diubah.
- `flutter analyze` harus 0 issues dan `flutter test` harus 100% lulus pada setiap task.
- JANGAN jalankan `dart format` pada `README.md`.

---

## Task 1 — Concurrency Controller, Typed Rejection, & Concurrency Tests (P1-01, P1-06, P1-07, P1-08)

### Files
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

### Langkah:
1. Definisikan `enum AuthCommandRejection { cleanupRequired, operationInProgress, invalidState }`.
2. Perbarui `AuthCommandResult` dengan properti `final AuthCommandRejection? rejection;`.
3. Tambahkan `Future<LogoutResult>? _activeLogoutFuture;` pada `AuthController`.
4. Refactor `logout()` agar memanggil `_runLogout()` melalui single-flight guard.
5. Pada `login()`, kembalikan `AuthCommandRejection.cleanupRequired` bila cleanup belum clean, dan `AuthCommandRejection.invalidState` bila state bukan `AuthSignedOut`.
6. Pada `cancelSignIn()`, kembalikan `AuthCommandRejection.operationInProgress` saat fase committing, dan `AuthCommandRejection.invalidState` saat fase idle.
7. Bungkus pemanggilan `skStore.saveSk/clear` di dalam try-catch non-kritis pada login.
8. Tulis failing tests di `test/auth_controller_test.dart`:
   - SC-06: concurrent `logout()` memanggil 1 siklus mutasi/cleanup.
   - SC-07: login saat cleanup pending/failed menghasilkan `AuthCommandRejection.cleanupRequired`.
   - SC-13: barrier test membuktikan stale ticket sebelum queue dibatalkan tanpa write.
   - SC-16: barrier test membuktikan cancel saat committing menghasilkan `AuthCommandRejection.operationInProgress`.
   - P1-08: kegagalan I/O pada `skStore` tidak menggagalkan login yang sudah sah.
9. Jalankan verifikasi, format, dan commit.

---

## Task 2 — Strict Storage Ownership & Canonical Account Contracts (P1-02, P1-03, P2-01)

### Files
- Modify: `lib/core/auth/data/auth_repository.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/features/login_page.dart`
- Modify: `test/auth_repository_test.dart`
- Modify: `test/auth_token_storage_test.dart`
- Modify: `test/auth_hardening_test.dart`
- Modify: `test/auth_hardening_remediation_test.dart`
- Modify all affected tests calling old constructor or methods

### Langkah:
1. Ubah `AuthRepository.restoreSession(String refreshToken)` mewajibkan non-null token; hapus `Future<void> logout()`.
2. Hapus `tokenStorage` dan `skStore` dari constructor dan fields `DemoAuthRepository`; hapus getter `storage`; hapus method `logout()`.
3. Ubah `DemoAuthRepository.revokeSession()` mengembalikan `RemoteRevocationStatus.notApplicable`.
4. Standarisasi tiga akun demo kanonis di `DemoAuthRepository`:
   - DEMO-001: id `usr_garut_kota`, sk `DEMO-001`.
   - DEMO-002: id `usr_tarogong_kidul`, sk `DEMO-002`.
   - DEMO-003: id `usr_koni_kab`, sk `DEMO-003`, password `konigarut123`, permissions memuat `'reports:export'`.
5. Hapus method legacy pada `AuthTokenStorage`: `saveRefreshToken`, `readRefreshToken`, `getRefreshToken`, dan `clear()`.
6. Update `login_page.dart` sheet akun demo agar password DEMO-003 adalah `konigarut123`.
7. Lakukan migration sweep pada seluruh file test yang memanggil constructor lama atau method token legacy.
8. Jalankan verifikasi, format, dan commit.

---

## Task 3 — UI Permission Guard, SICABOR Label Cleanup, & Scope Check (P1-04, P1-05, P2-04, P2-07)

### Files
- Modify: `lib/features/sport_detail/sport_detail_page.dart`
- Modify: `lib/features/athlete_detail/athlete_detail_page.dart`
- Modify: `lib/features/club_detail/club_people_tab.dart`
- Modify: `lib/features/club_detail/club_document_tab.dart`
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/data/providers/snapshot_provider.dart`
- Modify tests: `test/sport_detail_test.dart`, `test/athlete_detail_test.dart`, `test/club_detail_widgets_test.dart`, `test/profile_page_test.dart`, `test/session_scope_test.dart`

### Langkah:
1. Di `SportDetailPage`, baca `currentUserProvider` dan `snapshot.scope`.
2. Nonaktifkan tombol `Salin Rekapitulasi Cabor` bila user tidak memiliki izin `'reports:export'`.
3. Di method `_copySummary`, periksa izin secara defensif dan gantikan teks hardcoded `Kecamatan Garut Kota` dengan `${snapshot.scope.name}`.
4. Ganti `'ID SICABOR · ATL-${person.id}'` di `athlete_detail_page.dart` menjadi `'ID DEMO · ATL-${person.id}'`.
5. Ganti `'Data milik SICABOR.'` di `club_people_tab.dart` dan `club_document_tab.dart` dengan `'Data demo lokal—belum terhubung dengan SICABOR. Perubahan diajukan lewat pengurus klub.'`.
6. Di `ProfilePage`, gunakan `user?.roleTitle` dinamis dan badge role dinamis berbasis `user?.scope.type`.
7. Di `snapshotProvider`, tambahkan validasi `if (snapshot.scope != context.scope) throw StateError(...)`.
8. Tulis/perbarui tests untuk memverifikasi SC-30 di detail cabor (DEMO-002 ditolak ekspor), detail atlet tanpa klaim SICABOR, dan validasi scope snapshot.
9. Jalankan verifikasi, format, dan commit.

---

## Task 4 — Documentation, Final Verification, & Build (P2-02, P2-05, P2-06, Verifikasi Final)

### Files
- Modify: `README.md` (Update credentials, exact passwords, permissions; DO NOT run dart format)
- Modify: `walkthrough.md`
- Codebase clean sweep

### Langkah:
1. Sinkronkan `README.md` (password kanonis `konigarut123`, izin DEMO-003, exact IDs).
2. Jalankan code generation:
   `dart run build_runner build --delete-conflicting-outputs`
3. Jalankan format:
   `dart format --output=none --set-exit-if-changed lib test`
4. Jalankan analyzer:
   `flutter analyze` (harus 0 issues)
5. Jalankan audit grep untuk memastikan tidak ada API atau klaim terlarang:
   `git grep -nE "fetchDistrict|class CancelToken|readRefreshToken|getRefreshToken|saveRefreshToken|Future<void> logout\(\)" -- lib test`
   `git grep -nEi "ID SICABOR|Data milik SICABOR|SINKRONISASI DATA SICABOR|tersinkronisasi dengan SICABOR|data SICABOR aktif" -- lib`
6. Jalankan full test suite:
   `flutter test` (seluruh 320+ test harus lulus 100%)
7. Jalankan Android APK build:
   `flutter build apk --debug`
8. Perbarui `walkthrough.md` dengan bukti verifikasi lengkap.
9. Commit final.

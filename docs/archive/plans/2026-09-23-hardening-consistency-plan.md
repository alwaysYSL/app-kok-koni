# Rencana Implementasi — Hardening Integrasi & Konsistensi Mode Remote

## Ringkasan Eksekutif

Rencana ini merinci implementasi dua milestone kritis untuk mematangkan arsitektur integrasi aplikasi KOK dengan backend SICABOR:
- **Milestone 4.1 (Hardening Integrasi)**: Mengatasi kebocoran sesi saat ganti akun/logout, race condition pada pagination/filter dengan generation counter, penanganan global 401/403 ke logout terpusat via Dio Interceptor, serta perbaikan bug UI/layanan (opsi sort, isolasi scope demo, pemetaan reason code, label alamat, dan link SK).
- **Milestone 5 (Konsistensi Mode Remote)**: Menstandarkan halaman yang belum memiliki endpoint remote di SICABOR (Global Search, Perlu Perhatian, Anggota KOK) dengan widget informatif `RemoteFeaturePlaceholder` (mencegah crash `DataView`/`snapshotProvider`), serta migrasi parsial `ProfilePage` menggunakan data dari `profileSummaryProvider`.

Pekerjaan dilakukan langsung pada branch **`main`** menggunakan metodologi **Subagent-Driven Development (SDD)** dengan siklus pengujian TDD bertingkat, menjaga 100% test pass dan 0 issue pada `flutter analyze`.

---

## Prasyarat & Lingkungan

- Branch aktif: `main` (tersinkronisasi dengan `origin/main` dan `gitlab/main`).
- Milestone 1–4 telah selesai dengan 687 tests passing.
- Semua dokumen specs dan plans disimpan pada folder `docs/archive/specs/` dan `docs/archive/plans/`.

---

## Rincian Tugas (SDD Tasks)

### Task 1: Pagination Session Guard & Generation Counter in Providers
- **File Modifikasi**:
  - `lib/data/providers/club_providers.dart`:
    - `build()` menonton `dataRequestContextProvider` (otomatis me-reset state ke initial saat sesi berganti atau logout).
    - Tambahkan counter `_generation` di `ClubPaginationController`.
    - Di `loadFirstPage()` dan `loadMore()`: simpan `contextAtStart` dan `expectedGen = _generation`, validasi `currentContext == contextAtStart && expectedGen == _generation` sebelum menerapkan state response.
  - `lib/data/providers/athlete_providers.dart`:
    - Idem (`build()` watch context, generation counter, validasi context & gen).
  - `lib/data/providers/cabor_providers.dart`:
    - Idem + ubah `ref.read` menjadi `ref.refresh` pada `loadFirstPage()`.
- **File Uji Baru**:
  - `test/data/club_providers_session_test.dart` (test ganti akun, logout, data lama tidak bocor).
  - `test/data/athlete_providers_session_test.dart` (idem untuk atlet).
  - `test/data/cabor_providers_session_test.dart` (idem untuk cabor).
  - `test/data/pagination_race_test.dart` (simulasi request beruntun dengan delay berbeda, verifikasi response usang diabaikan).
- **Verifikasi**: `flutter test test/data/*session_test.dart test/data/pagination_race_test.dart`.

---

### Task 2: AuthSessionInterceptor for 401/403 Centralized Logout
- **File Baru**:
  - `lib/core/network/auth_session_interceptor.dart`:
    - Implementasi `Interceptor` Dio yang memeriksa response status code 401 dan 403.
    - Pada status 401: memanggil callback logout (`authController.handleUnauthorizedSession()`).
    - Pada status 403: memeriksa `error_code` JSON (`MEMBER_NOT_FOUND`, `MEMBER_INACTIVE`, `NOT_KOK` -> logout; sedangkan `NO_SUBDISTRICT` tidak mengakhiri sesi).
    - Tetap meneruskan error ke `handler.next(err)`.
- **File Modifikasi**:
  - `lib/core/network/api_client.dart`:
    - Menerima list interceptors opsional atau mendaftarkan `AuthSessionInterceptor`.
  - `lib/core/composition/app_composition.dart`:
    - Menghubungkan `AuthSessionInterceptor` saat `DataMode.remote`.
- **File Uji Baru**:
  - `test/core/network/auth_session_interceptor_test.dart`: Test unit interceptor untuk 401, 403 `NOT_KOK`, 403 `NO_SUBDISTRICT`, 200/404/500.
  - `test/integration/session_expiry_flow_test.dart`: Skenario integrasi saat token expired menghasilkan 401 -> logout otomatis ke state `AuthSignedOut`.
- **Verifikasi**: `flutter test test/core/network/auth_session_interceptor_test.dart test/integration/session_expiry_flow_test.dart`.

---

### Task 3: Bug Fixes (Sort Options, Demo Scope Fallback, Reason Code, Address Labels, SK URL)
- **File Modifikasi**:
  - `lib/features/clubs_page.dart`:
    - Perbaiki opsi modal sort agar sesuai parameter endpoint SICABOR (`name`, `code`, `since`, `status`).
  - `lib/data/services/demo/demo_club_service.dart`:
    - Hapus loop fallback pencarian antar-kecamatan pada `fetchClubDetail`. Jika ID tidak ada di scope kecamatan aktif, throw `NotFoundException`.
  - `lib/data/services/demo/demo_athlete_service.dart`:
    - Hapus loop fallback pencarian antar-kecamatan pada `fetchAthleteDetail`. Jika ID tidak ada di scope kecamatan aktif, throw `NotFoundException`.
  - `lib/features/club_detail/club_detail_page.dart`:
    - Tambahkan mapping `_mapReasonToMessage` (misal `NOT_RECORDED_IN_SYSTEM` -> `"Belum tercatat di sistem"`).
    - Perbaiki label alamat di tab Info: `subdistrictName` dilabeli `"Kecamatan"`, `districtName` dilabeli `"Kabupaten / Kota"`.
    - Tambahkan aksi buka/salin link file SK pada baris informasi berkas SK.
- **File Uji Modifikasi**:
  - `test/clubs_page_test.dart`
  - `test/data/demo_club_service_test.dart`
  - `test/data/demo_athlete_service_test.dart`
  - `test/club_detail_test.dart`
- **Verifikasi**: `flutter test test/clubs_page_test.dart test/data/demo_club_service_test.dart test/data/demo_athlete_service_test.dart test/club_detail_test.dart`.

---

### Task 4: `RemoteFeaturePlaceholder` Widget & Search/Attention/Committee Migration
- **File Baru/Modifikasi**:
  - `lib/shared/remote_feature_placeholder.dart` (atau di `lib/shared/widgets.dart`):
    - Widget `RemoteFeaturePlaceholder` yang konsisten dengan ikon, judul, dan deskripsi penjelasan.
  - `lib/features/search/global_search_page.dart`:
    - Deteksi mode: pada `DataMode.remote`, tampilkan `RemoteFeaturePlaceholder` ("Pencarian global belum tersedia di mode server. Pencarian per-entitas tersedia di halaman Cabor, Atlet, dan Klub.").
  - `lib/features/attention_page.dart`:
    - Deteksi mode: pada `DataMode.remote`, tampilkan `RemoteFeaturePlaceholder` ("Fitur pemantauan kelengkapan dokumen belum tersedia di server SICABOR.").
  - `lib/features/committee_page.dart`:
    - Deteksi mode: pada `DataMode.remote`, tampilkan `RemoteFeaturePlaceholder` ("Data susunan anggota KOK belum tersedia di server SICABOR. Hubungi admin kabupaten untuk informasi.").
- **File Uji**:
  - `test/remote_feature_placeholder_test.dart`
  - Update `test/search_page_test.dart`, `test/attention_page_test.dart`, `test/committee_page_test.dart`.
- **Verifikasi**: `flutter test test/remote_feature_placeholder_test.dart test/search_page_test.dart test/attention_page_test.dart test/committee_page_test.dart`.

---

### Task 5: Partial Migration of `ProfilePage` in Remote Mode
- **File Modifikasi**:
  - `lib/features/profile_page.dart`:
    - Pada `DataMode.remote`, jangan panggil `DataView`.
    - Tampilkan ringkasan data statistik (`totalCabor`, `totalClub`, `totalAthlete`, `dataNotes`) dari `profileSummaryProvider`.
    - Tampilkan nama kontingen jika tersedia (`summary.kontingen?.name`).
    - Ekspor rekap data kecamatan menggunakan data `profileSummaryProvider`.
    - Sembunyikan modul Helpdesk dan Sync Status Card (karena bergantung pada snapshot demo).
    - Pertahankan `DataView` pada `DataMode.demo` untuk kompatibilitas.
- **File Uji Modifikasi**:
  - `test/profile_page_test.dart`: Tambahkan test case untuk mode remote dan verifikasi mode demo.
- **Verifikasi**: `flutter test test/profile_page_test.dart`.

---

### Task 6: End-to-End Verification & Documentation Update
- **File Modifikasi**:
  - `docs/project-status.md`: Catat penyelesaian Milestone 4.1 (Hardening) dan Milestone 5 (Remote Consistency).
- **Verifikasi Penuh**:
  - `dart format lib test`
  - `flutter analyze` : 0 issues
  - `flutter test` : 100% tests passing across all suites
  - Git commit & push langsung ke `main` di `origin` dan `gitlab`.

---

## Verifikasi Kualitas & Batasan

1. **Format Code**: Menjalankan `dart format` pada setiap task agar pipeline GitLab CI/CD selalu lulus.
2. **Scoping**: Semua pagination controller me-reset state secara reaktif saat `dataRequestContextProvider` berubah.
3. **Penyimpanan Dokumen**: Semua dokumen spesifikasi disimpan di `docs/archive/specs/` dan rencana implementasi di `docs/archive/plans/`.

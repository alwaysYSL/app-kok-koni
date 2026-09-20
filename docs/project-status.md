# Status proyek

Terakhir diperbarui: 20 September 2026.

## Ringkasan

Aplikasi KOK merupakan frontend Flutter untuk Koordinator Olahraga Kecamatan (KOK) Kabupaten Garut yang terhubung ke backend SICABOR. Milestone 1 (Autentikasi & Sesi) dan Milestone 2 (Integrasi Beranda & Cabang Olahraga) telah selesai diimplementasikan dan diverifikasi secara penuh dengan test suite otomatis.

## Status Integrasi SICABOR

### Milestone 1: Autentikasi & Session Bootstrap (SELESAI)
- Integrasi login SICABOR berbasis `application/x-www-form-urlencoded` dengan validasi peran `admin_kok`.
- Sesi bearer token tunggal (masa berlaku 24 jam tanpa refresh token) dengan penyimpanan aman di `flutter_secure_storage`.
- Auto-bootstrap sesi saat aplikasi dimulai, fail-safe token expiration handling (401 auto logout, 403 handling).
- Dukungan global password override untuk fallback autentikasi demo/testing.
- Mock server standalone untuk pengujian remote tanpa ketergantungan server live.

### Milestone 2: Integrasi Beranda & Cabang Olahraga (SELESAI)
- **Domain Models & Envelopes**:
  - Domain model `ProfileSummary`, `Cabor`, dan generic `PaginatedResult<T>`.
  - Generic envelope parser `SicaborListEnvelope<T>` & data mappers dari response JSON SICABOR.
- **Service Layer**:
  - `ProfileService` & `CaborService` dengan implementasi remote (`RemoteProfileService`, `RemoteCaborService`) dan demo (`DemoProfileService`, `DemoCaborService`).
- **State Management**:
  - Provider terpisah via Riverpod: `profileSummaryProvider` (auto-refresh saat switch akun/refresh) dan `caborPaginationProvider` (dikelola oleh `CaborPaginationController` dengan search & pagination).
- **UI Beranda (`HomePage`)**:
  - Migrasi penuh ke data dinamis endpoint `/profile`.
  - Menampilkan nama scope wilayah kecamatan, ringkasan metrik statistik (`totalCabor`, `totalClub`, `totalAthlete`, `totalAthleteWithoutClub`), `dataNotes`, dan status kontingen.
  - Metrik khusus demo disembunyikan secara bersih ketika berada dalam mode remote.
- **UI Cabang Olahraga (`SportsPage`)**:
  - Migrasi ke endpoint `/cabor` dengan mekanisme infinite scrolling pagination (25 item/halaman).
  - Logo cabor dari jaringan dengan fallback inisial avatar yang elegan.
  - Tampilan induk organisasi (`groupName`), filter/search dinamis, dan navigasi detail `/sport/${cabor.id}`.

### Milestone Berikutnya (In Progress / Backlog)
- **Milestone 3: Integrasi Atlet**
  - Endpoint `/api/v1/kok/athlete` (daftar atlet terpaginasi dengan filter cabor & klub).
  - Endpoint `/api/v1/kok/athlete/detail/{id}` (profil lengkap, dokumen, prestasi atlet).
- **Milestone 4: Integrasi Klub & Kepengurusan**
  - Endpoint `/api/v1/kok/club` & `/api/v1/kok/club/detail/{id}`.
  - Endpoint `/api/v1/kok/club/official`, `/api/v1/kok/club/coach`, `/api/v1/kok/club/management`.

## Gap sebelum Play Store

- Konfigurasi signing release masih memakai debug key.
- Permission jaringan pada manifest release perlu dipastikan sebelum mode remote diuji.
- App icon, nama final, versioning, application ID, kebijakan privasi, data safety, screenshot, dan listing belum difinalkan.
- Pengujian perangkat Android nyata, staging API, keamanan token, crash reporting, serta proses rilis AAB belum dilakukan.

## Batas klaim

APK debug dan pipeline CI membuktikan source dapat dianalisis, diuji, dan dibangun pada lingkungan yang dicatat. Keduanya belum membuktikan kesiapan produksi, kompatibilitas API aktual, atau kelayakan publikasi Play Store.

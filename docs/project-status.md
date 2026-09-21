# Status proyek

Terakhir diperbarui: 21 September 2026.

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

### Milestone 3: Integrasi Data Atlet (SELESAI)
- **Domain Models & DTOs**:
  - Domain model `Athlete`, `AthleteCabor`, `AthleteClub`, `AthleteDomicile`, dan `AthleteDetail`.
  - Generic detail envelope `SicaborDetailEnvelope<T>` dan DTO `SicaborAthleteItem`, `SicaborAthleteDetailItem`.
  - Dukungan `filterWarning` pada `PaginatedResult<T>` untuk menangani batasan filter dari server SICABOR.
- **Service Layer**:
  - Interface `AthleteService` dengan implementasi remote (`RemoteAthleteService` via `ApiClient`) dan adapter demo (`DemoAthleteService`).
- **State Management**:
  - `athleteServiceProvider`, `athleteListProvider`, `AthletePaginationController` (`athletePaginationProvider` berbasis family parameter cabor), dan `athleteDetailProvider`.
- **UI Tab Atlet di `SportDetailPage`**:
  - Migrasi tab Atlet remote ke `_RemoteAthletesTab` dengan infinite scrolling pagination (25 item/halaman).
  - Search bar terintegrasi dengan debounce 500ms untuk efisiensi beban server.
  - Filter chips jenis kelamin (`Semua`, `Laki-Laki`, `Perempuan`).
  - Banner peringatan filter (`filterWarning`) interaktif saat filter melebihi kuota.
  - Kartu atlet dengan avatar/foto jaringan, badge status aktif, badge cabor, dan indikasi klub ("Belum terdaftar di klub" jika null).
- **UI Halaman Detail Atlet (`AthleteDetailPage`)**:
  - Migrasi ke `ConsumerWidget` mengonsumsi `athleteDetailProvider(athleteId)`.
  - Penanganan error 404 `NotFoundException` yang elegan via `MissingPage` ("Data atlet tidak ditemukan.").
  - Tampilan visual lengkap: data bio identitas, data fisik (tinggi, berat, golongan darah), kontak (telepon, email), dan alamat lengkap domisili desa/kecamatan.
  - Sembunyikan checklist dokumen, milestones, dan tombol kontak klub jika atlet belum memiliki klub.
- **Pengujian & Verifikasi**:
  - 595 unit & widget test passing (100% test suite pass, 0 warning/lint issue).

### Milestone 4: Integrasi Klub & Kepengurusan (SELESAI)
- **Milestone 4A: Daftar & Detail Klub (Info + Pengurus Inline)**:
  - **Domain Models & DTOs**: `Club`, `ClubCabor`, `ClubAddress`, `ClubDetail`, `ClubPersonnelBlock`, `ClubManagementBlock`, `ClubPersonnelItem` (handling nullable `id`). DTOs: `SicaborClubItem`, `SicaborClubDetailItem` dengan mapper data lengkap.
  - **Service Layer**: Interface `ClubService` dengan `RemoteClubService` (endpoint `/club`, `/club/detail/{id}`) dan `DemoClubService` adapter.
  - **State Management**: `clubServiceProvider`, `clubListProvider`, `ClubPaginationController` (`clubPaginationProvider(idCabor)`), dan `clubDetailProvider(clubId)`.
  - **UI Tab Klub di `SportDetailPage`**: `_RemoteClubsTab` dengan search debounce 500ms, filter status chip (`Semua`, `Aktif`, `Belum Aktif`), warning banner, infinite scrolling, empty & error states, dan navigasi detail `/club/:id`.
  - **UI Halaman Daftar Klub (`ClubsPage`)**: Migrasi ke remote pagination dengan modal sort (`name`, `-name`, `-total_athlete`, `status`), filter chip status, dan search terintegrasi.
  - **UI Halaman Detail Klub (`ClubDetailPage`)**: Migrasi ke layout 3-tab (`Info`, `Pengurus`, `Atlet`) dengan branding dinamis, single counter total anggota lintas kecamatan, penanganan 404 `NotFoundException`, kartu alamat sekretariat & latihan, serta blok pengurus/official/pelatih inline (`data_available: false` & `partial: true` handling).
- **Milestone 4B: Tab Atlet Klub & Scope-Extended Pagination**:
  - Perluasan `AthletePaginationController` dengan family scope `AthleteFilterScope` (`({int? idCabor, int? idClub})`).
  - Tab 3 (Tab Atlet) di `ClubDetailPage` terhubung ke endpoint `/athlete?id_club={id}`.
  - Banner peringatan `CLUB_MEMBERSHIP_SPARSE` saat keanggotaan klub bersifat lintas kecamatan.
  - Rekonsiliasi angka total anggota klub vs total atlet lokal kecamatan user.
  - Search bar debounce, filter chips jenis kelamin, dan infinite scroll.
- **Pengujian & Verifikasi**:
  - 687 unit & widget test passing (100% test suite pass, 0 warning/lint issue).

### Milestone Berikutnya (In Progress / Backlog)
- **Milestone 5: Integrasi Pelatih, Official, dan Profil Keolahragaan Lanjutan**
  - Endpoint `/api/v1/kok/club/official`, `/api/v1/kok/club/coach`, `/api/v1/kok/club/management` lanjutan.
  - Tab Pelatih/Official di `SportDetailPage` dan verifikasi berkas person.

## Gap sebelum Play Store

- Konfigurasi signing release masih memakai debug key.
- Permission jaringan pada manifest release perlu dipastikan sebelum mode remote diuji.
- App icon, nama final, versioning, application ID, kebijakan privasi, data safety, screenshot, dan listing belum difinalkan.
- Pengujian perangkat Android nyata, staging API, keamanan token, crash reporting, serta proses rilis AAB belum dilakukan.

## Batas klaim

APK debug dan pipeline CI membuktikan source dapat dianalisis, diuji, dan dibangun pada lingkungan yang dicatat. Keduanya belum membuktikan kesiapan produksi, kompatibilitas API aktual, atau kelayakan publikasi Play Store.

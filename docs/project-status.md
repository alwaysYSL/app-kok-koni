# Status proyek

Terakhir diperbarui: 25 September 2026.

## Ringkasan

Aplikasi KOK merupakan frontend Flutter untuk Koordinator Olahraga Kecamatan (KOK) Kabupaten Garut. Seluruh jalur integrasi remote untuk Autentikasi, Beranda, Cabang Olahraga, Atlet, dan Klub telah diimplementasikan dan diverifikasi secara menyeluruh. Pengujian acceptance lokal memanfaatkan *standalone mock server* dengan alur HTTP riil dan penegakan kontrak sesi 24 jam. Kesiapan produksi dan kompatibilitas server resmi menunggu ketersediaan URL HTTPS backend dan kredensial uji pada Milestone 6.

## Status Integrasi SICABOR

Label “SELESAI” pada milestone di bawah menyatakan seluruh implementasi, pengerasan arsitektur (*hardening*), dan suite pengujian lokal telah diserahkan dan lulus verifikasi 100%.

### Milestone 1: Autentikasi & Session Bootstrap (SELESAI)
- Integrasi login SICABOR berbasis `application/x-www-form-urlencoded` dengan validasi peran `admin_kok`.
- Sesi bearer token tunggal (masa berlaku 24 jam tanpa refresh token) dengan penyimpanan aman di `flutter_secure_storage`.
- Auto-bootstrap sesi saat aplikasi dimulai, fail-safe token expiration handling (401 auto logout, 403 handling).
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

### Milestone 4: Integrasi Klub & Kepengurusan (SELESAI)
- **Milestone 4A: Daftar & Detail Klub (Info + Pengurus Inline)**:
  - **Domain Models & DTOs**: `Club`, `ClubCabor`, `ClubAddress`, `ClubDetail`, `ClubPersonnelBlock`, `ClubManagementBlock`, `ClubPersonnelItem` (handling nullable `id`). DTOs: `SicaborClubItem`, `SicaborClubDetailItem` dengan mapper data lengkap.
  - **Service Layer**: Interface `ClubService` dengan `RemoteClubService` (endpoint `/club`, `/club/detail/{id}`) dan `DemoClubService` adapter.
  - **State Management**: `clubServiceProvider`, `clubListProvider`, `ClubPaginationController` (`clubPaginationProvider(idCabor)`), dan `clubDetailProvider(clubId)`.
  - **UI Tab Klub di `SportDetailPage`**: `_RemoteClubsTab` dengan search debounce 500ms, filter status chip (`Semua`, `Aktif`, `Belum Aktif`), warning banner, infinite scrolling, empty & error states, dan navigasi detail `/club/:id`.
  - **UI Halaman Daftar Klub (`ClubsPage`)**: Migrasi ke remote pagination dengan modal sort (`name`, `code`, `since`, `status`), filter chip status, dan search terintegrasi.
  - **UI Halaman Detail Klub (`ClubDetailPage`)**: Migrasi ke layout 3-tab (`Info`, `Pengurus`, `Atlet`) dengan branding dinamis, single counter total anggota lintas kecamatan, penanganan 404 `NotFoundException`, kartu alamat sekretariat & latihan, serta blok pengurus/official/pelatih inline (`data_available: false` & `partial: true` handling).
- **Milestone 4B: Tab Atlet Klub & Scope-Extended Pagination**:
  - Perluasan `AthletePaginationController` dengan family scope `AthleteFilterScope` (`({int? idCabor, int? idClub})`).
  - Tab 3 (Tab Atlet) di `ClubDetailPage` terhubung ke endpoint `/athlete?id_club={id}`.
  - Banner peringatan `CLUB_MEMBERSHIP_SPARSE` saat keanggotaan klub bersifat lintas kecamatan.
  - Rekonsiliasi angka total anggota klub vs total atlet lokal kecamatan user.
  - Search bar debounce, filter chips jenis kelamin, dan infinite scroll.

### Milestone 4.1: Hardening Integrasi & Perbaikan Bug (SELESAI)
- **Pagination Session Reset**: Ketiga pagination controller (`ClubPaginationController`, `AthletePaginationController`, `CaborPaginationController`) menonton `dataRequestContextProvider` di `build()`, otomatis me-reset state saat user switch akun atau logout.
- **Race Condition Prevention**: Counter generation (`_generation`) pada semua pagination controller memastikan response usang/lambat dari search/filter sebelumnya tidak mengorup state aktif.
- **Centralized 401/403 Session Expiry**: `AuthSessionInterceptor` pada Dio secara otomatis memicu `handleUnauthorizedSession()` saat token kedaluwarsa (401) atau terjadi error fatal otorisasi (403 `MEMBER_NOT_FOUND`, `MEMBER_INACTIVE`, `NOT_KOK`), langsung mengarahkan user ke login tanpa terdampar di error screen.
- **Perbaikan Bug Layanan & UI**:
  - Opsi sort modal `ClubsPage` disesuaikan dengan parameter backend SICABOR (`name`, `code`, `since`, `status`).
  - Isolasi scope demo: `DemoClubService` dan `DemoAthleteService` tidak lagi membocorkan data antar-kecamatan (throw `NotFoundException` jika di luar scope aktif).
  - Mapping teks reason code `NOT_RECORDED_IN_SYSTEM` ke *"Belum tercatat di sistem"* pada `ClubDetailPage`.
  - Perbaikan label hierarki alamat pada `ClubDetailPage` (`subdistrictName` -> "Kecamatan", `districtName` -> "Kabupaten / Kota").

### Milestone 5: Konsistensi Mode Remote & Audit Halaman (SELESAI)
- **Shared Placeholder Widget**: Implementasi `RemoteFeaturePlaceholder` sebagai UI fallback standar yang informatif dan konsisten untuk fitur yang belum didukung endpoint server SICABOR.
- **Pencegahan Crash Halaman Non-Remote**:
  - `GlobalSearchPage`: Menampilkan `RemoteFeaturePlaceholder` yang mengarahkan user ke pencarian per-entitas (Cabor, Atlet, Klub).
  - `AttentionPage`: Menampilkan `RemoteFeaturePlaceholder` yang menjelaskan belum adanya modul monitoring kelengkapan berkas di SICABOR.
  - `CommitteePage`: Menampilkan `RemoteFeaturePlaceholder` yang menjelaskan data anggota KOK belum tersedia di SICABOR.
- **Migrasi Parsial Halaman Profil (`ProfilePage`)**:
  - Pada `DataMode.remote`, tidak lagi memanggil `DataView`/`snapshotProvider`.
  - Mengonsumsi `profileSummaryProvider` untuk menampilkan statistik data keolahragaan (Total Cabor, Total Klub, Total Atlet, Total Atlet Belum Ada Klub), catatan data notes, dan nama kontingen.
  - Utilitas ekspor rekapitulasi data kecamatan terhubung langsung dengan `ProfileSummary`.
  - Modul Helpdesk dan Sync Status Card disembunyikan secara bersih pada mode remote.

### Milestone 5.1: Integritas Sesi & Kontrak Error (SELESAI)
- **Isolasi Revisi Sesi 401/403 (`AuthSessionTokens.revision`)**:
  - Interceptor mencatat nomor revisi sesi aktif pada setiap request options (`AuthSessionInterceptor.sessionRevisionExtraKey`).
  - Respons 401 atau 403 usang dari request sesi sebelumnya (misal akun A) yang tiba setelah user beralih akun (ke akun B) diabaikan secara aman tanpa memutus sesi aktif akun B.
- **Sentralisasi Presentasi Error (`RemoteErrorPresentation`)**:
  - Komponen terpadu `describeRemoteError` di seluruh layar remote (Beranda, Profil, Cabor, Atlet, Klub).
  - Pesan error 403 `NO_SUBDISTRICT` menyajikan pesan server spesifik beserta arahan menghubungi admin kabupaten tanpa menampilkan tombol *retry* (karena bukan kegagalan sementara jaringan).
  - Menyimpan dan menampilkan alasan *forced logout* pada layar login (`AuthSignedOut.errorMessage`).
- **Validasi Skema Profil Mendalam & Timeout Auth**:
  - Validasi Map mentah dan skema DTO `SicaborProfileResponse` pada alur login dan restore session sebelum token disimpan ke *secure storage*. Menolak data yang tidak lengkap (`member`, `scope`, `summary`, `subdistrict_id <= 0`, status non-aktif).
  - Penerusan batas waktu (*connect & receive timeout*) dari deployment profile ke instans `Dio` autentikasi (`RemoteAuthRepository`).
- **Deteksi Payload Non-JSON (`ApiConfigurationException`)**:
  - `requireJsonContentType` mendeteksi respons HTML/teks (misal *proxy error* atau salah URL) dan memetakannya ke `ApiConfigurationException` informatif tanpa *type casting crash*.
  - Status 401 tetap diprioritaskan agar pemutusan sesi kedaluwarsa berjalan konsisten.
- **Guard Error Pagination Lintas Sesi**:
  - Penanganan blok `catch` pada `loadFirstPage` dan `loadMore` di ketiga controller (`CaborPaginationController`, `AthletePaginationController`, `ClubPaginationController`) memvalidasi `dataRequestContextProvider` dan `_generation`, mencegah error tertunda dari sesi lama mengorup state sesi baru.

### Milestone 5.2: Fidelitas Mock & Ketepatan Tampilan (SELESAI)
- **Fidelitas Mock Server & Sesi 24 Jam**:
  - `MockSessionStore` mandiri per-instans server dengan penerbitan token acak kriptografis (`Random.secure()`, URL-safe base64).
  - Kedaluwarsa token tepat 24 jam dengan verifikasi clock; penolakan token acak buatan tangan (401 `INVALID_TOKEN`) dan akun non-aktif (403 `MEMBER_NOT_FOUND`).
  - Penghapusan seluruh *universal password override* dari kode sumber mock dan dokumentasi.
  - Konfigurasi default bind host `127.0.0.1` dan opsi `--host=0.0.0.0` untuk pengujian perangkat fisik.
- **Suite Pengujian Integrasi HTTP Riil & Android Cleartext**:
  - Suite pengujian `test/integration/mock_http_flow_test.dart` menguji alur autentikasi, paging >25 item, detail relasional, isolasi multi-kecamatan, dan error handling langsung terhadap server HTTP lokal.
  - Manifest Android debug dikonfigurasi dengan `android:usesCleartextTraffic="true"` untuk pengujian emulator lokal terhadap mock HTTP, sementara manifest release tetap aman tanpa celah cleartext.
- **Ketepatan Label Metrik Beranda & Cakupan Grafik Cabor**:
  - Perbaikan label metrik Beranda: `totalCaborFromClub` dilabeli "Cabor dengan klub", `totalCaborFromAthlete` dilabeli "Cabor dengan atlet", serta atribusi sumber data "Data SICABOR" tanpa timestamp tiruan.
  - Grafik Cabor menampilkan cakupan aktual cabor yang telah dimuat (`X dari Y`) tanpa klaim pemeringkatan keseluruhan.
- **Pembersihan Cache Filter & Pembatalan Debounce**:
  - State item dan total langsung dibersihkan saat filter/query baru diterapkan sebelum request loading selesai, mencegah tampilan data usang.
  - Pembatalan debounce timer (`_debounce?.cancel()`) saat input pencarian dihapus atau widget di-dispose.
- **Representasi Identitas Atlet & Eliminasi CTA Kontak**:
  - Kartu atlet remote menampilkan kode atlet (`Athlete.code`) dan badge status keaktifan (`Athlete.statusLabel`).
  - Eliminasi tombol CTA kontak fiktif pada detail atlet mode remote yang tidak memiliki data kontak, dengan tetap mempertahankan informasi identitas klub.
- **Distribusi Data Kepengurusan Klub & Pembukaan Dokumen SK**:
  - Pembedaan status `management.dataAvailable == false` ("Belum tercatat di sistem") dengan daftar pengurus kosong.
  - Penjelasan komparasi total anggota klub lintas kecamatan vs atlet lokal hasil filter kecamatan.
  - Integrasi `url_launcher` untuk membuka tautan berkas SK di peramban eksternal (`LaunchMode.externalApplication`) disertai fallback salin tautan ke clipboard.

### Polish UI berbasis kontrak SICABOR
- Beranda, Cabor, Klub, Atlet, dan Akun mode remote memakai data kecamatan dari API KOK; komponen UI dan alur HTTP mock diuji secara lokal.
- Halaman Anggota KOK tetap tersedia dengan penjelasan bahwa data resmi belum tersedia melalui kontrak API saat ini.
- Perubahan tampilan mencakup transisi header membulat, kartu direktori dan detail, serta keadaan kosong dan fallback gambar. Pemeriksaan langsung Flutter web terhadap mock lokal pada lebar 320 dan 390 dp mencakup Garut Kota dan Balubur Limbangan; 36 tangkapan layar halaman setelah login dibuat dan ditinjau. Label metrik Beranda pada 320 dp dan pesan daftar Klub tanpa data diperbaiki setelah pemeriksaan tersebut.
- Validasi terhadap server resmi tetap menunggu URL HTTPS dan kredensial uji yang aktif.

### Hasil Pengujian & Verifikasi Kualitas (25 September 2026)
- **Automated Test Suite**: `flutter test --no-pub` selesai dengan 892 lulus, 1 dilewati, 0 gagal.
- **Alur HTTP Mock**: `flutter test test/integration/mock_http_flow_test.dart` selesai dengan 9 lulus, 0 gagal.
- **Static Analysis**: `flutter analyze --no-pub` melaporkan `No issues found!`.
- **Code Formatting**: `dart format --output=none --set-exit-if-changed lib test scripts/mock_server` memeriksa 176 file, 0 berubah.
- **QA Visual Browser**: Capture Flutter web mode remote di 320/390 dp untuk kedua kecamatan meliputi Beranda, daftar/detail Cabor, daftar Klub, daftar/detail Atlet, Anggota KOK, dan Akun. Detail Klub serta fallback logo diverifikasi dengan data Garut Kota; Balubur Limbangan tidak memiliki Klub pada fixture mock. Transisi header membulat dan keadaan kosong juga diperiksa. Bukti dan path capture tercatat pada laporan Task 10.
- **Batas QA Visual**: Capture browser belum membuktikan tampilan pada perangkat Android fisik. Uji emulator pasca-login dihentikan sesuai perubahan arah QA; validasi perangkat nyata dan API resmi masih diperlukan.

---

### Milestone Berikutnya (Fase Selanjutnya)
- **Milestone 6: Validasi API Resmi & Uji Perangkat Nyata**:
  - Uji kontrak end-to-end terhadap server backend SICABOR resmi saat URL endpoint HTTPS dan kredensial uji aktif tersedia.
  - Pengujian alur remote menyeluruh pada perangkat fisik Android (jaringan rilis & koneksi HTTPS).
- **Backlog**:
  - Profil pelatih/official lanjutan dan verifikasi kelengkapan berkas menunggu ketersediaan endpoint pendukung di backend SICABOR.

## Gap sebelum Play Store

- Konfigurasi signing release masih memakai debug key.
- Permission `INTERNET` sudah ada di manifest utama; koneksi HTTPS ke server resmi dan perilaku jaringan pada build release masih perlu diuji.
- App icon, nama final, versioning, application ID, kebijakan privasi, data safety, screenshot, dan listing belum difinalkan.
- Pengujian perangkat Android nyata, staging API, keamanan token, crash reporting, serta proses rilis AAB belum dilakukan.

## Batas klaim

APK debug dan pipeline CI membuktikan source dapat dianalisis, diuji, dan dibangun pada lingkungan yang dicatat. Keduanya belum membuktikan kesiapan produksi, kompatibilitas API aktual, atau kelayakan publikasi Play Store.

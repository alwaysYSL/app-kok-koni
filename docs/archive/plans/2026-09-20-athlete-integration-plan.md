# Rencana Implementasi — Milestone 3: Integrasi Atlet SICABOR

## Ringkasan Eksekutif

Milestone 3 mengintegrasikan endpoint `/api/v1/kok/athlete` dan `/api/v1/kok/athlete/detail/{id}` dari SICABOR ke dalam aplikasi KOK Flutter. Ini mencakup tab Atlet di `SportDetailPage` (dengan infinite scrolling pagination, search debounce, filter jenis kelamin, dan filter warning) serta halaman detail atlet `AthleteDetailPage` (dengan visualisasi data fisik atlet, domisili, status keanggotaan klub, penanganan atlet tanpa klub, dan penanganan error 404).

Pekerjaan ini dilakukan langsung pada branch `main` menggunakan metodologi **Subagent-Driven Development (SDD)** dengan siklus pengujian TDD bertingkat.

---

## Prasyarat & Lingkungan

- Branch aktif: `main` (tersinkronisasi dengan GitHub `origin/main` dan GitLab `gitlab/main`).
- Milestone 1 (Auth) & Milestone 2 (Beranda + Cabor) telah selesai dan 100% verified (529 passing tests).
- Mock server `scripts/mock_server/sicabor_mock_server.dart` sudah memiliki endpoint `/athlete` dan `/athlete/detail/{id}` dengan dataset lengkap.

---

## Rincian Tugas (SDD Tasks)

### Task 1: Domain Models & PaginatedResult FilterWarning
- **File Baru**:
  - `lib/data/models/athlete.dart`: `Athlete`, `AthleteCabor`, `AthleteClub`, `AthleteDomicile`.
  - `lib/data/models/athlete_detail.dart`: `AthleteDetail`.
  - `test/data/athlete_domain_models_test.dart`.
- **File Modifikasi**:
  - `lib/data/models/paginated_result.dart`: Tambah field opsional `filterWarning` (`hasFilterWarning`, `filterWarningMessage`).
- **Verifikasi**: `flutter test test/data/athlete_domain_models_test.dart`.

### Task 2: DTOs, Generic Detail Envelope & Data Mapper
- **File Baru**:
  - `lib/data/dto/sicabor_athlete_item.dart`: `SicaborAthleteItem`.
  - `lib/data/dto/sicabor_athlete_detail_item.dart`: `SicaborAthleteDetailItem`.
  - `lib/data/dto/sicabor_detail_envelope.dart`: Generic `SicaborDetailEnvelope<T>`.
  - `test/data/sicabor_athlete_dto_test.dart`.
- **File Modifikasi**:
  - `lib/data/mapper/sicabor_data_mapper.dart`: Tambah method `mapAthlete(SicaborAthleteItem)` dan `mapAthleteDetail(SicaborAthleteDetailItem)`.
  - `test/data/sicabor_data_mapper_test.dart`.
- **Verifikasi**: `flutter test test/data/sicabor_athlete_dto_test.dart test/data/sicabor_data_mapper_test.dart`.

### Task 3: Service Interfaces & Remote Implementations
- **File Baru**:
  - `lib/data/services/athlete_service.dart`: Interface `AthleteService` (`fetchAthleteList`, `fetchAthleteDetail`).
  - `lib/data/services/remote/remote_athlete_service.dart`: Implementasi `RemoteAthleteService` dengan `ApiClient`.
  - `test/data/remote_athlete_service_test.dart`.
- **Verifikasi**: `flutter test test/data/remote_athlete_service_test.dart`.

### Task 4: Demo Service Adapter
- **File Baru**:
  - `lib/data/services/demo/demo_athlete_service.dart`: Implementasi `DemoAthleteService` yang mengadaptasi data lokal `DemoKokRepository`.
  - `test/data/demo_athlete_service_test.dart`.
- **Verifikasi**: `flutter test test/data/demo_athlete_service_test.dart`.

### Task 5: Riverpod Providers & Pagination Controller
- **File Baru**:
  - `lib/data/providers/athlete_providers.dart`:
    - `athleteServiceProvider`: Provider untuk `AthleteService` (remote/demo).
    - `athleteListProvider`: FutureProvider.family untuk fetching daftar atlet dengan filter/pagination.
    - `athletePaginationProvider`: FamilyNotifier (`AthletePaginationController`, `AthletePaginationState`) berparameter `idCabor: int?`.
    - `athleteDetailProvider`: FutureProvider.family berparameter `athleteId: int`.
  - `test/data/athlete_providers_test.dart`.
- **Verifikasi**: `flutter test test/data/athlete_providers_test.dart`.

### Task 6: AppComposition & DI Wiring
- **File Modifikasi**:
  - `lib/core/composition/app_composition.dart`: Tambah field `AthleteService athleteService` dan inisiasi di `AppComposition.fromProfile()`.
  - `test/app_environment_test.dart`.
  - `test/test_composition.dart`.
- **Verifikasi**: `flutter test test/app_environment_test.dart`.

### Task 7: UI Tab Atlet di `SportDetailPage` Migration
- **File Modifikasi**:
  - `lib/features/sport_detail/sport_detail_page.dart`:
    - Hubungkan tab Atlet (index 1) pada `DataMode.remote` ke `athletePaginationProvider(cabor.id)`.
    - Search bar dengan debounce 500ms.
    - Filter chips jenis kelamin (`Semua`, `Laki-Laki`, `Perempuan`).
    - Infinite scrolling pagination (25 item/halaman).
    - Banner peringatan filter jika `filterWarning` aktif.
    - Kartu atlet dengan foto network, fallback avatar, badge cabor, nama klub atau "Belum terdaftar di klub", dan navigasi ke `/person/${athlete.id}`.
    - Pertahankan fallback mode demo untuk pengujian offline.
  - `test/sport_detail_test.dart`.
- **Verifikasi**: `flutter test test/sport_detail_test.dart`.

### Task 8: UI `AthleteDetailPage` Migration & 404 Handling
- **File Modifikasi**:
  - `lib/features/athlete_detail/athlete_detail_page.dart`:
    - Migrasi ke `ConsumerWidget` mengonsumsi `athleteDetailProvider(int.tryParse(widget.id) ?? 0)`.
    - Render field data fisik (tinggi, berat, golongan darah), domisili desa & kecamatan, kontak (telepon, email), alamat lengkap.
    - Sembunyikan checklist dokumen, milestones, dan badge verifikasi di mode remote (karena tidak ada di API SICABOR).
    - Sembunyikan tombol "Hubungi pengurus klub" jika atlet belum memiliki klub (`club == null`).
    - Tampilan graceful error 404 `ATHLETE_NOT_FOUND` ("Atlet tidak ditemukan").
    - Pertahankan dukungan mode demo agar widget test lokal tetap berjalan lancar.
  - `test/athlete_detail_test.dart` (update/create).
- **Verifikasi**: `flutter test test/athlete_detail_test.dart`.

### Task 9: End-to-End Verification & Documentation Update
- **File Modifikasi**:
  - `docs/project-status.md`: Catat penyelesaian Milestone 3 (Integrasi Atlet) dan persiapan Milestone 4 (Klub & Kepengurusan).
- **Verifikasi Penuh**:
  - `flutter analyze` : 0 issues.
  - `flutter test` : 100% passing tests across the entire suite.
  - Git commit & push langsung ke `main` di `origin` dan `gitlab`.

---

## Verifikasi Kualitas & Batasan

1. **Format Code**: Menjalankan `dart format` pada setiap task agar pipeline GitLab CI/CD selalu lulus.
2. **Scoping**: Semua pemanggilan remote tidak mengirim parameter scope kecamatan manual, karena backend SICABOR menerapkan otorisasi scope berbasis token.
3. **Penyimpanan Dokumen**: Semua dokumen spesifikasi disimpan di `docs/archive/specs/` dan rencana implementasi di `docs/archive/plans/`.

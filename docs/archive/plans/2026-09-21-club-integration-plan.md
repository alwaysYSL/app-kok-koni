# Rencana Implementasi — Milestone 4: Integrasi Klub & Kepengurusan SICABOR

## Ringkasan Eksekutif

Milestone 4 mengintegrasikan data klub dan kepengurusan dari backend SICABOR ke dalam aplikasi KOK Flutter. Integrasi dibagi menjadi dua fase sesuai dokumen spesifikasi:
- **Milestone 4A: Daftar & Detail Klub (Info + Pengurus Inline)** — Endpoint `/api/v1/kok/club` dan `/api/v1/kok/club/detail/{id}` dengan visualisasi profil lengkap klub (alamat sekretariat, alamat latihan, SK, kontak, total anggota lintas kecamatan) dan status kepengurusan/official/pelatih inline (`data_available: false` & `partial: true`).
- **Milestone 4B: Tab Atlet Klub** — Menghubungkan Tab Atlet pada halaman detail klub ke endpoint `/api/v1/kok/athlete?id_club={id}` menggunakan `athletePaginationProvider` dengan banner peringatan `CLUB_MEMBERSHIP_SPARSE` dan rekonsiliasi angka anggota.

Pekerjaan dilakukan langsung pada branch **`main`** menggunakan metodologi **Subagent-Driven Development (SDD)** dengan siklus pengujian TDD bertingkat, menjaga 100% test pass dan 0 issue pada `flutter analyze`.

---

## Prasyarat & Lingkungan

- Branch aktif: `main` (tersinkronisasi dengan GitHub `origin/main` dan GitLab `gitlab/main`).
- Milestone 1 (Auth), Milestone 2 (Beranda + Cabor), dan Milestone 3 (Atlet) telah selesai dan 100% verified (595 passing tests).
- Mock server `scripts/mock_server/sicabor_mock_server.dart` telah mendukung endpoint `/club`, `/club/detail/{id}`, `/club/official/{id}`, `/club/coach/{id}`, `/club/management/{id}`, dan `/athlete?id_club={id}`.

---

## Rincian Tugas (SDD Tasks)

### Task 1: Domain Models for Club & ClubDetail
- **File Baru**:
  - `lib/data/models/club.dart`: `Club`, `ClubCabor`, `ClubAddress`.
  - `lib/data/models/club_detail.dart`: `ClubDetail`, `ClubPersonnelBlock`, `ClubManagementBlock`, `ClubPersonnelItem`.
  - `test/data/club_domain_models_test.dart`.
- **Deskripsi**:
  - Implementasikan immutability, `==`, `hashCode`, dan helper properties.
  - Tangani `id: null` pada `ClubPersonnelItem` (karena nama ketua dari fallback `club.head_name` tidak memiliki ID person di database).
- **Verifikasi**: `flutter test test/data/club_domain_models_test.dart`.

### Task 2: DTOs & Mapper Methods for Club
- **File Baru**:
  - `lib/data/dto/sicabor_club_item.dart`: DTO untuk item daftar `/club`.
  - `lib/data/dto/sicabor_club_detail_item.dart`: DTO untuk detail `/club/detail/{id}` beserta sub-blok inline `officials`, `coaches`, `management`.
  - `test/data/sicabor_club_dto_test.dart`.
  - `test/data/sicabor_data_mapper_club_test.dart`.
- **File Modifikasi**:
  - `lib/data/mapper/sicabor_data_mapper.dart`: Tambahkan method `mapClub()`, `mapClubDetail()`, `_mapAddress()`, `_mapPersonnelBlock()`, `_mapManagementBlock()`, dan `_mapPersonnelItem()`.
- **Verifikasi**: `flutter test test/data/sicabor_club_dto_test.dart test/data/sicabor_data_mapper_club_test.dart`.

### Task 3: Service Interfaces & Remote Implementation
- **File Baru**:
  - `lib/data/services/club_service.dart`: Interface `ClubService` (`fetchClubList`, `fetchClubDetail`).
  - `lib/data/services/remote/remote_club_service.dart`: Implementasi `RemoteClubService` menggunakan `ApiClient` dan envelope `SicaborListEnvelope<SicaborClubItem>` serta `SicaborDetailEnvelope<SicaborClubDetailItem>`.
  - `test/data/remote_club_service_test.dart`.
- **Verifikasi**: `flutter test test/data/remote_club_service_test.dart`.

### Task 4: Demo Club Service Adapter
- **File Baru**:
  - `lib/data/services/demo/demo_club_service.dart`: Implementasi `DemoClubService` yang mengadaptasi data lokal `DemoKokRepository` ke model domain `Club` dan `ClubDetail`.
  - `test/data/demo_club_service_test.dart`.
- **Verifikasi**: `flutter test test/data/demo_club_service_test.dart`.

### Task 5: Riverpod Providers & Pagination Controller for Club
- **File Baru/Modifikasi**:
  - `lib/data/providers/club_providers.dart`:
    - `clubServiceProvider`: Provider untuk `ClubService` (remote / demo adapter).
    - `clubListProvider`: FutureProvider.family untuk fetching daftar klub dengan parameter filter (`limit`, `offset`, `idCabor`, `status`, `search`, `sort`).
    - `clubPaginationProvider`: FamilyNotifier (`ClubPaginationController`, `ClubPaginationState`) berparameter `idCabor: int?`.
    - `clubDetailProvider`: FutureProvider.family berparameter `clubId: int` dengan session guard dan cancellation token.
  - `test/data/club_providers_test.dart`.
- **Verifikasi**: `flutter test test/data/club_providers_test.dart`.

### Task 6: AppComposition & DI Wiring for ClubService
- **File Modifikasi**:
  - `lib/core/composition/app_composition.dart`: Tambah field `ClubService clubService` dan inisiasi di `AppComposition.fromProfile()` (menggunakan `RemoteClubService` untuk `DataMode.remote` dan `DemoClubService` untuk `DataMode.demo`).
  - `test/app_environment_test.dart`.
  - `test/test_composition.dart`.
  - Update seluruh test composition fixture agar menyertakan `clubService`.
- **Verifikasi**: `flutter test test/app_environment_test.dart`.

### Task 7: UI Tab Klub di `SportDetailPage` Migration
- **File Modifikasi**:
  - `lib/features/sport_detail/sport_detail_page.dart`:
    - Ganti placeholder di tab index 0 (Tab Klub) pada mode remote dengan `_RemoteClubsTab` yang menonton `clubPaginationProvider(cabor?.id)`.
    - Tambahkan search bar dengan debounce 500ms, filter status chip (Semua, Aktif, Belum Aktif), infinite scroll list view, kartu klub (logo/inisial, nama, cabor, status, ketua, total anggota, lokasi sekretariat), navigasi ke `/club/${club.id}`, dan empty/error state.
  - `test/sport_detail_test.dart`.
- **Verifikasi**: `flutter test test/sport_detail_test.dart`.

### Task 8: UI `ClubsPage` Migration & Pagination
- **File Modifikasi**:
  - `lib/features/clubs_page.dart`:
    - Migrasi ke `ConsumerWidget`/`ConsumerStatefulWidget` dengan branching remote vs demo.
    - Pada mode remote: hubungkan ke `clubPaginationProvider(null)` dengan search bar debounce 500ms, filter status chip, sort modal/dropdown, infinite scrolling (25 item/halaman), kartu klub remote, dan navigasi detail `/club/${club.id}`.
    - Pertahankan fallback mode demo untuk pengujian offline.
  - `test/clubs_page_test.dart` (update / buat pengujian komprehensif).
- **Verifikasi**: `flutter test test/clubs_page_test.dart`.

### Task 9: UI `ClubDetailPage` Migration & 3-Tab Structure (Milestone 4A)
- **File Modifikasi**:
  - `lib/features/club_detail/club_detail_page.dart`:
    - Migrasi ke `ConsumerWidget` mengonsumsi `clubDetailProvider(int.tryParse(id) ?? 0)`.
    - Struktur 3 tab: Tab 1 (Info), Tab 2 (Pengurus), Tab 3 (Atlet Klub — placeholder untuk 4A).
    - Tab Info: Logo, nama, kode, badge cabor, badge status, tahun berdiri, no SK & link file SK, ketua, telepon, email, alamat sekretariat, alamat latihan (dengan catatan beda kecamatan jika ada), total anggota (`totalAthleteInClub` dengan catatan "Termasuk atlet dari kecamatan lain").
    - Tab Pengurus: Blok Kepengurusan (`management` dengan catatan `partial: true`), blok Official (`officials` dengan status `dataAvailable: false` -> "Belum tercatat di sistem"), blok Pelatih (`coaches` dengan status `dataAvailable: false` -> "Belum tercatat di sistem"). Penanganan item dengan `id: null` tanpa crash.
    - Tab Atlet Klub: Placeholder informatif "Daftar atlet klub sedang dalam tahap integrasi."
    - Header: Adaptasi stat counter (tampilkan total anggota, sembunyikan counter kosong untuk pelatih/official).
    - Penanganan 404 `NotFoundException` (`CLUB_NOT_FOUND`): Menampilkan `MissingPage(message: 'Data klub tidak ditemukan.')`.
    - Pertahankan fallback mode demo untuk backward compatibility test suite.
  - `lib/features/club_detail/club_detail_header.dart`.
  - `test/club_detail_test.dart` / `test/club_detail_widgets_test.dart`.
- **Verifikasi**: `flutter test test/club_detail_test.dart test/club_detail_widgets_test.dart`.

### Task 10: Milestone 4B — Extend `AthletePaginationController` & Implement Tab Atlet Klub
- **File Modifikasi**:
  - `lib/data/providers/athlete_providers.dart`:
    - Perluas family parameter `AthletePaginationController` dari `int? idCabor` menjadi `AthleteFilterScope` (`({int? idCabor, int? idClub})`).
    - Pastikan `loadFirstPage()` dan `loadMore()` mengirimkan `id_cabor` atau `id_club` sesuai scope.
  - `lib/features/sport_detail/sport_detail_page.dart`:
    - Update pemanggilan provider ke `athletePaginationProvider((idCabor: cabor.id, idClub: null))`.
  - `lib/features/club_detail/club_detail_page.dart`:
    - Ganti placeholder Tab 3 dengan `_RemoteClubAthletesTab` yang menonton `athletePaginationProvider((idCabor: null, idClub: club.id))`.
    - Render banner `CLUB_MEMBERSHIP_SPARSE` saat `filterWarning` ada pada state.
    - Tampilkan keterangan perbedaan angka `totalAthleteInClub` (anggota semua kecamatan) vs `meta.total` (atlet kecamatan user).
    - Tangani daftar kosong dengan banner penjelasan informatif ("Tidak ada atlet dari kecamatan ini yang tercatat di klub").
  - `test/data/athlete_providers_test.dart`.
  - `test/sport_detail_test.dart`.
  - `test/club_detail_test.dart`.
- **Verifikasi**: `flutter test test/data/athlete_providers_test.dart test/sport_detail_test.dart test/club_detail_test.dart`.

### Task 11: End-to-End Verification & Documentation Update
- **File Modifikasi**:
  - `docs/project-status.md`: Catat penyelesaian Milestone 4 (Integrasi Klub & Kepengurusan: 4A & 4B).
- **Verifikasi Penuh**:
  - `dart format lib test` (seluruh file rapi).
  - `flutter analyze` : 0 issues.
  - `flutter test` : 100% passing tests across the entire suite.
  - Git commit & push langsung ke `main` di `origin` dan `gitlab`.

---

## Verifikasi Kualitas & Batasan

1. **Format Code**: Menjalankan `dart format` pada setiap task agar pipeline GitLab CI/CD selalu lulus.
2. **Scoping**: Semua pemanggilan remote tidak mengirim parameter scope kecamatan manual, karena backend SICABOR menerapkan otorisasi scope berbasis token.
3. **Penyimpanan Dokumen**: Semua dokumen spesifikasi disimpan di `docs/archive/specs/` dan rencana implementasi di `docs/archive/plans/`.

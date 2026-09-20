# Integrasi Data Beranda + Cabor — Desain

**Milestone kedua:** Beranda menampilkan ringkasan server → Cabor menampilkan seluruh data → sesi tervalidasi saat mengambil data.

**Prasyarat selesai:** Auth SICABOR + Profile (milestone 1) ✅
**Kontrak API:** [api-kok-sicabor.md](../../api/api-kok-sicabor.md)
**Mock server:** [scripts/mock_server/](../../../scripts/mock_server/)

---

## 1. Konteks masalah

Seluruh UI aplikasi saat ini menggunakan `DataView` yang menonton satu `snapshotProvider: FutureProvider<KokSnapshot>`. Demo repository mengembalikan snapshot monolitik berisi semua klub, orang, komite, dan helpdesk. SICABOR tidak memiliki endpoint snapshot — datanya tersebar di endpoint granular (`/profile`, `/cabor`, `/club`, `/athlete`).

Migrasi langsung seluruh UI ke provider granular terlalu besar untuk satu langkah. Pendekatan yang dipilih adalah **migrasi bertahap**: Beranda dan Cabor bermigrasi duluan ke provider baru, halaman lain tetap menggunakan `DataView`/`KokSnapshot` via demo sampai gilirannya.

## 2. Keputusan desain yang sudah ditetapkan

| # | Keputusan | Pilihan |
|---|-----------|---------|
| 1 | Transisi dari KokSnapshot | Migrasi bertahap ke provider granular. Beranda + Cabor duluan. |
| 2 | Model cabor | Model domain baru `Cabor` (id, code, name, group_name, logo, status, total_club, total_athlete). Terpisah dari `Club.sport`. |
| 3 | Data dashboard | Gunakan `summary` dari `/profile` langsung. Provider `profileSummaryProvider` baru. |
| 4 | Fitur tanpa dukungan SICABOR | Sembunyikan/nonaktifkan dengan pesan jelas. Tidak tampilkan data demo di mode remote. |
| 5 | Pagination cabor | Provider mengembalikan satu halaman + meta. UI menggunakan infinite scroll. |
| 6 | Kontrak repository | `KokRepository` tetap untuk demo. Buat interface per-fitur baru (`ProfileService`, `CaborService`, dll) untuk remote. |

## 3. Arsitektur data layer baru

### 3.1 Dua jalur data: demo vs remote

```
                  ┌──────────────────────┐
                  │  AppComposition       │
                  │  (memilih jalur)      │
                  └──────────┬───────────┘
                             │
              ┌──────────────┼──────────────┐
              │                             │
     DataMode.demo                 DataMode.remote
              │                             │
   ┌──────────▼──────────┐     ┌────────────▼────────────┐
   │  DemoKokRepository   │     │  Service per-fitur:     │
   │  + DemoDataAdapter   │     │  • ProfileService       │
   │  (bridge ke provider │     │  • CaborService         │
   │   granular baru)     │     │  • ClubService (nanti)  │
   └──────────┬──────────┘     │  • AthleteService (nanti)│
              │                 └────────────┬────────────┘
              │                              │
              └──────────┬───────────────────┘
                         │
              ┌──────────▼──────────┐
              │  Provider granular   │
              │  (dipanggil UI)      │
              │  • profileSummary    │
              │  • caborList         │
              └─────────────────────┘
```

**Mengapa demo juga melalui provider granular:** Agar UI hanya punya satu jalur konsumsi data. `DemoDataAdapter` mengonversi data `DemoKokRepository` menjadi format yang sama dengan respons SICABOR (misalnya, menurunkan daftar cabor dari klub demo).

### 3.2 Model domain baru

#### `Cabor` (baru)

```dart
/// Cabang olahraga yang tersedia di kecamatan.
/// Bukan data milik kecamatan langsung — diturunkan dari klub dan atlet.
class Cabor {
  final int id;
  final String code;
  final String name;
  final String? groupName;   // Induk organisasi (FAJI, PBSI, dll)
  final String? logoUrl;
  final int status;           // 0=Belum Aktif, 1=Aktif
  final String statusLabel;
  final int totalClub;        // Dalam kecamatan ini
  final int totalAthlete;     // Dalam kecamatan ini
}
```

#### `ProfileSummary` (baru)

```dart
/// Ringkasan data kecamatan dari /profile.
/// Cukup untuk mengisi dashboard tanpa memanggil endpoint lain.
class ProfileSummary {
  final SicaborScope scope;
  final SicaborMember member;
  final SicaborKontingen? kontingen;
  final int totalCabor;
  final int totalCaborFromClub;
  final int totalCaborFromAthlete;
  final int totalClub;
  final int totalAthlete;
  final int totalAthleteWithoutClub;
  final List<String> dataNotes;
}
```

**Catatan:** `SicaborScope`, `SicaborMember`, `SicaborKontingen` sudah ada di auth DTO. Untuk domain model, kita bisa membuat class terpisah atau reuse DTO yang sudah stabil dan read-only. Pilihan pragmatis: reuse DTO yang sudah ada, karena bentuknya identik dengan domain model yang dibutuhkan.

#### `PaginatedResult<T>` (baru, generic)

```dart
/// Hasil endpoint daftar dengan informasi paging.
class PaginatedResult<T> {
  final List<T> items;
  final int limit;
  final int offset;
  final int total;

  bool get hasMore => offset + items.length < total;
  int get nextOffset => offset + items.length;
}
```

### 3.3 Service interfaces (kontrak remote)

#### `ProfileService`

```dart
abstract interface class ProfileService {
  /// Mengambil profil dan ringkasan kecamatan.
  /// Digunakan oleh dashboard dan oleh auth untuk restore sesi.
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  });
}
```

#### `CaborService`

```dart
abstract interface class CaborService {
  /// Mengambil satu halaman daftar cabor di kecamatan.
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',  // 'all' | 'club' | 'athlete'
    String sort = 'name',   // 'name' | 'code' | 'athlete' | 'club'
    RequestCancellation? cancellation,
  });
}
```

### 3.4 Implementasi remote

#### `RemoteProfileService implements ProfileService`

```dart
class RemoteProfileService implements ProfileService {
  RemoteProfileService(this._client);
  final ApiClient _client;

  @override
  Future<ProfileSummary> fetchProfileSummary({...}) async {
    final response = await _client.request('/profile', method: 'GET', ...);
    final dto = SicaborProfileResponse.fromJson(response.data);
    return SicaborDataMapper.mapProfileSummary(dto);
  }
}
```

#### `RemoteCaborService implements CaborService`

```dart
class RemoteCaborService implements CaborService {
  RemoteCaborService(this._client);
  final ApiClient _client;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({...}) async {
    final response = await _client.request(
      '/cabor',
      method: 'GET',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'source': source,
        'sort': sort,
      },
      ...
    );
    // Parse envelope "success"
    final envelope = SicaborListResponse<SicaborCaborItem>.fromJson(
      response.data,
      SicaborCaborItem.fromJson,
    );
    return PaginatedResult(
      items: envelope.data.map(SicaborDataMapper.mapCabor).toList(),
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
    );
  }
}
```

### 3.5 Implementasi demo (adapter)

#### `DemoProfileService implements ProfileService`

```dart
class DemoProfileService implements ProfileService {
  DemoProfileService(this._demoRepo);
  final DemoKokRepository _demoRepo;

  @override
  Future<ProfileSummary> fetchProfileSummary({...}) async {
    // Dapatkan scope dari konteks sesi aktif
    // Bangun ProfileSummary dari data demo
    final snapshot = await _demoRepo.fetchScope(scope);
    return ProfileSummary(
      scope: ...,
      totalCabor: snapshot.sports.length,
      totalClub: snapshot.clubs.length,
      totalAthlete: snapshot.people.where((p) => p.role == 'Atlet').length,
      // ... dll
    );
  }
}
```

#### `DemoCaborService implements CaborService`

```dart
class DemoCaborService implements CaborService {
  DemoCaborService(this._demoRepo);
  final DemoKokRepository _demoRepo;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({...}) async {
    final snapshot = await _demoRepo.fetchScope(scope);
    // Turunkan daftar cabor dari klub demo
    final sports = snapshot.clubs.map((c) => c.sport).toSet().toList()..sort();
    final caborList = sports.asMap().entries.map((e) => Cabor(
      id: e.key,
      code: 'DEMO-${e.key}',
      name: e.value,
      totalClub: snapshot.clubs.where((c) => c.sport == e.value).length,
      totalAthlete: snapshot.people.where((p) =>
        p.role == 'Atlet' && snapshot.clubs.any((c) =>
          c.id == p.clubId && c.sport == e.value)).length,
      // ... dll
    )).toList();
    // Terapkan pagination
    final page = caborList.skip(offset).take(limit).toList();
    return PaginatedResult(items: page, limit: limit, offset: offset, total: caborList.length);
  }
}
```

### 3.6 Provider granular baru

#### `profileSummaryProvider`

```dart
final profileSummaryProvider = FutureProvider<ProfileSummary>((ref) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) throw SessionRequiredException();

  final service = ref.watch(profileServiceProvider);
  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel());

  final summary = await service.fetchProfileSummary(
    cancellation: cancellationController.token,
  );

  // Validasi sesi masih aktif
  final currentContext = ref.read(dataRequestContextProvider);
  if (currentContext != context) throw RequestCancelledException();

  return summary;
});
```

#### `caborListProvider`

```dart
/// Parameter untuk memuat halaman cabor.
typedef CaborListParams = ({
  int offset,
  int limit,
  String source,
  String sort,
});

final caborListProvider = FutureProvider.family<PaginatedResult<Cabor>, CaborListParams>(
  (ref, params) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) throw SessionRequiredException();

    final service = ref.watch(caborServiceProvider);
    final cancellationController = RequestCancellationController();
    ref.onDispose(() => cancellationController.cancel());

    final result = await service.fetchCaborList(
      limit: params.limit,
      offset: params.offset,
      source: params.source,
      sort: params.sort,
      cancellation: cancellationController.token,
    );

    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != context) throw RequestCancelledException();

    return result;
  },
);
```

#### `caborPaginationController` (Notifier untuk infinite scroll)

```dart
/// Mengelola state pagination cabor: halaman yang sudah dimuat,
/// loading state, dan aksi loadMore.
class CaborPaginationController extends Notifier<CaborPaginationState> {
  static const _pageSize = 25;

  @override
  CaborPaginationState build() => CaborPaginationState.initial();

  Future<void> loadFirstPage({String source = 'all', String sort = 'name'}) async {
    state = CaborPaginationState.loading();
    try {
      final result = await ref.read(caborListProvider(
        (offset: 0, limit: _pageSize, source: source, sort: sort),
      ).future);
      state = CaborPaginationState.loaded(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        source: source,
        sort: sort,
      );
    } catch (e, s) {
      state = CaborPaginationState.error(e, s);
    }
  }

  Future<void> loadMore() async {
    if (state is! CaborPaginationLoaded || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await ref.read(caborListProvider(
        (offset: state.items.length, limit: _pageSize, source: state.source, sort: state.sort),
      ).future);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e, s) {
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }
}
```

### 3.7 DTO baru

#### `SicaborCaborItem` (untuk parsing `/cabor`)

```dart
class SicaborCaborItem {
  final int id;
  final String code;
  final String name;
  final String? groupName;   // "group_name" di JSON
  final String? logo;
  final int status;
  final String statusLabel;  // "status_label" di JSON
  final int totalClub;       // "total_club" di JSON
  final int totalAthlete;    // "total_athlete" di JSON

  factory SicaborCaborItem.fromJson(Map<String, dynamic> json) => ...;
}
```

#### `SicaborListEnvelope<T>` (generic envelope untuk endpoint daftar)

```dart
/// Amplop respons daftar SICABOR. Satu parser untuk semua endpoint.
/// Menggunakan `success` (bukan `status` seperti login).
class SicaborListEnvelope<T> {
  final bool success;
  final String message;
  final SicaborScope scope;
  final SicaborPaginationMeta meta;
  final List<T> data;

  factory SicaborListEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) => ...;
}

class SicaborPaginationMeta {
  final int limit;
  final int offset;
  final int total;
  // Field tambahan opsional per endpoint (source, derived_from, dll)
  final Map<String, dynamic>? extra;

  factory SicaborPaginationMeta.fromJson(Map<String, dynamic> json) => ...;
}
```

### 3.8 Mapper baru

#### `SicaborDataMapper`

```dart
class SicaborDataMapper {
  /// Mengubah DTO cabor menjadi domain model.
  static Cabor mapCabor(SicaborCaborItem item) => Cabor(
    id: item.id,
    code: item.code,
    name: item.name,
    groupName: item.groupName,
    logoUrl: item.logo,
    status: item.status,
    statusLabel: item.statusLabel,
    totalClub: item.totalClub,
    totalAthlete: item.totalAthlete,
  );

  /// Mengubah profil DTO menjadi ringkasan dashboard.
  static ProfileSummary mapProfileSummary(SicaborProfileResponse dto) =>
    ProfileSummary(
      scope: dto.scope,
      member: dto.data.member,
      kontingen: dto.data.kontingen,
      totalCabor: dto.data.summary.totalCabor,
      totalCaborFromClub: dto.data.summary.totalCaborFromClub,
      totalCaborFromAthlete: dto.data.summary.totalCaborFromAthlete,
      totalClub: dto.data.summary.totalClub,
      totalAthlete: dto.data.summary.totalAthlete,
      totalAthleteWithoutClub: dto.data.summary.totalAthleteWithoutClub,
      dataNotes: dto.data.dataNotes,
    );
}
```

## 4. Perubahan UI

### 4.1 `HomePage` — Beranda

**Sebelum:** `DataView(builder: (KokSnapshot data) { ... })` — menghitung semua angka dari snapshot.

**Sesudah:** Konsumsi `profileSummaryProvider` langsung.

Perubahan utama:

| Elemen UI | Sebelum (demo) | Sesudah (SICABOR) |
|---|---|---|
| Judul kecamatan | `user.scope.name` | `summary.scope.subdistrictName` |
| Total atlet | `data.people.where(role=='Atlet').length` | `summary.totalAthlete` |
| Persentase terverifikasi | Dihitung dari `people.verified` | **Disembunyikan** — SICABOR tidak punya data verifikasi |
| Total pelatih | `data.people.where(role=='Pelatih').length` | **Disembunyikan** — data pelatih belum tersedia |
| Total klub | `data.clubs.length` | `summary.totalClub` |
| Total official | `data.people.where(role=='Official').length` | **Disembunyikan** — data official belum tersedia |
| Tile "Berkas kurang" | Dihitung dari `missingDocuments` | **Disembunyikan** — tidak ada di SICABOR |
| Tile "Lisensi kedaluwarsa" | Dihitung dari `expiredLicense` | **Disembunyikan** — tidak ada di SICABOR |
| Top 3 Clubs | `data.clubs.take(3)` | **Disembunyikan sementara** — integrasi klub belum di milestone ini |
| Catatan data | Tidak ada | `summary.dataNotes` ditampilkan sebagai info cards |
| Waktu sinkronisasi | `data.loadedAt` | Waktu lokal saat `profileSummary` dimuat |
| Total cabor | Diturunkan dari klub | `summary.totalCabor` |

**Elemen baru untuk remote mode:**
- Kartu ringkasan: Total Cabor, Total Klub, Total Atlet, Atlet Tanpa Klub.
- Data notes dari server (render apa adanya).
- Info kontingen (`summary.kontingen?.name`).

**Penanganan mode:**
```dart
final isRemote = ref.watch(appCompositionProvider).profile.dataMode == DataMode.remote;
```
Jika `isRemote`, gunakan `profileSummaryProvider`. Jika demo, gunakan `snapshotProvider` seperti sekarang (atau adapter demo yang menghasilkan `ProfileSummary`).

> **Rekomendasi:** Gunakan provider yang sama (`profileSummaryProvider`) untuk kedua mode, dengan implementasi service yang berbeda (remote vs demo adapter). Ini menghindari branching di UI.

### 4.2 `SportsPage` → `CaborPage` — Daftar Cabor

**Sebelum:** `DataView(builder: (data) { ... })` — menghitung cabor dari `data.clubs.map(c => c.sport)`.

**Sesudah:** Konsumsi `caborPaginationController`.

Perubahan utama:

| Elemen UI | Sebelum (demo) | Sesudah (SICABOR) |
|---|---|---|
| Daftar cabor | Diturunkan dari nama sport klub | Dari `/cabor` endpoint |
| Jumlah per cabor | Dihitung dari people + clubs | `cabor.totalClub`, `cabor.totalAthlete` dari server |
| Distribusi horizontal | Bar chart dari athlete count | Bar chart dari `totalAthlete` |
| Total aktif | `allSports.length` | `summary.totalCabor` dari header |
| Badge peringatan | Dokumen hilang per cabor | **Disembunyikan** — tidak ada di SICABOR |
| Logo cabor | Tidak ada (ikon generik) | `cabor.logoUrl` (dengan fallback ke ikon generik jika null) |
| Induk organisasi | Tidak ada | `cabor.groupName` (FAJI, PBSI, dll) — ditampilkan sebagai subtitle |
| Pagination | Tidak ada (semua di-render) | Infinite scroll, muat 25 item per halaman |
| Navigasi detail | `/sport/${sport_name}` | `/sport/${cabor.id}` (berubah dari nama ke ID) |

**Widget tambahan:**
- Loading indicator di bawah daftar saat `loadMore` aktif.
- Empty state yang berbeda antara "belum ada cabor" vs error.
- Pull-to-refresh yang membersihkan dan memuat ulang dari halaman pertama.

### 4.3 `SportDetailPage` — Detail Cabor (perlu disesuaikan tapi bukan prioritas milestone ini)

Halaman detail cabor masih bisa menampilkan data terbatas dari model `Cabor` yang sudah dimuat (nama, totalClub, totalAthlete). Tab Atlet dan Klub membutuhkan endpoint terpisah (`/athlete?id_cabor=X`, `/club?id_cabor=X`) yang akan diintegrasikan di milestone berikutnya.

**Untuk milestone ini:** Halaman detail cabor menampilkan header + statistik dari model `Cabor`. Tab konten menampilkan "Fitur ini sedang dalam pengembangan" sampai endpoint atlet dan klub diintegrasikan.

### 4.4 Halaman lain

Semua halaman selain Beranda dan Cabor **tidak berubah** di milestone ini. Mereka tetap menggunakan `DataView`/`snapshotProvider` yang hanya berfungsi di demo mode.

## 5. Composition dan wiring

### `AppComposition` — penambahan

```dart
class AppComposition {
  // ... field yang sudah ada ...

  // Baru:
  final ProfileService profileService;
  final CaborService caborService;
}
```

Di `AppComposition.fromProfile()`:

```dart
// Profile service
final ProfileService profileService;
final CaborService caborService;

if (profile.dataMode == DataMode.demo) {
  final demoRepo = DemoKokRepository();
  profileService = DemoProfileService(demoRepo);
  caborService = DemoCaborService(demoRepo);
  kokRepository = demoRepo; // Tetap untuk halaman lain
} else {
  profileService = RemoteProfileService(apiClient!);
  caborService = RemoteCaborService(apiClient!);
  kokRepository = RemoteKokRepository(apiClient!); // Tetap stub untuk halaman lain
}
```

### Provider wiring baru

```dart
final profileServiceProvider = Provider<ProfileService>(
  (ref) => ref.watch(appCompositionProvider).profileService,
);

final caborServiceProvider = Provider<CaborService>(
  (ref) => ref.watch(appCompositionProvider).caborService,
);
```

## 6. Penanganan error dan sesi

### 6.1 Token kedaluwarsa saat mengambil data

Provider granular baru memeriksa `dataRequestContextProvider` sebelum dan sesudah request. Tapi `ApiClient` pada 401 langsung throw `UnauthorizedException` — ini harus berujung pada logout terpusat.

**Mekanisme yang sudah ada** (dari milestone auth):
- `ApiClient` throw `UnauthorizedException` pada 401.
- Interceptor/listener pada `AuthController` menangkap dan memicu logout.

**Yang perlu dipastikan:**
- Provider membedakan `UnauthorizedException` (jangan retry) dari error jaringan (boleh retry).
- UI menampilkan pesan "Sesi berakhir" sebelum redirect ke login.

### 6.2 Error 403 mid-session

| `error_code` | Di Beranda/Cabor | Tindakan |
|---|---|---|
| `NOT_KOK` | `profileSummaryProvider` gagal | Paksa logout via auth controller |
| `MEMBER_INACTIVE` | `profileSummaryProvider` gagal | Paksa logout + pesan |
| `NO_SUBDISTRICT` | `profileSummaryProvider` gagal | Tampilkan pesan + blok akses data |
| `MEMBER_NOT_FOUND` | `profileSummaryProvider` gagal | Paksa logout |

### 6.3 Gangguan jaringan

- Provider menampilkan error dengan tombol "Coba lagi".
- Token TIDAK dihapus.
- Cabor pagination: error pada `loadMore` hanya menampilkan error di bawah daftar, item yang sudah dimuat tetap terlihat.

### 6.4 Pergantian akun

- `dataRequestContextProvider` berubah saat akun berubah (user ID + scope + generation berbeda).
- Provider granular memeriksa konteks sebelum dan sesudah request.
- `caborPaginationController` di-reset saat sesi berubah (build() dipanggil ulang oleh Riverpod).
- Data kecamatan sebelumnya tidak boleh terlihat setelah pergantian akun.

## 7. Fitur yang disembunyikan di mode remote

| Fitur | Alasan | Perlakuan |
|---|---|---|
| Persentase verifikasi dokumen | SICABOR tidak punya data verifikasi | Sembunyikan kartu |
| Badge "Berkas Kurang" | Tidak ada `missingDocuments` | Sembunyikan tile |
| Badge "Lisensi Kedaluwarsa" | Data pelatih kosong | Sembunyikan tile |
| Jumlah pelatih di dashboard | Data pelatih kosong | Sembunyikan kolom |
| Jumlah official di dashboard | Data official kosong | Sembunyikan kolom |
| Top 3 Clubs di dashboard | Integrasi klub belum di milestone ini | Sembunyikan (atau tampilkan placeholder) |
| Komite KOK | Tidak ada di API | Sembunyikan atau tampilkan info statis |
| Helpdesk | Tidak ada di API | Sembunyikan atau tampilkan info statis |
| Grafik distribusi usia atlet | Perlu data atlet detail | Sementara disembunyikan |
| Pie chart dokumen | Tidak ada data verifikasi | Sembunyikan |

**Mekanisme:**
```dart
// Di widget
if (!isRemoteMode) ...[
  // Widget khusus demo
  _buildVerificationCard(data),
],
// Widget yang tampil di kedua mode
_buildSummaryCard(summary),
```

## 8. File baru dan yang berubah

### File baru

| File | Isi |
|---|---|
| `lib/data/models/cabor.dart` | Model domain `Cabor` |
| `lib/data/models/profile_summary.dart` | Model domain `ProfileSummary` |
| `lib/data/models/paginated_result.dart` | Generic `PaginatedResult<T>` |
| `lib/data/services/profile_service.dart` | Interface `ProfileService` |
| `lib/data/services/cabor_service.dart` | Interface `CaborService` |
| `lib/data/services/remote/remote_profile_service.dart` | Implementasi remote profil |
| `lib/data/services/remote/remote_cabor_service.dart` | Implementasi remote cabor |
| `lib/data/services/demo/demo_profile_service.dart` | Adapter demo profil |
| `lib/data/services/demo/demo_cabor_service.dart` | Adapter demo cabor |
| `lib/data/dto/sicabor_cabor_item.dart` | DTO parsing `/cabor` |
| `lib/data/dto/sicabor_list_envelope.dart` | Generic list envelope |
| `lib/data/mapper/sicabor_data_mapper.dart` | Mapper DTO → domain |
| `lib/data/providers/profile_providers.dart` | `profileSummaryProvider` |
| `lib/data/providers/cabor_providers.dart` | `caborListProvider`, `caborPaginationController` |
| `test/data/sicabor_cabor_item_test.dart` | Unit test DTO |
| `test/data/sicabor_data_mapper_test.dart` | Unit test mapper |
| `test/data/remote_cabor_service_test.dart` | Test service dengan mock HTTP |
| `test/data/cabor_providers_test.dart` | Test provider pagination |

### File yang berubah

| File | Perubahan |
|---|---|
| `lib/core/composition/app_composition.dart` | Tambah wiring `ProfileService`, `CaborService` |
| `lib/features/home_page.dart` | Migrasi dari `DataView` ke `profileSummaryProvider`. Sembunyikan fitur non-SICABOR. |
| `lib/features/sports_page.dart` | Migrasi dari `DataView` ke `caborPaginationController`. Infinite scroll. Logo, groupName. |
| `lib/features/sport_detail/sport_detail_page.dart` | Terima `cabor.id` bukan nama. Tampilkan data terbatas. Tab konten → placeholder. |
| `lib/app.dart` | Route `/sport/:id` menerima int ID, bukan encoded name. |
| `docs/project-status.md` | Update status: auth selesai, data beranda+cabor dalam pengembangan. |

### File yang TIDAK berubah

- Seluruh `lib/core/auth/` (sudah selesai di milestone 1).
- `lib/core/network/` (sudah disesuaikan di milestone 1).
- `lib/data/kok_repository.dart`, `lib/data/demo_kok_repository.dart` (tetap untuk demo mode dan halaman lain).
- `lib/data/remote_kok_repository.dart` (tetap stub sampai halaman lain dimigrasi).
- `lib/data/models.dart` (model lama tetap untuk demo).
- `lib/data/providers/snapshot_provider.dart` (tetap untuk halaman yang belum dimigrasi).
- Semua halaman UI kecuali Beranda, Cabor, dan detail Cabor.

## 9. Urutan implementasi

1. **Model domain + generic result** (~½ hari)
   - `Cabor`, `ProfileSummary`, `PaginatedResult<T>`.
   - Unit test.

2. **DTO + envelope + mapper** (~½ hari)
   - `SicaborCaborItem`, `SicaborListEnvelope<T>`, `SicaborPaginationMeta`.
   - `SicaborDataMapper` (cabor + profile summary).
   - Unit test.

3. **Service interfaces + remote implementasi** (~1 hari)
   - `ProfileService`, `CaborService`.
   - `RemoteProfileService`, `RemoteCaborService`.
   - Test dengan mock HTTP (mock Dio adapter).

4. **Demo adapters** (~½ hari)
   - `DemoProfileService`, `DemoCaborService`.
   - Test.

5. **Provider granular + pagination** (~1 hari)
   - `profileSummaryProvider`, `caborListProvider`, `caborPaginationController`.
   - Sesi guard, stale response check.
   - Test provider.

6. **Composition wiring** (~¼ hari)
   - Update `AppComposition` untuk service baru.
   - Test wiring.

7. **UI Beranda** (~1 hari)
   - Migrasi dari `DataView` ke `profileSummaryProvider`.
   - Sembunyikan fitur non-SICABOR di remote mode.
   - Loading, error, retry.
   - Test widget.

8. **UI Cabor** (~1 hari)
   - Migrasi dari `DataView` ke `caborPaginationController`.
   - Infinite scroll, logo, groupName, empty state.
   - Test widget.

9. **Verifikasi end-to-end** (~½ hari)
   - `flutter test` hijau.
   - `flutter analyze` bersih.
   - Manual test via mock server: login → beranda → cabor → logout → login akun lain.
   - Verifikasi data kecamatan berubah saat berganti akun.

**Total estimasi: 5–6 hari kerja.**

## 10. Kriteria selesai milestone ini

- [ ] Login via mock → Beranda menampilkan ringkasan dari `/profile` (total cabor, klub, atlet)
- [ ] `data_notes` dari server tampil di Beranda
- [ ] Cabor menampilkan seluruh data dari `/cabor` dengan infinite scroll
- [ ] Logo cabor ditampilkan (fallback jika null)
- [ ] `groupName` (induk organisasi) ditampilkan
- [ ] Fitur yang tidak ada di SICABOR tersembunyi di mode remote
- [ ] Token kedaluwarsa saat di Cabor → logout bersih
- [ ] Gangguan jaringan → error + retry, token tidak terhapus
- [ ] Login akun lain → data kecamatan berganti sepenuhnya
- [ ] Demo mode tetap berfungsi
- [ ] Semua test hijau
- [ ] `flutter analyze` bersih
- [ ] `docs/project-status.md` diperbarui

## 11. Apa yang belum termasuk milestone ini

- Daftar atlet per cabor (milestone 3, via `/athlete?id_cabor=X`).
- Daftar klub + detail (milestone 4, via `/club`, `/club/detail/{id}`).
- Official, pelatih, kepengurusan klub (endpoint ada tapi data belum terisi).
- Pencarian global (membutuhkan endpoint search masing-masing).
- Halaman perhatian/attention (bergantung data verifikasi yang tidak ada di SICABOR).
- Halaman komite (tidak ada di API SICABOR).
- Detail cabor: tab atlet dan klub (butuh endpoint terintegrasi).

## 12. Catatan teknis tambahan

### Content-Type check

Dokumen API memperingatkan: URL yang salah ketik bisa mengembalikan HTML bukan JSON. Service remote harus memeriksa `Content-Type` sebelum parsing:

```dart
if (response.headers['content-type']?.contains('application/json') != true) {
  throw ApiConfigurationException('Response bukan JSON — periksa URL endpoint');
}
```

### Parameter yang diam-diam diabaikan

SICABOR menjepit parameter di luar batas ke default tanpa error. Salah tulis nama parameter tidak akan ketahuan dari respons. Test harus memverifikasi bahwa parameter yang dikirim benar-benar terpakai (bandingkan hasil dengan dan tanpa parameter).

### `total_cabor` bukan penjumlahan

`total_cabor` dari `/profile` ≠ `total_cabor_from_club + total_cabor_from_athlete`. Satu cabor bisa muncul di keduanya. **Jangan menghitung ulang di frontend.**

# Integrasi Atlet — Desain

**Milestone ketiga:** Cabor → daftar atlet (pagination, search, filter) → detail atlet → sesi tervalidasi.

**Prasyarat selesai:**
- Auth SICABOR + Profile (milestone 1) ✅
- Beranda + Cabor (milestone 2) ✅

**Kontrak API:** [api-kok-sicabor.md](../../api/api-kok-sicabor.md) (baris 397–476)
**Mock server:** [scripts/mock_server/](../../../scripts/mock_server/) — endpoint atlet sudah didukung.

---

## 1. Konteks

`SportDetailPage` sudah menampilkan data cabor dari server, tetapi ketiga tab-nya (Klub, Atlet, Pelatih) masih berupa placeholder di mode remote. Milestone ini mengisi **tab Atlet** dan **halaman detail atlet** dengan data dari `/athlete` dan `/athlete/detail/{id}`.

Pola yang diikuti sama persis dengan milestone 2: service interface → remote/demo impl → DTO → mapper → provider → UI. Tidak ada arsitektur baru.

## 2. Keputusan desain

| # | Keputusan | Pilihan |
|---|-----------|---------|
| 1 | Model domain | Dua model terpisah: `Athlete` (daftar) dan `AthleteDetail` (detail). |
| 2 | Route | Pertahankan `/person/:id`. Provider melakukan `int.parse(id)`. |
| 3 | Pagination + filter | `AthletePaginationController` via `NotifierProvider.family<..., int?>` (parameter = `idCabor`). Filter search/sex/status dikelola internal. |
| 4 | Fitur demo-only | Sembunyikan: document checklist, milestones, verification badge. Tampilkan field baru: blood_type, height, weight. |
| 5 | Club null | Tampilkan "Belum terdaftar di klub" di kartu. Sembunyikan "Hubungi pengurus klub" di detail jika club null. |
| 6 | Filter warning | Tampilkan banner penjelasan dari `filter_warning.message` di atas daftar saat filter `id_club` aktif. |

## 3. Model domain baru

### `Athlete` (untuk daftar)

```dart
@immutable
final class Athlete {
  final int id;
  final String code;          // "KGAT-002281"
  final String name;
  final String sex;            // "l" | "p"
  final String sexLabel;       // "Laki-Laki" | "Perempuan"
  final String? pob;           // Tempat lahir
  final String? dob;           // "2005-08-03"
  final int? age;
  final String photoUrl;       // Selalu ada (avatar default dari server)
  final int status;
  final String statusLabel;    // "Aktif", "Belum Aktif", dll
  final AthleteCabor cabor;
  final AthleteClub? club;     // Sering null
  final AthleteDomicile domicile;
}

@immutable
final class AthleteCabor {
  final int id;
  final String code;
  final String name;
}

@immutable
final class AthleteClub {
  final int id;
  final String code;
  final String name;
}

@immutable
final class AthleteDomicile {
  final int subdistrictId;
  final String subdistrictName;
  final int districtId;
  final String districtName;
  final String? village;
}
```

### `AthleteDetail` (untuk halaman detail)

```dart
@immutable
final class AthleteDetail {
  // Semua field dari Athlete, plus:
  final int id;
  final String code;
  final String name;
  final String sex;
  final String sexLabel;
  final String? pob;
  final String? dob;
  final int? age;
  final String photoUrl;
  final int status;
  final String statusLabel;
  final AthleteCabor cabor;
  final AthleteClub? club;
  final AthleteDomicile domicile;

  // Field tambahan dari detail:
  final String? phone;
  final String? email;
  final int? height;         // cm
  final int? weight;         // kg
  final String? bloodType;
  final String? address;
}
```

## 4. DTO baru

### `SicaborAthleteItem`

```dart
@immutable
final class SicaborAthleteItem {
  final int id;
  final String code;
  final String name;
  final String sex;
  final String sexLabel;       // "sex_label"
  final String? pob;
  final String? dob;
  final int? age;
  final String photo;          // Selalu ada
  final int status;
  final String statusLabel;    // "status_label"
  final Map<String, dynamic> cabor;   // {id, code, name}
  final Map<String, dynamic>? club;   // null atau {id, code, name}
  final Map<String, dynamic> domicile;

  factory SicaborAthleteItem.fromJson(Map<String, dynamic> json) => ...;
}
```

### `SicaborAthleteDetailItem`

```dart
@immutable
final class SicaborAthleteDetailItem {
  // Semua field SicaborAthleteItem, plus:
  final String? phone;
  final String? email;
  final int? height;
  final int? weight;
  final String? bloodType;    // "blood_type"
  final String? address;

  factory SicaborAthleteDetailItem.fromJson(Map<String, dynamic> json) => ...;
}
```

**Catatan:** Detail atlet menggunakan envelope `success` dengan `data` berupa object (bukan array). Bisa diparse dengan `SicaborListEnvelope` yang sudah ada? **Tidak** — `data` di detail adalah object, bukan list. Perlu envelope terpisah atau generic detail envelope:

### `SicaborDetailEnvelope<T>` (generic, reusable untuk club detail nanti)

```dart
@immutable
final class SicaborDetailEnvelope<T> {
  final bool success;
  final String message;
  final SicaborScope scope;
  final T data;

  factory SicaborDetailEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) => ...;
}
```

## 5. Mapper tambahan di `SicaborDataMapper`

```dart
class SicaborDataMapper {
  // ... method yang sudah ada (mapCabor, mapProfileSummary) ...

  Athlete mapAthlete(SicaborAthleteItem item) => Athlete(
    id: item.id,
    code: item.code,
    name: item.name,
    sex: item.sex,
    sexLabel: item.sexLabel,
    pob: item.pob,
    dob: item.dob,
    age: item.age,
    photoUrl: item.photo,
    status: item.status,
    statusLabel: item.statusLabel,
    cabor: AthleteCabor(
      id: _asInt(item.cabor['id']),
      code: item.cabor['code'] as String,
      name: item.cabor['name'] as String,
    ),
    club: item.club == null ? null : AthleteClub(
      id: _asInt(item.club!['id']),
      code: item.club!['code'] as String,
      name: item.club!['name'] as String,
    ),
    domicile: _mapDomicile(item.domicile),
  );

  AthleteDetail mapAthleteDetail(SicaborAthleteDetailItem item) => AthleteDetail(
    // ... semua field Athlete ...
    phone: item.phone,
    email: item.email,
    height: item.height,
    weight: item.weight,
    bloodType: item.bloodType,
    address: item.address,
  );
}
```

## 6. Service interface dan implementasi

### `AthleteService`

```dart
abstract interface class AthleteService {
  Future<PaginatedResult<Athlete>> fetchAthleteList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? idClub,
    String? sex,
    int? status,
    String? search,
    String sort = 'name',
    RequestCancellation? cancellation,
  });

  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  });
}
```

### `RemoteAthleteService`

```dart
final class RemoteAthleteService implements AthleteService {
  RemoteAthleteService({required this.client, this.mapper = const SicaborDataMapper()});
  final ApiClient client;
  final SicaborDataMapper mapper;

  @override
  Future<PaginatedResult<Athlete>> fetchAthleteList({...}) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort': sort,
    };
    if (idCabor != null) queryParams['id_cabor'] = idCabor;
    if (idClub != null) queryParams['id_club'] = idClub;
    if (sex != null) queryParams['sex'] = sex;
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await client.request<dynamic>(
      '/athlete',
      method: 'GET',
      queryParameters: queryParams,
      cancellation: cancellation,
    );
    final envelope = SicaborListEnvelope<SicaborAthleteItem>.fromJson(
      response.data as Map<String, dynamic>,
      SicaborAthleteItem.fromJson,
    );

    // Simpan filter_warning dari meta.extra jika ada
    return PaginatedResult(
      items: envelope.data.map(mapper.mapAthlete).toList(),
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
      filterWarning: envelope.meta.extra['filter_warning'] as Map<String, dynamic>?,
    );
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(int id, {...}) async {
    final response = await client.request<dynamic>(
      '/athlete/detail/$id',
      method: 'GET',
      cancellation: cancellation,
    );
    final envelope = SicaborDetailEnvelope<SicaborAthleteDetailItem>.fromJson(
      response.data as Map<String, dynamic>,
      SicaborAthleteDetailItem.fromJson,
    );
    return mapper.mapAthleteDetail(envelope.data);
  }
}
```

### `DemoAthleteService`

```dart
final class DemoAthleteService implements AthleteService {
  DemoAthleteService({required this.demoRepo, required this.currentScopeProvider});
  final DemoKokRepository demoRepo;
  final AccessScope Function() currentScopeProvider;

  @override
  Future<PaginatedResult<Athlete>> fetchAthleteList({...}) async {
    final snapshot = await demoRepo.fetchScope(currentScopeProvider(), cancellation: cancellation);
    var athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();

    // Filter
    if (idCabor != null) { /* filter by cabor — via matching club sport */ }
    if (search != null) { /* filter by name */ }
    if (sex != null) { /* filter by gender */ }

    // Sort
    athletes.sort((a, b) => a.name.compareTo(b.name));

    // Map ke domain Athlete
    final mapped = athletes.map(_mapDemoPersonToAthlete).toList();

    // Pagination
    final page = mapped.skip(offset).take(limit).toList();
    return PaginatedResult(items: page, limit: limit, offset: offset, total: mapped.length);
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(int id, {...}) async {
    final person = await demoRepo.fetchPersonDetail(id.toString(), cancellation: cancellation);
    return _mapDemoPersonToAthleteDetail(person);
  }
}
```

## 7. `PaginatedResult` — tambahan field

`PaginatedResult<T>` perlu mendukung `filter_warning` dari meta:

```dart
@immutable
final class PaginatedResult<T> {
  final List<T> items;
  final int limit;
  final int offset;
  final int total;
  final Map<String, dynamic>? filterWarning;  // Baru

  bool get hasMore => offset + items.length < total;
  int get nextOffset => offset + items.length;

  bool get hasFilterWarning => filterWarning != null;
  String? get filterWarningMessage =>
    filterWarning?['message'] as String?;
}
```

## 8. Provider

### `athleteServiceProvider`

```dart
final athleteServiceProvider = Provider<AthleteService>((ref) {
  final composition = ref.watch(appCompositionProvider);
  if (composition.profile.dataMode == DataMode.demo) {
    final context = ref.watch(dataRequestContextProvider);
    return DemoAthleteService(
      demoRepo: composition.kokRepository as DemoKokRepository,
      currentScopeProvider: () => context!.scope,
    );
  }
  return composition.athleteService as RemoteAthleteService;
});
```

### `athleteListProvider`

```dart
typedef AthleteListParams = ({
  int offset,
  int limit,
  int? idCabor,
  int? idClub,
  String? sex,
  int? status,
  String? search,
  String sort,
});

final athleteListProvider = FutureProvider.family<PaginatedResult<Athlete>, AthleteListParams>(
  (ref, params) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) throw RequestCancelledException('Sesi tidak aktif.');

    final service = ref.watch(athleteServiceProvider);
    final cc = RequestCancellationController();
    ref.onDispose(() => cc.cancel('Provider disposed'));

    final result = await service.fetchAthleteList(
      limit: params.limit,
      offset: params.offset,
      idCabor: params.idCabor,
      idClub: params.idClub,
      sex: params.sex,
      status: params.status,
      search: params.search,
      sort: params.sort,
      cancellation: cc.token,
    );

    if (!ref.mounted) throw RequestCancelledException();
    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != context) throw RequestCancelledException();

    return result;
  },
  retry: (_, __) => null,
);
```

### `AthletePaginationController`

```dart
/// Parameter family = idCabor (null untuk daftar umum)
class AthletePaginationController
    extends FamilyNotifier<AthletePaginationState, int?> {

  static const int pageSize = 25;

  @override
  AthletePaginationState build(int? arg) => AthletePaginationState.initial();

  int? get idCabor => arg;

  // Filter state internal
  String? _search;
  String? _sex;
  int? _status;
  String _sort = 'name';

  Future<void> loadFirstPage() async {
    state = AthletePaginationState.loading();
    try {
      final result = await ref.read(athleteListProvider((
        offset: 0,
        limit: pageSize,
        idCabor: idCabor,
        idClub: null,
        sex: _sex,
        status: _status,
        search: _search,
        sort: _sort,
      )).future);
      state = AthletePaginationState.loaded(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        filterWarning: result.filterWarning,
      );
    } catch (e, s) {
      state = AthletePaginationState.error(e, s);
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await ref.read(athleteListProvider((
        offset: state.items.length,
        limit: pageSize,
        idCabor: idCabor,
        idClub: null,
        sex: _sex,
        status: _status,
        search: _search,
        sort: _sort,
      )).future);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e, s) {
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  void updateSearch(String? query) {
    _search = query;
    loadFirstPage();
  }

  void updateSexFilter(String? sex) {
    _sex = sex;
    loadFirstPage();
  }

  void updateSort(String sort) {
    _sort = sort;
    loadFirstPage();
  }

  Future<void> refresh() async {
    await loadFirstPage();
  }
}

final athletePaginationProvider = NotifierProvider.family<
    AthletePaginationController, AthletePaginationState, int?>(
  AthletePaginationController.new,
);
```

### `athleteDetailProvider`

```dart
final athleteDetailProvider = FutureProvider.family<AthleteDetail, int>(
  (ref, athleteId) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) throw RequestCancelledException('Sesi tidak aktif.');

    final service = ref.watch(athleteServiceProvider);
    final cc = RequestCancellationController();
    ref.onDispose(() => cc.cancel('Provider disposed'));

    final detail = await service.fetchAthleteDetail(
      athleteId,
      cancellation: cc.token,
    );

    if (!ref.mounted) throw RequestCancelledException();
    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != context) throw RequestCancelledException();

    return detail;
  },
  retry: (_, __) => null,
);
```

## 9. Perubahan UI

### 9.1 `SportDetailPage` — Tab Atlet (mode remote)

**Sebelum:** `_buildIntegrationPlaceholder()` di tab index 1.

**Sesudah:** Tab Atlet dihubungkan ke `athletePaginationProvider(cabor.id)`.

Komponen:
- **Search bar** di atas daftar — memanggil `controller.updateSearch(query)` dengan debounce 500ms.
- **Filter chips:**
  - Jenis kelamin: `Semua` | `Laki-Laki` | `Perempuan` → `controller.updateSexFilter('l'|'p'|null)`.
  - (Filter status dan sort bisa ditambahkan kemudian via dropdown.)
- **Daftar atlet** — `ListView.builder` dengan scroll listener untuk infinite scroll.
- **Kartu atlet:**
  - Foto (network image, `photoUrl` selalu ada).
  - Nama, kode.
  - Cabor badge (dari `athlete.cabor.name`).
  - Klub: `athlete.club?.name ?? "Belum terdaftar di klub"`.
  - Status badge (`statusLabel`).
  - Tap → `context.push('/person/${athlete.id}')`.
- **Filter warning banner:** Saat `state.filterWarning != null`, tampilkan `MaterialBanner` di atas daftar dengan `filterWarningMessage`.
- **Empty state:** "Tidak ada atlet ditemukan" jika daftar kosong setelah filter.
- **Loading:** Shimmer atau `CircularProgressIndicator` saat `state.isLoading`.
- **Load more:** Spinner di bawah daftar saat `state.isLoadingMore`.
- **Error:** Pesan + "Coba lagi" saat `state.error != null`.

### 9.2 `AthleteDetailPage` — migrasi dari DataView

**Sebelum:** `StatelessWidget` dengan `DataView(builder: (data) { ... })`, mencari atlet di `data.people`.

**Sesudah:** `ConsumerWidget` menonton `athleteDetailProvider(int.parse(id))`.

**State handling:**
```dart
ref.watch(athleteDetailProvider(int.parse(widget.id))).when(
  data: (detail) => _buildContent(detail),
  loading: () => _buildLoadingSkeleton(),
  error: (e, _) => e is NotFoundException
    ? _buildNotFoundPage()     // 404 ATHLETE_NOT_FOUND
    : _buildErrorPage(e),
);
```

**Perubahan konten (mode remote):**

| Section | Sebelum (demo) | Sesudah (SICABOR) |
|---|---|---|
| Header + gradient | ClubBrandPalette dari klub | Warna default atau dari cabor |
| Avatar | `photoUrl` atau inisial | `detail.photoUrl` (selalu ada dari server) |
| Nama + kode | `person.name`, `person.id` | `detail.name`, `detail.code` |
| Badge verifikasi | ✅ Terverifikasi / ⚠ Belum | **Disembunyikan** |
| Klub | `club.name` (selalu ada) | `detail.club?.name` atau "Belum terdaftar di klub" |
| Cabor + group | Dari klub | `detail.cabor.name` |
| TTL + Usia | `birthPlace`, `birthDate`, `age` | `detail.pob`, `detail.dob`, `detail.age` |
| Jenis kelamin | `person.gender` | `detail.sexLabel` |
| Domisili | Tidak ada | `detail.domicile.village`, `detail.domicile.subdistrictName` |
| Telepon, email | Tidak ada di daftar; ada di detail | `detail.phone`, `detail.email` |
| Tinggi, berat, goldar | Tidak ada | `detail.height`, `detail.weight`, `detail.bloodType` (field baru) |
| Alamat | `person.address` | `detail.address` |
| Document checklist | KTP, KK, Akta, Surat sehat + progress | **Disembunyikan** |
| Timeline riwayat | Milestones | **Disembunyikan** |
| Bottom bar "Hubungi pengurus" | Selalu tampil | **Disembunyikan jika `club == null`** |

### 9.3 Halaman lain — tidak berubah

Tab Klub dan Pelatih di `SportDetailPage` tetap placeholder. Halaman klub, komite, helpdesk, search tetap demo. Ini milestone 4+.

## 10. Penanganan error dan sesi

### 10.1 Error spesifik atlet

| Kondisi | HTTP | `error_code` | Tindakan |
|---|---|---|---|
| Atlet tidak ditemukan (atau bukan kecamatan user) | 404 | `ATHLETE_NOT_FOUND` | Tampilkan "Atlet tidak ditemukan". **Bukan** "Anda tidak punya akses" |
| Token kedaluwarsa | 401 | `INVALID_TOKEN` | Logout terpusat (sudah ditangani global) |
| Akun dinonaktifkan | 403 | `MEMBER_INACTIVE` | Logout + pesan |
| Bukan akun KOK | 403 | `NOT_KOK` | Logout |
| Timeout / offline | — | — | Tampilkan error + "Coba lagi". Token tetap. |

### 10.2 Pergantian akun

- `AthletePaginationController.build()` dipanggil ulang saat sesi berubah (Riverpod rebuild).
- `athleteDetailProvider` di-invalidate karena `dataRequestContextProvider` berubah.
- Data kecamatan lama tidak boleh tersisa — dibuktikan di test.

### 10.3 Search debounce

Pencarian atlet menggunakan debounce 500ms untuk menghindari request berlebihan. API tidak memiliki rate limit, tapi dokumen memperingatkan untuk tidak memanggil pada setiap ketikan.

## 11. File baru dan yang berubah

### File baru

| File | Isi |
|---|---|
| `lib/data/models/athlete.dart` | `Athlete`, `AthleteCabor`, `AthleteClub`, `AthleteDomicile` |
| `lib/data/models/athlete_detail.dart` | `AthleteDetail` |
| `lib/data/dto/sicabor_athlete_item.dart` | DTO daftar atlet |
| `lib/data/dto/sicabor_athlete_detail_item.dart` | DTO detail atlet |
| `lib/data/dto/sicabor_detail_envelope.dart` | Generic detail envelope (reusable) |
| `lib/data/services/athlete_service.dart` | Interface `AthleteService` |
| `lib/data/services/remote/remote_athlete_service.dart` | Implementasi remote |
| `lib/data/services/demo/demo_athlete_service.dart` | Adapter demo |
| `lib/data/providers/athlete_providers.dart` | Provider, pagination controller, state |
| `test/data/sicabor_athlete_item_test.dart` | Unit test DTO |
| `test/data/sicabor_athlete_detail_test.dart` | Unit test DTO detail |
| `test/data/sicabor_detail_envelope_test.dart` | Unit test generic envelope |
| `test/data/remote_athlete_service_test.dart` | Test service mock HTTP |
| `test/data/athlete_providers_test.dart` | Test provider + pagination |

### File yang berubah

| File | Perubahan |
|---|---|
| `lib/data/models/paginated_result.dart` | Tambah field `filterWarning` |
| `lib/data/mapper/sicabor_data_mapper.dart` | Tambah `mapAthlete()`, `mapAthleteDetail()` |
| `lib/core/composition/app_composition.dart` | Tambah `AthleteService athleteService` + wiring |
| `lib/features/sport_detail/sport_detail_page.dart` | Tab Atlet: ganti placeholder → daftar atlet real |
| `lib/features/athlete_detail/athlete_detail_page.dart` | Migrasi dari DataView ke ConsumerWidget + athleteDetailProvider. Sembunyikan fitur non-SICABOR. Tampilkan field baru. |
| `test/test_composition.dart` | Tambah `athleteService` ke `buildTestAppComposition` |
| `docs/project-status.md` | Update status milestone 3 |

### File yang TIDAK berubah

- Seluruh `lib/core/auth/` dan `lib/core/network/`.
- `lib/data/services/cabor_service.dart`, `profile_service.dart` dan implementasinya.
- `lib/data/providers/cabor_providers.dart`, `profile_providers.dart`.
- `lib/features/home_page.dart`, `sports_page.dart`.
- Semua halaman lain (clubs, committee, search, attention, profile).

## 12. Urutan implementasi

1. **Model domain** (~¼ hari)
   - `Athlete`, `AthleteDetail`, sub-class (AthleteCabor, AthleteClub, AthleteDomicile).
   - Unit test equality/construction.

2. **DTO + detail envelope** (~½ hari)
   - `SicaborAthleteItem`, `SicaborAthleteDetailItem`, `SicaborDetailEnvelope<T>`.
   - Unit test parsing JSON (termasuk club null, village casing aneh).

3. **`PaginatedResult` + mapper** (~¼ hari)
   - Tambah `filterWarning` ke `PaginatedResult`.
   - Tambah `mapAthlete()`, `mapAthleteDetail()` ke `SicaborDataMapper`.
   - Unit test mapper.

4. **Service interface + remote impl** (~½ hari)
   - `AthleteService`, `RemoteAthleteService`.
   - Test dengan mock HTTP (mock Dio adapter).

5. **Demo adapter** (~½ hari)
   - `DemoAthleteService`.
   - Test.

6. **Provider + pagination controller** (~1 hari)
   - `athleteServiceProvider`, `athleteListProvider`, `athletePaginationProvider`, `athleteDetailProvider`.
   - `AthletePaginationState`, `AthletePaginationController`.
   - Test: pagination, filter update, session guard, stale response.

7. **Composition wiring** (~¼ hari)
   - Update `AppComposition` + test composition.

8. **UI tab Atlet di SportDetailPage** (~1 hari)
   - Ganti placeholder → daftar atlet.
   - Search + debounce, filter chips, infinite scroll, filter warning banner.
   - Kartu atlet: foto, nama, kode, cabor, klub/null, status.
   - Test widget.

9. **UI AthleteDetailPage** (~1 hari)
   - Migrasi dari DataView ke ConsumerWidget.
   - Handle loading, error, 404.
   - Sembunyikan fitur non-SICABOR (dokumen, milestones, verifikasi).
   - Tampilkan field baru (tinggi, berat, goldar, domisili).
   - Sembunyikan "Hubungi pengurus" jika club null.
   - Test widget.

10. **Verifikasi end-to-end** (~½ hari)
    - `flutter test` hijau.
    - `flutter analyze` bersih.
    - Manual test via mock: login → Cabor → pilih Cabor → atlet list → search → detail → ganti akun → data berubah.

**Total estimasi: 5–6 hari kerja.**

## 13. Kriteria selesai

- [ ] Tab Atlet di detail Cabor menampilkan daftar atlet dari server
- [ ] Pagination (infinite scroll) berfungsi
- [ ] Pencarian atlet berfungsi dengan debounce
- [ ] Filter jenis kelamin berfungsi
- [ ] Kartu atlet menampilkan "Belum terdaftar di klub" jika club null
- [ ] Filter warning banner tampil saat `id_club` dipakai
- [ ] Detail atlet menampilkan data dari `/athlete/detail/{id}`
- [ ] Detail atlet menampilkan field baru (tinggi, berat, goldar, domisili)
- [ ] Fitur demo-only tersembunyi di mode remote (dokumen, milestones, verifikasi)
- [ ] "Hubungi pengurus klub" tersembunyi jika club null
- [ ] 404 ATHLETE_NOT_FOUND → tampilan "Atlet tidak ditemukan"
- [ ] 401 saat di halaman atlet → logout bersih
- [ ] Ganti akun → data kecamatan lama hilang
- [ ] Demo mode tetap berfungsi
- [ ] Semua test hijau
- [ ] `flutter analyze` bersih

## 14. Apa yang BELUM termasuk

- Daftar atlet umum (bukan per cabor) — butuh halaman baru.
- Filter `id_club` dari halaman klub (milestone 4).
- Filter `status` (belum prioritas — hampir semua atlet status 1).
- Tab Klub dan Pelatih di `SportDetailPage` (milestone 4+).
- Navigasi atlet → detail klub (butuh integrasi klub dulu).
- Daftar klub + detail (milestone 4).

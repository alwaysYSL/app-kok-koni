# Integrasi Klub — Desain

**Milestone 4A:** Daftar klub + detail (Info + Pengurus dari inline)
**Milestone 4B:** Tab Atlet Klub (via `/athlete?id_club=...`)

**Prasyarat selesai:**
- Auth SICABOR + Profile (milestone 1) ✅
- Beranda + Cabor (milestone 2) ✅
- Atlet (milestone 3) ✅

**Kontrak API:** [api-kok-sicabor.md](../../api/api-kok-sicabor.md) (baris 250–393)
**Mock server:** Endpoint klub sudah didukung penuh.

---

## 1. Konteks

Tab Klub di `SportDetailPage` masih placeholder di mode remote. Halaman `/clubs` dan `/club/:id` masih sepenuhnya dari demo `DataView`. SICABOR menyediakan `/club`, `/club/detail/{id}`, dan sub-endpoint official/coach/management — tetapi official dan coach masih kosong (`data_available: false`).

Pola yang diikuti sama dengan milestone 2+3: service → DTO → mapper → provider → UI.

## 2. Keputusan desain

| # | Keputusan | Pilihan |
|---|-----------|---------|
| 1 | Model domain | Dua model: `Club` (daftar) dan `ClubDetail` (detail + sub-entitas inline). |
| 2 | Sub-entitas | Dari blok inline `/club/detail/{id}`. Endpoint terpisah hanya jika perlu nanti. |
| 3 | Tab detail (remote) | 3 tab: Info, Pengurus, Atlet Klub. Hapus tab Dokumen terpisah (hanya `file_sk`). |
| 4 | `total_athlete_in_club` | Tampilkan dengan keterangan "Termasuk atlet dari kecamatan lain". |
| 5 | Batas 4A vs 4B | 4A = list + detail + Tab Info + Tab Pengurus. 4B = Tab Atlet Klub (`/athlete?id_club=...`). |
| 6 | Tab Pelatih di Cabor | Tidak diisi — pelatih per-cabor butuh N request. Pelatih hanya di detail klub. |

## 3. Pembagian milestone

### Milestone 4A — Daftar dan detail klub

**Scope:**
- Model `Club`, `ClubDetail`, sub-model (ClubCabor, ClubAddress, ClubPersonnel)
- DTO `SicaborClubItem`, `SicaborClubDetailItem`
- `ClubService` interface, `RemoteClubService`, `DemoClubService`
- Provider: `clubPaginationProvider`, `clubDetailProvider`
- UI: `ClubsPage` (migrasi ke provider), `SportDetailPage` Tab Klub, `ClubDetailPage` (migrasi + Tab Info + Tab Pengurus)

### Milestone 4B — Tab Atlet Klub

**Scope:**
- Tab Atlet di `ClubDetailPage` menggunakan `athletePaginationProvider` dengan parameter `idClub`
- `filter_warning` banner (`CLUB_MEMBERSHIP_SPARSE`)
- Penjelasan perbedaan angka `total_athlete_in_club` vs daftar yang ditampilkan

---

# MILESTONE 4A — DAFTAR DAN DETAIL KLUB

## 4. Model domain baru

### `Club` (untuk daftar)

```dart
@immutable
final class Club {
  final int id;
  final String code;            // "KGCL-0029"
  final String name;
  final String? logoUrl;
  final ClubCabor cabor;
  final String? headName;       // Ketua klub
  final String? phone;
  final String? email;
  final String? since;          // "2022" (tahun berdiri, string)
  final String? noSk;           // Nomor SK
  final int status;
  final String statusLabel;
  final ClubAddress secretariat;
  final int totalAthleteInClub; // Lintas kecamatan!
}

@immutable
final class ClubCabor {
  final int id;
  final String code;
  final String name;
}

@immutable
final class ClubAddress {
  final String? address;
  final int subdistrictId;
  final String subdistrictName;
  final int districtId;
  final String districtName;
}
```

### `ClubDetail` (untuk halaman detail)

```dart
@immutable
final class ClubDetail {
  // Semua field dari Club:
  final int id;
  final String code;
  final String name;
  final String? logoUrl;
  final ClubCabor cabor;
  final String? headName;
  final String? phone;
  final String? email;
  final String? since;
  final String? noSk;
  final int status;
  final String statusLabel;
  final ClubAddress secretariat;
  final int totalAthleteInClub;

  // Field tambahan dari detail:
  final ClubAddress? training;     // Bisa beda kecamatan dari secretariat
  final String? fileSkUrl;         // URL berkas SK (null jika belum diunggah)

  // Sub-entitas inline dari respons detail:
  final ClubPersonnelBlock officials;
  final ClubPersonnelBlock coaches;
  final ClubManagementBlock management;
}

/// Blok official atau coach — saat ini selalu kosong.
@immutable
final class ClubPersonnelBlock {
  final bool dataAvailable;
  final String? reason;            // "NOT_RECORDED_IN_SYSTEM"
  final List<ClubPersonnelItem> items;
}

@immutable
final class ClubPersonnelItem {
  final int? id;                   // Bisa null
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String? source;            // "club.head_name" dsb
}

/// Blok kepengurusan — saat ini hanya 1 orang (ketua).
@immutable
final class ClubManagementBlock {
  final bool dataAvailable;
  final bool partial;              // true = data belum lengkap
  final String? source;            // "club.head_name"
  final List<ClubPersonnelItem> items;
}
```

## 5. DTO baru

### `SicaborClubItem` (untuk `/club`)

```dart
@immutable
final class SicaborClubItem {
  final int id;
  final String code;
  final String name;
  final String? logo;
  final Map<String, dynamic> cabor;     // {id, code, name}
  final String? headName;               // "head_name"
  final String? phone;
  final String? email;
  final String? since;
  final String? noSk;                   // "no_sk"
  final int status;
  final String statusLabel;             // "status_label"
  final Map<String, dynamic> secretariat;
  final int totalAthleteInClub;         // "total_athlete_in_club"

  factory SicaborClubItem.fromJson(Map<String, dynamic> json) => ...;
}
```

### `SicaborClubDetailItem` (untuk `/club/detail/{id}`)

```dart
@immutable
final class SicaborClubDetailItem {
  // Semua field SicaborClubItem, plus:
  final Map<String, dynamic>? training;
  final String? fileSk;                  // "file_sk"
  final Map<String, dynamic> officials;
  final Map<String, dynamic> coaches;
  final Map<String, dynamic> management;

  factory SicaborClubDetailItem.fromJson(Map<String, dynamic> json) => ...;
}
```

**Parsing blok sub-entitas:** Blok `officials`, `coaches`, `management` bukan envelope standar — mereka inline di dalam `data`. Parsing di DTO, mapping ke domain model di mapper.

## 6. Mapper tambahan

```dart
class SicaborDataMapper {
  // ... method yang sudah ada ...

  Club mapClub(SicaborClubItem item) => Club(
    id: item.id,
    code: item.code,
    name: item.name,
    logoUrl: item.logo,
    cabor: ClubCabor(
      id: _asInt(item.cabor['id']),
      code: item.cabor['code'] as String,
      name: item.cabor['name'] as String,
    ),
    headName: item.headName,
    phone: item.phone,
    email: item.email,
    since: item.since,
    noSk: item.noSk,
    status: item.status,
    statusLabel: item.statusLabel,
    secretariat: _mapAddress(item.secretariat),
    totalAthleteInClub: item.totalAthleteInClub,
  );

  ClubDetail mapClubDetail(SicaborClubDetailItem item) => ClubDetail(
    // ... semua field Club ...
    training: item.training != null ? _mapAddress(item.training!) : null,
    fileSkUrl: item.fileSk,
    officials: _mapPersonnelBlock(item.officials),
    coaches: _mapPersonnelBlock(item.coaches),
    management: _mapManagementBlock(item.management),
  );

  ClubAddress _mapAddress(Map<String, dynamic> json) => ClubAddress(
    address: json['address'] as String?,
    subdistrictId: _asInt(json['subdistrict_id']),
    subdistrictName: json['subdistrict_name'] as String,
    districtId: _asInt(json['district_id']),
    districtName: json['district_name'] as String,
  );

  ClubPersonnelBlock _mapPersonnelBlock(Map<String, dynamic> json) =>
    ClubPersonnelBlock(
      dataAvailable: json['data_available'] as bool? ?? false,
      reason: json['reason'] as String?,
      items: (json['data'] as List? ?? [])
        .map((e) => _mapPersonnelItem(e as Map<String, dynamic>))
        .toList(),
    );

  ClubManagementBlock _mapManagementBlock(Map<String, dynamic> json) =>
    ClubManagementBlock(
      dataAvailable: json['data_available'] as bool? ?? false,
      partial: json['partial'] as bool? ?? false,
      source: json['source'] as String?,
      items: (json['data'] as List? ?? [])
        .map((e) => _mapPersonnelItem(e as Map<String, dynamic>))
        .toList(),
    );

  ClubPersonnelItem _mapPersonnelItem(Map<String, dynamic> json) =>
    ClubPersonnelItem(
      id: json['id'] as int?,        // Bisa null!
      name: json['name'] as String,
      role: json['role'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo'] as String?,
      source: json['source'] as String?,
    );
}
```

## 7. Service

### `ClubService`

```dart
abstract interface class ClubService {
  Future<PaginatedResult<Club>> fetchClubList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? status,
    String? search,
    String sort = 'name',
    RequestCancellation? cancellation,
  });

  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  });
}
```

### `RemoteClubService`

```dart
final class RemoteClubService implements ClubService {
  RemoteClubService({required this.client, this.mapper = const SicaborDataMapper()});
  final ApiClient client;
  final SicaborDataMapper mapper;

  @override
  Future<PaginatedResult<Club>> fetchClubList({...}) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort': sort,
    };
    if (idCabor != null) queryParams['id_cabor'] = idCabor;
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await client.request<dynamic>(
      '/club', method: 'GET', queryParameters: queryParams, cancellation: cancellation,
    );
    final envelope = SicaborListEnvelope<SicaborClubItem>.fromJson(
      response.data as Map<String, dynamic>,
      SicaborClubItem.fromJson,
    );
    return PaginatedResult(
      items: envelope.data.map(mapper.mapClub).toList(),
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
    );
  }

  @override
  Future<ClubDetail> fetchClubDetail(int id, {...}) async {
    final response = await client.request<dynamic>(
      '/club/detail/$id', method: 'GET', cancellation: cancellation,
    );
    final envelope = SicaborDetailEnvelope<SicaborClubDetailItem>.fromJson(
      response.data as Map<String, dynamic>,
      SicaborClubDetailItem.fromJson,
    );
    return mapper.mapClubDetail(envelope.data);
  }
}
```

### `DemoClubService`

```dart
final class DemoClubService implements ClubService {
  DemoClubService({required this.demoRepo, required this.currentScopeProvider});
  final DemoKokRepository demoRepo;
  final AccessScope Function() currentScopeProvider;

  @override
  Future<PaginatedResult<Club>> fetchClubList({...}) async {
    final snapshot = await demoRepo.fetchScope(currentScopeProvider(), cancellation: cancellation);
    var clubs = snapshot.clubs.toList();
    // Filter by idCabor (match sport name), status, search
    // Sort, pagination
    final mapped = clubs.map(_mapDemoClub).toList();
    final page = mapped.skip(offset).take(limit).toList();
    return PaginatedResult(items: page, limit: limit, offset: offset, total: mapped.length);
  }

  @override
  Future<ClubDetail> fetchClubDetail(int id, {...}) async {
    final demoClub = await demoRepo.fetchClubDetail(id.toString(), cancellation: cancellation);
    return _mapDemoClubToDetail(demoClub);
  }
}
```

## 8. Provider

### `clubServiceProvider`

```dart
final clubServiceProvider = Provider<ClubService>((ref) {
  final composition = ref.watch(appCompositionProvider);
  final context = ref.watch(dataRequestContextProvider);
  if (composition.profile.dataMode == DataMode.demo &&
      context != null &&
      composition.kokRepository is DemoKokRepository) {
    return DemoClubService(
      demoRepo: composition.kokRepository as DemoKokRepository,
      currentScopeProvider: () => context.scope,
    );
  }
  return composition.clubService;
});
```

### `ClubPaginationController`

Mengikuti pola `AthletePaginationController` dan `CaborPaginationController`:

```dart
class ClubPaginationController
    extends FamilyNotifier<ClubPaginationState, int?> {

  static const int pageSize = 25;

  @override
  ClubPaginationState build(int? arg) => ClubPaginationState.initial();

  int? get idCabor => arg;

  // Filter internal
  String? _search;
  int? _status;
  String _sort = 'name';

  Future<void> loadFirstPage() async { /* sama dengan pola atlet */ }
  Future<void> loadMore() async { /* sama */ }
  void updateSearch(String? query) { _search = query; loadFirstPage(); }
  void updateStatusFilter(int? status) { _status = status; loadFirstPage(); }
  void updateSort(String sort) { _sort = sort; loadFirstPage(); }
  Future<void> refresh() => loadFirstPage();
}

final clubPaginationProvider = NotifierProvider.family<
    ClubPaginationController, ClubPaginationState, int?>(
  ClubPaginationController.new,
);
```

### `clubDetailProvider`

```dart
final clubDetailProvider = FutureProvider.family<ClubDetail, int>(
  (ref, clubId) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) throw RequestCancelledException('Sesi tidak aktif.');

    final service = ref.watch(clubServiceProvider);
    final cc = RequestCancellationController();
    ref.onDispose(() => cc.cancel('Provider disposed'));

    final detail = await service.fetchClubDetail(clubId, cancellation: cc.token);

    if (!ref.mounted) throw RequestCancelledException();
    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != context) throw RequestCancelledException();

    return detail;
  },
  retry: (_, __) => null,
);
```

## 9. Perubahan UI — Milestone 4A

### 9.1 `SportDetailPage` — Tab Klub (mode remote)

**Sebelum:** `_buildIntegrationPlaceholder()` di tab index 0.

**Sesudah:** Widget `_RemoteClubsTab` yang menonton `clubPaginationProvider(cabor?.id)`.

Komponen:
- Search bar + debounce 500ms.
- Filter status: Semua | Aktif | Belum Aktif (chip).
- Daftar klub dengan infinite scroll.
- Kartu klub: logo (fallback ikon cabor), nama, cabor, status badge, ketua, total atlet, lokasi secretariat.
- Tap → `context.push('/club/${club.id}')`.
- Empty state, loading, error + retry.

### 9.2 `ClubsPage` — Halaman utama Klub

**Sebelum:** `DataView(builder: (data) { ... })` dengan filter lokal.

**Sesudah:** Migrasi ke `clubPaginationProvider(null)` (tanpa filter cabor).

Sama seperti tab Klub di `SportDetailPage` tapi full-page. Filter yang sudah ada (sport dropdown, status, village, sort) dipetakan ke parameter API yang tersedia (`id_cabor`, `status`, `search`, `sort`).

**Catatan:** Filter `village` tidak didukung API — hanya tersedia secara lokal dari `secretariat.subdistrict_name` (tapi semua klub pasti kecamatan yang sama). Filter village mungkin perlu dihapus atau menjadi filter alamat yang lebih umum. Untuk 4A: sederhanakan filter ke search + status + sort.

### 9.3 `ClubDetailPage` — Restrukturisasi (mode remote)

**Sebelum:** 4 tab (Atlet, Pelatih, Official, Dokumen) dari `DataView`.

**Sesudah:** 3 tab (Info, Pengurus, Atlet Klub).

**Tab 1: Info**
- Logo klub (network image, fallback ikon cabor).
- Nama + kode.
- Cabor badge.
- Status badge (`statusLabel`).
- Tahun berdiri (`since`).
- Nomor SK (`noSk`) + link berkas SK (`fileSkUrl` — buka di browser jika ada).
- Ketua (`headName`).
- Kontak: telepon, email.
- Alamat secretariat (alamat + kecamatan + kabupaten).
- Alamat latihan (`training`) — dengan catatan jika kecamatan berbeda dari secretariat.
- Total anggota klub: `totalAthleteInClub` + keterangan "Termasuk atlet dari kecamatan lain".

**Tab 2: Pengurus**

Tampilkan tiga blok berturut-turut:

1. **Kepengurusan** (`management`):
   - Jika `dataAvailable == true`:
     - Daftar item (saat ini 1 orang: Ketua).
     - Jika `partial == true`: banner "Data kepengurusan belum lengkap".
     - Key item: gunakan index (bukan `id` yang null). Atau generate key stabil dari `name + role`.
   - Jika `dataAvailable == false`: "Belum tercatat di sistem".

2. **Official** (`officials`):
   - `dataAvailable == false` → "Belum tercatat di sistem". Tidak ada tombol retry (ini permanen sampai data diisi admin).

3. **Pelatih** (`coaches`):
   - `dataAvailable == false` → "Belum tercatat di sistem".

**Tab 3: Atlet Klub** → **Placeholder di 4A**, diimplementasikan di 4B.

Tampilkan pesan: "Daftar atlet klub sedang dalam tahap integrasi."

### 9.4 Header detail klub

**Sebelum:** ClubBrandPalette, sport-specific gradient, counts for atlet/pelatih/official.

**Sesudah (remote):**
- Gradient default atau dari cabor.
- Logo klub dari `logoUrl`.
- Nama + kode.
- Cabor + status.
- Stat counter: `totalAthleteInClub` (dengan keterangan lintas kecamatan).
- Sembunyikan counter pelatih dan official (data kosong).

### 9.5 Fitur demo-only yang disembunyikan di remote

| Fitur | Alasan |
|---|---|
| Tab Dokumen (checklist) | SICABOR hanya punya `file_sk` (link tunggal) — ditampilkan di Tab Info |
| Badge "berkas kurang" per person | Tidak ada data verifikasi dokumen |
| Counter pelatih/official di header | Data kosong |
| Brand palette dari hex code | SICABOR tidak mengirim brand colors |
| Village filter | Semua klub pasti kecamatan yang sama |

## 10. Error handling

### 10.1 Error spesifik klub

| Kondisi | HTTP | `error_code` | Tindakan |
|---|---|---|---|
| Klub tidak ditemukan / bukan kecamatan user | 404 | `CLUB_NOT_FOUND` | Tampilkan "Klub tidak ditemukan" |
| Token kedaluwarsa | 401 | `INVALID_TOKEN` | Logout terpusat |
| Akun non-aktif / bukan KOK | 403 | Various | Logout + pesan |
| Timeout / offline | — | — | Error + retry, token tetap |

### 10.2 `data_available: false` vs error

**Ini bukan error.** Response tetap 200 dengan `success: true`. Daftar kosong adalah jawaban yang sah.

- **`data_available: false`** → "Belum tercatat di sistem". **Tidak ada tombol retry.** Kondisi ini permanen sampai admin mengisi data.
- **`data_available: true` tapi `data` kosong** (setelah filter) → "Tidak ada hasil".

### 10.3 `partial: true`

Satu nama ketua tanpa penjelasan akan terbaca seolah klub hanya punya satu pengurus. Selalu tampilkan keterangan: "Data kepengurusan belum lengkap. Saat ini hanya menampilkan nama ketua."

## 11. File baru dan yang berubah — Milestone 4A

### File baru

| File | Isi |
|---|---|
| `lib/data/models/club.dart` | `Club`, `ClubCabor`, `ClubAddress` |
| `lib/data/models/club_detail.dart` | `ClubDetail`, `ClubPersonnelBlock`, `ClubManagementBlock`, `ClubPersonnelItem` |
| `lib/data/dto/sicabor_club_item.dart` | DTO daftar klub |
| `lib/data/dto/sicabor_club_detail_item.dart` | DTO detail klub |
| `lib/data/services/club_service.dart` | Interface `ClubService` |
| `lib/data/services/remote/remote_club_service.dart` | Implementasi remote |
| `lib/data/services/demo/demo_club_service.dart` | Adapter demo |
| `lib/data/providers/club_providers.dart` | Provider, pagination, state (replace file lama) |
| `test/data/sicabor_club_item_test.dart` | Unit test DTO |
| `test/data/sicabor_club_detail_test.dart` | Unit test DTO detail + sub-entitas |
| `test/data/remote_club_service_test.dart` | Test service mock HTTP |
| `test/data/club_providers_test.dart` | Test provider + pagination |
| `test/data/sicabor_data_mapper_club_test.dart` | Test mapper klub + personnel blocks |

### File yang berubah

| File | Perubahan |
|---|---|
| `lib/data/mapper/sicabor_data_mapper.dart` | Tambah `mapClub`, `mapClubDetail`, `_mapAddress`, `_mapPersonnelBlock`, `_mapManagementBlock`, `_mapPersonnelItem` |
| `lib/core/composition/app_composition.dart` | Tambah `ClubService clubService` + wiring |
| `lib/features/sport_detail/sport_detail_page.dart` | Tab Klub: ganti placeholder → `_RemoteClubsTab` |
| `lib/features/clubs_page.dart` | Migrasi dari DataView ke `clubPaginationProvider` |
| `lib/features/club_detail/club_detail_page.dart` | Migrasi ke ConsumerWidget + 3 tab baru (Info, Pengurus, Atlet placeholder) |
| `lib/features/club_detail/club_detail_header.dart` | Adaptasi untuk model baru + sembunyikan counter kosong |
| `test/test_composition.dart` | Tambah `clubService` |
| `docs/project-status.md` | Update status |

---

# MILESTONE 4B — TAB ATLET KLUB

## 12. Scope 4B

Tab Atlet di `ClubDetailPage` menggunakan endpoint `/athlete?id_club=...` yang **sudah diintegrasikan di milestone 3**. Yang perlu dilakukan:

1. **Hubungkan `athletePaginationProvider` dengan parameter `idClub`.**

Saat ini `AthletePaginationController` menggunakan `int? idCabor` sebagai family parameter. Untuk mendukung `idClub`, perlu diperluas:

**Opsi A (recommended):** Buat parameter lebih generik:
```dart
typedef AthleteFilterScope = ({int? idCabor, int? idClub});

class AthletePaginationController
    extends FamilyNotifier<AthletePaginationState, AthleteFilterScope> {
  int? get idCabor => arg.idCabor;
  int? get idClub => arg.idClub;
}
```

Pemanggilan dari detail Cabor: `athletePaginationProvider((idCabor: cabor.id, idClub: null))`
Pemanggilan dari detail Klub: `athletePaginationProvider((idCabor: null, idClub: club.id))`

**Opsi B:** Buat controller terpisah `ClubAthletePaginationController`. Lebih banyak duplikasi.

2. **Tampilkan `filter_warning` banner.**

Saat `id_club` dikirim, respons meta berisi:
```json
"filter_warning": {
  "code": "CLUB_MEMBERSHIP_SPARSE",
  "message": "Keanggotaan club pada data atlet belum lengkap. …"
}
```

Tampilkan banner informatif di atas daftar atlet. Gunakan `message` langsung (sudah berbahasa Indonesia).

3. **Jelaskan perbedaan angka.**

`total_athlete_in_club` (di header detail klub) bisa berbeda dari `meta.total` (di daftar atlet yang ditampilkan) karena:
- `total_athlete_in_club` = semua anggota, lintas kecamatan.
- Daftar = hanya atlet berdomisili di kecamatan pengguna.

Tampilkan keterangan: "Menampilkan X atlet dari kecamatan ini. Total anggota klub: Y (termasuk kecamatan lain)."

4. **Tangani daftar kosong dengan benar.**

Daftar kosong saat filter `id_club` aktif **bukan berarti bug**. Keanggotaan klub hampir belum terisi. Jangan tampilkan error — tampilkan spanduk penjelasan + "Tidak ada atlet dari kecamatan ini yang tercatat di klub."

## 13. Perubahan untuk 4B

| File | Perubahan |
|---|---|
| `lib/data/providers/athlete_providers.dart` | Ubah family parameter dari `int?` ke `AthleteFilterScope`. Update `loadFirstPage`/`loadMore` untuk pass `idClub`. |
| `lib/features/sport_detail/sport_detail_page.dart` | Update pemanggilan `athletePaginationProvider` ke parameter baru. |
| `lib/features/club_detail/club_detail_page.dart` | Tab Atlet: ganti placeholder → `_ClubAthletesTab` yang menonton `athletePaginationProvider((idCabor: null, idClub: club.id))`. |
| Test terkait | Update parameter provider. |

## 14. Urutan implementasi gabungan

### Milestone 4A (~5–6 hari)

1. **Model domain** (~¼ hari) — `Club`, `ClubDetail`, sub-model.
2. **DTO** (~½ hari) — `SicaborClubItem`, `SicaborClubDetailItem` + test.
3. **Mapper** (~½ hari) — `mapClub`, `mapClubDetail`, address, personnel blocks + test.
4. **Service interface + remote** (~½ hari) — `ClubService`, `RemoteClubService` + test.
5. **Demo adapter** (~½ hari) — `DemoClubService` + test.
6. **Provider + pagination** (~1 hari) — `clubPaginationProvider`, `clubDetailProvider`, state, controller + test.
7. **Composition wiring** (~¼ hari).
8. **UI Tab Klub di SportDetailPage** (~½ hari) — `_RemoteClubsTab`.
9. **UI ClubsPage migrasi** (~½ hari) — pagination, search, filter.
10. **UI ClubDetailPage migrasi** (~1 hari) — 3 tab: Info + Pengurus + placeholder Atlet.
11. **Verifikasi** (~½ hari) — test + analyze + build.

### Milestone 4B (~2–3 hari)

1. **Refactor `AthletePaginationController` parameter** (~½ hari).
2. **Tab Atlet Klub di ClubDetailPage** (~1 hari) — wire, filter_warning, penjelasan angka.
3. **Update SportDetailPage** (~¼ hari) — parameter baru.
4. **Verifikasi** (~½ hari).

**Total 4A+4B: 7–9 hari kerja.**

## 15. Kriteria selesai

### Milestone 4A

- [ ] Tab Klub di detail Cabor menampilkan daftar klub dari server
- [ ] Halaman utama Klub menampilkan daftar dengan pagination
- [ ] Pencarian dan filter status berfungsi
- [ ] Detail klub menampilkan Tab Info (alamat, SK, kontak, total atlet)
- [ ] Detail klub menampilkan Tab Pengurus (`data_available: false` → "Belum tercatat")
- [ ] `partial: true` pada kepengurusan diberi keterangan
- [ ] Item pengurus dengan `id: null` tidak crash (key stabil)
- [ ] `total_athlete_in_club` tampil dengan keterangan lintas kecamatan
- [ ] Logo klub ditampilkan (fallback jika null)
- [ ] 404 CLUB_NOT_FOUND → "Klub tidak ditemukan"
- [ ] Demo mode tetap berfungsi
- [ ] Semua test hijau, analyze bersih

### Milestone 4B

- [ ] Tab Atlet Klub menampilkan atlet dari `/athlete?id_club=...`
- [ ] `filter_warning` CLUB_MEMBERSHIP_SPARSE banner tampil
- [ ] Penjelasan perbedaan angka total anggota vs atlet yang ditampilkan
- [ ] Daftar kosong ditangani dengan spanduk penjelasan
- [ ] `AthletePaginationController` mendukung `idCabor` dan `idClub`
- [ ] Pergantian akun membersihkan data
- [ ] Test hijau, analyze bersih

## 16. Apa yang BELUM termasuk

- Tab Pelatih di `SportDetailPage` (tidak bisa efisien tanpa endpoint per-cabor).
- Endpoint terpisah official/coach/management (saat ini data inline sudah cukup).
- Navigasi dari atlet → detail klubnya (bisa ditambahkan setelah 4A+4B selesai).
- Pencarian global lintas entitas.
- Halaman komite KOK dan helpdesk (tidak ada di API).
- Halaman perhatian/attention (bergantung data verifikasi yang tidak ada).

# Hardening Integrasi & Konsistensi Mode Remote — Desain

**Milestone 4.1:** Perbaikan sesi, race condition, bug UI, dan test
**Milestone 5:** Audit halaman yang masih pakai `DataView`/`snapshotProvider`

**Prasyarat selesai:**
- Auth SICABOR + Profile (milestone 1) ✅
- Beranda + Cabor (milestone 2) ✅
- Atlet (milestone 3) ✅
- Klub (milestone 4) ✅

---

## 1. Konteks

Milestone 4 menyelesaikan integrasi data keempat (klub), tetapi review menemukan masalah keamanan sesi dan konsistensi yang menembus **semua** pagination controller — bukan hanya klub. Menambah fitur baru di atas fondasi yang bocor akan memperbesar masalah.

Verifikasi lokal: 687 test lulus, `flutter analyze` bersih. Tetapi **test belum menangkap** masalah pergantian sesi dan race condition.

## 2. Keputusan desain

| # | Keputusan | Pilihan |
|---|-----------|---------|
| 1 | Reset pagination saat ganti sesi | Watch `dataRequestContextProvider` di `build()`. Riverpod auto-rebuild + reset state. |
| 2 | 401/403 → logout terpusat | Dio interceptor global di `AppComposition`. Panggil `handleUnauthorizedSession()`. |
| 3 | Race condition filter | Generation counter di setiap pagination controller. Response lama diabaikan. |
| 4 | Halaman tanpa endpoint remote | Tampilkan placeholder informatif "Fitur belum tersedia". Tidak crash. Profil pakai `profileSummaryProvider`. |

---

# MILESTONE 4.1 — HARDENING

## 3. Perbaikan 1: Reset pagination saat pergantian sesi

### Masalah

Ketiga pagination controller (`CaborPaginationController`, `AthletePaginationController`, `ClubPaginationController`) memiliki masalah identik: `build()` mengembalikan state awal tanpa menonton `dataRequestContextProvider`. Saat pengguna logout atau ganti akun, data kecamatan sebelumnya tetap tersimpan.

Bandingkan dengan `profileSummaryProvider` yang sudah benar — menonton context di baris pertama.

### Solusi

Tambahkan `ref.watch(dataRequestContextProvider)` di `build()` setiap pagination controller:

```dart
// SEBELUM (semua 3 controller):
@override
ClubPaginationState build() {
  return const ClubPaginationState();
}

// SESUDAH:
@override
ClubPaginationState build() {
  // Riverpod akan memanggil build() ulang saat context berubah
  // (ganti akun, logout, perubahan scope/generation).
  // Ini otomatis me-reset state ke initial.
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) {
    // Tidak ada sesi aktif — kembalikan state kosong.
    return const ClubPaginationState();
  }
  // Sesi aktif — state awal siap di-load.
  return const ClubPaginationState();
}
```

Selain itu, setiap `loadFirstPage()` dan `loadMore()` menyimpan snapshot context saat mulai, dan memvalidasi setelah response:

```dart
Future<void> loadFirstPage() async {
  final contextAtStart = ref.read(dataRequestContextProvider);
  if (contextAtStart == null) return;

  state = state.copyWith(isLoading: true, error: null);
  _generation++; // Untuk race condition (lihat perbaikan 3)
  final expectedGen = _generation;

  try {
    final result = await ref.refresh(clubListProvider((...)).future);

    // Guard: sesi masih sama?
    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != contextAtStart || expectedGen != _generation) return;

    state = ClubPaginationState.loaded(items: result.items, ...);
  } catch (e, s) {
    if (expectedGen != _generation) return;
    state = state.copyWith(isLoading: false, error: e);
  }
}
```

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/data/providers/club_providers.dart` | `build()` watch context, `loadFirstPage()`/`loadMore()` validasi context |
| `lib/data/providers/athlete_providers.dart` | Idem |
| `lib/data/providers/cabor_providers.dart` | Idem + ubah `ref.read` → `ref.refresh` di `loadFirstPage()` |

### Test baru

| Test | Verifikasi |
|---|---|
| `test/data/club_providers_session_test.dart` | Ganti akun → state di-reset, data lama hilang |
| `test/data/athlete_providers_session_test.dart` | Idem untuk atlet |
| `test/data/cabor_providers_session_test.dart` | Idem untuk cabor |

Untuk setiap controller:
1. Muat data dengan akun A.
2. Simulasikan ganti ke akun B (ubah `dataRequestContextProvider`).
3. Verifikasi state kembali ke initial.
4. Verifikasi `loadMore()` tidak append ke data lama.
5. Verifikasi logout (`context → null`) me-reset state.

---

## 4. Perbaikan 2: 401/403 → logout terpusat

### Masalah

`handleUnauthorizedSession()` sudah ada di `AuthController` tapi tidak pernah dipanggil dari data layer. Saat token kedaluwarsa, request data gagal dengan `UnauthorizedException`, tapi pengguna tetap di `AuthSignedIn` — melihat error widget tanpa pernah diarahkan ke login.

### Solusi

Pasang Dio interceptor di `AppComposition` yang menangkap respons 401/403 dan memanggil `handleUnauthorizedSession()`:

```dart
class AuthSessionInterceptor extends Interceptor {
  AuthSessionInterceptor(this._authController);

  final AuthController _authController;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    if (statusCode == 401) {
      // Token tidak valid — akhiri sesi
      _authController.handleUnauthorizedSession();
      // Tetap teruskan error ke caller agar provider bisa menampilkan pesan
      handler.next(err);
      return;
    }

    if (statusCode == 403) {
      final body = err.response?.data;
      final errorCode = body is Map ? body['error_code'] as String? : null;

      // Error codes yang mengakhiri sesi:
      const sessionEndingCodes = {
        'MEMBER_NOT_FOUND',
        'MEMBER_INACTIVE',
        'NOT_KOK',
      };

      if (sessionEndingCodes.contains(errorCode)) {
        _authController.handleUnauthorizedSession();
      }
      // NO_SUBDISTRICT: jangan logout — akun sah tapi belum punya kecamatan

      handler.next(err);
      return;
    }

    handler.next(err);
  }
}
```

### Wiring di `AppComposition`

```dart
// Di AppComposition.fromProfile():
if (profile.dataMode == DataMode.remote) {
  dio.interceptors.add(AuthSessionInterceptor(authController));
}
```

**Catatan:** Interceptor harus didaftarkan setelah `authController` tersedia. Interceptor **tidak** mem-block error — ia meneruskan ke handler berikutnya agar provider bisa menampilkan pesan sebelum redirect. Single-flight di `handleUnauthorizedSession()` mencegah multiple logout.

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/core/network/auth_session_interceptor.dart` | **[NEW]** Dio interceptor |
| `lib/core/composition/app_composition.dart` | Daftarkan interceptor |

### Test baru

| Test | Verifikasi |
|---|---|
| `test/core/network/auth_session_interceptor_test.dart` | 401 → panggil `handleUnauthorizedSession()`. 403 `NOT_KOK` → panggil. 403 `NO_SUBDISTRICT` → jangan panggil. 200/404/500 → lewatkan. |
| `test/integration/session_expiry_flow_test.dart` | Skenario end-to-end: login → muat data → token expired → 401 → logout otomatis → state berubah ke `AuthSignedOut`. |

---

## 5. Perbaikan 3: Race condition filter/pagination

### Masalah

Saat pengguna mengetik di search bar, setiap perubahan memanggil `loadFirstPage()`. Request sebelumnya mungkin belum selesai. Jika response lama datang setelah response baru, daftar menampilkan hasil filter lama.

### Solusi

Generation counter di setiap pagination controller:

```dart
class ClubPaginationController extends ... {
  int _generation = 0;

  Future<void> loadFirstPage() async {
    _generation++;
    final expectedGen = _generation;

    state = state.copyWith(isLoading: true, error: null, items: []);

    try {
      final result = await ref.refresh(clubListProvider((...)).future);

      // Guard: apakah ini masih request terbaru?
      if (expectedGen != _generation) return; // Response lama, abaikan

      state = ClubPaginationState.loaded(items: result.items, ...);
    } catch (e, s) {
      if (expectedGen != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final expectedGen = _generation;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await ref.refresh(clubListProvider((...)).future);

      if (expectedGen != _generation) return;

      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e, s) {
      if (expectedGen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  void updateSearch(String? query) {
    _search = query;
    loadFirstPage(); // _generation++ di dalam
  }
}
```

**Mengapa generation counter, bukan cancel token:**
- Cancel token lebih efisien (membatalkan request HTTP) tapi butuh integrasi Dio di level provider.
- Generation counter lebih sederhana dan sudah cukup — response lama hanya diabaikan, bukan dicegah.
- Kedua teknik bisa digabungkan nanti jika perlu optimasi bandwidth.

### File terpengaruh

Ketiga pagination controller (sama dengan perbaikan 1 — perubahan digabung).

### Test baru

| Test | Verifikasi |
|---|---|
| `test/data/pagination_race_test.dart` | Simulasikan: `loadFirstPage()` → delay → `loadFirstPage()` lagi → response pertama datang → diabaikan → response kedua datang → diterapkan |

---

## 6. Perbaikan 4: Sort values invalid

### Masalah

`ClubsPage` menawarkan sort `-name` dan `-total_athlete` yang tidak didukung API. Server diam-diam jatuh ke default `name`.

### Solusi

Ganti opsi sort sesuai kontrak:

```dart
// SEBELUM:
final options = [
  ('name', 'Nama (A → Z)'),
  ('-name', 'Nama (Z → A)'),
  ('-total_athlete', 'Jumlah Atlet Terbanyak'),
  ('status', 'Status (Aktif Terlebih Dahulu)'),
];

// SESUDAH:
final options = [
  ('name', 'Nama (A → Z)'),
  ('code', 'Kode Klub'),
  ('since', 'Tahun Berdiri'),
  ('status', 'Status'),
];
```

**Catatan:** API tidak mendukung sort descending. Jika pengguna menginginkan Z → A, itu harus dilakukan client-side setelah semua data dimuat — tapi itu bertentangan dengan pagination. Untuk saat ini, hanya menawarkan opsi yang didukung server.

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/features/clubs_page.dart` | Ganti opsi sort |

---

## 7. Perbaikan 5: Demo scope leak

### Masalah

`DemoClubService.fetchClubDetail()` dan `DemoAthleteService.fetchAthleteDetail()` mencari klub/atlet di **semua** kecamatan demo jika tidak ditemukan di scope pengguna. Ini melanggar isolasi scope.

### Solusi

Hapus loop pencarian lintas scope. Jika tidak ditemukan di scope saat ini, throw `NotFoundException`:

```dart
// SEBELUM (demo_club_service.dart, line 127-160):
// 3. Search across other standard demo scopes
const scopes = [ ... ];
for (final s in scopes) { ... }

// SESUDAH:
// Tidak ditemukan di scope pengguna → tidak ada
throw NotFoundException('Klub tidak ditemukan di kecamatan Anda');
```

Terapkan perbaikan yang sama di `DemoAthleteService.fetchAthleteDetail()`.

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/data/services/demo/demo_club_service.dart` | Hapus fallback lintas scope |
| `lib/data/services/demo/demo_athlete_service.dart` | Idem |

---

## 8. Perbaikan 6: `NOT_RECORDED_IN_SYSTEM` mentah

### Masalah

`club_detail_page.dart` menampilkan `officials.reason` langsung — yang berisi kode teknis `"NOT_RECORDED_IN_SYSTEM"`.

### Solusi

Map reason code ke teks Indonesia:

```dart
String _mapReasonToMessage(String? reason, String fallback) {
  return switch (reason) {
    'NOT_RECORDED_IN_SYSTEM' => 'Belum tercatat di sistem',
    'NOT_AVAILABLE' => 'Data belum tersedia',
    _ => fallback,
  };
}

// Penggunaan:
if (!officials.dataAvailable)
  _UnavailableNotice(
    message: _mapReasonToMessage(
      officials.reason,
      'Data official belum tersedia.',
    ),
  )
```

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/features/club_detail/club_detail_page.dart` | Map reason code ke teks Indonesia |

---

## 9. Perbaikan 7: Label alamat tertukar

### Masalah

Di `club_detail_page.dart`:
- `subdistrictName` (kecamatan, misal "Garut Kota") dilabeli "Kelurahan / Desa"
- `districtName` (kabupaten, misal "Kabupaten Garut") dilabeli "Kecamatan"

### Solusi

```dart
// SEBELUM:
_InfoRow(label: 'Kelurahan / Desa', value: detail.secretariat.subdistrictName),
_InfoRow(label: 'Kecamatan', value: detail.secretariat.districtName),

// SESUDAH:
_InfoRow(label: 'Kecamatan', value: detail.secretariat.subdistrictName),
_InfoRow(label: 'Kabupaten / Kota', value: detail.secretariat.districtName),
```

**Catatan:** API tidak menyertakan kelurahan/desa di objek `secretariat` dan `training` — hanya ada di `domicile` atlet (`village`). Label "Kelurahan / Desa" seharusnya tidak ada di alamat klub.

Terapkan di kedua blok: secretariat (line 720-727) dan training (line 750-757).

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/features/club_detail/club_detail_page.dart` | Perbaiki label di 4 baris |

---

## 10. Perbaikan 8: SK URL tidak bisa dibuka

### Masalah

`fileSkUrl` ditampilkan sebagai teks statis "Berkas tersedia" tanpa bisa diklik.

### Solusi

Jadikan bisa diklik menggunakan `url_launcher`:

```dart
// SESUDAH:
_InfoRow(
  label: 'Berkas SK',
  value: detail.fileSkUrl != null && detail.fileSkUrl!.isNotEmpty
      ? 'Berkas tersedia'
      : 'Berkas belum tersedia',
  trailing: detail.fileSkUrl != null && detail.fileSkUrl!.isNotEmpty
      ? IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          tooltip: 'Buka berkas SK',
          onPressed: () => _launchUrl(detail.fileSkUrl!),
        )
      : null,
),
```

**Catatan:** `url_launcher` sudah di `pubspec.yaml`? Jika belum, tambahkan. Buka di browser eksternal, bukan in-app.

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/features/club_detail/club_detail_page.dart` | Tambah button buka URL |
| `pubspec.yaml` | Tambah `url_launcher` jika belum ada |

---

# MILESTONE 5 — KONSISTENSI MODE REMOTE

## 11. Audit halaman yang masih pakai `DataView`/`snapshotProvider`

### Halaman dan penanganan

| Halaman | Masalah di remote | Penanganan |
|---|---|---|
| **Global Search** (`search/global_search_page.dart`) | `DataView` → `UnimplementedError` | Placeholder "Pencarian global belum tersedia di mode server". Jelaskan: pencarian per-entitas tersedia di halaman masing-masing (Cabor, Atlet, Klub). |
| **Perlu Perhatian** (`attention_page.dart`) | `DataView` → crash. Fitur verifikasi dokumen tidak ada di SICABOR. | Placeholder "Fitur pemantauan kelengkapan dokumen belum tersedia". Ini bukan fitur yang bisa diaktifkan tanpa endpoint baru. |
| **Anggota KOK** (`committee_page.dart`) | `DataView` → crash. Endpoint komite tidak ada di API. | Placeholder "Data anggota KOK belum tersedia di SICABOR. Hubungi admin untuk informasi." |
| **Profil** (`profile_page.dart`) | `DataView` → crash. Tapi sudah ada `profileSummaryProvider`. | **Migrasi parsial:** Tampilkan member info, scope, kontingen dari `profileSummaryProvider`. Sembunyikan helpdesk dan sync status card yang bergantung pada snapshot. |
| **4 halaman lain** (sport detail, clubs, club detail, athlete detail) | Sudah punya dual-mode tapi masih import `DataView` untuk demo fallback | Verifikasi: di remote mode, path `DataView` tidak pernah dicapai. |

### Strategi implementasi

Buat widget reusable `RemoteFeaturePlaceholder`:

```dart
class RemoteFeaturePlaceholder extends StatelessWidget {
  const RemoteFeaturePlaceholder({
    super.key,
    required this.featureName,
    this.description,
    this.icon = Icons.construction_outlined,
  });

  final String featureName;
  final String? description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(featureName, style: Theme.of(context).textTheme.titleMedium),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 32, right: 32),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    ),
  );
}
```

### Profil — migrasi parsial

`ProfilePage` saat ini menampilkan:
1. Info akun (nama, username, role) — dari `currentUserProvider` ✅ sudah berfungsi
2. Ringkasan data (total atlet, klub, dll) — dari `DataView` ❌ crash di remote
3. Helpdesk — dari `DataView` ❌ tidak ada di API
4. Sync status card — dari `snapshotProvider` ❌

**Solusi untuk remote mode:**
- Section ringkasan: ambil dari `profileSummaryProvider` (total_cabor, total_club, total_athlete, data_notes). Sudah tersedia, hanya perlu dihubungkan.
- Helpdesk: sembunyikan atau tampilkan info statis dari config lokal.
- Sync status card: sembunyikan (tidak relevan — remote selalu mengambil data terbaru).
- Kontingen: tampilkan `summary.kontingen?.name`.

### File terpengaruh

| File | Perubahan |
|---|---|
| `lib/shared/widgets.dart` | Tambah `RemoteFeaturePlaceholder` (atau file terpisah) |
| `lib/features/search/global_search_page.dart` | Remote mode → placeholder |
| `lib/features/attention_page.dart` | Remote mode → placeholder |
| `lib/features/committee_page.dart` | Remote mode → placeholder |
| `lib/features/profile_page.dart` | Migrasi parsial: ringkasan dari `profileSummaryProvider`, sembunyikan helpdesk/sync |
| `docs/project-status.md` | Update status seluruh integrasi |

---

## 12. Ringkasan seluruh file yang berubah

### Milestone 4.1

| File | Perubahan |
|---|---|
| `lib/data/providers/club_providers.dart` | Watch context di `build()`, generation counter, context validation |
| `lib/data/providers/athlete_providers.dart` | Idem |
| `lib/data/providers/cabor_providers.dart` | Idem + `ref.read` → `ref.refresh` |
| `lib/core/network/auth_session_interceptor.dart` | **[NEW]** Interceptor 401/403 |
| `lib/core/composition/app_composition.dart` | Daftarkan interceptor |
| `lib/features/clubs_page.dart` | Perbaiki sort options |
| `lib/data/services/demo/demo_club_service.dart` | Hapus fallback lintas scope |
| `lib/data/services/demo/demo_athlete_service.dart` | Hapus fallback lintas scope |
| `lib/features/club_detail/club_detail_page.dart` | Map reason code, perbaiki label alamat, URL SK bisa dibuka |
| `pubspec.yaml` | Tambah `url_launcher` (jika belum) |
| `test/data/club_providers_session_test.dart` | **[NEW]** Test ganti akun |
| `test/data/athlete_providers_session_test.dart` | **[NEW]** Test ganti akun |
| `test/data/cabor_providers_session_test.dart` | **[NEW]** Test ganti akun |
| `test/data/pagination_race_test.dart` | **[NEW]** Test race condition |
| `test/core/network/auth_session_interceptor_test.dart` | **[NEW]** Test interceptor |
| `test/integration/session_expiry_flow_test.dart` | **[NEW]** Test sesi berakhir end-to-end |

### Milestone 5

| File | Perubahan |
|---|---|
| `lib/shared/widgets.dart` | Tambah `RemoteFeaturePlaceholder` |
| `lib/features/search/global_search_page.dart` | Remote mode → placeholder |
| `lib/features/attention_page.dart` | Remote mode → placeholder |
| `lib/features/committee_page.dart` | Remote mode → placeholder |
| `lib/features/profile_page.dart` | Migrasi parsial ke `profileSummaryProvider` |
| `docs/project-status.md` | Update status keseluruhan |

---

## 13. Urutan implementasi

### Milestone 4.1 (~4–5 hari)

1. **Pagination session reset** (~1 hari) — ketiga controller + test.
2. **Generation counter** (~½ hari) — ketiga controller + test race.
3. **Auth session interceptor** (~1 hari) — interceptor + wiring + test.
4. **Bug fixes** (~1 hari) — sort, scope demo, label, reason code, SK URL.
5. **Verifikasi** (~½ hari) — `flutter test`, `flutter analyze`, manual test ganti akun.

### Milestone 5 (~2–3 hari)

1. **`RemoteFeaturePlaceholder` widget** (~¼ hari).
2. **Audit 4 halaman** (~1 hari) — Search, Attention, Committee, Profile.
3. **Profil migrasi parsial** (~1 hari) — hubungkan ke `profileSummaryProvider`.
4. **Update docs** (~¼ hari).
5. **Verifikasi** (~½ hari).

**Total 4.1 + 5: 6–8 hari kerja.**

---

## 14. Kriteria selesai

### Milestone 4.1

- [ ] Ganti akun → semua pagination state (cabor, atlet, klub) di-reset
- [ ] Logout → state kembali ke initial, data lama tidak tampil
- [ ] 401 saat data request → logout otomatis + redirect ke login
- [ ] 403 `NOT_KOK`/`MEMBER_INACTIVE`/`MEMBER_NOT_FOUND` → logout otomatis
- [ ] 403 `NO_SUBDISTRICT` → **tidak** logout (akun sah)
- [ ] Filter berubah cepat → hanya hasil terakhir yang ditampilkan
- [ ] Sort hanya menawarkan opsi yang didukung API
- [ ] Demo detail tidak bisa melihat data kecamatan lain
- [ ] `NOT_RECORDED_IN_SYSTEM` tampil sebagai "Belum tercatat di sistem"
- [ ] Label alamat benar: kecamatan dan kabupaten
- [ ] URL berkas SK bisa dibuka di browser
- [ ] Test baru: 6 file test, minimal 20 test case baru
- [ ] Semua test hijau, analyze bersih

### Milestone 5

- [ ] Global Search di remote → placeholder informatif, tidak crash
- [ ] Perlu Perhatian di remote → placeholder informatif
- [ ] Anggota KOK di remote → placeholder informatif
- [ ] Profil di remote → menampilkan data dari `profileSummaryProvider`
- [ ] Profil di remote → helpdesk disembunyikan, sync card disembunyikan
- [ ] Semua halaman navigable di remote tanpa crash
- [ ] `docs/project-status.md` mencerminkan status terkini
- [ ] Demo mode tetap berfungsi
- [ ] Semua test hijau

---

## 15. Apa yang BELUM termasuk

- Integrasi pelatih/official per cabor (API tidak menyediakan endpoint).
- Modul Anggota KOK (butuh kontrak tambahan dari tim SICABOR).
- Pencarian global via API (butuh endpoint search server-side).
- Fitur verifikasi dokumen (tidak ada di SICABOR).
- Helpdesk dari server (tidak ada endpoint).
- Logging/observability.
- Performance: cancel pending Dio request saat filter berubah (optimasi, bukan bug fix).

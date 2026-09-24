# KOK UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menjadikan aplikasi KOK sebuah ringkasan kondisi olahraga kecamatan dan direktori data yang konsisten dengan kontrak SICABOR.

**Architecture:** Pertahankan lima cabang GoRouter dan provider Riverpod yang sudah ada. Tambahkan halaman daftar atlet umum dan komponen transisi header detail; susun ulang tampilan mode remote di atas model dan layanan yang tersedia. Mode demo tetap terpisah, sedangkan mock HTTP hanya mendapat fixture dan pemeriksaan kontrak tanpa endpoint KOK baru.

**Tech Stack:** Flutter 3.44.4, Dart 3.12.2, Riverpod, GoRouter, `flutter_test`, mock server `dart:io`.

**Spec:** `docs/archive/specs/2026-09-24-kok-ui-polish-design.md`

## Global Constraints

- Kontrak data ialah `docs/api/api-kok-sicabor.md`; jangan menambah endpoint/field SICABOR atau mengartikan nilai kosong sebagai verifikasi berkas.
- Navigasi utama tetap `Beranda`, `Cabor`, `Klub`, `Anggota`, `Profil`; `Anggota` berarti kepengurusan KOK.
- Mode remote tidak menampilkan data contoh sebagai data resmi, termasuk nama `Pak Asep`, pelatih/official cabor, lisensi, kelengkapan berkas, dan susunan pengurus KOK.
- Jumlah daftar berasal dari `meta.total`, jumlah Beranda dari `/profile`; `total_athlete_in_club` mencakup lintas kecamatan.
- `data_notes` ditampilkan dengan isi dan urutan server; `filter_warning`, `data_available: false`, dan `partial: true` dipresentasikan sesuai arti kontrak.
- Bidang putih di Detail Cabor dan Detail Klub menumpang header berwarna dengan sudut kiri/kanan atas membulat; tab pil berada di dalam bidang tersebut.
- Setelah setiap tugas, jalankan test yang disebutkan, `flutter analyze --no-pub`, lalu komit perubahan tugas itu. Jangan mengubah mode demo kecuali untuk menjaga kompilasi dan label contoh.

---

## Peta file dan batas komponen

| Unit | File utama | Tanggung jawab |
|---|---|---|
| Tema bersama | `lib/core/theme.dart`, `lib/shared/detail_header_lip.dart` (baru) | Token radius/warna dan transisi header ke konten putih. |
| Penemuan data | `lib/features/home_page.dart`, `lib/features/search/global_search_page.dart`, `lib/app.dart` | Ringkasan wilayah dan tiga tujuan navigasi yang nyata. |
| Direktori atlet | `lib/features/athlete_list/athlete_list_page.dart` (baru) | Daftar `/athlete` tanpa filter klub, pencarian dan pagination. |
| Cabor | `lib/features/sports_page.dart`, `lib/data/providers/cabor_providers.dart`, `lib/features/sport_detail/sport_detail_page.dart` | Direktori, resolusi cabor berdasarkan ID, dan detail dua tab. |
| Klub | `lib/features/clubs_page.dart`, `lib/features/club_detail/club_detail_page.dart`, `lib/features/club_detail/club_detail_tabs.dart` | Label cakupan daftar dan tiga tab detail dengan bentuk yang disepakati. |
| Akun/pengurus/atlet | `lib/features/profile_page.dart`, `lib/features/committee_page.dart`, `lib/features/athlete_detail/athlete_detail_page.dart` | Identitas akun, kepengurusan KOK tanpa data resmi, detail atlet tanpa klaim dokumen. |
| Mock dan QA | `scripts/mock_server/mock_data.dart`, `scripts/mock_server/sicabor_mock_server.dart`, `scripts/mock_server/README.md` | Fixture konsisten, gambar lokal, dan matriks skenario; respons API tetap sama. |

## Task 1: Token visual dan transisi header detail

**Files:**
- Modify: `lib/core/theme.dart`
- Create: `lib/shared/detail_header_lip.dart`
- Create: `test/shared/detail_header_lip_test.dart`

**Interfaces:** Produces `KokRadii.contentTop`, `KokRadii.card`, `KokRadii.tab` dan `DetailHeaderLip({required Widget header})`. Task 5 dan 6 memakai widget ini.

- [ ] **Step 1: Tulis widget test lebar kecil yang gagal sebelum widget tersedia.**

```dart
testWidgets('detail header lip fits a narrow screen', (tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: DetailHeaderLip(header: SizedBox(height: 180))),
  ));
  expect(tester.takeException(), isNull);
  expect(find.byKey(const Key('detail-header-lip')), findsOneWidget);
});
```

- [ ] **Step 2: Jalankan** `flutter test test/shared/detail_header_lip_test.dart`; harapkan gagal karena kelas belum tersedia.
- [ ] **Step 3: Tambahkan token dan komponen tanpa mengubah alur data.**

```dart
abstract final class KokRadii {
  static const contentTop = 28.0;
  static const card = 16.0;
  static const tab = 18.0;
}

class DetailHeaderLip extends StatelessWidget {
  const DetailHeaderLip({super.key, required this.header});
  final Widget header;
  @override
  Widget build(BuildContext context) => Stack(children: [
    header,
    Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        key: const Key('detail-header-lip'),
        height: KokRadii.contentTop,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(KokRadii.contentTop)),
        ),
      ),
    ),
  ]);
}
```

- [ ] **Step 4: Jalankan** test Task 1 dan `flutter analyze --no-pub`; periksa juga bentuk pada lebar 320 dan 390 dp melalui preview.
- [ ] **Step 5: Komit** `lib/core/theme.dart`, komponen, dan test dengan pesan `feat(ui): add shared detail header transition`.

## Task 2: Direktori atlet umum dan rute

**Files:**
- Create: `lib/features/athlete_list/athlete_list_page.dart`
- Modify: `lib/app.dart`
- Create: `test/athlete_list_page_test.dart`

**Interfaces:** Produces route `/athletes` dan `AthleteListPage`. Consumes `athletePaginationProvider((idCabor: null, idClub: null))`; tidak membuat provider atau endpoint baru.

- [ ] **Step 1: Tulis widget test yang memberi state dua atlet, salah satunya `club: null`, lalu periksa judul, `meta.total`, label klub, dan navigasi detail.**

```dart
expect(find.text('Daftar Atlet'), findsOneWidget);
expect(find.text('Klub belum tercatat'), findsOneWidget);
expect(find.text('361 atlet'), findsOneWidget);
await tester.tap(find.text('Klub belum tercatat').first);
await tester.pumpAndSettle();
expect(router.routeInformationProvider.value.uri.path, '/person/2375');
```

- [ ] **Step 2: Jalankan** `flutter test test/athlete_list_page_test.dart`; harapkan gagal karena halaman/rute belum ada.
- [ ] **Step 3: Buat halaman dengan pencarian server ber-debounce 500 ms, filter jenis kelamin dan status, daftar paginated, serta error/empty state.**

```dart
const scope = (idCabor: null, idClub: null);
final state = ref.watch(athletePaginationProvider(scope));
final controller = ref.read(athletePaginationProvider(scope).notifier);
// Pada init: controller.loadFirstPage(); pada input setelah 500 ms:
controller.updateSearch(query);
// Pada batas scroll: controller.loadMore(); jumlah UI: state.total.
```

Tambahkan `GoRoute(path: '/athletes', builder: (_, _) => const AthleteListPage())` di luar shell pada `lib/app.dart`, sejajar dengan route detail. Kartu memakai `Athlete.code`, `cabor.name`, `statusLabel`, dan label netral ketika `club == null`; `photoUrl` memakai fallback ketika gambar gagal.

- [ ] **Step 4: Jalankan** `flutter test test/athlete_list_page_test.dart test/data/athlete_providers_test.dart` dan `flutter analyze --no-pub`; uji pagination halaman kedua serta hasil filter kosong.
- [ ] **Step 5: Komit** halaman, route, dan test dengan pesan `feat(athlete): add scoped athlete directory`.

## Task 3: Beranda dan pintu masuk tiga direktori

**Files:**
- Modify: `lib/features/home_page.dart`, `lib/features/search/global_search_page.dart`
- Test: `test/home_page_test.dart`, `test/search_page_test.dart`

**Interfaces:** Consumes `/athletes` dari Task 2; mempertahankan `/sports`, `/clubs`, dan route `/search` sebagai pemilih tujuan di mode remote.

- [ ] **Step 1: Tambahkan test mode remote untuk tiga aksi dan ketiadaan nama/status demo.**

```dart
expect(find.text('Jelajahi Cabor'), findsOneWidget);
expect(find.text('Cari Klub'), findsOneWidget);
expect(find.text('Cari Atlet'), findsOneWidget);
expect(find.textContaining('terverifikasi'), findsNothing);
expect(find.textContaining('Pak Asep'), findsNothing);
```

- [ ] **Step 2: Jalankan** `flutter test test/home_page_test.dart test/search_page_test.dart`; harapkan test baru gagal.
- [ ] **Step 3: Ganti kotak pencarian remote dengan tiga aksi eksplisit; tampilkan ringkasan `/profile` dan catatan server tanpa timestamp tiruan.**

```dart
_DirectoryAction(label: 'Jelajahi Cabor', onTap: () => context.go('/sports'));
_DirectoryAction(label: 'Cari Klub', onTap: () => context.go('/clubs'));
_DirectoryAction(label: 'Cari Atlet', onTap: () => context.push('/athletes'));
```

Gunakan `summary.member.name` atau identitas principal yang tersedia; jika keduanya kosong tampilkan label netral `Akun KOK`, bukan nama contoh. `dataNotes` tetap berurutan dalam bagian yang dapat dibuka. Cabang remote `/search` memakai tiga tujuan yang sama; cabang demo tetap menjalankan pencarian demo.

- [ ] **Step 4: Jalankan** dua test Task 3 dan `flutter analyze --no-pub`; periksa Beranda Garut Kota dan Limbangan, termasuk klub berjumlah nol.
- [ ] **Step 5: Komit** dengan pesan `feat(home): make regional summary lead to real directories`.

## Task 4: Direktori Cabor sesuai source dan sort API

**Files:**
- Modify: `lib/features/sports_page.dart`
- Test: `test/sports_page_test.dart`

**Interfaces:** Consumes `CaborPaginationController.loadFirstPage(source:, sort:)` yang sudah tersedia; tidak memakai pencarian cabor yang tidak ada di API.

- [ ] **Step 1: Tambahkan test yang memilih `Ada Klub`, memastikan controller menerima `source: club`, dan memastikan grafik sebaran tidak muncul.**

```dart
await tester.tap(find.text('Ada Klub'));
await tester.pump();
final container = ProviderScope.containerOf(tester.element(find.byType(SportsPage)));
expect(container.read(caborPaginationProvider).source, 'club');
expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsNothing);
```

- [ ] **Step 2: Jalankan** `flutter test test/sports_page_test.dart`; harapkan test filter/tampilan baru gagal.
- [ ] **Step 3: Hapus kartu grafik remote; pertahankan satu judul `Cabang Olahraga`, keterangan kecamatan dan `state.total`, daftar cabor, filter source, dan sort.**

```dart
const sourceOptions = [('Semua', 'all'), ('Ada Klub', 'club'), ('Ada Atlet', 'athlete')];
controller.loadFirstPage(source: selectedSource, sort: state.sort);
// Opsi sort yang tampil: name, athlete, club.
```

Pertahankan fallback logo dan pagination. Saat filter berubah, tampilkan loading baru tanpa item filter sebelumnya; hitungan berasal dari `state.total`.

- [ ] **Step 4: Jalankan** `flutter test test/sports_page_test.dart test/data/cabor_providers_test.dart` dan `flutter analyze --no-pub`; periksa state 0 cabor pada filter `Ada Klub` untuk Limbangan.
- [ ] **Step 5: Komit** dengan pesan `feat(cabor): focus directory on scoped data`.

## Task 5: Detail Cabor dua tab dan identitas yang dapat diresolusi

**Files:**
- Modify: `lib/data/providers/cabor_providers.dart`, `lib/features/sport_detail/sport_detail_page.dart`
- Test: `test/data/cabor_providers_test.dart`, `test/sport_detail_test.dart`

**Interfaces:** Produces `caborByIdProvider = FutureProvider.family<Cabor?, int>` dengan paging `/cabor`; consumes `DetailHeaderLip` dari Task 1. Tab remote menjadi `Atlet`, `Klub`; tab demo tetap sesuai data demo.

- [ ] **Step 1: Tulis test resolusi ID pada halaman kedua dan test remote yang tidak menampilkan `Pelatih`, `Berkas Lengkap`, atau grafik usia.**

```dart
final cabor = await container.read(caborByIdProvider(31).future);
expect(cabor?.id, 31);
expect(find.text('Atlet'), findsWidgets);
expect(find.text('Klub'), findsWidgets);
expect(find.text('Pelatih'), findsNothing);
expect(find.textContaining('Berkas Lengkap'), findsNothing);
```

- [ ] **Step 2: Jalankan** `flutter test test/data/cabor_providers_test.dart test/sport_detail_test.dart`; harapkan test baru gagal.
- [ ] **Step 3: Resolusi ID memakai daftar terurut nama dengan ukuran halaman maksimum kontrak dan guard sesi provider yang sudah ada.**

```dart
final caborByIdProvider = FutureProvider.family<Cabor?, int>((ref, id) async {
  if (id <= 0) return null;
  ref.watch(dataRequestContextProvider);
  var offset = 0;
  while (true) {
    final page = await ref.read(caborListProvider((
      offset: offset, limit: 100, source: 'all', sort: 'name',
    )).future);
    for (final item in page.items) {
      if (item.id == id) return item;
    }
    if (!page.hasMore || page.items.isEmpty) return null;
    offset += page.items.length;
  }
});
```

Mode remote memakai hasil provider untuk header dan angka; selama loading jangan mengganti angka dengan `0`. Bangun bidang putih membulat dengan `_RemoteAthletesTab` sebagai tab awal dan `_RemoteClubsTab` sebagai tab kedua; keduanya menerima `caborId: cabor.id` serta parameter palet yang sudah dipakai widget tersebut. Lepaskan kartu analitik, tab Pelatih, dan rekap yang menyebut verifikasi berkas pada mode remote.

- [ ] **Step 4: Jalankan** dua test Task 5 dan `flutter analyze --no-pub`; periksa cabor klub tanpa atlet, atlet tanpa klub, ID tidak ditemukan, serta deep link ID halaman kedua.
- [ ] **Step 5: Komit** dengan pesan `feat(cabor): show contract-backed two-tab detail`.

## Task 6: Daftar dan Detail Klub dengan cakupan yang jelas

**Files:**
- Modify: `lib/features/clubs_page.dart`, `lib/features/club_detail/club_detail_page.dart`, `lib/features/club_detail/club_detail_tabs.dart`
- Test: `test/clubs_page_test.dart`, `test/club_detail_test.dart`

**Interfaces:** Consumes `DetailHeaderLip` dari Task 1 dan model `ClubDetail`/provider klub yang ada; tidak mengubah bentuk API.

- [ ] **Step 1: Tambahkan test label anggota lintas kecamatan, penjelasan `partial`, `data_available: false`, dan warning pada tab Atlet.**

```dart
expect(find.textContaining('atlet terdaftar di klub'), findsWidgets);
expect(find.textContaining('belum lengkap'), findsWidgets);
expect(find.text('Belum tercatat di sistem'), findsWidgets);
expect(find.textContaining('kecamatan ini'), findsWidgets);
```

- [ ] **Step 2: Jalankan** `flutter test test/clubs_page_test.dart test/club_detail_test.dart`; harapkan test baru gagal.
- [ ] **Step 3: Pertahankan urutan tab remote `Info`, `Pengurus`, `Atlet`; bungkus `_RemoteClubDetailHeader` dengan `DetailHeaderLip`, beri latar putih pada tab dan badan detail.**

```dart
DetailHeaderLip(header: _RemoteClubDetailHeader(detail: detail, palette: palette));
// Label jumlah: '${detail.totalAthleteInClub} atlet terdaftar di klub'.
// Tab Atlet: tampilkan state.filterWarningMessage dari server jika tersedia.
```

Pada daftar, tampilkan satu judul `Klub`, `state.total` di keterangan daftar, cabor dan lokasi sekretariat pada kartu. Jangan membandingkan `totalAthleteInClub` dengan total atlet cabor. Pada Info, bedakan alamat sekretariat dan tempat latihan; pada Pengurus, pertahankan `partial` dan `dataAvailable` semantik yang sudah dipetakan.

- [ ] **Step 4: Jalankan** dua test Task 6 dan `flutter analyze --no-pub`; periksa tab pada 320/390 dp, klub tanpa atlet lokal, status belum aktif, dan alamat latihan lintas kecamatan.
- [ ] **Step 5: Komit** dengan pesan `feat(club): clarify scope and round detail content`.

## Task 7: Detail Atlet

**Files:**
- Modify: `lib/features/athlete_detail/athlete_detail_page.dart`
- Test: `test/athlete_detail_test.dart`

**Interfaces:** Uses existing `athleteDetailProvider`; no new endpoint is introduced.

- [ ] **Step 1: Tambahkan test remote untuk klub null, status, cabor, dan tidak adanya checklist dokumen.**

```dart
expect(find.text('Klub belum tercatat'), findsOneWidget);
expect(find.text('Aktif'), findsWidgets);
expect(find.textContaining('Berkas Lengkap'), findsNothing);
```

- [ ] **Step 2: Jalankan** `flutter test test/athlete_detail_test.dart`; harapkan test baru gagal.
- [ ] **Step 3: Pertahankan komponen detail atlet yang didukung API, ubah label klub null menjadi netral, dan jangan munculkan checklist/CTA yang membutuhkan endpoint lain.**

```dart
final clubLabel = detail.club?.name ?? 'Klub belum tercatat';
```

- [ ] **Step 4: Jalankan** `flutter test test/athlete_detail_test.dart` dan `flutter analyze --no-pub`; periksa detail atlet tanpa klub, URL foto gagal, dan ID 404.
- [ ] **Step 5: Komit** dengan pesan `feat(athlete): clarify detail data scope`.

## Task 8: Kepengurusan KOK dan Akun

**Files:**
- Modify: `lib/features/committee_page.dart`, `lib/features/profile_page.dart`
- Test: `test/committee_page_test.dart`, `test/profile_page_test.dart`

**Interfaces:** Uses existing `profileSummaryProvider` and `RemoteFeaturePlaceholder`; no committee provider is introduced.

- [ ] **Step 1: Tambahkan test remote untuk status kepengurusan KOK serta Akun tanpa ringkasan ganda atau waktu sinkronisasi fiktif.**

```dart
expect(find.text('Data susunan pengurus KOK resmi belum tersedia di aplikasi.'), findsOneWidget);
expect(find.textContaining('Terakhir sinkron'), findsNothing);
expect(find.textContaining('Pak Asep'), findsNothing);
```

- [ ] **Step 2: Jalankan** `flutter test test/committee_page_test.dart test/profile_page_test.dart`; harapkan test baru gagal.
- [ ] **Step 3: Pada remote `CommitteePage`, tampilkan kecamatan dari `profileSummaryProvider` dan pesan status data tanpa jumlah/periode SK.** `ProfilePage` menampilkan member, scope, status, kontingen kondisional, rekap jika berizin, pengaturan, dan keluar; ringkasan angka besar hanya di Beranda. Demo mempertahankan penanda data contoh.
- [ ] **Step 4: Jalankan** dua test Task 8 dan `flutter analyze --no-pub`; periksa akun dengan `kontingen: null` serta sesi yang kedaluwarsa.
- [ ] **Step 5: Komit** dengan pesan `feat(ui): clarify committee and account data`.

## Task 9: Fixture mock yang konsisten dan gambar lokal

**Files:**
- Modify: `scripts/mock_server/mock_data.dart`, `scripts/mock_server/sicabor_mock_server.dart`, `scripts/mock_server/README.md`
- Test: `test/scripts/mock_data_test.dart`, `test/scripts/sicabor_mock_server_test.dart`, `test/integration/mock_http_flow_test.dart`

**Interfaces:** Existing `/api/v1/kok/*` responses retain the documented envelope and fields. Static `/mock-media/*` files only support local image URLs; they are not KOK API endpoints.

- [ ] **Step 1: Tambahkan pemeriksaan ringkasan turunan untuk setiap akun aktif dan satu HTTP test yang memuat gambar mock.**

```dart
final localAthletes = MockData.athletes.where(
  (a) => a.domicileSubdistrictId == account.subdistrictId,
).toList();
expect(account.summary['total_athlete'], localAthletes.length);
expect(account.summary['total_athlete_without_club'],
    localAthletes.where((a) => a.clubId == null).length);
```

Hitung pula himpunan cabor gabungan, asal klub, asal atlet, dan jumlah klub berdasarkan sekretariat. Jangan mengubah angka fixture hanya agar test lolos; betulkan penyebab ketidaksesuaian.

- [ ] **Step 2: Jalankan** `flutter test test/scripts/mock_data_test.dart test/integration/mock_http_flow_test.dart`; harapkan pemeriksaan baru gagal bila ada ketidaksesuaian atau gambar belum dilayani.
- [ ] **Step 3: Layani dua gambar PNG yang sudah ada di `assets/branding/` pada rute non-API dan masukkan URL lokal ke beberapa item mock; sisakan kasus logo null/URL gagal.**

```dart
if (request.uri.path == '/mock-media/logo.png') {
  response.headers.contentType = ContentType('image', 'png');
  await File('assets/branding/logo-koni.png').openRead().pipe(response);
  return;
}
final mediaOrigin = 'http://${request.headers.value(HttpHeaders.hostHeader)}';
```

Teruskan `mediaOrigin` sebagai argumen opsional ke builder JSON daftar/detail yang memuat media, agar URL valid juga saat host emulator memakai `10.0.2.2`. Perbarui README dengan tabel akun → cabor/klub/atlet → state UI yang diuji. Jangan menambah `/committee`, `/search`, atau field berkas/lisensi.

- [ ] **Step 4: Jalankan** tiga test Task 9 dan `flutter analyze --no-pub`; periksa respons gambar `200 image/png` dan JSON endpoint tetap lulus test kontrak.
- [ ] **Step 5: Komit** dengan pesan `test(mock): cover UI scenarios without API drift`.

## Task 10: Verifikasi akhir dan penyerahan

**Files:**
- Modify: `docs/project-status.md` untuk mencatat polish UI yang benar-benar selesai dan batas validasi API resmi.
- Test: seluruh suite `test/` dan alur HTTP mock.

**Interfaces:** Tidak menambah API. Hasilnya adalah daftar verifikasi yang dapat ditinjau pengguna.

- [ ] **Step 1: Jalankan** `dart format --output=none --set-exit-if-changed lib test scripts/mock_server` dan perbaiki hanya file yang berubah dalam rangkaian ini.
- [ ] **Step 2: Jalankan** `flutter analyze --no-pub`, `flutter test --no-pub`, dan `flutter test test/integration/mock_http_flow_test.dart`; catat hasil sebenarnya, bukan status yang diasumsikan.
- [ ] **Step 3: Ambil screenshot mode remote untuk Garut Kota dan Limbangan pada lebar sekitar 320/390 dp.** Tinjau Beranda, Daftar/Detail Cabor, Daftar/Detail Klub, Daftar/Detail Atlet, Anggota KOK, dan Akun. Bandingkan transisi header membulat dengan referensi pengguna; periksa overflow, logo fallback, serta data kosong.
- [ ] **Step 4: Perbarui `docs/project-status.md` dengan hanya hasil yang terverifikasi.**

```markdown
### Polish UI berbasis kontrak SICABOR
- Beranda dan direktori memakai data kecamatan dari API KOK.
- Anggota KOK tetap ada dengan status data resmi belum tersedia.
- Validasi server resmi tetap menunggu URL/kredensial produksi.
```

- [ ] **Step 5: Komit** dokumentasi dan perbaikan final dengan pesan `docs: record contract-backed UI polish verification`; laporkan file berubah, hasil tes, risiko yang tersisa, dan rute mock untuk meninjau UI.

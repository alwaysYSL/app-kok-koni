# Milestone 5.1 dan 5.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup temuan audit integrasi KOK–SICABOR yang dapat diuji tanpa URL API resmi, sehingga alur remote, mock, dan informasi yang ditampilkan konsisten dengan kontrak.

**Architecture:** Milestone 5.1 memperkuat identitas request/sesi, validasi respons, dan satu pemetaan error untuk halaman remote. Milestone 5.2 membuat mock server menegakkan kontrak token serta memperbaiki representasi data dan aksi UI; test HTTP mock menjadi gerbang penerimaan lokal.

**Tech Stack:** Flutter, Dart `^3.12.2`, Riverpod `^3.0.0`, Dio `^5.9.0`, `flutter_test`, `dart:io` mock server, Android debug manifest. `url_launcher` ditambahkan hanya untuk membuka berkas SK.

**Spec:** [Desain Milestone 5.1 dan 5.2](../specs/2026-09-23-milestone-5-1-5-2-design.md). Baca juga [audit sumber](../audits/2026-09-23-audit-spesifikasi-integrasi-sicabor.md) dan [kontrak resmi](../../api/api-kok-sicabor.md).

## Global Constraints

- API resmi belum memiliki URL yang dapat dipakai; seluruh acceptance lokal memakai mock. Jangan menyatakan kompatibilitas server resmi setelah tugas ini.
- Production tetap `AuthMode.remote`, `DataMode.remote`, dan HTTPS. HTTP hanya untuk mock debug/staging.
- Jangan memasukkan token, password, atau header Authorization ke log, snapshot test, maupun dokumen.
- Pertahankan perilaku mode demo kecuali ketika test baru membuktikan bug demo.
- `401` mengakhiri sesi aktif tanpa retry token lama; `403 NO_SUBDISTRICT` mempertahankan sesi dan menampilkan pesan server tanpa retry.
- Test baru harus membuktikan skenario sebelum perbaikan (merah), lalu lulus setelah perubahan (hijau). Jalankan format dan analyzer setelah setiap kelompok tugas.
- Implementasi dilakukan pada branch kerja terisolasi, bukan langsung pada `main`; pilih cara penggabungan sesuai alur GitLab tim setelah seluruh gate lulus.

## Peta file dan tanggung jawab

| Area | File utama | Tanggung jawab |
|---|---|---|
| Identitas request | `lib/core/network/auth_session_tokens.dart`, `api_client.dart`, `auth_session_interceptor.dart` | Revisi sesi ditangkap saat request dibuat; error lama tidak memutus sesi baru. |
| Auth | `lib/core/auth/presentation/auth_controller.dart`, `lib/core/auth/data/remote_auth_repository.dart`, `lib/core/composition/app_composition.dart` | Alasan logout paksa, validasi profil, timeout login/restore. |
| Kontrak network | `lib/core/network/api_exceptions.dart`, `api_client.dart`, helper JSON baru | Respons HTML/teks ditangani sebagai kesalahan URL/API, bukan cast error. |
| State data | `lib/data/providers/{cabor,athlete,club}_providers.dart` | Guard sesi pada sukses/error dan item sesuai query terbaru. |
| Presentasi error | `lib/shared/remote_error_presentation.dart` dan halaman remote yang memakainya | Pesan dan tombol retry konsisten dengan `error_code`. |
| Mock | `scripts/mock_server/mock_session_store.dart`, `mock_data.dart`, `sicabor_mock_server.dart` | Token diterbitkan dan kedaluwarsa menurut jam injeksi. |
| Data UI | `lib/features/home_page.dart`, `sports_page.dart`, `sport_detail/sport_detail_page.dart`, `athlete_detail/athlete_detail_page.dart`, `club_detail/club_detail_page.dart` | Angka, pencarian, personel, dan aksi sesuai kontrak. |
| Panduan | `scripts/mock_server/README.md`, `docs/project-status.md` | Jalur pengujian HTTP mock dan status implementasi yang terverifikasi. |

## Milestone 5.1 — integritas sesi dan kontrak error

### Task 1: Kaitkan 401/403 ke revisi sesi request

**Files:** Modify `lib/core/network/auth_session_tokens.dart`, `lib/core/network/api_client.dart`, `lib/core/network/auth_session_interceptor.dart`, `lib/core/auth/presentation/auth_controller.dart`; test `test/core/network/auth_session_interceptor_test.dart`, `test/integration/session_expiry_flow_test.dart`.

**Interfaces:** `AuthSessionTokens.revision → int`; `AuthSessionInterceptor.sessionRevisionExtraKey → String`; callback `void Function({String? errorCode, String? serverMessage})`; request bertoken membawa revisi hanya pada `RequestOptions.extra`.

- [ ] **Step 1: Tulis test gagal.** Tambahkan dua skenario pada `session_expiry_flow_test.dart`: A memulai request, A logout, B login, respons A `401` atau `403 MEMBER_INACTIVE` tiba; `AuthSignedIn.user` dan token B tetap. Tambahkan test bahwa dua 401 milik B tetap memicu satu logout.

```dart
final revisionA = tokens.revision;
tokens.clear();
tokens.replace(accessToken: 'token-B', sessionToken: 'token-B');
expect(tokens.revision, greaterThan(revisionA));
// Selesaikan Completer<ResponseBody> request A dengan 401.
expect(container.read(authControllerProvider), isA<AuthSignedIn>());
expect(tokens.accessToken, 'token-B');
```

- [ ] **Step 2: Jalankan test baru.** `flutter test --no-pub test/core/network/auth_session_interceptor_test.dart test/integration/session_expiry_flow_test.dart`; pastikan skenario A→B gagal pada source awal.
- [ ] **Step 3: Implementasi minimal.** Revisi naik pada setiap `replace`/`clear`. `ApiClient._optionsWithAuth` menyimpan revisi saat menyisipkan Bearer; `AuthSessionInterceptor.onError` mengabaikan callback bila revisi request tidak sama dengan revisi aktif. Update callback di `AuthController.build` agar menerima pesan walau pemakaian pesannya diselesaikan pada Task 2.

```dart
int _revision = 0;
int get revision => _revision;
void clear() {
  _accessToken = null;
  _sessionToken = null;
  _revision++;
}
void replace({String? accessToken, String? sessionToken}) {
  _accessToken = accessToken;
  _sessionToken = sessionToken;
  _revision++;
}
// Saat menyusun request bertoken:
final extra = <String, dynamic>{...?options.extra};
extra[AuthSessionInterceptor.sessionRevisionExtraKey] = _tokens.revision;
// Sebelum mengakhiri sesi:
if (requestRevision != tokens.revision) return handler.next(err);
```

- [ ] **Step 4: Verifikasi.** Jalankan dua file test di atas dan `flutter analyze --no-pub`; pastikan request aktif tetap memicu logout dan request lama tidak.
- [ ] **Step 5: Commit.** Stage hanya empat file produksi dan dua file test tugas ini; commit `fix(auth): ignore unauthorized responses from old sessions`.

### Task 2: Pertahankan alasan logout paksa dan pesan 403

**Files:** Modify `lib/core/auth/presentation/auth_controller.dart`, `lib/features/login_page.dart`, `home_page.dart`, `profile_page.dart`, `sports_page.dart`, `clubs_page.dart`, `sport_detail/sport_detail_page.dart`, `athlete_detail/athlete_detail_page.dart`, `club_detail/club_detail_page.dart`; create `lib/shared/remote_error_presentation.dart`; test `test/auth_controller_test.dart`, `test/login_page_test.dart`, `test/profile_page_test.dart`, `test/sports_page_test.dart`, `test/home_page_test.dart`, `test/clubs_page_test.dart`, `test/club_detail_test.dart`, `test/athlete_detail_test.dart`, `test/sport_detail_test.dart`.

**Interfaces:** `handleUnauthorizedSession({String? errorCode, String? serverMessage})`; `RemoteErrorPresentation describeRemoteError(Object error)` menghasilkan `message` dan `canRetry`. `ForbiddenException.errorCode/serverMessage` tetap sumber kode/pesan data.

- [ ] **Step 1: Tulis test gagal.** `MEMBER_INACTIVE` yang datang saat signed-in harus menghasilkan `AuthSignedOut.errorMessage == message` server; 401 harus memberi pesan sesi berakhir; logout manual tidak membawa pesan. Widget Profil/Cabor yang mendapat `ForbiddenException(..., 'NO_SUBDISTRICT', 'Akun belum memiliki kecamatan')` harus menampilkan kalimat itu, arahan admin, dan tidak menampilkan tombol retry.

```dart
expect(describeRemoteError(
  const ForbiddenException('Akun belum memiliki kecamatan',
      'NO_SUBDISTRICT', 'Akun belum memiliki kecamatan'),
).canRetry, isFalse);
expect(find.textContaining('Akun belum memiliki kecamatan'), findsOneWidget);
expect(find.text('Coba Lagi'), findsNothing);
```

- [ ] **Step 2: Jalankan file test terkait.** `flutter test --no-pub test/auth_controller_test.dart test/login_page_test.dart test/profile_page_test.dart test/sports_page_test.dart`; catat test baru yang gagal.
- [ ] **Step 3: Implementasi minimal.** Teruskan `errorCode`/`serverMessage` dari interceptor ke controller. Simpan alasan hanya untuk logout paksa sesi yang aktif dan tempelkan saat `_runLogout` mempublikasikan `AuthSignedOut`; clear alasan saat login berikutnya. Gunakan pemetaan presentasi pada Beranda, Profil, Cabor, daftar/detail Atlet, daftar/detail Klub. Untuk timeout/offline/5xx, tetap izinkan retry; untuk `NO_SUBDISTRICT`, jangan.

```dart
final class RemoteErrorPresentation {
  const RemoteErrorPresentation(this.message, {required this.canRetry});
  final String message;
  final bool canRetry;
}
RemoteErrorPresentation describeRemoteError(Object error) => switch (error) {
  ForbiddenException(errorCode: 'NO_SUBDISTRICT', :final serverMessage) =>
    RemoteErrorPresentation(
      '${serverMessage ?? 'Akun belum memiliki kecamatan.'} Hubungi admin kabupaten.',
      canRetry: false),
  ApiTimeoutException() || NetworkOfflineException() || ServerErrorException() =>
    const RemoteErrorPresentation('Koneksi ke server terganggu.', canRetry: true),
  _ => const RemoteErrorPresentation('Gagal memuat data.', canRetry: true),
};
```

- [ ] **Step 4: Verifikasi.** Jalankan test controller dan widget yang diperbarui, termasuk `test/home_page_test.dart`, `test/clubs_page_test.dart`, `test/club_detail_test.dart`, `test/athlete_detail_test.dart`, `test/sport_detail_test.dart`; cek akun tetap signed-in pada `NO_SUBDISTRICT`.
- [ ] **Step 5: Commit.** Commit `fix(ui): explain sicabor authorization errors` beserta helper dan test.

### Task 3: Validasi profil auth dan batasi waktu login/restore

**Files:** Modify `lib/core/auth/data/remote_auth_repository.dart`, `lib/core/composition/app_composition.dart`; test `test/remote_auth_repository_test.dart`, `test/auth_controller_test.dart`, `test/app_environment_test.dart`, `test/api_readiness_auth_test.dart`.

**Interfaces:** `ProfileFetchFailedFailure` untuk respons profil tidak lengkap; `AccountNotKokFailure` atau `AccountInactiveFailure` untuk member profil yang tidak memenuhi peran/status; `Dio(BaseOptions(connectTimeout: ..., receiveTimeout: ...))` untuk auth.

- [ ] **Step 1: Tulis test gagal.** Mutasi fixture respons `/profile` pada jalur login dan restore: hapus `member`, `scope`, atau `summary`; ubah `member.id` menjadi 0, `type` bukan `admin_kok`, `status` bukan 1, serta `subdistrict_id` menjadi 0. Repository harus menghasilkan kegagalan; test controller memastikan token tidak disimpan dan sesi tidak menjadi signed-in. Test composition memeriksa timeout `Dio` auth lewat adapter yang menangkap `RequestOptions` atau timeout request terkontrol.

```dart
final brokenProfile = Map<String, dynamic>.from(validProfile)
  ..remove('scope');
final result = await repository.restoreSession('token-valid');
expect(result.isSuccess, isFalse);
// Di test controller: login dengan profil rusak tidak menulis secure storage.
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/remote_auth_repository_test.dart test/auth_controller_test.dart test/app_environment_test.dart test/api_readiness_auth_test.dart`; pastikan fixture rusak belum ditolak dengan benar.
- [ ] **Step 3: Implementasi minimal.** Validasi Map mentah sebelum `SicaborProfileResponse.fromJson`, lalu validasi nilai DTO. Tolak `success:true` tanpa identitas/scope/summary wajib. Buat auth `Dio` dengan `BaseOptions` yang memakai timeout profile; pertahankan pemetaan `NetworkTimeoutFailure` yang sudah ada.

```dart
final body = profileResponse.data;
if (body is! Map<String, dynamic> ||
    body['scope'] is! Map ||
    body['data'] is! Map ||
    (body['data'] as Map)['member'] is! Map ||
    (body['data'] as Map)['summary'] is! Map) {
  return const AuthResult.failed(ProfileFetchFailedFailure());
}
// Setelah DTO: id > 0, username/name tidak kosong, type admin_kok,
// status 1, subdistrictId > 0, subdistrictName tidak kosong.
final authDio = Dio(BaseOptions(
  connectTimeout: profile.connectTimeout,
  receiveTimeout: profile.receiveTimeout,
));
```

- [ ] **Step 4: Verifikasi.** Jalankan file test di atas dan `flutter analyze --no-pub`; pastikan demo auth tidak berubah.
- [ ] **Step 5: Commit.** Commit `fix(auth): validate profile before session commit`.

### Task 4: Deteksi respons non-JSON sebagai konfigurasi API

**Files:** Modify `lib/core/network/api_exceptions.dart`, `lib/core/network/api_client.dart`, `lib/core/auth/data/remote_auth_repository.dart`, `lib/shared/remote_error_presentation.dart`; create `lib/core/network/json_response_guard.dart`; test `test/api_client_test.dart`, `test/remote_auth_repository_test.dart`, `test/data/remote_services_test.dart`, `test/sports_page_test.dart`.

**Interfaces:** `ApiConfigurationException extends ApiException`; `void requireJsonContentType(Headers headers)` menerima `application/json` dan subtype `+json`; 401 tetap dipetakan berdasarkan status lebih dulu.

- [ ] **Step 1: Tulis test gagal.** Respons 200 `text/html` pada `/profile` dan `/cabor` serta 404 HTML karena URL salah harus menjadi `ApiConfigurationException`, bukan `TypeError`/`NotFoundException`; 401 tetap menjadi `UnauthorizedException`. Auth login/restore dengan HTML menghasilkan kegagalan profil/konfigurasi yang ramah, tanpa menyimpan sesi.

```dart
expect(
  () => client.request<dynamic>('/cabor', method: 'GET'),
  throwsA(isA<ApiConfigurationException>()),
);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/api_client_test.dart test/remote_auth_repository_test.dart test/data/remote_services_test.dart`; pastikan jalur HTML gagal seperti yang dideskripsikan audit.
- [ ] **Step 3: Implementasi minimal.** Periksa `Headers.contentTypeHeader` setelah respons sukses dan pada error non-401 yang mempunyai body non-JSON; pertahankan urutan 401 → sesi, lalu non-JSON → konfigurasi, lalu pemetaan 403/404/5xx. Auth repository memakai guard yang sama sebelum DTO parse; UI memakai `RemoteErrorPresentation(canRetry:false)` untuk exception ini.

```dart
final class ApiConfigurationException extends ApiException {
  const ApiConfigurationException()
      : super('Respons server bukan JSON. Periksa alamat API.');
}
void requireJsonContentType(Headers headers) {
  final contentType = headers.value(Headers.contentTypeHeader)?.toLowerCase();
  if (contentType == null ||
      !(contentType.contains('application/json') || contentType.contains('+json'))) {
    throw const ApiConfigurationException();
  }
}
```

- [ ] **Step 4: Verifikasi.** Test HTML/JSON dan `flutter analyze --no-pub`; pastikan 404 JSON detail tetap tampil sebagai “tidak ditemukan”.
- [ ] **Step 5: Commit.** Commit `fix(network): report non-json sicabor responses clearly`.

### Task 5: Tutup jalur error pagination lintas sesi

**Files:** Modify `lib/data/providers/cabor_providers.dart`, `athlete_providers.dart`, `club_providers.dart`; test `test/data/cabor_providers_session_test.dart`, `athlete_providers_session_test.dart`, `club_providers_session_test.dart`.

**Interfaces:** `contextAtStart` dan `expectedGen` yang sudah ada pada tiap controller dipakai sebelum seluruh penulisan state, termasuk `catch` pada `loadFirstPage` dan `loadMore`.

- [ ] **Step 1: Tulis test gagal.** Dalam satu `ProviderContainer`, mulai page pertama atau page berikut akun A dengan `Completer` service, ganti ke B, kemudian selesaikan A dengan error. Verifikasi state B tetap kosong atau memuat B, tanpa `error`/`loadMoreError` dari A. Jalankan untuk ketiga controller dan kedua metode.

```dart
final pendingA = Completer<PaginatedResult<Cabor>>();
// A memulai loadFirstPage; auth provider diganti ke B di container sama.
pendingA.completeError(StateError('request A gagal'));
await Future<void>.delayed(Duration.zero);
expect(container.read(caborPaginationProvider).error, isNull);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/data/cabor_providers_session_test.dart test/data/athlete_providers_session_test.dart test/data/club_providers_session_test.dart`; pastikan enam skenario baru gagal sebelum patch.
- [ ] **Step 3: Implementasi minimal.** Di setiap `catch`, setelah `ref.mounted`, baca `dataRequestContextProvider`; return bila berbeda dengan `contextAtStart` atau generation sudah berubah. Jangan mereset state B dari request A.

```dart
} catch (error) {
  if (!ref.mounted ||
      ref.read(dataRequestContextProvider) != contextAtStart ||
      expectedGen != _generation) return;
  state = state.copyWith(isLoading: false, error: error);
}
```

- [ ] **Step 4: Verifikasi.** Test ketiga provider, `test/data/pagination_race_test.dart`, dan `flutter analyze --no-pub`.
- [ ] **Step 5: Commit.** Commit `fix(data): ignore pagination failures from old sessions`.

**Gate 5.1:** Jalankan `flutter test --no-pub` dan `flutter analyze --no-pub`. Periksa manual dengan dua akun mock: logout A saat request tertunda, login B, dan lihat bahwa profil/daftar B tetap milik B. Jika gate gagal, selesaikan sebelum Task 6.

## Milestone 5.2 — fidelitas mock dan ketepatan tampilan

### Task 6: Jadikan token mock benar-benar diterbitkan dan kedaluwarsa

**Files:** Create `scripts/mock_server/mock_session_store.dart`; modify `scripts/mock_server/mock_data.dart`, `scripts/mock_server/sicabor_mock_server.dart`; test `test/scripts/mock_data_test.dart`, `test/scripts/sicabor_mock_server_test.dart`.

**Interfaces:** `MockSessionStore({DateTime Function()? clock})`, `issue(MockAccount account) → String`, `lookup(String token) → MockSessionLookup` dengan keadaan `valid`, `unknownOrExpired`, dan `memberMissing`. Lookup akun menggunakan resolver yang dapat diinjeksi pada test untuk mensimulasikan akun dihapus. Satu `SicaborMockServer` memiliki satu store; masa berlaku token tepat 24 jam.

- [ ] **Step 1: Tulis test gagal.** Login menghasilkan token yang dapat dipakai sebelum 24 jam; token buatan tangan dan token dari instance server lama menghasilkan 401 `INVALID_TOKEN`; waktu tepat `issuedAt + 24 jam` menghasilkan 401; akun yang dihapus setelah token diterbitkan menghasilkan 403 `MEMBER_NOT_FOUND`. Test dua instance terpisah tidak saling menerima token. Pastikan tidak ada password/header Authorization tercetak di startup/log.

```dart
var now = DateTime.utc(2026, 9, 23);
final sessions = MockSessionStore(clock: () => now);
final token = sessions.issue(account);
expect(sessions.lookup(token).status, MockSessionStatus.valid);
now = now.add(const Duration(hours: 24));
expect(sessions.lookup(token).status, MockSessionStatus.unknownOrExpired);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/scripts/mock_data_test.dart test/scripts/sicabor_mock_server_test.dart`; pastikan test penolakan token palsu/kedaluwarsa gagal pada source awal.
- [ ] **Step 3: Implementasi minimal.** Pindahkan `_activeTokens`, counter, dan fallback parsing token dari `MockData` ke store per instance. Gunakan generator byte acak kriptografis `Random.secure()` dan encode URL-safe; simpan ID akun, waktu terbit, dan waktu kedaluwarsa. Cek keberadaan akun lewat resolver setelah lookup token. Hapus password universal dari seluruh fixture dan pesan startup; hanya akun/kredensial sintetis mock yang terdokumentasi. Ubah default host CLI menjadi `127.0.0.1`, sementara `--host=0.0.0.0` tetap tersedia untuk uji HP fisik. Selaraskan help dan startup URL dengan alamat bind aktual.

```dart
final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
final token = base64UrlEncode(bytes);
_sessions[token] = MockSession(
  accountId: account.id,
  expiresAt: _clock().add(const Duration(hours: 24)),
);
// lookup: now >= expiresAt berarti INVALID_TOKEN (HTTP 401).
```

- [ ] **Step 4: Verifikasi.** Jalankan dua file test mock dan `flutter analyze --no-pub`; telusuri source/docs agar password universal dan fallback token tidak tersisa, tanpa mencetak nilainya ke output.
- [ ] **Step 5: Commit.** Commit `fix(mock): enforce issued expiring sessions` bersama test.

### Task 7: Uji alur HTTP remote dan benahi petunjuk menjalankan mock

**Files:** Create `test/integration/mock_http_flow_test.dart`; modify `scripts/mock_server/README.md`, `android/app/src/debug/AndroidManifest.xml`; test layanan remote yang sudah ada melalui `test/data/remote_services_test.dart` bila fixture perlu penyesuaian.

**Interfaces:** Test membuka `SicaborMockServer.start(host: '127.0.0.1', port: 0)` dan menggunakan `server.port` untuk `API_BASE_URL=http://127.0.0.1:<port>/api/v1/kok`. Android debug mengizinkan HTTP lokal; manifest main/release tetap tanpa cleartext opt-in.

- [ ] **Step 1: Tulis test gagal.** Melalui Dio/`ApiClient` sungguhan, login, `/profile`, lalu panggil `RemoteProfileService`, `RemoteCaborService`, `RemoteAthleteService`, dan `RemoteClubService`: paging Cabor melewati 25 item, detail Atlet/Klub cocok dengan daftar, dua akun mengembalikan kecamatan berbeda, serta token invalid/expired menghasilkan 401 dan `NO_SUBDISTRICT` menghasilkan 403. Tutup server di `tearDown`; jangan memakai port tetap atau koneksi internet. Tambahkan pemeriksaan README agar contoh startup menggunakan `DATA_MODE=remote`.

```dart
final server = SicaborMockServer();
await server.start(host: '127.0.0.1', port: 0, verbose: false);
addTearDown(server.stop);
final baseUrl = 'http://127.0.0.1:${server.port}/api/v1/kok';
// Buat deployment profile remote/remote dan jalankan layanan lewat baseUrl ini.
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/integration/mock_http_flow_test.dart test/data/remote_services_test.dart`; pastikan assertion kontrak/README baru gagal sebelum patch.
- [ ] **Step 3: Implementasi minimal.** Perbaiki mock sesuai perilaku yang dibuktikan test. README memuat perintah server, contoh `APP_ENV=staging`, `AUTH_MODE=remote`, `DATA_MODE=remote`, dan `API_BASE_URL` untuk desktop (`127.0.0.1`), Android emulator (`10.0.2.2`), serta HP fisik (IP LAN + `--host=0.0.0.0`); semua memakai port yang benar-benar tercetak saat startup, termasuk port fallback. Tambahkan `android:usesCleartextTraffic="true"` hanya pada `<application>` manifest debug untuk HTTP mock. Jelaskan production memerlukan HTTPS.

```text
flutter run --dart-define=APP_ENV=staging --dart-define=AUTH_MODE=remote \
  --dart-define=DATA_MODE=remote \
  --dart-define=API_BASE_URL=http://10.0.2.2:8088/api/v1/kok
```

- [ ] **Step 4: Verifikasi.** Test HTTP mock lulus, `flutter analyze --no-pub` lulus, dan contoh README dicoba pada emulator debug. Pastikan request halaman benar-benar masuk ke mock, bukan data demo; periksa manifest release/main tidak mengizinkan cleartext.
- [ ] **Step 5: Commit.** Commit `test(integration): exercise remote flows against local mock` bersama README dan manifest debug.

### Task 8: Koreksi arti angka Beranda dan cakupan grafik Cabor

**Files:** Modify `lib/features/home_page.dart`, `lib/features/sports_page.dart`; test `test/home_page_test.dart`, `test/sports_page_test.dart`.

**Interfaces:** `totalCaborFromClub` dilabeli “Cabor dengan klub”; `totalCaborFromAthlete` dilabeli “Cabor dengan atlet”. Grafik Cabor mengumumkan `items.length` dari `total` sesuai filter aktif dan bukan mengklaim seluruh cabor.

- [ ] **Step 1: Tulis test gagal.** Fixture `totalCaborFromClub=7`, `totalCaborFromAthlete=9`, `totalClub=20`, `totalAthlete=80` harus menampilkan empat label/angka sesuai makna. Cabor dengan 25 dari 40 item menampilkan “25 dari 40”, tanpa judul “Aktif” atau klaim pemeringkatan seluruh cabor. Remote Beranda tidak menunjukkan “Terakhir Dimuat” hasil `DateTime.now()` saat rebuild.

```dart
expect(find.textContaining('Cabor dengan klub'), findsWidgets);
expect(find.textContaining('Cabor dengan atlet'), findsWidgets);
expect(find.textContaining('25 dari 40'), findsOneWidget);
expect(find.textContaining('Terakhir Dimuat'), findsNothing);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/home_page_test.dart test/sports_page_test.dart`; pastikan label/cakupan salah tertangkap.
- [ ] **Step 3: Implementasi minimal.** Tukar hanya label yang salah, bukan field data. Pada grafik gunakan hasil halaman yang sudah dimuat dan tampilkan cakupannya; judul menjadi “Cabang Olahraga”. Pada Beranda remote tampilkan “Data SICABOR” sebagai sumber, sedangkan data demo boleh mempertahankan indikator demo. Jangan membuat timestamp atau agregasi baru yang belum disediakan API.

```dart
final chartScope = 'Berdasarkan cabor yang sudah dimuat '
    '(${state.items.length} dari ${state.total})';
```

- [ ] **Step 4: Verifikasi.** Jalankan dua widget test dan `flutter analyze --no-pub`; coba mode remote dengan hasil page pertama dan setelah `loadMore`.
- [ ] **Step 5: Commit.** Commit `fix(ui): label sicabor counts and chart scope accurately`.

### Task 9: Buang hasil filter lama dan batalkan debounce pencarian

**Files:** Modify `lib/data/providers/cabor_providers.dart`, `athlete_providers.dart`, `club_providers.dart`, `lib/features/clubs_page.dart`, `lib/features/sport_detail/sport_detail_page.dart`, `lib/features/club_detail/club_detail_page.dart`; test `test/data/pagination_race_test.dart`, `test/sports_page_test.dart`, `test/sport_detail_test.dart`, `test/clubs_page_test.dart`, `test/club_detail_test.dart`.

**Interfaces:** `loadFirstPage` untuk query/filter baru langsung mereset `items`, `total`, dan `hasMore` sebelum status loading; request lama tetap dipagari context/generation. Aksi hapus pencarian memanggil `Timer.cancel()` sebelum menerapkan query kosong.

- [ ] **Step 1: Tulis test gagal.** Saat query/filter berubah, halaman tidak menampilkan item/total query sebelumnya selama loading maupun setelah error. `loadMore` yang gagal tetap menampilkan item query saat ini. Ketik teks, hapus sebelum 500 ms, lalu maju waktu test melewati debounce: query akhir harus kosong dan hasil teks lama tidak kembali. Ulangi untuk daftar Klub, tab Atlet Cabor, dan tab Atlet Klub.

```dart
controller.loadFirstPage(search: 'voli');
expect(container.read(caborPaginationProvider).items, isEmpty);
expect(container.read(caborPaginationProvider).total, 0);
// Pada widget test, hapus field sebelum timer 500 ms dan pump > 500 ms.
expect(find.textContaining('hasil pencarian lama'), findsNothing);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/data/pagination_race_test.dart test/sports_page_test.dart test/sport_detail_test.dart test/clubs_page_test.dart test/club_detail_test.dart`; catat kasus yang merah.
- [ ] **Step 3: Implementasi minimal.** Reset state awal sebelum request filter/page pertama, lalu pertahankan context/generation guard pada sukses dan error. Pada handler clear setiap layar, `_debounce?.cancel()` dilakukan sebelum controller teks dikosongkan dan query kosong dikirim. Pastikan `dispose` juga membatalkan timer.

```dart
_debounce?.cancel();
searchController.clear();
ref.read(clubPaginationProvider.notifier).loadFirstPage(search: '');
```

- [ ] **Step 4: Verifikasi.** Jalankan test race/widget di atas dan `flutter analyze --no-pub`; uji manual ketik-hapus cepat serta filter yang gagal di mode remote.
- [ ] **Step 5: Commit.** Commit `fix(data): keep lists aligned with current filters`.

### Task 10: Tampilkan identitas Atlet tanpa aksi kontak yang tidak tersedia

**Files:** Modify `lib/features/sport_detail/sport_detail_page.dart`, `lib/features/athlete_detail/athlete_detail_page.dart`; test `test/sport_detail_test.dart`, `test/athlete_detail_test.dart`.

**Interfaces:** Kartu atlet remote menampilkan `Athlete.code` dan `Athlete.statusLabel`; detail atlet remote menampilkan nama/kode klub sebagai informasi, tetapi CTA kontak hanya muncul bila sumber data benar-benar memiliki tujuan kontak yang dapat dibuka. Mode demo mempertahankan CTA demo bila fixture demo menyediakan datanya.

- [ ] **Step 1: Tulis test gagal.** Fixture atlet remote berkode `ATL-001` dan status “Aktif” menampilkan keduanya di kartu. Detail dengan klub bernama tetapi tanpa nomor/URL kontak menampilkan klub, tanpa tombol “Hubungi pengurus klub”. Fixture demo yang memiliki kontak tetap menampilkan aksinya.

```dart
expect(find.text('ATL-001'), findsOneWidget);
expect(find.text('Aktif'), findsWidgets);
expect(find.text('Hubungi pengurus klub'), findsNothing);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/sport_detail_test.dart test/athlete_detail_test.dart`; pastikan jalur remote gagal sesuai temuan audit.
- [ ] **Step 3: Implementasi minimal.** Render code dan status pada kartu menggunakan field model yang sudah ada. Pada detail, gunakan nilai kontak eksplisit yang sudah tersedia di model demo; mode remote tanpa nilai kontak tidak membuat nomor/URL sintetis. Tetap tampilkan identitas klub yang diberikan API.

```dart
if (athlete.code.trim().isNotEmpty) Text(athlete.code);
if (athlete.statusLabel.trim().isNotEmpty) Text(athlete.statusLabel);
```

- [ ] **Step 4: Verifikasi.** Dua widget test dan `flutter analyze --no-pub`; uji atlet remote yang punya klub tetapi tidak punya kontak.
- [ ] **Step 5: Commit.** Commit `fix(athlete): show status and avoid unsupported contact action`.

### Task 11: Bedakan data pengurus Klub, hitungan atlet, dan buka berkas SK

**Files:** Modify `lib/features/club_detail/club_detail_page.dart`, `club_people_tab.dart`, `club_document_tab.dart`, `lib/features/clubs_page.dart`, `pubspec.yaml`, `pubspec.lock`; test `test/club_detail_test.dart`, `test/club_detail_widgets_test.dart`, `test/clubs_page_test.dart`.

**Interfaces:** `management.dataAvailable == false` → “Belum tercatat di sistem”; `true` + daftar kosong → empty state biasa. URL SK valid `http`/`https` dibuka dengan `url_launcher` `LaunchMode.externalApplication`; kegagalan membuka menawarkan salin tautan. Hitungan hasil filter lokal hanya tampil setelah loading filter selesai.

- [ ] **Step 1: Tulis test gagal.** Buat tiga fixture: `dataAvailable=false`, `true` tetapi kosong, dan `true` dengan pengurus. Pastikan dua keadaan kosong berbeda. Pada klub dengan `totalAthleteInClub=100` tetapi daftar lokal berjumlah 6, label menjelaskan 100 adalah total seluruh kecamatan dan 6 adalah hasil filter saat ini setelah loading; jangan menyimpulkan selisihnya hanya lintas wilayah. Test URL SK valid memanggil launcher eksternal; URL invalid/gagal launch menampilkan opsi salin.

```dart
expect(find.text('Belum tercatat di sistem'), findsOneWidget);
expect(find.textContaining('seluruh kecamatan'), findsOneWidget);
expect(find.textContaining('hasil filter'), findsOneWidget);
```

- [ ] **Step 2: Jalankan test.** `flutter test --no-pub test/club_detail_test.dart test/club_detail_widgets_test.dart test/clubs_page_test.dart`; pastikan empty state, label, dan pembukaan SK gagal seperti audit.
- [ ] **Step 3: Implementasi minimal.** Cabang UI personel berdasarkan flag `dataAvailable`, bukan hanya panjang daftar. Gunakan `state.total` untuk hasil filter lokal saat `!isLoading`; jelaskan `totalAthleteInClub` sebagai angka API lintas kecamatan. Tambahkan `url_launcher`; pisahkan aksi buka URL menjadi fungsi yang dapat diinjeksi di widget test. Validasi scheme dan host sebelum `launchUrl`; tangkap `false`/exception untuk menawarkan salin lewat `Clipboard.setData`.

```dart
final uri = Uri.tryParse(documentUrl);
final canOpen = uri != null &&
    (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
if (canOpen) {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) showCopyLinkAction(documentUrl);
} else {
  showCopyLinkAction(documentUrl);
}
```

- [ ] **Step 4: Verifikasi.** Jalankan test Klub, `flutter pub get`, dan `flutter analyze --no-pub`; coba URL SK di emulator debug, termasuk kegagalan aplikasi browser.
- [ ] **Step 5: Commit.** Commit `fix(club): clarify coverage and open sk documents` bersama lockfile.

### Task 12: Gerbang penerimaan lokal dan pembaruan status

**Files:** Modify `docs/project-status.md`, `docs/README.md` hanya untuk hasil yang benar-benar terverifikasi; no production code changes pada task ini. Gunakan `test/integration/mock_http_flow_test.dart` dan test Milestone 5.1/5.2 sebagai bukti.

**Interfaces:** Status proyek menyebut Milestone 5.1/5.2 selesai hanya bila seluruh acceptance di desain lulus; kesiapan API resmi tetap menunggu URL, kredensial uji, dan validasi kontrak nyata.

- [ ] **Step 1: Tambah checklist penerimaan terukur.** Dalam dokumen status, catat hasil uji dua akun, token invalid/expired, restart server, paging >25, filter/debounce, 403 khusus, pembukaan SK, dan smoke Android debug. Jangan menandai hasil sebelum uji dijalankan.
- [ ] **Step 2: Jalankan verifikasi penuh.** `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test scripts/mock_server`, `flutter analyze --no-pub`, `flutter test --no-pub --reporter compact`, dan `git diff --check`. Jika formatter mendeteksi file lama di luar scope, format hanya file yang disentuh dan catat pengecualian secara spesifik.
- [ ] **Step 3: Smoke manual.** Jalankan mock dengan host/port yang sesuai lalu aplikasi staging remote/remote di emulator Android; login, buka ulang aplikasi, Beranda, Cabor, Atlet, Klub, SK, logout. Uji desktop atau emulator dengan server mati untuk timeout/offline; bila ada HP fisik, gunakan `--host=0.0.0.0` hanya selama tes. Catat perintah, platform, dan hasil tanpa mencatat kredensial.
- [ ] **Step 4: Cocokkan desain.** Telusuri semua kriteria “5.1 selesai” dan “5.2 selesai” dalam spec; bila satu belum terpenuhi, perbaiki task terkait dan ulangi gate yang relevan. Tulis hasil akhir, batasan API resmi, dan pekerjaan Milestone 6 di status proyek.
- [ ] **Step 5: Commit.** Commit `docs: record milestone 5.1 and 5.2 verification` setelah seluruh bukti tersedia. Buka merge request ke GitLab `main` sesuai proses tim; jangan menganggap Play Store siap hanya karena mock lokal lulus.


# API Readiness SICABOR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax - [ ] for tracking.

**Goal:** Menyiapkan aplikasi Flutter KOK agar seluruh data UI memiliki kontrak model/repository/provider yang siap dipetakan ke SICABOR, dengan HTTP/auth boundary yang fail-closed dan scope data tetap mengikuti kecamatan pengguna.

**Architecture:** Pertahankan fetchScope() untuk kompatibilitas dashboard, lalu tambahkan query granular pada KokRepository dan provider yang menjaga konteks sesi. DemoKokRepository menjadi adapter lengkap untuk fixture lokal, sedangkan adapter remote menggunakan ApiClient tetapi menolak operasi sampai endpoint resmi tersedia. UI hanya membaca model/provider dan tidak menambahkan cache offline atau guard yang menyembunyikan tab Cabor, Klub, dan Anggota.

**Tech Stack:** Flutter 3.44.4, Dart 3.12.2, Riverpod 3, Dio 5, Freezed 3, JSON Serializable, SharedPreferences, Flutter Secure Storage.

**Spec:** docs/superpowers/specs/2026-09-12-api-readiness-design.md

## Global Constraints

- Jangan menebak URL, HTTP method, payload, response envelope, pagination, atau nama field SICABOR yang belum didokumentasikan tim.
- Mode demo harus tetap berjalan dengan fixture lokal; mode remote harus fail-closed melalui error endpoint belum tersedia.
- Scope data harus berasal dari AuthSignedIn.user.scope; otorisasi lintas kecamatan tetap tanggung jawab backend.
- Tab Cabor, Klub, dan Anggota tetap terlihat dan dapat dibuka oleh sesi terautentikasi; hasPermission tidak dipakai untuk menyembunyikan tab tersebut.
- Tidak menambahkan Drift, Hive, SQLite, atau cache offline sebelum keputusan offline-first tersedia.
- Setiap production code baru diawali test yang gagal, lalu dibuat minimal sampai test hijau.
- File Freezed/JSON generated tidak diedit manual; regenerasikan dengan build_runner.
- Jika Git tetap diblokir sandbox saat membuat index.lock, jangan mengubah .git; lanjutkan perubahan di checkout aktif dan laporkan commit yang perlu dibuat pengguna.

---

### Task 1: Perluas kontrak model dan serialization

**Files:**

- Modify: lib/data/models.dart
- Modify: lib/core/auth/domain/user_principal.dart
- Generate: lib/data/models.freezed.dart dan lib/data/models.g.dart
- Test: test/api_readiness_models_test.dart
- Test: test/user_principal_test.dart

**Interfaces:**

- Club menambah phone, email, address, dan @Default(<ClubDocument>[]) List<ClubDocument> documents.
- ClubDocument memiliki id, name, status, fileUrl, uploadedAt, dan verifiedAt.
- SportPerson menambah nik, birthPlace, birthDate, address, milestones, requiredDocuments, dan completedDocuments.
- Milestone memiliki year, title, dan description.
- CommitteeMember menambah phone, email, dan photoUrl.
- KokSnapshot menambah HelpdeskContact? helpdesk.
- HelpdeskContact memiliki whatsapp, phone, email, address, dan operationalHours.
- UserPrincipal menyediakan Map<String, dynamic> toJson() dan factory UserPrincipal.fromJson(dynamic value).

- [ ] **Step 1: Write the failing model tests.** Uji field baru lewat JSON supaya red phase memverifikasi kontrak serialization.

~~~dart
test('Club membaca kontak dan dokumen dari JSON SICABOR', () {
  final club = Club.fromJson({
    'id': 'garuda',
    'name': 'Klub Garuda Muda',
    'sport': 'Sepak Bola',
    'village': 'Pakuwon',
    'phone': '081234567890',
    'email': 'garuda@example.test',
    'address': 'Jl. Pakuwon',
    'documents': [
      {
        'id': 'doc-1',
        'name': 'SK Klub',
        'status': 'verified',
        'fileUrl': 'https://example.test/doc-1.pdf',
        'uploadedAt': '2026-01-10T08:00:00.000Z',
        'verifiedAt': '2026-01-11T08:00:00.000Z',
      },
    ],
  });

  expect(club.toJson()['phone'], '081234567890');
  expect((club.toJson()['documents'] as List).single['status'], 'verified');
});

test('field opsional mempertahankan default list kosong', () {
  final person = SportPerson.fromJson({
    'id': 'p-1',
    'name': 'Nama Atlet',
    'clubId': 'garuda',
    'role': 'Atlet',
    'group': 'U-18',
  });
  expect(person.toJson()['milestones'], isEmpty);
  expect(person.toJson()['requiredDocuments'], isEmpty);
});
~~~

- [ ] **Step 2: Run the model tests and confirm red.**

Run: flutter test test/api_readiness_models_test.dart -r expanded

Expected: FAIL because the new fields/classes are not present or are not serialized.

- [ ] **Step 3: Add the Freezed models and JSON factories.** Pertahankan field lama dan letakkan field baru sebagai optional/default sesuai interface. Gunakan DateTime? untuk timestamp dan String untuk status agar nilai status baru dari backend tidak terpotong oleh enum client.

- [ ] **Step 4: Add strict UserPrincipal JSON conversion.** Terima hanya object JSON, validasi string wajib tidak kosong, parse scope melalui AccessScope.fromJson, terima permissions sebagai list string, dan serialisasikan permissions sebagai list deterministik. Payload corrupt harus melempar FormatException tanpa membuat principal parsial.

- [ ] **Step 5: Regenerate generated sources and run the tests.**

Run: flutter pub run build_runner build --delete-conflicting-outputs

Run: flutter test test/api_readiness_models_test.dart test/user_principal_test.dart -r expanded

Expected: PASS.

- [ ] **Step 6: Commit the model contract.**

~~~powershell
git add lib/data/models.dart lib/data/models.freezed.dart lib/data/models.g.dart lib/core/auth/domain/user_principal.dart test/api_readiness_models_test.dart test/user_principal_test.dart
git commit -m "feat: expand API-ready domain models"
~~~

---

### Task 2: Perkaya fixture demo dan pecah kontrak repository

**Files:**

- Modify: lib/data/kok_repository.dart
- Modify: lib/data/demo_kok_repository.dart
- Test: test/api_readiness_repository_test.dart
- Update implementers: test/session_scope_test.dart dan test double repository lain yang gagal compile

**Interfaces:**

Tambahkan method berikut tanpa menghapus fetchScope():

~~~dart
Future<List<Club>> fetchClubs(
  AccessScope scope, {
  String? sport,
  String? query,
  RequestCancellation? cancellation,
});

Future<Club> fetchClubDetail(String clubId, {RequestCancellation? cancellation});

Future<List<SportPerson>> fetchClubMembers(
  String clubId, {
  String? role,
  RequestCancellation? cancellation,
});

Future<SportPerson> fetchPersonDetail(
  String personId, {
  RequestCancellation? cancellation,
});

Future<List<CommitteeMember>> fetchCommittee(
  AccessScope scope, {
  RequestCancellation? cancellation,
});

Future<HelpdeskContact?> fetchHelpdesk({RequestCancellation? cancellation});
~~~

Definisikan KokResourceNotFoundException untuk ID klub/orang yang tidak ada; UnsupportedScopeException tetap dipakai untuk scope yang tidak didukung.

- [ ] **Step 1: Write failing repository tests.** Uji filter cabor/query, lookup detail, filter role, committee per scope, helpdesk, dan cancellation.

~~~dart
test('fetchClubs menerapkan scope, filter cabor, dan query', () async {
  final repo = DemoKokRepository(simulateLatency: false);
  final clubs = await repo.fetchClubs(
    garutKotaScope,
    sport: 'Sepak Bola',
    query: 'garuda',
  );
  expect(clubs.map((club) => club.id), ['garuda']);
  expect(clubs.single.phone, isNotNull);
});

test('fetchClubMembers dapat difilter berdasarkan role', () async {
  final members = await DemoKokRepository(simulateLatency: false)
      .fetchClubMembers('garuda', role: 'Pelatih');
  expect(members, isNotEmpty);
  expect(members.every((person) => person.role == 'Pelatih'), isTrue);
});
~~~

- [ ] **Step 2: Run the repository tests and confirm red.**

Run: flutter test test/api_readiness_repository_test.dart -r expanded

Expected: FAIL because KokRepository and DemoKokRepository do not expose the granular methods.

- [ ] **Step 3: Implement the interface and demo queries.** Reuse existing scope builders, check cancellation before/after latency, apply case-insensitive trimmed query matching to club name/sport/village, and return defensive list copies. Detail methods melempar KokResourceNotFoundException untuk ID tidak dikenal.

- [ ] **Step 4: Enrich demo fixture data.** Add representative phone/email/address/documents to clubs, birth/detail/milestone/document lists to representative people, contacts to committee members, and a helpdesk object to each snapshot. Keep all existing record counts and scope IDs unchanged.

- [ ] **Step 5: Run repository and regression tests.**

Run: flutter test test/api_readiness_repository_test.dart test/repository_test.dart test/session_scope_test.dart -r expanded

Expected: PASS.

- [ ] **Step 6: Commit the repository contract and fixture.**

~~~powershell
git add lib/data/kok_repository.dart lib/data/demo_kok_repository.dart test/api_readiness_repository_test.dart test/session_scope_test.dart
git commit -m "feat: add granular KOK repository queries"
~~~

---

### Task 3: Tambahkan provider granular dengan guard sesi

**Files:**

- Create: lib/data/providers/club_providers.dart
- Modify: lib/data/providers/snapshot_provider.dart only if shared context/helper extraction is needed
- Test: test/api_readiness_providers_test.dart

**Interfaces:**

~~~dart
final clubDetailProvider = FutureProvider.family<Club, String>(
  (ref, clubId) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) throw const SessionRequiredException();
    final cancellation = RequestCancellationController();
    ref.onDispose(() => cancellation.cancel('Provider disposed'));
    final result = await ref.read(repositoryProvider).fetchClubDetail(
      clubId,
      cancellation: cancellation.token,
    );
    cancellation.token.throwIfCancelled();
    if (ref.read(dataRequestContextProvider) != context) {
      throw const RequestCancelledException('Stale granular response rejected');
    }
    return result;
  },
);

final clubMembersProvider = FutureProvider.family<
  List<SportPerson>,
  ({String clubId, String? role})
>((ref, params) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) throw const SessionRequiredException();
  final cancellation = RequestCancellationController();
  ref.onDispose(() => cancellation.cancel('Provider disposed'));
  final result = await ref.read(repositoryProvider).fetchClubMembers(
    params.clubId,
    role: params.role,
    cancellation: cancellation.token,
  );
  cancellation.token.throwIfCancelled();
  if (ref.read(dataRequestContextProvider) != context) {
    throw const RequestCancelledException('Stale granular response rejected');
  }
  return result;
});

final personDetailProvider = FutureProvider.family<SportPerson, String>(
  (ref, personId) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) throw const SessionRequiredException();
    final cancellation = RequestCancellationController();
    ref.onDispose(() => cancellation.cancel('Provider disposed'));
    final result = await ref.read(repositoryProvider).fetchPersonDetail(
      personId,
      cancellation: cancellation.token,
    );
    cancellation.token.throwIfCancelled();
    if (ref.read(dataRequestContextProvider) != context) {
      throw const RequestCancelledException('Stale granular response rejected');
    }
    return result;
  },
);

final committeeProvider = FutureProvider<List<CommitteeMember>>((ref) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) throw const SessionRequiredException();
  final cancellation = RequestCancellationController();
  ref.onDispose(() => cancellation.cancel('Provider disposed'));
  return ref.read(repositoryProvider).fetchCommittee(
    context.scope,
    cancellation: cancellation.token,
  );
});

final helpdeskProvider = FutureProvider<HelpdeskContact?>((ref) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) throw const SessionRequiredException();
  final cancellation = RequestCancellationController();
  ref.onDispose(() => cancellation.cancel('Provider disposed'));
  return ref.read(repositoryProvider).fetchHelpdesk(
    cancellation: cancellation.token,
  );
});
~~~

- [ ] **Step 1: Write failing provider tests.** Override dataRequestContextProvider and repositoryProvider dengan fake repository; assert method granular dan scope yang benar dipakai; ubah konteks saat request menunggu dan assert RequestCancelledException.

- [ ] **Step 2: Run the provider tests and confirm red.**

Run: flutter test test/api_readiness_providers_test.dart -r expanded

Expected: FAIL karena club_providers.dart dan provider-providernya belum ada.

- [ ] **Step 3: Implement provider request helpers.** Capture DataRequestContext sebelum request, buat RequestCancellationController, cancel pada provider dispose, panggil method repository, lalu bandingkan konteks saat ini sebelum return. Session-required, cancellation, unsupported-scope, not-found, dan state mismatch tidak boleh di-retry.

- [ ] **Step 4: Run provider and regression tests.**

Run: flutter test test/api_readiness_providers_test.dart test/session_scope_test.dart -r expanded

Expected: PASS.

- [ ] **Step 5: Commit granular providers.**

~~~powershell
git add lib/data/providers/club_providers.dart lib/data/providers/snapshot_provider.dart test/api_readiness_providers_test.dart
git commit -m "feat: add session-scoped granular data providers"
~~~

---

### Task 4: Tambahkan token session in-memory dan expose auth token

**Files:**

- Create: lib/core/network/auth_session_tokens.dart
- Modify: lib/core/auth/domain/auth_state.dart
- Modify: lib/core/auth/presentation/auth_controller.dart
- Modify: lib/core/composition/app_composition.dart
- Test: test/api_readiness_auth_test.dart

**Interfaces:**

~~~dart
final class AuthSessionTokens {
  String? get accessToken;
  String? get refreshToken;
  void replace({String? accessToken, String? refreshToken});
  void clear();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.user,
    required this.generation,
    this.accessToken,
  });
  final UserPrincipal user;
  final int generation;
  final String? accessToken;
}
~~~

- [ ] **Step 1: Write failing auth tests.** Login dan restore dengan fake repository yang mengembalikan accessToken 'access-1'; assert AuthSignedIn.accessToken, token bridge, refresh token persisten mengikuti AuthTokenStorage, dan logout membersihkan token in-memory.

- [ ] **Step 2: Run the auth tests and confirm red.**

Run: flutter test test/api_readiness_auth_test.dart -r expanded

Expected: FAIL because AuthSignedIn.accessToken dan token bridge belum ada.

- [ ] **Step 3: Implement token bridge dan composition wiring.** Buat constructor AppComposition tetap kompatibel dengan test lama dengan membuat AuthSessionTokens default saat tidak diberikan. Tambahkan sessionTokensProvider di dekat auth providers.

- [ ] **Step 4: Update every successful restore/login state assignment.** Isi AuthSignedIn dengan access token hasil repository, simpan refresh token hanya untuk sesi aktif, dan clear bridge saat logout. Jangan persist access token ke AuthTokenStorage.

- [ ] **Step 5: Run auth regression tests.**

Run: flutter test test/api_readiness_auth_test.dart test/auth_controller_test.dart test/auth_hardening_test.dart test/auth_hardening_remediation_test.dart -r expanded

Expected: PASS.

- [ ] **Step 6: Commit auth token exposure.**

~~~powershell
git add lib/core/network/auth_session_tokens.dart lib/core/auth/domain/auth_state.dart lib/core/auth/presentation/auth_controller.dart lib/core/composition/app_composition.dart test/api_readiness_auth_test.dart
git commit -m "feat: expose in-memory auth access tokens"
~~~

---

### Task 5: Siapkan deployment profile, exception taxonomy, dan Dio client

**Files:**

- Create: lib/core/network/api_exceptions.dart
- Create: lib/core/network/api_client.dart
- Modify: lib/core/config/deployment_profile.dart
- Test: test/api_client_test.dart
- Modify: test/app_environment_test.dart

**Interfaces:**

DeploymentProfile menambah apiBaseUrl, connectTimeout, dan receiveTimeout dengan default yang menjaga profile demo lama tetap compile. fromEnvironment() membaca API_BASE_URL, API_CONNECT_TIMEOUT_MS, dan API_RECEIVE_TIMEOUT_MS; mode remote memerlukan absolute http/https URL dan timeout positif.

~~~dart
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => '$runtimeType: $message';
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Sesi tidak sah'])
      : super(message, statusCode: 401);
}

final class ForbiddenException extends ApiException {
  const ForbiddenException([String message = 'Akses ditolak'])
      : super(message, statusCode: 403);
}

final class NotFoundException extends ApiException {
  const NotFoundException([String message = 'Data tidak ditemukan'])
      : super(message, statusCode: 404);
}

final class NetworkOfflineException extends ApiException {
  const NetworkOfflineException([String message = 'Tidak ada koneksi'])
      : super(message);
}

final class ServerErrorException extends ApiException {
  const ServerErrorException(String message, {int? statusCode})
      : super(message, statusCode: statusCode);
}

final class TimeoutException extends ApiException {
  const TimeoutException([String message = 'Request timeout']) : super(message);
}
~~~

ApiClient menerima AuthSessionTokens, callback Future<AuthResult> Function(String refreshToken) refreshSession, optional injected Dio untuk test, dan menyediakan request<T>() yang menerima RequestCancellation?.

- [ ] **Step 1: Write failing profile/exception/client tests.** Cover remote base URL validation, Bearer injection, one retry after 401, refresh single-flight untuk concurrent 401, cancellation mapping, dan status/network/timeout mapping.

- [ ] **Step 2: Run the network tests and confirm red.**

Run: flutter test test/api_client_test.dart test/app_environment_test.dart -r expanded

Expected: FAIL karena fields, exception classes, dan client belum ada.

- [ ] **Step 3: Implement DeploymentProfile configuration and validation.** Include new fields in equality, hashCode, dan toString; demo defaults tetap kosong/standard dan valid URL diwajibkan saat auth atau data mode remote. Update staging/production fixture test dengan apiBaseUrl 'https://api.example.test'.

- [ ] **Step 4: Implement exception mapping.** Map HTTP 401/403/404/5xx, Dio connection errors, dan Dio timeout types ke domain exceptions. Preserve cancellation sebagai RequestCancelledException.

- [ ] **Step 5: Implement Dio client.** Configure BaseOptions dari profile, inject Authorization: Bearer <accessToken>, skip auth untuk refresh request, serialize refreshes melalui satu future, retry original request sekali dengan token baru, dan reject setelah refresh failure tanpa looping.

- [ ] **Step 6: Run network and regression tests.**

Run: flutter test test/api_client_test.dart test/app_environment_test.dart test/auth_controller_test.dart -r expanded

Expected: PASS.

- [ ] **Step 7: Commit network infrastructure.**

~~~powershell
git add lib/core/network/api_exceptions.dart lib/core/network/api_client.dart lib/core/config/deployment_profile.dart test/api_client_test.dart test/app_environment_test.dart
git commit -m "feat: add configurable Dio API client"
~~~

---

### Task 6: Buat remote adapter fail-closed dan wiring composition

**Files:**

- Create: lib/core/auth/data/remote_auth_repository.dart
- Create: lib/data/remote_kok_repository.dart
- Modify: lib/core/composition/app_composition.dart
- Test: test/remote_adapters_test.dart
- Modify: test/app_environment_test.dart

**Interfaces:**

RemoteAuthRepository mengimplementasikan seluruh AuthRepository. RemoteKokRepository mengimplementasikan seluruh KokRepository. Setiap operasi remote melempar UnimplementedError dengan pesan endpoint SICABOR belum dikonfigurasi, tanpa memanggil path buatan.

- [ ] **Step 1: Write failing adapter tests.** Assert setiap method remote melempar UnimplementedError, demo composition tetap memakai adapter demo, staging remote auth memakai RemoteAuthRepository, dan production remote/remote membangun kedua adapter dengan ApiClient.

- [ ] **Step 2: Run adapter tests and confirm red.**

Run: flutter test test/remote_adapters_test.dart test/app_environment_test.dart -r expanded

Expected: FAIL karena adapter belum ada dan composition masih melempar sebelum construction.

- [ ] **Step 3: Implement remote adapter boundaries.** Simpan ApiClient yang di-inject untuk mapping endpoint kelak, tetapi throw sebelum request. Di composition, buat satu client dan wire refresh melalui late-bound callback ke RemoteAuthRepository.refreshToken; ini menjaga endpoint tetap tidak ditebak.

- [ ] **Step 4: Replace fail-closed composition throws with adapter construction.** Profile validation tetap dijalankan pertama. Demo mode tidak berubah; remote mode membuat placeholder adapter dan expose apiClient pada AppComposition.

- [ ] **Step 5: Run adapter, auth, and environment tests.**

Run: flutter test test/remote_adapters_test.dart test/app_environment_test.dart test/auth_controller_test.dart -r expanded

Expected: PASS.

- [ ] **Step 6: Commit adapters.**

~~~powershell
git add lib/core/auth/data/remote_auth_repository.dart lib/data/remote_kok_repository.dart lib/core/composition/app_composition.dart test/remote_adapters_test.dart test/app_environment_test.dart
git commit -m "feat: add fail-closed remote repository adapters"
~~~

---

### Task 7: Hilangkan hardcoded mock dari UI

**Files:**

- Modify: lib/features/login_page.dart
- Modify: lib/features/athlete_detail/athlete_detail_page.dart
- Modify: lib/features/club_detail/club_document_tab.dart
- Modify: lib/features/profile_page.dart
- Update tests: test/login_page_test.dart, test/athlete_detail_test.dart, test/profile_page_test.dart, dan test club detail terkait

**Interfaces:**

- Login merender tombol Pilih Akun Demo hanya saat profile.authMode == AuthMode.demo.
- Detail atlet menggunakan SportPerson.milestones, birthDate, birthPlace, address, dan Club.phone/email/address; field kosong memakai - atau empty state.
- Tab dokumen merender Club.documents; daftar kosong menampilkan pesan data dokumen belum tersedia, bukan membuat kategori SK Klub/Kepengurusan baru.
- Helpdesk menerima HelpdeskContact? dari KokSnapshot.helpdesk; nomor, email, alamat, dan jam layanan berasal dari model.

- [ ] **Step 1: Write failing widget tests.** Buat fixture berisi milestone, kontak klub, dua dokumen berbeda status, dan helpdesk khusus; assert teksnya tampil. Buat remote composition test yang memastikan tombol akun demo tidak tampil. Uji empty state dokumen/helpdesk tanpa data.

- [ ] **Step 2: Run focused UI tests and confirm red.**

Run: flutter test test/login_page_test.dart test/athlete_detail_test.dart test/profile_page_test.dart test/club_detail_widgets_test.dart -r expanded

Expected: FAIL karena widget masih membaca nilai hardcoded atau selalu menampilkan demo account.

- [ ] **Step 3: Implement conditional demo UI.** Baca profile melalui composition provider; pertahankan selector akun hanya pada mode demo, form login remote tetap tersedia tanpa selector.

- [ ] **Step 4: Implement dynamic athlete, document, and helpdesk rendering.** Teruskan AccessScope.name bila fallback alamat memerlukan label wilayah, gunakan formatter tanggal deterministic untuk test, dan jangan menambahkan nomor/alamat fallback demo baru ke widget.

- [ ] **Step 5: Verify tabs remain available.** Jangan menambah redirect/disable pada /sports, /clubs, atau /committee; tambahkan assertion navigasi bila router tersentuh.

- [ ] **Step 6: Run focused UI and full widget regression tests.**

Run: flutter test test/login_page_test.dart test/athlete_detail_test.dart test/profile_page_test.dart test/club_detail_widgets_test.dart test/app_test.dart -r expanded

Expected: PASS.

- [ ] **Step 7: Commit UI data cleanup.**

~~~powershell
git add lib/features/login_page.dart lib/features/athlete_detail/athlete_detail_page.dart lib/features/club_detail/club_document_tab.dart lib/features/profile_page.dart test/login_page_test.dart test/athlete_detail_test.dart test/profile_page_test.dart test/club_detail_widgets_test.dart test/app_test.dart
git commit -m "refactor: render API-ready data in UI"
~~~

---

### Task 8: Perbarui dokumentasi keputusan dan lakukan verifikasi menyeluruh

**Files:**

- Modify: docs/rencana-kesiapan-integrasi-api.md
- Modify: README.md
- Verify: generated model files dan seluruh test dari Tasks 1–7

- [x] **Step 1: Record all open-question resolutions.** Ganti bagian Open Questions dengan keputusan: endpoint belum tersedia, tab Cabor/Klub/Anggota tetap terbuka dalam scope sesi, offline-first belum disepakati sehingga tidak ada cache, dan seluruh fase dikerjakan terstruktur.

- [x] **Step 2: Update README integration guidance.** Dokumentasikan granular repository/provider, profile API_BASE_URL dan timeout defines, remote adapter fail-closed, serta kewajiban backend menegakkan scope/permission.

- [x] **Step 3: Search for removed hardcoded domain values.**

Run: rg -n "0812-3456-7890|Porkot Garut|Kejuaraan Antar Klub|SK Klub.*Kepengurusan|sekretariat@konigarut.or.id|233-546" lib/features

Expected: no domain contact/history/document fixture remains in target UI files; legitimate labels and test fixtures boleh tetap ada di luar target UI.

- [x] **Step 4: Regenerate, format, analyze, test, and build.**

~~~powershell
flutter pub run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
flutter build web
~~~

Expected: setiap command yang tersedia exit 0 tanpa analyzer errors. Jika Flutter kembali menggantung sebelum output, catat command dan blocker environment; jangan mengklaim pass.

- [x] **Step 5: Run final diff checks.**

~~~powershell
git diff --check
git status --short
~~~

Review hanya source, test, generated files, README, dan dokumen API readiness yang direncanakan berubah; pertahankan dokumen rencana user-provided jika tidak sengaja ditambahkan.

- [x] **Step 6: Request independent code review.** Dispatch reviewer dengan diff final dan plan ini. Gunakan gpt-5.6-luna; allowlist tool saat ini mendukung reasoning_effort max, bukan xhigh, sehingga gunakan max. Perbaiki temuan Critical/Important dan jalankan ulang test terdampak. Reviewer mencapai timeout tanpa mengembalikan temuan; verifikasi controller tetap dilakukan dengan analyze, test penuh, build_runner, dan web build.

- [x] **Step 7: Commit dokumentasi dan state final terverifikasi jika Git dapat ditulis.**

~~~powershell
git add docs/rencana-kesiapan-integrasi-api.md README.md docs/superpowers/specs/2026-09-12-api-readiness-design.md docs/superpowers/plans/2026-09-12-api-readiness.md
git commit -m "docs: record SICABOR integration readiness decisions"
~~~

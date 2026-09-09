# Auth Hardening & Lifecycle Remediation Implementation Plan (v3 Deterministic)

Tanggal: 2026-09-09
Status: **Approved for Execution**
Penulis: Pengembang & Reviewer Teknis
Spesifikasi acuan: Spesifikasi Final Remediasi Autentikasi & Lifecycle — Tahap A Patch 2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup R2-01 s/d R2-07 dan catatan konsistensi Bagian 5 melalui state machine crash-resilient, storage ownership guard, typed failure handling, explicit scope, stale-result rejection, composition root fail-closed, serta UI yang jujur.

**Architecture:** `Reserve → Execute → Commit`; satu mutation queue untuk storage lokal; `SignInPhase` internal; `SessionMetadata` sebagai restore gate; `RemoteSessionHandle` privat; `DataRequestContext` sebagai cache/lifecycle identity; adapter storage dan repository dapat diinjeksi.

**Dependency baseline yang harus diverifikasi dari `pubspec.lock`:** Dart SDK sesuai `pubspec.yaml`, `flutter_riverpod 3.4.3`, `go_router 17.5.0`, `shared_preferences 2.5.5`, dan `flutter_secure_storage 9.2.4`. Nilai aktual hasil resolver yang berlaku; jangan mengubah versi sebagai bagian remediasi kecuali diperlukan dan direview terpisah.

---

## Global Constraints

- Seluruh perubahan mengikuti spesifikasi acuan di atas.
- Tidak menebak endpoint, issuer, client ID, atau kontrak SICABOR.
- Tidak menambahkan plaintext token fallback.
- Setiap key/namespace wajib eksplisit dan environment-scoped.
- Raw token tidak masuk state publik, log, assertion message, atau fixture snapshot.
- Semua breaking change disertai migration sweep pada task yang sama.
- `dart format`, `flutter analyze`, dan test terdampak wajib lulus sebelum commit.
- Setelah Task 1, 2, 3, 5, 7, dan 8, jalankan full `flutter test` karena task tersebut mengubah kontrak lintas-layer.
- Hasil test/build merupakan target sampai benar-benar dijalankan; jangan menuliskannya sebagai fakta sebelum ada output runtime.

---

## Task 0 — Baseline Verification & Environment Lock

**Files:** `pubspec.yaml`, `pubspec.lock`, status Git, seluruh test yang sudah ada.

- [ ]  Catat `flutter --version` dan `dart --version`.
- [ ]  Jalankan `flutter pub get` tanpa mengubah dependency yang tidak terkait.
- [ ]  Jalankan baseline analyzer dan test.
- [ ]  Catat jumlah test aktual, failure bila ada, dan durasi; jangan memakai angka hardcoded.
- [ ]  Pastikan working tree bersih dan buat branch implementasi.

```bash
flutter --version
dart --version
flutter pub get
flutter analyze
flutter test
git status --short
git switch -c feat/auth-hardening-patch-2
```

**Gate:** baseline harus hijau atau seluruh failure existing harus didokumentasikan dan dipisahkan dari remediasi.

---

## Task 1 — Pure Domain Models, Defensive Permissions, & Credential IDs

### Files

- Modify: `lib/core/auth/domain/user_principal.dart`
- Modify: `lib/core/auth/domain/auth_state.dart`
- Create: `lib/core/auth/domain/credential_id_generator.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `lib/data/repository.dart` sebagai compatibility layer sementara
- Modify tests: `user_principal_test.dart`, `auth_token_storage_test.dart`, `auth_hardening_test.dart`, `profile_page_test.dart`, `auth_controller_test.dart`, `home_page_test.dart`, `app_test.dart`
- Create: `test/credential_id_generator_test.dart`

### Kontrak yang dihasilkan

- `AccessScopeType { district, county }`
- `AccessScope(type, id, name)` dengan equality `(type, id)` dan strict JSON round-trip
- `UserPrincipal(..., required scope, permissions)` dengan `Set.unmodifiable`
- Getter `name`, `role`, `districtId`, dan `districtName` hanya sebagai deprecated compatibility API
- `AuthSignedIn(user, generation)` tanpa token
- `CredentialIdGenerator`, generator UUID secure, dan fake deterministik

### Langkah

- [ ]  Tulis failing tests untuk equality scope, strict JSON parsing, defensive permission copy, UUID format, dan generator deterministik.
- [ ]  Implementasikan model domain serta value equality `UserPrincipal` menggunakan `setEquals` dan `Object.hashAllUnordered`.
- [ ]  Hapus argumen `accessToken:` dari seluruh instansiasi `AuthSignedIn`.
- [ ]  Migrasikan constructor principal lama ke `scope:` kanonis.
- [ ]  Pertahankan getter compatibility agar UI lama tetap hijau; beri `@Deprecated`.
- [ ]  Pastikan raw token tidak berada pada `AuthState`.

### Migration sweep

```bash
git grep -n "accessToken:" -- lib test
git grep -n "districtId:" -- lib test
git grep -n "districtName:" -- lib test
```

Kemunculan yang tersisa harus disengaja, didokumentasikan, dan bukan constructor principal lama.

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/user_principal_test.dart test/credential_id_generator_test.dart \
  test/auth_controller_test.dart test/auth_hardening_test.dart \
  test/profile_page_test.dart test/home_page_test.dart test/app_test.dart
flutter test
```

### Checkpoint

```bash
git add lib test
git commit -m "feat(auth): add scoped principals, defensive permissions, and credential IDs"
```

---

## Task 2 — Storage Adapters, Strict Parsers, Namespace, & Legacy Migration

### Files

- Create: `lib/core/auth/data/secure_key_val_store.dart`
- Create: `lib/core/auth/data/session_metadata_store.dart`
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/core/auth/data/remembered_sk_store.dart`
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Create: `test/session_metadata_store_test.dart`
- Modify all constructor consumers in:
    - `test/session_scope_test.dart`
    - `test/login_page_test.dart`
    - `test/auth_token_storage_test.dart`
    - `test/auth_repository_test.dart`
    - `test/auth_hardening_test.dart`
    - `test/auth_controller_test.dart`
    - `test/app_test.dart`

### Kontrak yang dihasilkan

- `SecureKeyValStore` dan `FlutterSecureKeyValStore`
- `StoredCredential` dengan parser strict, batas 128/8192, dan redacted `toString()`
- `SessionMetadata` dengan private constructor/factory invariant
- `SessionMetadataStore` yang memeriksa return `setString/remove`
- `SecureAuthTokenStorage` dengan required namespace dan required adapter
- `RememberedSkStore` dengan required key
- `migrateLegacyStorage()` eksplisit; `read()` bebas side effect

### Langkah

- [ ]  Tulis fake secure key-value store dengan fault injection read/write/delete.
- [ ]  Tulis test absent vs corrupt untuk credential dan metadata.
- [ ]  Tulis test tipe non-string, empty string, whitespace, schema unknown, ID terlalu panjang, serta `expectedCredentialId` non-null saat restore false.
- [ ]  Tulis test actual `SecureAuthTokenStorage`, bukan hanya fake interface.
- [ ]  Tulis test `clearIfOwnedBy(A)` tidak menghapus B.
- [ ]  Tulis test migrasi legacy tidak pernah melakukan restore.
- [ ]  Implementasikan adapter dan parser tanpa mencetak underlying cause/token.
- [ ]  Gunakan key eksplisit sementara yang tetap berasal dari environment aktif; jangan hardcode demo di provider lintas-environment.

### Migration sweep

```bash
git grep -n "RememberedSkStore(" -- lib test
git grep -n "SecureAuthTokenStorage(" -- lib test
git grep -n "v1_kok_refresh_token" -- lib test
```

Periksa setiap constructor memiliki dependency/key yang lengkap. Legacy key hanya boleh berada pada implementasi migrasi dan test terkait.

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/session_metadata_store_test.dart test/auth_token_storage_test.dart \
  test/login_page_test.dart test/auth_repository_test.dart \
  test/auth_hardening_test.dart test/auth_controller_test.dart test/app_test.dart
flutter test
```

### Checkpoint

```bash
git add lib test
git commit -m "feat(auth): add strict credential and session metadata storage"
```

---

## Task 3 — Repository Contracts, RemoteSessionHandle, & Scoped Dataset

### Files

- Modify: `lib/core/auth/data/auth_repository.dart`
- Modify: `lib/core/auth/data/demo_auth_repository.dart`
- Create: `lib/data/kok_repository.dart`
- Create: `lib/data/demo_kok_repository.dart`
- Modify: `lib/data/models.dart`
- Regenerate: `lib/data/models.freezed.dart`, `lib/data/models.g.dart`
- Modify: `lib/data/repository.dart` sebagai compatibility barrel
- Modify tests using `fetch()`/`fetchDistrict()`:
    - `sports_page_test.dart`, `sport_detail_test.dart`, `search_page_test.dart`
    - `profile_page_test.dart`, `home_page_test.dart`, `committee_page_test.dart`
    - `attention_page_test.dart`, `athlete_detail_test.dart`
    - `auth_hardening_test.dart`, `auth_repository_test.dart`, `repository_test.dart`

### Kontrak yang dihasilkan

- `RemoteSessionHandle` strict dan redacted
- `AuthRepository.revokeSession(RemoteSessionHandle)`
- `KokRepository.fetchScope(AccessScope, {RequestCancellation?})`
- `KokSnapshot` Freezed membawa `AccessScope scope`
- Dataset county dengan 5 cabor unik, 9 klub, 213 atlet, dan 18 pelatih
- Unknown scope melempar `UnsupportedScopeException`

### Langkah

- [ ]  Tulis failing test tiga login/token mapping dan restore masing-masing akun.
- [ ]  Tulis test login nonpersisten tetap menghasilkan private remote handle tetapi tidak mewajibkan refresh-token persistence.
- [ ]  Tambahkan `AccessScope` pada `KokSnapshot` aktual yang memakai Freezed.
- [ ]  Jalankan build runner dan periksa diff generated code.
- [ ]  Tambahkan JSON round-trip test yang mempertahankan seluruh scope.
- [ ]  Buat county snapshot dengan penggabungan fixture dinamis; jangan infer scope dari ID klub.
- [ ]  Standarisasi nama `Bola Voli`.
- [ ]  Migrasikan seluruh `fetch()` dan `fetchDistrict()` ke `fetchScope()`.

### Migration sweep

```bash
git grep -nE "\.fetch\(|fetchDistrict|CancelToken" -- lib test
```

Expected: tidak ada API lama, kecuali komentar migrasi yang akan dibersihkan pada Task 7.

### Verifikasi

```bash
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/auth_repository_test.dart test/repository_test.dart \
  test/sports_page_test.dart test/sport_detail_test.dart test/search_page_test.dart \
  test/profile_page_test.dart test/home_page_test.dart test/committee_page_test.dart \
  test/attention_page_test.dart test/athlete_detail_test.dart test/auth_hardening_test.dart
flutter test
```

### Checkpoint

```bash
git add lib test
git commit -m "feat(repo): add remote session handles and scoped county snapshots"
```

---

## Task 4 — Mutation Queue & Bootstrap Truth Table

### Files

- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `test/auth_controller_test.dart`

### Langkah

- [ ]  Buat fault-injectable controller fixtures untuk metadata, token storage, repository, dan queue.
- [ ]  Tulis test seluruh bootstrap truth table dari spesifikasi.
- [ ]  Tulis test queue: mutasi pertama melempar, mutasi berikutnya tetap berjalan.
- [ ]  Implementasikan mutation tail yang menyampaikan error ke caller tetapi menjaga tail berikutnya sukses.
- [ ]  Jalankan migrasi legacy sebelum pembacaan v2.
- [ ]  Bedakan absent, corrupt, read error, restore false, mismatch ID, dan expired session.
- [ ]  Pada orphan token: force clear + metadata clean menghasilkan clean hanya bila keduanya sukses; selain itu failed.
- [ ]  Pada expired restore: `clearIfOwnedBy` + metadata clean; failure apa pun menghasilkan failed.
- [ ]  Bootstrap idempoten dan hanya memiliki satu active Future.

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib test/auth_controller_test.dart
flutter analyze
flutter test test/auth_controller_test.dart
```

### Checkpoint

```bash
git add lib/core/auth/presentation/auth_controller.dart test/auth_controller_test.dart
git commit -m "feat(auth): implement resilient mutation queue and bootstrap truth table"
```

---

## Task 5 — Login, Logical Cancellation, Logout, & Recovery

### Files

- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `lib/core/auth/data/auth_repository.dart` bila adapter cancellation hook diperlukan
- Modify: `test/auth_controller_test.dart`
- Modify: `test/auth_hardening_test.dart`

### Kontrak yang dihasilkan

- `SignInPhase { idle, executing, waitingForCommit, committing }`
- Typed `AuthCommandResult`/rejection
- Logical cancellation via typed `Future.any`
- `LogoutResult(localSessionClosed, credentialCleared, metadataClean, remoteRevocationStatus)`
- Injectable `revocationTimeout` untuk test cepat
- Recovery hanya legal dari cleanup failed

### Langkah login

- [ ]  Reserve hanya dari signed-out clean; set phase executing dan simpan ticket.
- [ ]  Execute repository di luar queue.
- [ ]  Race result dengan cancel trigger bertipe `AuthResult`.
- [ ]  Jelaskan bahwa `Future.any()` tidak membatalkan transport; panggil transport cancel hook hanya bila tersedia.
- [ ]  Set waiting-for-commit, lalu di dalam queue validasi ticket dan set committing sebelum write pertama.
- [ ]  Login nonpersisten: metadata signed-out clean; session handle hanya di memory.
- [ ]  Login persisten: metadata pending → credential write → epoch check → metadata restore-enabled.
- [ ]  Semua jalur mengembalikan phase ke idle.

### Fault-injection FT-01 s/d FT-08

- [ ]  FT-01 metadata pending gagal: tidak ada credential; state temporarily unavailable.
- [ ]  FT-02 credential write ambigu: metadata/state failed.
- [ ]  FT-03 epoch berubah setelah write: rollback owned credential.
- [ ]  FT-04 metadata final gagal: rollback; clean hanya bila rollback dan metadata clean sukses.
- [ ]  FT-05 ownership mismatch: jangan global clear; state failed.
- [ ]  FT-06 expired restore dan cleanup gagal: failed.
- [ ]  FT-07 token clear sukses tetapi metadata clean gagal: failed.
- [ ]  FT-08 force clear sukses tetapi metadata recovery gagal: failed.

### Langkah logout/recovery

- [ ]  Invalidate session in-memory dan generation sebelum I/O.
- [ ]  Metadata pending failure tidak boleh menghentikan percobaan local clear dan remote revocation.
- [ ]  `clearIfOwnedBy == false` diperlakukan sebagai anomaly bila credential awal diketahui ada.
- [ ]  Publish clean hanya bila credential dan metadata berada pada kondisi aman.
- [ ]  Await revocation di luar queue dengan timeout injectable; timeout menjadi status failed.
- [ ]  Recovery mengubah state ke pending, menolak double tap/login, force-clears, lalu menulis metadata clean.

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib test/auth_controller_test.dart test/auth_hardening_test.dart
flutter analyze
flutter test test/auth_controller_test.dart test/auth_hardening_test.dart
flutter test
```

### Checkpoint

```bash
git add lib test/auth_controller_test.dart test/auth_hardening_test.dart
git commit -m "feat(auth): implement two-phase login, cancellation, logout, and recovery"
```

---

## Task 6 — Data Lifecycle, Request Cancellation, & Stale Guard

### Files

- Create: `lib/data/providers/snapshot_provider.dart`
- Modify: `lib/data/kok_repository.dart`
- Modify: `lib/data/demo_kok_repository.dart`
- Modify: `lib/data/repository.dart` re-export sementara
- Modify: `test/session_scope_test.dart`

### Langkah

- [ ]  Implementasikan `RequestCancellation` dan controller idempoten dengan reason pertama tetap.
- [ ]  Demo repository memeriksa cancel sebelum dan sesudah setiap delayed `await`.
- [ ]  Provider membuat token per lifecycle dan cancel pada dispose.
- [ ]  Setelah fetch selesai, jalankan `throwIfCancelled()` sebelum membaca `ref`.
- [ ]  Cocokkan `DataRequestContext(environment, userId, scope, generation)` sebelum publish.
- [ ]  Lifecycle exceptions mengembalikan `null` dari retry callback; error lain memakai `ProviderContainer.defaultRetry`.
- [ ]  Test transport yang mengabaikan cancellation tetapi menyelesaikan respons lama.
- [ ]  Pastikan internal cache, bila ada, memakai seluruh `DataRequestContext`, bukan hanya scope ID.

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib/data test/session_scope_test.dart
flutter analyze
flutter test test/session_scope_test.dart
```

### Checkpoint

```bash
git add lib/data test/session_scope_test.dart
git commit -m "feat(data): reject cancelled and stale cross-session responses"
```

---

## Task 7 — DeploymentProfile, Composition Root, & Import Cleanup

### Files

- Create: `lib/core/config/deployment_profile.dart`
- Create: `lib/core/composition/app_composition.dart`
- Modify: `lib/main.dart`, `lib/app.dart`
- Modify: `test/app_environment_test.dart`, `test/app_test.dart`
- Migrate all imports from `app_environment.dart` dan `repository.dart`
- Delete compatibility barrels only after grep is clean

### Langkah

- [ ]  Implementasikan matriks validasi profile persis seperti spesifikasi.
- [ ]  Pisahkan profile validation dari adapter availability.
- [ ]  Inject `SharedPreferences`, `SecureKeyValStore`, `CredentialIdGenerator`, dan `revocationTimeout`.
- [ ]  Derive auth/data/storage providers dari `appCompositionProvider`.
- [ ]  `main()` membuat dependency platform dan hanya meng-override composition serta dependency dasar yang memang diperlukan.
- [ ]  Tulis positive tests untuk profile valid dan negative tests untuk kombinasi ilegal.
- [ ]  Test namespace credential/metadata/SK terisolasi antar-environment.
- [ ]  Production remote/remote lolos profile validation tetapi composition fail-closed selama adapter belum tersedia.
- [ ]  Migrasikan seluruh import dan hapus barrel lama setelah tidak digunakan.

### Migration sweep

```bash
git grep -n "core/config/app_environment.dart" -- lib test
git grep -n "data/repository.dart" -- lib test
git grep -n "appCompositionProvider" -- lib test
```

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/app_environment_test.dart test/app_test.dart
flutter test
```

### Checkpoint

```bash
git add lib test
git commit -m "feat(composition): add fail-closed deployment profile and composition root"
```

---

## Task 8 — UI, Awaited Actions, Permission Guard, & Honest Labels

### Files

- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/login_page.dart`
- Modify: `lib/features/home_page.dart`
- Modify: `lib/core/auth/presentation/session_unavailable_page.dart`
- Modify: `README.md`
- Modify: `profile_page_test.dart`, `login_page_test.dart`, `home_page_test.dart`, `session_pages_test.dart`

### Langkah

- [ ]  Await semua logout dan retry calls.
- [ ]  Busy state menonaktifkan tombol dan mencegah double tap.
- [ ]  Cleanup failed menonaktifkan login dan menampilkan banner recovery.
- [ ]  DEMO-002 melihat tombol rekap disabled; handler memeriksa ulang permission.
- [ ]  Dokumentasikan bahwa guard Flutter bukan backend authorization boundary.
- [ ]  Hapus klaim aktif SICABOR; pertahankan kalimat jujur “Data demo lokal—belum terhubung dengan SICABOR.”
- [ ]  Tandai kontak demo belum diverifikasi.
- [ ]  Audit font eksplisit, card-title color, back button, dan struktur lima tab.

### Verifikasi

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/profile_page_test.dart test/login_page_test.dart \
  test/home_page_test.dart test/session_pages_test.dart
flutter test
```

Jangan memasukkan `README.md` ke `dart format`.

### Checkpoint

```bash
git add lib README.md test
git commit -m "feat(ui): add awaited auth actions, permission guard, and honest demo labels"
```

---

## Task 9 — Cross-Layer Regression, Audit, Build, & Device Smoke Test

### Cross-layer flows

- [ ]  DEMO-003 persistent login → dispose container → bootstrap baru → `usr_koni_kab` → county snapshot benar.
- [ ]  Delayed fetch akun A → switch akun B → respons A tidak pernah dipublikasikan.
- [ ]  Logout clear gagal → restart → restore ditolak → recovery sukses → login kembali tersedia.
- [ ]  Nonpersistent login → logout → remote revocation status tersedia tanpa credential persisted.
- [ ]  Production profile invalid/adapter missing gagal secara fail-closed.

`test/auth_hardening_remediation_test.dart` hanya memuat cross-layer flows; unit test SC/FT tetap berada pada file domain masing-masing untuk menghindari duplikasi.

### Audit commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug

git grep -nE "fetchDistrict|class CancelToken|accessToken.*AuthSignedIn" -- lib test
git grep -nE "SINKRONISASI DATA SICABOR|tersinkronisasi dengan SICABOR|data SICABOR aktif" -- lib
```

Expected grep untuk API/klaim terlarang: tidak ada hasil.

### UI audit

- [ ]  Scan explicit `fontSize` dan verifikasi tidak ada nilai di bawah 12.
- [ ]  Widget tests memverifikasi tombol kembali dan busy states penting.
- [ ]  Pastikan lima destination navigation tetap ada.
- [ ]  Pastikan kalimat disclaimer SICABOR tetap ada; jangan melarang semua penggunaan kata “SICABOR”.

### Device/emulator smoke test

- [ ]  Login persisten masing-masing akun dan restart aplikasi.
- [ ]  Verifikasi identitas/scope tidak berubah.
- [ ]  Logout dan pastikan restore tidak terjadi.
- [ ]  Simulasikan cleanup failure melalui debug/fake build, restart, lalu recovery.
- [ ]  Uji Android platform storage pada perangkat/emulator target.
- [ ]  Bila web/iOS juga target rilis, jalankan build dan smoke test platform tersebut secara terpisah.

### Evidence record

Catat:

- commit SHA;
- Flutter/Dart version;
- resolved dependency version;
- analyzer output;
- jumlah dan hasil test aktual;
- build artifact/target;
- perangkat/emulator dan OS version;
- hasil SC-01–SC-31 dan FT-01–FT-08;
- exception atau deviasi yang masih terbuka.

### Final checkpoint

```bash
git status --short
git add lib test README.md pubspec.lock
git commit -m "test(auth): complete auth lifecycle regression and platform verification"
```
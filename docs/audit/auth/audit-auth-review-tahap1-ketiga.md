Tanggal review: 2026-09-10
Reviewer: Notion AI — review teknis statis

## 2. Implementasi yang Terkonfirmasi Baik

1. **Parser metadata telah diperbaiki.** `expectedCredentialId` non-string ditolak sebelum cast; restore false mensyaratkan ID null; restore true mensyaratkan status clean dan ID valid.
2. **SessionMetadata memakai invariant factories.** Kombinasi clean, pending, failed, dan restore-enabled tidak dibuat lewat constructor publik bebas.
3. **StoredCredential strict dan redacted.** Batas `credentialId` 128 dan refresh token 8192 diterapkan; JSON invalid, whitespace, dan tipe salah ditolak.
4. **Secure storage diabstraksi.** `SecureKeyValStore` serta `FlutterSecureKeyValStore` memetakan platform exception ke pesan non-secret.
5. **Bootstrap truth table cukup lengkap.** Orphan credential, ID mismatch, expired restore, corrupt metadata/credential, dan failure normalisasi memiliki cabang deterministik.
6. **Mutation queue tetap hidup setelah error.** Error diberikan ke caller tetapi tail berikutnya dinormalisasi.
7. **Logical cancellation dibedakan dari transport cancellation.** `Future.any<AuthResult>` mencegah commit respons login stale; tidak ada klaim bahwa transport otomatis berhenti.
8. **Data lifecycle guard sudah substantif.** `DataRequestContext` memuat environment, user, scope, dan generation; provider melakukan cancel-on-dispose serta post-await context check; lifecycle exceptions tidak di-retry.
9. **KokSnapshot scoped dan serializable.** Generated JSON memakai `AccessScope.fromJson()`/`toJson()` dan round-trip test tersedia.
10. **Dataset county sesuai hitungan.** 5 cabor unik, 9 klub, 213 atlet, dan 18 pelatih terbentuk dari agregasi Garut Kota dan Tarogong Kidul.
11. **DeploymentProfile dan composition root tersedia.** Matriks demo/staging/production divalidasi; adapter remote yang belum tersedia gagal secara fail-closed.
12. **Namespace per environment tersedia.** Credential, metadata, dan remembered SK memakai `kok.auth.v2.<env>.*` dan diuji non-colliding.
13. **UI logout/retry utama di-await.** Dialog logout dan halaman session unavailable memiliki busy state dan mencegah double tap pada level widget.
14. **Lima tab utama tetap ada.** Beranda, Cabor, Klub, Anggota, dan Profil terkonfirmasi pada router.
15. **Audit font literal mendukung klaim minimum 12px.** Tidak ditemukan `fontSize` literal di bawah 12 pada `lib/`.

---

## 3. Temuan Wajib Sebelum Final Acceptance

### P1-01 — SC-06 gagal: logout controller belum single-flight

**Bukti:** `auth_controller.dart:688–793` tidak memiliki `_activeLogoutFuture`, command reservation, atau guard state. Setiap pemanggilan `logout()`:

- menaikkan operation epoch dan generation lagi;
- menulis metadata pending/clean lagi;
- menjalankan local cleanup lagi;
- dapat memulai revocation terpisah.

Widget memang menahan double tap, tetapi kontrak controller harus aman terhadap pemanggilan paralel dari UI lain, test, lifecycle callback, atau integrasi masa depan. Tidak ada test double-logout pada suite.

**Perbaikan:** tambahkan single-flight logout:

```dart
Future<LogoutResult>? _activeLogoutFuture;

Future<LogoutResult> logout() {
  final active = _activeLogoutFuture;
  if (active != null) return active;
  final run = _runLogout();
  _activeLogoutFuture = run;
  return run.whenComplete(() {
    if (identical(_activeLogoutFuture, run)) {
      _activeLogoutFuture = null;
    }
  });
}
```

Tambahkan test dua pemanggilan paralel menghasilkan satu pending write, satu owned clear, satu clean write, satu revocation, dan hasil Future yang ekuivalen.

### P1-02 — Ownership storage belum ditutup pada interface repository

Kontrak final mensyaratkan controller/coordinator sebagai satu-satunya pemilik storage. Source masih mempertahankan jalur bypass:

- `AuthRepository.restoreSession([String? refreshToken])` menerima argumen opsional;
- `DemoAuthRepository.restoreSession()` membaca token storage bila argumen null;
- `AuthRepository.logout()` dan `DemoAuthRepository.logout()` menghapus storage;
- `DemoAuthRepository` menyimpan serta mengekspos `AuthTokenStorage`;
- `AuthTokenStorage` masih memiliki `saveRefreshToken`, `readRefreshToken`, `getRefreshToken`, dan global `clear()`;
- compatibility `saveRefreshToken()` membuat credential ID literal `legacy`, melewati ownership generator.

Walaupun controller utama memakai jalur baru, API lama tetap dapat menghapus credential tanpa `clearIfOwnedBy()` dan mempertahankan dua sumber ownership.

**Perbaikan:** ubah interface menjadi exact:

```dart
abstract interface class AuthRepository {
  Future<AuthResult> login(...);
  Future<AuthResult> restoreSession(String refreshToken);
  Future<AuthResult> refreshToken(String refreshToken);
  Future<RemoteRevocationResult> revokeSession(RemoteSessionHandle session);
}
```

Hapus dependency storage, getter `storage`, method `logout()`, seluruh compatibility methods token storage, `_DefaultAuthTokenStorage`, serta test yang melegitimasi API lama.

### P1-03 — Kontrak exact tiga akun demo tidak sesuai specs

| Field | Specs | Implementasi |
| --- | --- | --- |
| DEMO-001 user ID | `usr_garut_kota` | `usr-garut-kota-001` |
| DEMO-002 user ID | `usr_tarogong_kidul` | `usr-tarogong-kidul-002` |
| DEMO-003 user ID | `usr_koni_kab` | `usr-koni-kab-003` |
| DEMO-003 password | `konigarut123` | menerima `konigarut123` dan `kokkabgarut123`; UI mengisi password kedua |
| DEMO-003 reports permission | secara perilaku hanya DEMO-002 yang wajib ditolak | implementasi tidak memberi `reports:export`, tetapi README mengklaim memilikinya |

Cross-layer test mengunci ID dan password implementasi yang berbeda dari specs, sehingga test lulus tidak membuktikan SC-17 versi kanonis.

**Perbaikan:** pilih satu sumber kebenaran. Untuk patuh pada specs, gunakan ID underscore exact dan `konigarut123` saja. Tambahkan `reports:export` pada DEMO-003 bila akun county memang boleh membuat rekap kabupaten; bila tidak, koreksi README dan acceptance behavior secara eksplisit.

### P1-04 — SC-30 dapat dilewati dari halaman detail cabor

Guard `reports:export` hanya diterapkan pada `ProfilePage`. `sport_detail_page.dart:63–92` dan `1101–1109` menyediakan “Salin Rekapitulasi Cabor” tanpa pemeriksaan permission. DEMO-002 tetap dapat mengekspor ringkasan melalui layar ini.

Lebih buruk, teks ekspor pada `sport_detail_page.dart:76` selalu menulis:

```
Wilayah : Kecamatan Garut Kota
```

Artinya akun Tarogong Kidul atau Kabupaten menyalin rekap dengan wilayah salah.

**Perbaikan:** baca principal aktif dan `snapshot.scope`; disable tombol bila permission tidak tersedia; periksa ulang permission di handler; gunakan `data.scope.name`; tambah widget test DEMO-002 pada detail cabor dan test rekap DEMO-003 county.

### P1-05 — SC-31 belum terpenuhi secara aplikasi penuh

Grep walkthrough hanya mencari tiga frasa sempit. Source masih menampilkan klaim aktif pada data mock:

- `club_people_tab.dart:123`: “Data milik SICABOR.”
- `club_document_tab.dart:58`: “Data milik SICABOR.”
- `athlete_detail_page.dart:229`: `ID SICABOR · ATL-${person.id}` walaupun ID dibentuk dari fixture demo.

Test SC-31 hanya memeriksa `ProfilePage`, bukan seluruh UI.

**Perbaikan:** gunakan label seperti “Data demo—belum terhubung dengan SICABOR” dan `ID DEMO`. Tambahkan repo-wide source audit serta widget test untuk detail atlet, tab orang, dan tab dokumen.

### P1-06 — Typed command rejection belum diimplementasikan

Specs mensyaratkan alasan typed seperti `cleanupRequired`, `operationInProgress`, dan `invalidState`. Implementasi hanya memiliki:

```dart
enum AuthCommandStatus { success, failed, rejected, cancelled }
```

dengan `errorMessage` string. Login dari cleanup failed/pending tidak dapat dibedakan secara programatik dari login saat bootstrapping atau sudah signed-in. Cancel saat committing juga hanya menghasilkan generic `rejected`.

**Dampak:** SC-07 dan SC-16 tidak memenuhi kontrak typed; tidak ada test khusus cancel saat committing.

**Perbaikan:** gunakan sealed result atau tambahkan `AuthCommandRejection? rejection`; uji exact reason untuk cleanup, invalid state, dan committing.

### P1-07 — SC-13 dan SC-16 belum memiliki regression test exact

- FT-03 mengubah epoch setelah credential write; ini bukan skenario SC-13 “ticket stale saat menunggu queue sebelum commit”.
- Cabang `SignInPhase.committing` tersedia di source, tetapi tidak ada test yang menahan write pertama lalu memanggil `cancelSignIn()` untuk membuktikan rejection `operationInProgress`.

Tambahkan controlled queue barrier agar kedua fase diuji tanpa bergantung timing nyata.

### P1-08 — Kegagalan Remembered SK terjadi setelah sesi dipublikasikan

Pada login nonpersisten dan persisten, controller memublikasikan `AuthSignedIn` sebelum `skStore.saveSk()`/`clear()`. Jika SharedPreferences gagal:

- Future login melempar exception;
- state tetap signed-in;
- UI menangkapnya sebagai kesalahan kredensial;
- caller menerima failure sementara router dapat berpindah ke home.

Tidak ada controller test untuk failure ini.

**Perbaikan:** jadikan remembered SK preference non-kritis dan tangkap error secara terpisah, atau selesaikan preference write sebelum publish. Jangan mengubah keberhasilan sesi menjadi error kredensial. Tambahkan fault-injection test untuk save dan clear.

---

## 4. Temuan Penting Non-Blocker

### P2-01 — Demo revocation melaporkan `revoked`

`DemoAuthRepository.revokeSession()` mengembalikan `revoked`, padahal tidak ada remote session server. Status yang jujur untuk mode demo adalah `notApplicable`. Local logout tetap dapat sukses.

### P2-02 — Composition fallback dan compatibility barrel belum dibersihkan

`appCompositionProvider` nullable; provider auth/data masih membuat fallback demo dan bahkan metadata in-memory ketika composition tidak tersedia. `app_environment.dart`, `repository.dart`, `SessionScope`, getter district, dan banyak import lama masih aktif. Ini menjaga test lama hijau tetapi membuat migration Task 7 belum selesai dan membuka jalur yang melewati composition root.

Untuk production bootstrap, jadikan composition required/fail-fast. Fakes sebaiknya diinjeksi eksplisit dalam test.

### P2-03 — Material sesi memiliki getter publik

`AuthController.activeRemoteHandle`, `activeCredentialId`, dan `RemoteSessionHandle.revocationToken` dapat diakses publik. Getter controller sebaiknya dihapus atau dibatasi `@visibleForTesting`; adapter revocation menerima handle tanpa UI dapat membaca token.

### P2-04 — Role profil masih di-hardcode

`ProfilePage` selalu menulis `Koordinator · ...` dan badge `AKSES READ-ONLY`, sehingga DEMO-003 dengan role `Tim Verifikator` ditampilkan salah. Gunakan `user.roleTitle` dan label scope berbasis `scope.type`.

### P2-05 — Dokumentasi repository mengalami drift

README masih memuat:

- password DEMO-002 yang tidak diterima source;
- permission DEMO-003 yang tidak sama dengan source;
- `KokRepository.fetch()` alih-alih `fetchScope()`;
- pernyataan native Android belum divalidasi, yang bertentangan dengan walkthrough build Android;
- petunjuk path lokal absolut Windows.

Plan Markdown di ZIP juga masih memiliki 99 checkbox tidak dicentang. Ini tidak memengaruhi runtime, tetapi tidak cocok sebagai evidence record penyelesaian.

### P2-06 — Klaim warna tombol kembali terlalu absolut

Icon dan ukuran 28 konsisten, tetapi warnanya context-aware: putih atau palette foreground pada hero gelap, `KokColors.cardTitle` pada layar terang. Perbaiki walkthrough menjadi “warna kontras sesuai surface”, bukan menyatakan semuanya `KokColors.cardTitle`.

### P2-07 — Snapshot scope hasil repository belum divalidasi

Provider memvalidasi context sesi sebelum publish, tetapi tidak memeriksa `snapshot.scope == initialContext.scope`. Tambahkan check agar adapter yang salah tidak dapat mengembalikan dataset wilayah lain untuk context yang tetap sama.

---

## 5. Validasi Klaim Walkthrough

| Klaim | Hasil review |
| --- | --- |
| Parser strict dan metadata invariant | **Terkonfirmasi** |
| Mutation queue dan ownership ID | **Terkonfirmasi sebagian**; compatibility API masih bypass ownership |
| County 5/9/213/18 | **Terkonfirmasi statis** |
| 322 test + 1 skip | **322 deklarasi dan 1 skip terkonfirmasi**; runtime pass tidak dapat direproduksi di lingkungan ini |
| 5 cross-layer test | **Terkonfirmasi ada**; beberapa mengunci kontrak akun yang berbeda dari specs |
| SC-01–SC-31 seluruhnya terverifikasi | **Tidak terkonfirmasi**; hanya SC-24, SC-29, SC-30, SC-31 yang diberi ID pada test; SC-06 gagal secara source dan beberapa skenario hanya partial |
| FT-01–FT-08 | **8 ID unik tersedia**, dengan duplikasi suite; runtime pass belum direproduksi |
| Forbidden API grep bersih | **API utama bersih**, tetapi compatibility API lama masih aktif |
| Seluruh label SICABOR jujur | **Tidak benar**; tiga klaim aktif masih ada |
| Semua back button memakai cardTitle | **Tidak benar**; warna menyesuaikan surface/palette |
| Android APK berhasil | **Dilaporkan, tidak dapat diverifikasi dari ZIP**; APK/log tidak disertakan |
| Riwayat commit terstruktur | **Tidak dapat diverifikasi**; `.git` tidak disertakan |

### Status skenario yang perlu dibuka kembali

| ID | Status | Alasan |
| --- | --- | --- |
| SC-06 | **Fail** | logout tidak single-flight |
| SC-07 | **Partial** | controller menolak, tetapi tidak memberi typed `cleanupRequired` dan tidak ada test exact |
| SC-11 | **Partial** | enum ada; demo memberi `revoked`, test `notApplicable` tidak jelas |
| SC-13 | **Partial** | tidak ada test ticket stale sebelum commit |
| SC-16 | **Partial** | branch ada, typed reason dan test exact tidak ada |
| SC-17 | **Fail terhadap specs** | ID/password DEMO-003 berbeda dari kontrak kanonis |
| SC-30 | **Fail aplikasi penuh** | detail cabor dapat mengekspor tanpa permission |
| SC-31 | **Fail aplikasi penuh** | label “Data milik SICABOR” dan “ID SICABOR” masih ada |

---

## 6. Patch 3 yang Disarankan

Urutan remediasi terpendek:

1. **Tutup controller concurrency:** single-flight logout; typed command rejection; test SC-06, SC-07, SC-13, SC-16.
2. **Tutup storage ownership:** hapus seluruh compatibility methods dan dependency storage dari repository.
3. **Kunci fixture exact:** samakan ID, password, token, scope, permission, README, UI picker, dan semua test.
4. **Perluas permission boundary:** lindungi seluruh rekap/export/copy report, terutama detail cabor; hilangkan hardcoded Garut Kota.
5. **Bersihkan label demo:** ganti `ID SICABOR`/`Data milik SICABOR`; perluas SC-31 ke semua layar.
6. **Perbaiki preference failure:** jangan publish signed-in lalu melempar karena remembered SK.
7. **Finalisasi composition migration:** provider required/fail-fast, hapus barrel/API legacy, dan migrasikan imports.
8. **Sinkronkan dokumentasi/evidence:** update README dan walkthrough; sertakan output log, manifest evidence, atau CI link yang dapat diulang.

### Regression test minimum tambahan

- double logout paralel menghasilkan satu cleanup/revocation;
- login saat cleanup failed/pending → `cleanupRequired`;
- stale ticket ketika menunggu queue → tidak ada write;
- cancel saat committing → `operationInProgress`;
- remembered SK save/clear gagal → auth result/state konsisten;
- DEMO-003 exact ID/password/permission setelah restart;
- DEMO-002 tidak dapat ekspor dari Profile maupun detail cabor;
- rekap Tarogong/Kabupaten menggunakan `snapshot.scope.name`;
- seluruh layar mock tidak memakai `ID SICABOR` atau klaim kepemilikan data aktif;
- snapshot dengan scope salah ditolak provider.

---

## 7. Final Verification yang Harus Diulang

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug

git grep -nE "fetchDistrict|class CancelToken|readRefreshToken|getRefreshToken|saveRefreshToken|Future<void> logout\(\)" -- lib test
git grep -nEi "ID SICABOR|Data milik SICABOR|SINKRONISASI DATA SICABOR|tersinkronisasi dengan SICABOR|data SICABOR aktif" -- lib
```

Sertakan commit SHA, versi toolchain, resolved dependencies, raw analyzer/test/build logs, hasil SC/FT per ID, serta smoke test secure storage pada emulator/perangkat Android.

---

## 8. Keputusan Akhir

**Status:** `Needs Focused Patch 3 — belum Final Accepted`.

Implementasi ini sudah memiliki fondasi yang kuat dan merupakan kemajuan besar dibanding revisi sebelumnya. Parser, persistence gate, rollback, stale-data guard, namespace, dataset county, dan composition profile telah bergerak ke arah yang benar. Namun delapan temuan P1 di atas membuat R2-01/R2-04, R2-05 ownership, kontrak R2-03, dan SC-30/SC-31 belum dapat dinyatakan ditutup 100%.

Setelah Patch 3 menutup temuan tersebut dan bukti runtime dapat direproduksi, review berikutnya dapat difokuskan sebagai final acceptance, bukan redesign.
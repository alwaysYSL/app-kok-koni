<aside>
🧪

**Verdict: revisi ini menutup banyak temuan secara nyata, tetapi Tahap A belum layak dinyatakan selesai.** A-01 dan A-08 sudah tertutup dengan baik; A-07 sebagian besar tertutup; A-03 dan A-04 sudah memiliki kontrol minimum. Blocker tersisa berada pada race commit/clear token, penanganan kegagalan logout, konsistensi akun demo ketiga, dan bukti cancellation/session isolation yang belum lengkap.

</aside>

## 1. Lingkup review

**Sumber:** `app-kok-koni-main (2).zip`, dikirim 9 September 2026 pukul 07.55 WIB. SHA-256: `ac54442f48234337411c73d37c89507c6c922553232258e135edff1721891f85`.

**Pembanding:** ZIP revisi sebelumnya dan Review Implementasi Tahap A — KOK Flutter · 8 September 2026.

**Metode:** diff source, penelusuran alur router–controller–storage–repository, pemeriksaan assertion regression test, dan pengecekan penggunaan state/label lama. Revisi memuat 43 file Dart di `lib/` dan 28 file `*_test.dart`.

**Batas:** review tetap statis. Flutter/Dart tidak tersedia di lingkungan pemeriksaan, sehingga `flutter analyze`, `flutter test`, build, dan tes perangkat belum dijalankan oleh reviewer. Nama test dan isi assertion diperiksa, tetapi belum dapat diklaim lulus. ZIP tidak diubah.

## 2. Ringkasan perubahan yang tervalidasi dari source

- Guard sekarang menangani `AuthSigningOut`, `AuthBootstrapping`, unavailable, seluruh state non-signed-in, dan auth gate secara eksplisit di `lib/app.dart:29–50`.
- Route `/signing-out` memiliki layar tersendiri dan tidak memulai bootstrap.
- Boolean session lama sudah dihapus; tidak ditemukan `sessionProvider` atau `SessionController` di `lib/` maupun `test/`.
- `snapshotProvider` menolak scope null dan memasang cancellation hook.
- Environment enum dan production fail-closed minimum sudah ditambahkan.
- `StorageException` sekarang dipropagasikan oleh wrapper secure storage.
- Restore hanya menerima token fixture yang dikenal; token acak ditolak.
- Bootstrap memakai single-flight dan timeout restore dipetakan ke unavailable.
- `UserPrincipal.permissions` dibuat unmodifiable dan equality mencakup seluruh field.
- Rekap kecamatan, waktu pemuatan, dan snackbar reload sudah lebih jujur/dinamis.
- Regression suite baru memakai `Completer`, repository counter, storage failure double, serta router widget test.

## 3. Status A-01 sampai A-09

| Temuan review sebelumnya | Status revisi 2 | Penilaian |
| --- | --- | --- |
| A-01 · Guard state transisi | **Tertutup** | Signing-in diarahkan ke login; signing-out ke route terpisah; route data tidak dibiarkan terbuka |
| A-02 · Stale async result/generation | **Sebagian** | Epoch mencegah hasil login/restore lama mengubah state, tetapi mutasi storage belum diserialkan dan stale cleanup dapat menghapus token sesi baru |
| A-03 · Fetch tanpa sesi/cancellation | **Sebagian besar** | Scope null ditolak tanpa fetch; cancellation hook ada. Belum ada bukti delayed fetch A → B dan token cancellation bukan Dio `CancelToken` |
| A-04 · Demo/staging/production | **Kontrol minimum tercapai** | Production dengan flag demo ditolak; composition root masih selalu demo dan flag validasi belum diturunkan dari adapter aktual |
| A-05 · Storage error | **Sebagian** | Wrapper tidak lagi menelan error; logout tetap memublikasikan signed-out walau clear gagal dan pemanggil UI tidak menangani Future |
| A-06 · Token unknown/expiry/revocation | **Sebagian** | Token acak ditolak; refresh masih mengabaikan argumen dan akun demo ketiga memiliki mapping token yang salah |
| A-07 · Bootstrap/retry/failure mapping | **Sebagian besar** | Single-flight dan reason tersedia; `canRetry` belum dipakai, tetapi duplikasi restore saat retry telah dikendalikan |
| A-08 · Dua sumber sesi | **Tertutup** | Controller boolean dan login/logout ganda sudah dihapus; preferences dipindahkan |
| A-09 · Label dan metadata | **Sebagian** | Home/reload/rekap membaik; status sinkron, kontak, README, dan banyak layar masih hardcoded Garut Kota |

## 4. Temuan blocker revisi 2

### R2-01 · Epoch menjaga state, tetapi belum menjaga kepemilikan token — tinggi

**Bukti:** `auth_controller.dart:99–149`. Setelah repository login selesai, controller menulis token pada baris 122–130. Jika epoch berubah sesudah write, operasi stale menjalankan `tokenStorage.clear()` pada baris 124–126.

Pola tersebut aman untuk skenario sederhana “login lama → logout → login lama selesai” yang sudah dites. Namun masih ada race lain:

1. Login A mulai commit ke storage.
2. Logout atau login B menaikkan epoch.
3. Login B menyimpan token baru.
4. Operasi A mendeteksi stale lalu menjalankan `clear()` global.
5. Token B ikut terhapus walaupun state dapat menunjukkan B sudah signed-in.

Race sebaliknya juga mungkin: logout sedang menunggu `repo.logout()`, login baru diizinkan mulai, lalu clear milik logout selesai setelah token login baru ditulis. Tidak ada lock/queue yang menyatukan login, restore, token write, dan clear.

**Perbaikan:**

- Pilihan paling sederhana untuk Tahap A: jangan izinkan login/restore baru selama `AuthSigningOut`; serialisasikan semua mutasi credential storage.
- Controller menjadi satu-satunya pemilik commit/clear token. Hindari cabang `repo is DemoAuthRepository` di `auth_controller.dart:119–135`; adapter tidak semestinya menentukan storage mana yang dipakai melalui pemeriksaan tipe runtime.
- Jangan membersihkan storage global dari operasi stale kecuali operasi memiliki bukti bahwa token yang hendak dihapus masih token miliknya. Untuk backend nyata, gunakan session/token-family identity atau compare-and-delete abstraction.
- Periksa epoch setelah setiap `await`, termasuk penyimpanan remembered SK, tetapi koordinasikan cleanup agar tidak menghapus sesi baru.

**Test wajib:** delayed token write A → login B sukses → A stale selesai; token B harus tetap ada. Tambahkan pula logout tertahan → login B dicoba; login harus ditolak/ditunda sampai cleanup selesai.

### R2-02 · Logout storage failure belum memiliki hasil yang aman dan dapat ditangani — tinggi

**Bukti:** `auth_controller.dart:173–187`. `repo.logout()` dapat melempar `StorageException`, tetapi blok `finally` tetap mengubah state menjadi `AuthSignedOut`. Di `profile_page.dart:540–543` dan `session_unavailable_page.dart:117–119`, `logout()` dipanggil tanpa `await` atau error handler.

**Dampak:** UI keluar dari akun, Future dapat menghasilkan unhandled asynchronous error, sedangkan token yang gagal dihapus masih berada di perangkat. Pada startup berikutnya, restore dapat memasukkan pengguna kembali. Layar “Membersihkan sesi lokal” tidak membedakan cleanup berhasil dan gagal.

**Prinsip yang benar:** data/UI harus segera terkunci walaupun offline atau cleanup gagal, tetapi kegagalan menghapus secret tidak boleh hilang. Sediakan state/hasil seperti `signedOut(cleanupPending: true)` atau recovery state yang tetap tidak membuka data. Tombol masuk ulang dapat ditahan sampai storage berhasil dibersihkan atau kebijakan recovery eksplisit dijalankan.

**Test wajib:** storage delete melempar → state tidak membuka data, error tidak unhandled, token lama tidak dianggap aman, dan restart tidak diam-diam memulihkan sesi tanpa jalur recovery yang disepakati.

### R2-03 · Akun DEMO-003 menghasilkan identitas berbeda setelah restart — tinggi untuk konsistensi demo

**Bukti:** `demo_auth_repository.dart:35–43,70–97`. Semua akun selain Garut Kota mendapatkan access/refresh token Tarogong Kidul. Karena itu login `DEMO-003` sebagai “Ibu Rina / KONI Kabupaten” dengan Tetap Masuk menghasilkan `token_usr_tarogong_kidul`. Pada restore, token itu dikembalikan sebagai Pak Cecep/Tarogong Kidul (`116–121`).

Selain itu, `DemoKokRepository.fetchDistrict('koni_kab')` tidak memiliki fixture khusus dan jatuh ke dataset Garut Kota.

**Perbaikan:** untuk scope Tahap A, hapus/nonaktifkan akun ketiga dari pemilih demo; atau buat token exact dan fixture scope yang benar. Jangan memakai ternary dua wilayah untuk tiga principal.

**Test wajib:** login setiap akun persisten → dispose container → bootstrap baru → principal id/district/permissions harus identik dengan sebelum restart.

### R2-04 · Mutasi auth masih dapat berjalan paralel — tinggi/menengah

Early guard `_busy` pada UI sudah ditambahkan, tetapi controller tidak menolak dua pemanggilan `login()` langsung. Setiap login menaikkan epoch sehingga hasil terakhir biasanya menang pada state, tetapi kedua request tetap berjalan dan dapat menyentuh storage/preference. Pemanggilan login saat bootstrap atau signing-out juga belum dibatasi.

**Perbaikan:** definisikan matriks transisi yang legal. Contoh minimum:

```
bootstrapping -> signedOut | signedIn | unavailable
signedOut -> signingIn
signingIn -> signedIn | signedOut | unavailable
signedIn -> signingOut
unavailable -> bootstrapping | signingOut
signingOut -> signedOut | cleanupError
```

Operasi yang tidak legal ditolak tanpa memulai repository call. Jika kebutuhan UX mengizinkan ganti upaya login, batalkan request lama dahulu dan tetap serialisasikan commit.

### R2-05 · Interface storage memiliki default recursion berbahaya — menengah

**Bukti:** `auth_token_storage.dart:13–17`:

```dart
Future<String?> getRefreshToken() => readRefreshToken();
Future<String?> readRefreshToken() => getRefreshToken();
```

Implementer yang lupa override keduanya akan masuk rekursi tanpa akhir saat runtime. Duplikasi nama ini juga menyebabkan setiap fake harus mengimplementasikan dua method yang artinya sama.

**Perbaikan:** pilih satu kontrak abstrak saja:

```dart
abstract interface class AuthTokenStorage {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clearRefreshToken();
}
```

Tambahkan namespace environment/issuer/client pada key sebelum staging dan production memakai package ID/storage domain yang sama. Key saat ini tetap `v1_kok_refresh_token` untuk semua environment.

### R2-06 · Cancellation data adalah fondasi, belum bukti isolasi end-to-end — menengah

**Bukti positif:** `repository.dart:101–116` menolak null scope, membuat token, dan membatalkannya saat provider state dibuang. Demo repository mengecek token sebelum dan setelah delay.

**Sisa:**

- `CancelToken` buatan sendiri memiliki nama sama dengan `dio.CancelToken`, tetapi tidak dapat membatalkan request Dio nyata.
- Belum ada test fetch A yang ditahan, scope berubah ke B, lalu A selesai/cancel.
- `KokRepository.fetch()` masih tersedia tanpa scope dan mengembalikan Garut Kota, sehingga kontrak repository tetap menyediakan jalur tidak scoped.
- Belum ada pemeriksaan scope/generation sesudah hasil kembali di repository boundary; saat ini mengandalkan lifecycle provider.

**Perbaikan:** ubah nama menjadi abstraction netral seperti `RequestCancellation` dan adapter Dio memetakan ke `dio.CancelToken`, atau langsung gunakan token Dio pada adapter HTTP. Hilangkan `fetch()` tanpa scope bila tidak dibutuhkan. Tambahkan delayed-response regression test dan cek tab/detail/search/media setelah pergantian akun.

### R2-07 · Environment gate sudah fail-closed, tetapi belum terikat komposisi aktual — menengah

**Bukti positif:** `app_environment.dart:7–28` menolak production jika flag demo true. `main.dart:10–14` saat ini memasukkan `true/true`, jadi `APP_ENV=production` gagal sebelum aplikasi berjalan. Ini perbaikan yang valid.

**Sisa:** provider aktual tetap selalu `DemoAuthRepository` dan `DemoKokRepository`. Boolean validasi dimasukkan manual; nanti seseorang dapat mengubah flag ke `false` tanpa mengganti provider dan membuat validasi lolos secara palsu. Staging juga masih eksplisit mengizinkan kedua adapter demo.

**Perbaikan:** buat satu `DeploymentProfile` yang menentukan environment, auth mode, data mode, dan konfigurasi; validasi objek yang sama sebelum menghasilkan provider overrides. Tidak harus membuat OIDC sekarang. Production tanpa factory nyata harus gagal; staging boleh memakai auth/data demo hanya jika mode tersebut ditampilkan eksplisit.

## 5. Temuan non-blocker tetapi perlu dibereskan sebelum Tahap B/C

### Label, wilayah, dan dokumentasi masih bercampur

- `profile_page.dart:73` masih memakai judul “SINKRONISASI DATA SICABOR”.
- `profile_page.dart:775–776` masih menyatakan data lokal tersinkronisasi dengan SICABOR.
- Kontak pada `profile_page.dart:294–348` masih disebut helpdesk/email resmi tanpa penanda telah diverifikasi.
- README tidak berubah: masih menyatakan sesi demo berakhir setelah restart, padahal opsi Tetap Masuk kini menyimpan token demo.
- Cabor, pencarian, kepengurusan, detail sport/atlet, dan beberapa informasi klub masih hardcoded “Garut Kota”. Sesudah multi-akun ditambahkan, ini menjadi inkonsistensi produk, bukan sekadar kosmetik.
- Default unavailable masih menyebut validasi token ke server, padahal mode demo tidak memakai server.

Gunakan metadata sumber/lingkungan yang eksplisit. Jangan mengganti semua string hanya dengan `currentUser` di setiap widget; berikan `DistrictContext` atau data source metadata yang konsisten.

### Permission sudah dimodelkan tetapi belum dipakai

`DEMO-002` tidak memiliki `reports:export`, tetapi tetap dapat membuka dan menyalin rekap. Tentukan apakah salin rekap dianggap ekspor. Jika ya, sembunyikan/disable sesuai permission untuk UX dan siapkan penegakan server nantinya. `hasPermission()` saat ini hanya terlihat di test.

### Token masih berada pada state publik

`AuthSignedIn.accessToken` masih dapat dibaca setiap consumer Riverpod dan masuk equality/hash. Untuk token demo belum merupakan insiden, tetapi sebelum auth nyata pindahkan token ke session service internal. State UI cukup principal, phase, generation, dan status sesi non-secret.

### Refresh contract belum diuji

`DemoAuthRepository.refreshToken(String refreshToken)` masih mengabaikan parameter dan memanggil `restoreSession()`. Controller belum memakai refresh. Ini dapat ditunda sampai keputusan Tahap B, tetapi jangan menjadikan implementasi ini dasar interceptor nyata.

## 6. Penilaian regression test

### Sudah baik

- Login tertahan → logout → hasil login lama ditolak.
- Bootstrap simultaneous call → satu restore.
- Scope null → repository counter tetap nol.
- Signing-in/signing-out → route internal ditolak.
- Storage wrapper failure → `StorageException`.
- Token acak → `SessionExpiredFailure`.
- Production flag demo → `StateError`.
- Rekap Tarogong Kidul dan clipboard dinamis.
- Principal permissions unmodifiable dan equality diperluas.

### Masih dibutuhkan

| Test | Assertion utama |
| --- | --- |
| Login A tertahan di storage, login B selesai | Cleanup A tidak menghapus token B |
| Logout tertahan, login baru diminta | Login ditolak/ditunda; token baru tidak dihapus logout lama |
| Dua login dipanggil langsung | Hanya transisi legal; tidak ada dua commit storage |
| Restore tertahan lalu logout | Hasil restore tidak membuka sesi |
| Delete storage gagal saat logout | UI terkunci, error tertangani, recovery state jelas |
| Restart setelah cleanup gagal | Tidak terjadi silent re-login yang bertentangan dengan UX |
| Persist DEMO-003 lalu restore | Principal tidak berubah menjadi Tarogong Kidul |
| Fetch A tertahan lalu login B | A dibatalkan/diabaikan dan tidak pernah terlihat |
| Cancellation adapter Dio | Request HTTP nyata menerima cancellation token yang benar |
| Mode production aktual | Adapter yang dihasilkan bukan demo; flag dan komposisi tidak dapat berbeda |
| Semua layar dengan DEMO-002 | Tidak ada label Garut Kota atau klaim sinkron SICABOR |
| Permission tanpa `reports:export` | Aksi rekap mengikuti keputusan permission |

## 7. Urutan patch penutup Tahap A

1. **Serialisasikan lifecycle credential:** login/restore/logout dan write/clear berada dalam satu coordinator; larang login saat signing-out.
2. **Tangani cleanup failure:** jangan menghasilkan Future error yang diabaikan; tetap lock data dan sediakan status/retry aman.
3. **Perbaiki/hapus DEMO-003:** lakukan round-trip persistent session untuk setiap principal.
4. **Sederhanakan storage interface:** satu read method, namespace environment, tidak ada runtime type check untuk memilih storage.
5. **Lengkapi cancellation test dan kontrak repository:** tidak ada fetch tanpa scope, buktikan delayed A tidak tampil pada B.
6. **Ikat environment ke composition root:** objek konfigurasi yang divalidasi harus menjadi sumber provider yang benar-benar dipakai.
7. **Rapikan label dan seluruh konteks wilayah:** sumber mock, status belum tersinkron, README akurat, kontak ditandai/verifikasi.
8. **Jalankan bukti runtime:**

```bash
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## 8. Definition of Done revisi

Tahap A dapat ditandai selesai apabila:

- [ ]  Semua mutasi auth/storage terserialisasi atau mempunyai ownership guard yang tidak dapat menghapus token sesi baru.
- [ ]  Login/restore tidak dapat berjalan melewati logout; seluruh state non-signed-in tetap terkunci.
- [ ]  Kegagalan clear secure storage memiliki state/UX dan tidak menjadi unhandled Future.
- [ ]  Tidak ada fetch data tanpa session scope; delayed response lintas akun diuji.
- [ ]  Production tidak dapat memakai adapter demo melalui mismatch flag/provider.
- [ ]  Semua akun demo yang ditawarkan mempunyai persist/restore identity yang konsisten.
- [ ]  Auth hanya mempunyai satu sumber kebenaran dan satu kontrak storage yang tidak rekursif.
- [ ]  Label sumber data dan wilayah konsisten pada seluruh alur akun kedua.
- [ ]  Output analyze/test dari mesin Flutter dicatat dan semua regression test kritis lulus.

**Keputusan akhir:** revisi 2 jauh lebih baik dan menunjukkan implementasi review sebelumnya, bukan hanya perubahan dokumentasi. Lanjutkan dengan patch lifecycle terfokus; jangan menambah SDK OIDC/JWT lebih dahulu. Diskusi Tahap B dengan pemilik SICABOR/IdP tetap boleh berjalan paralel.
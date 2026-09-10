<aside>
🔎

**Verdict: kemajuan struktural nyata, tetapi Tahap A belum selesai.** Model identitas, abstraction auth, layar sesi, profil dinamis, pemisahan tombol keluar, dan fixture lintas kecamatan sudah ditambahkan. Penghalang utamanya sekarang adalah konsistensi state, guard pada fase transisi, hasil operasi terlambat setelah logout, fallback data tanpa sesi, serta pemisahan demo dari produksi. Tidak perlu menulis ulang semuanya; tutup celah ini sebelum memasang auth nyata.

</aside>

## 1. Lingkup dan cara membaca hasil

**Sumber terbaru:** `app-kok-koni-main (1).zip`, dikirim 8 September 2026 pukul 21.52 WIB. SHA-256: `12a63fded0098bb3081f7f2199145cd4bed81e12633d94deaf7151be9b1a8890`.

**Pembanding:** ZIP audit awal dan checklist Bagian 10, Tahap A pada Audit Autentikasi & Roadmap Implementasi — KOK KONI Garut (Flutter).

**Metode:** membandingkan berkas lama–baru, membaca implementasi dan assertion test, serta menelusuri alur asynchronous dan wiring provider/router. ZIP terbaru memuat 41 file Dart di `lib/` termasuk generated dan 25 file `*_test.dart`, meningkat dari 31 dan 18. Jumlah file bukan ukuran coverage atau bukti keamanan.

**Batas validasi:** Flutter dan Dart masih tidak tersedia pada lingkungan pemeriksaan. Tidak ada `flutter analyze`, `flutter test`, build, atau tes perangkat yang dijalankan dalam review ini. Semua skenario di bawah adalah analisis statis atau regression test yang direkomendasikan, bukan laporan runtime lulus/gagal. Preview PNG, nama test, dan klaim dokumen proyek tidak diperlakukan sebagai bukti eksekusi ulang.

**Tidak dilakukan:** mengubah source ZIP, membuat backend, atau memasang layanan autentikasi. Dokumen ini adalah review revisi baru; temuan audit awal tetap menjadi catatan historis.

### Batas penilaian Tahap A

Tidak adanya OIDC, `/me`, refresh server, MFA, atau integrasi SICABOR **bukan alasan menyatakan Tahap A gagal**. Semua itu belum menjadi target tahap ini. Yang harus benar sekarang adalah boundary demo, state machine, perilaku tanpa sesi, race handling, dan fake yang dapat menguji kondisi buruk sebelum server tersedia.

## 2. Perubahan yang sudah baik

- **Auth sudah dipisahkan ke modul:** `lib/core/auth/domain/`, `data/`, dan `presentation/` memuat `UserPrincipal`, `AuthState`, `AuthFailure`, `AuthRepository`, storage abstraction, dan controller. Fondasinya dapat dipertahankan.
- **Ada enam state auth:** bootstrapping, signed out, signing in, signed in, temporarily unavailable, signing out. Ini peningkatan dari boolean, walaupun consumer/router belum menangani semuanya dengan aman.
- **Profil dan tombol keluar sudah di luar DataView:** `profile_page.dart:39–136`. Ini menutup masalah struktural audit awal ketika loading/error data olahraga menyembunyikan kontrol keluar. Test khusus error snapshot tersedia di `profile_page_test.dart:152–174`.
- **Nama dan wilayah mengikuti principal pada jalur signed-in:** `home_page.dart:15–16,110–126` dan `profile_page.dart:576–594`. Fallback hardcoded masih perlu dihapus dari jalur tanpa identitas.
- **Ingat SK dibedakan dari Tetap Masuk:** `login_page.dart:19–20,465–557`. Username/password memiliki autofill hints dan `AutofillGroup`. Password tetap tidak disimpan oleh kode login yang diperiksa; nilai persisten demo adalah token sintetis.
- **Scope data mulai benar:** `SessionScope` memuat user ID, district ID, dan generation; `snapshotProvider` sudah bergantung pada scope.
- **Fixture Tarogong Kidul tersedia:** 4 klub/cabor dan 88 atlet, berbeda dari Garut Kota. Test berurutan akun A → logout → akun B ada di `session_scope_test.dart:37–89`.
- **Subtitle lisensi sudah dihitung dari data:** special case `expired == 5` di beranda telah dihapus.

## 3. Status terhadap checklist Tahap A

| Butir Tahap A | Status review | Alasan |
| --- | --- | --- |
| Pisah demo/staging/production, tanpa fallback produksi | Belum | Satu `main.dart`; provider auth/data default selalu demo; tidak ada validasi environment produksi |
| AuthRepository + principal + state + adapter demo | Sebagian besar struktur tersedia | Controller boolean lama masih dipanggil UI; demo belum dibatasi deployment |
| Startup gate dan auth unavailable | Sebagian | Route tersedia, tetapi state transisi belum dijaga; failure restore dan retry masih bermasalah |
| Profil akun dan logout tidak bergantung data olahraga | Terpenuhi secara struktur | Ada pemisahan widget dan test error snapshot; jalur controller logout tetap perlu diperbaiki |
| Session-scoped cache dan desain cancellation | Sebagian | Dependency scope ada; tanpa sesi masih fetch, tidak ada cancellation request, generation belum menjadi pengaman operasi auth |
| Label Ingat SK, mock, snackbar, kontak | Sebagian | Label Ingat SK benar; klaim sinkronisasi dan kontak contoh masih ada |
| Fake success/rejection/timeout/expiry/revocation | Sebagian | Success/rejection/login timeout ada; expiry/revocation terkontrol dan token tak dikenal belum ditolak |

**Keputusan:** jangan centang seluruh Tahap A hanya karena alur login normal terlihat berjalan. Diskusi kontrak Tahap B boleh dimulai paralel, tetapi implementasi auth nyata sebaiknya menunggu penutupan temuan prioritas berikut.

## 4. Temuan utama yang perlu diperbaiki

Prioritas berikut adalah urutan engineering, bukan CVSS dan bukan klaim kebocoran data resmi. Dataset masih mock.

### A-01 · Guard membiarkan fase signingIn dan signingOut mengakses route data — prioritas tinggi

**Bukti:** `lib/app.dart:28–47`. Guard hanya menangani `AuthBootstrapping`, `AuthTemporarilyUnavailable`, `AuthSignedOut`, dan `AuthSignedIn`. Dua state lainnya jatuh ke `return null`.

**Implikasi:** saat login belum selesai, navigasi/deep link ke `/home` atau `/club/...` tidak ditolak oleh guard. Saat logout berjalan, route lama tidak segera dialihkan ke layar terkunci. Di versi ini repository lokal bahkan masih dapat menyediakan data tanpa principal; gabungan kedua pola tersebut membuat pemisahan UI tanpa sesi lemah.

**Perbaikan:** semua state selain `AuthSignedIn` harus memiliki tujuan publik/terkunci yang eksplisit. `AuthSigningIn` tetap di login; `AuthSigningOut` masuk layar keluar yang tidak memicu restore.

**Penting:** jangan sekadar mengarahkan signingOut ke `/session` dengan implementasi sekarang. `SessionStartupPage.initState()` otomatis menjalankan `bootstrap()`, sehingga layar logout dapat memulai restore lagi. Pisahkan layar keluar, atau jadikan startup screen murni UI dan pindahkan orkestrasi bootstrap ke satu pemilik.

**Tes penerimaan:** tahan future login/logout, coba route terlindungi, pastikan tidak ada halaman data sebelum/sesudah sesi dianggap aktif.

### A-02 · Generation masih menjadi penghitung, belum menolak hasil operasi stale — prioritas tinggi

**Bukti:** `auth_controller.dart:47–66,69–115,122–130`. Generation dinaikkan pada login/restore sukses dan awal logout, tetapi tidak pernah ditangkap sebelum `await` lalu dibandingkan setelahnya. Tidak ada guard operasi ganda pada controller.

**Urutan reproduksi yang perlu dites:**

1. Mulai `login()` dengan fake repository yang hasilnya ditahan menggunakan `Completer`.
2. Panggil dan selesaikan `logout()`.
3. Selesaikan future login lama dengan hasil sukses.
4. Jalur kode sekarang tetap mencapai `state = AuthSignedIn(...)` pada baris 94.

Restore lama juga dapat menimpa hasil logout. Login paralel dapat menimpa identitas berdasarkan urutan selesai request, bukan urutan aksi pengguna. Error dari operasi lama pun dapat menimpa sesi baru.

**Risiko tambahan:** `DemoAuthRepository.login()` menulis refresh token sebelum mengembalikan hasil (`80–84`). Jadi menambahkan generation check pada controller saja belum cukup: hasil login yang dibuang masih mungkin meninggalkan token di storage setelah cleanup logout.

**Perbaikan:** operation epoch/generation diperbarui saat boundary operasi dimulai; periksa semua success/error setelah await; cegah login/restore bersamaan; serialisasikan commit token dan clear storage; batalkan/abaikan operasi lama. Jangan membersihkan token secara global dari operasi stale tanpa memastikan token tersebut bukan milik sesi baru.

**Tes penerimaan:** logout selama login/restore/write-storage → tetap signed out dan storage kosong; login A/B terkontrol → hasil A yang terlambat tidak menimpa B.

### A-03 · Tanpa sesi justru mengambil dataset Garut Kota — prioritas tinggi

**Bukti:** `lib/data/repository.dart:79–86`:

```dart
final scope = ref.watch(sessionScopeProvider);
// ...
if (scope != null) {
  return repository.fetchDistrict(scope.districtId);
}
return repository.fetchDistrict('garut_kota');
```

**Fakta:** provider yang dibaca saat `sessionScope == null` tetap mengambil data. Tidak ada token pembatalan/cancellation dalam signature `fetchDistrict`; generation hanya menjadi dependency, bukan argumen/check pada proses fetch.

**Yang sudah membaik:** perubahan scope dapat memicu recomputation Riverpod. Jangan menyimpulkan bahwa Riverpod pasti memublikasikan future lama; perilaku disposal/recomputation perlu diuji. Tetapi recomputation **tidak sama dengan membatalkan request jaringan** dan bukan bukti seluruh cache sensitif sudah dibuang.

**Perbaikan:** tanpa sesi kembalikan keadaan unauthenticated tanpa memanggil repository. Jika widget preview membutuhkan data, override provider/principal pada test/preview, bukan menambahkan fallback pada aplikasi. Tambahkan cancellation dan session-keyed lifecycle; gunakan scope `(environment, userId, districtId, generation)` ketika environment tersedia.

**Tes penerimaan:** dengan scope null, jumlah panggilan repository harus nol; pergantian scope menutup request lama; hasil lama tidak terlihat pada akun baru. Uji juga tab indexed stack, detail, pencarian, dan cache media—bukan hanya jumlah klub setelah dua login berurutan.

### A-04 · Adapter demo tetap default untuk semua build — prioritas tinggi sebelum integrasi nyata

**Bukti:** `auth_controller.dart:20–25` selalu membuat `DemoAuthRepository`; `data/repository.dart:75–77` selalu `DemoKokRepository`; `main.dart:7–16` belum memilih environment. Tidak ditemukan entrypoint/config validator demo–staging–production pada `lib/`.

**Implikasi:** menjalankan release tidak otomatis mematikan login demo. Build release dan environment produksi bukan konsep yang sama; demo juga boleh dibangun release, tetapi keputusan itu harus eksplisit.

**Perbaikan:** tentukan enum environment dan composition root. Demo secara eksplisit memilih adapter mock. Staging/production yang belum memiliki adapter sah harus menolak startup, bukan fallback demo. Pemilihan auth dan data dapat terpisah pada staging. Tidak wajib langsung menambah seluruh flavor native; configuration boundary yang fail-closed dapat menjadi langkah awal.

**Tes penerimaan:** environment tak dikenal, production dengan demo auth, atau konfigurasi wajib kosong → ditolak oleh kontrol runtime yang tetap aktif pada release, bukan hanya `assert`.

### A-05 · Error membaca/menghapus secure storage disembunyikan — prioritas tinggi untuk sesi persisten

**Bukti:** `auth_token_storage.dart:21–39`: read failure diubah menjadi `null`; delete failure ditelan `catch (_) {}`. Key tunggal `v1_kok_refresh_token` belum dipisah environment/issuer.

**Dampak:** controller tidak dapat membedakan tidak ada token dengan storage bermasalah. Logout dapat tampak selesai walaupun token masih tersimpan. Bila pembacaan berhasil pada startup berikutnya, token demo tersebut dapat memulihkan sesi lagi.

**Perbaikan:** propagasikan atau petakan error storage secara bertipe; jangan fallback plaintext. Logout tetap mengunci UI lokal, tetapi status cleanup tidak boleh dianggap berhasil jika delete gagal. Tetapkan retry/reauth policy untuk restart setelah cleanup bermasalah. Gunakan namespace environment dan issuer/client ketika sudah disepakati.

**Nuansa versi:** ZIP mengunci `flutter_secure_storage 9.2.4`, bukan versi terbaru yang dibahas pada audit awal. `encryptedSharedPreferences: true` tidak otomatis merupakan API invalid pada versi yang dipakai. Jangan menyebutnya kerentanan hanya karena versinya lama. Review migrasi/backup/Keychain tetap diperlukan sebelum token nyata; secure storage web juga bukan jaminan setara native Keychain/Keystore.

**Kesenjangan test:** `auth_token_storage_test.dart:33–46` menguji `InMemoryAuthTokenStorage`, bukan wrapper `SecureAuthTokenStorage`. Fake melempar exception, sedangkan wrapper asli menelannya; test tersebut tidak menangkap perbedaan ini.

### A-06 · Restore menerima token apa pun; fake expiry/revocation belum memadai — prioritas menengah

**Bukti:** `demo_auth_repository.dart:93–117`. Semua nilai non-null yang tidak mengandung `tarogong`/`koni` dianggap sesi Garut Kota. String kosong, token acak, atau penanda expired/revoked dapat jatuh ke sukses. `refreshToken(String refreshToken)` pada baris 121–122 tidak memakai argumennya, melainkan membaca storage ulang.

**Penilaian proporsional:** mock tidak harus memverifikasi JWT nyata. Masalahnya adalah fake terlalu permisif untuk membuktikan state machine menolak token tidak dikenal atau sesi yang dicabut.

**Perbaikan:** map token fixture secara exact atau sediakan fake dengan hasil restore/login/refresh yang dapat diatur. Token unknown/expired/revoked harus gagal eksplisit. Bedakan tidak ada sesi, expired/revoked, dan unavailable. Fake harus bisa menahan hasil dan mensimulasikan error, bukan hanya akun `DEMO-TIMEOUT` pada login.

**Tes penerimaan:** token kosong/acak/revoked tidak pernah membuka Garut Kota; refresh memakai kontrak yang jelas dan tidak diam-diam mengabaikan input.

### A-07 · Failure bootstrap dan ownership retry belum konsisten — prioritas menengah

**Bukti:** `auth_controller.dart:51–65`: semua `AuthResult.failed(...)` saat restore menjadi `AuthSignedOut`, termasuk `NetworkTimeoutFailure`; hanya exception masuk unavailable. Sebaliknya login memeriksa failure timeout secara khusus.

**Masalah retry:** `SessionUnavailablePage:91–94` memanggil `retrySession()` → `bootstrap()`. Bootstrap mengubah state ke bootstrapping → router menampilkan `/session` → `SessionStartupPage:18–22` kembali memanggil bootstrap. Dengan restore yang belum selesai ketika layar terpasang, jalur ini dapat memulai restore kedua. Belum ada single-flight atau tes hitungan panggilan untuk jalur tersebut.

**Masalah pesan:** route unavailable dibuat tanpa `reason` (`app.dart:57–58`); halaman tidak membaca state auth untuk reason/canRetry. Pesan khusus pada `AuthTemporarilyUnavailable` tidak dipakai oleh halaman default.

**Perbaikan:** satu pemilik orkestrasi bootstrap, single-flight restore, pemetaan failure konsisten, dan halaman unavailable yang membaca reason/canRetry. Kegagalan sementara tidak boleh diperlakukan sebagai password salah atau token definitif dicabut.

**Tes penerimaan:** restore `AuthResult.failed(NetworkTimeoutFailure())` → unavailable; satu aksi retry → tepat satu restore; reason aktual tampil; tidak ada restore saat signingOut.

### A-08 · Dua sumber sesi masih aktif — prioritas menengah

**Bukti:** `lib/core/session.dart:7–28` masih controller boolean lama. Sesudah auth baru sukses, `login_page.dart:62–69` masih memanggil login lama; profil juga memanggil kedua logout (`profile_page.dart:539–545`). Helper `test/app_test.dart:73–85` melakukan login ganda.

**Dampak:** akun DEMO-002 berhasil pada auth baru, tetapi tidak cocok pada validator DEMO-001 lama. Sesi restore juga tidak menyetel boolean lama. Kini router memakai auth baru, jadi ini bukan bukti bypass router tambahan; masalahnya adalah state saling bertentangan, penulisan preferensi ganda, dan risiko pengembang memakai provider yang salah di fitur berikutnya.

**Perbaikan:** pindahkan `preferencesProvider` ke file preferences terpisah dan hapus `SessionController/sessionProvider` beserta pemanggilan UI. Migrasikan test lama ke auth controller/fake. Jangan mempertahankan validator kredensial lama hanya supaya test lama tetap bisa berjalan.

`_submit()` juga masih belum memiliki early guard `_busy` (`login_page.dart:48–54`). Tombol/keyboard sudah dibatasi, tetapi controller tetap harus menolak/coalesce operasi ganda; proteksi UI saja tidak cukup.

### A-09 · Label sinkronisasi dan metadata multi-akun belum selesai — prioritas menengah/rendah

- `home_page.dart:299`: masih “Terakhir Tersinkron SICABOR”.
- `profile_page.dart:738,751–760,774`: status sinkron, tooltip SICABOR, dan snackbar sukses segera setelah invalidate tanpa await.
- `profile_page.dart:176,186,244–251`: judul, deskripsi, serta clipboard rekap tetap Garut Kota meskipun dataset/principal Tarogong Kidul. Ini menjadi inkonsistensi nyata setelah fitur multi-akun ditambahkan.
- `profile_page.dart:576–594`: tanpa user kembali ke Pak Asep/Garut Kota; role profil masih “Koordinator” alih-alih principal.role.
- `profile_page.dart:302–348`: kontak hardcoded masih ditampilkan, termasuk label “Email Resmi”, tanpa penanda belum terverifikasi.
- `SessionStartupPage:94` dan default unavailable menyiratkan sesi aman/validasi server meskipun adapter hanya memeriksa string lokal.
- README masih menyatakan sesi demo berakhir setelah restart, padahal opsi Tetap Masuk kini menyimpan token sintetis dan restore dapat masuk kembali.

**Perbaikan:** sumber data eksplisit; gunakan “Memeriksa sesi demo”/“Data demo dimuat”; sukses reload hanya setelah future selesai; identitas rekap dari principal/snapshot metadata; hapus fallback identitas nyata saat user null; tandai kontak contoh. Update assertion test yang mempertahankan klaim sinkron palsu.

## 5. Catatan desain tambahan sebelum auth nyata

### Permission dan identitas

`UserPrincipal.permissions` bertipe `Set` final tetapi tidak dibuat defensive copy; final tidak membuat isi Set immutable. Equality principal hanya melihat id, SK, district ID (`user_principal.dart:22–32`), bukan nama, role, atau permissions. Karena `AuthSignedIn` ikut memakai equality tersebut, perubahan permission pada user yang sama dengan generation/token sama dapat dianggap tidak berubah. Gunakan model immutable dan equality yang sesuai; tetap pisahkan cache key dari keseluruhan principal.

Token berada pada `AuthSignedIn.accessToken`, sehingga semua consumer provider dapat membacanya. Ini bukan bukti kebocoran sekarang, tetapi sebaiknya token dipindahkan ke service internal sebelum kredensial nyata tersedia; state publik cukup principal, fase, dan generation.

Akun `DEMO-002` tidak memiliki `reports:export`, tetapi menu salin rekap tidak memeriksa permission. `hasPermission()` saat ini hanya dipakai dalam test. Tentukan dahulu apakah salin rekap termasuk ekspor; bila ya, enforce pada UX dan nantinya server. UI permission tidak pernah menggantikan otorisasi backend.

Akun `DEMO-003` memiliki `districtId = koni_kab` dan permission `documents:verify`, di luar scope awal viewer satu kecamatan. Repository tidak memiliki fixture khusus `koni_kab`, sehingga jatuh ke dataset Garut Kota. Ini bukan eskalasi privilege yang terbukti, tetapi scope demo menjadi ambigu. Untuk Tahap A, dua akun viewer berbeda kecamatan sudah cukup; nonaktifkan akun ketiga atau definisikan scope eksplisit.

### Kontrak AuthRepository

Interface sekarang berorientasi SK/password dan `logout(): Future<void>`. Itu boleh untuk adapter demo/credential, tetapi jangan menganggap cukup mengganti kelas jika Tahap B memilih OIDC. OIDC memakai browser/interactive flow, bukan meneruskan password dari form Flutter. Kontrak logout nyata juga perlu menyampaikan hasil cleanup lokal versus remote revocation. Putuskan bentuk akhir setelah IdP dipilih, tanpa membuat endpoint SICABOR tebakan.

## 6. Contoh perbaikan terarah

Contoh berikut belum di-compile, bukan patch lengkap, dan tidak diterapkan pada ZIP.

### 6.1 Redirect dengan default tertutup

Definisi state menggunakan nama pada revisi ini. `/signing-out` adalah route baru yang harus didaftarkan dan **tidak** menjalankan bootstrap.

```dart
String? authRedirect(AuthState auth, String location) {
  if (auth is AuthSigningOut) {
    return location == '/signing-out' ? null : '/signing-out';
  }
  if (auth is AuthBootstrapping) {
    return location == '/session' ? null : '/session';
  }
  if (auth is AuthTemporarilyUnavailable) {
    return location == '/session-unavailable'
        ? null : '/session-unavailable';
  }
  if (auth is! AuthSignedIn) {
    return location == '/login' ? null : '/login';
  }
  const gates = {
    '/login', '/session', '/session-unavailable', '/signing-out',
  };
  return gates.contains(location) ? '/home' : null;
}
```

Hubungkan ke redirect router dengan `state.matchedLocation`. Guard ini memperbaiki keputusan navigasi, bukan race controller, cancellation, atau otorisasi backend.

### 6.2 Hentikan fetch tanpa principal terlebih dahulu

Perubahan minimal berikut menghapus fallback; belum merupakan solusi cache/cancellation lengkap.

```dart
final class SessionRequired implements Exception {}

final snapshotProvider = FutureProvider<KokSnapshot>((ref) async {
  final scope = ref.watch(sessionScopeProvider);
  if (scope == null) throw SessionRequired();
  final repository = ref.watch(repositoryProvider);
  return repository.fetchDistrict(scope.districtId);
});
```

Untuk produksi, pisahkan state unauthenticated dari error jaringan pada UI dan tambahkan cancellation/session-scoped lifecycle. Test/preview yang sebelumnya bergantung fallback harus memberi principal atau override snapshot secara eksplisit.

### 6.3 Jangan mengubah error storage menjadi sukses

Perubahan minimal wrapper mempertahankan error untuk ditangani coordinator; namespace dan opsi platform tetap perlu dikonfigurasi.

```dart
@override
Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

@override
Future<void> clear() => _storage.delete(key: _refreshTokenKey);
```

Setelah perubahan ini, controller/UI wajib menangani exception. Jangan sekadar membuat delete melempar lalu membiarkan future logout tidak ditangani. Hasil keluar lokal, cleanup storage, dan revocation remote nantinya merupakan hasil berbeda.

### 6.4 Pengaman operasi asynchronous harus end-to-end

```
PSEUDOCODE — bukan implementasi Dart drop-in:

login/restore dimulai:
  validasi phase; gabungkan/tolak operasi ganda
  tangkap operationEpoch saat memulai
  await hasil adapter
  jika epoch berubah atau controller dibuang: jangan publish
  commit token melalui antrean storage bersama dengan logout
  cek epoch lagi setelah setiap await
  publish SignedIn hanya jika operasi masih berhak

logout dimulai:
  naikkan epoch segera; state SigningOut; tutup akses data
  batalkan request lama dan blokir login selama cleanup
  clear token melalui antrean yang sama
  hasil cleanup gagal tidak boleh dinyatakan berhasil
  jangan izinkan operasi lama menulis token kembali
  state signed-out/cleanup-error sesuai kontrak yang disepakati
```

Jangan menyalin hanya pemeriksaan epoch sebelum `state = ...` sambil membiarkan adapter menulis storage lebih dahulu tanpa koordinasi. Itulah sebabnya A-02 bukan sekadar menambah satu `if`.

## 7. Regression test yang paling dibutuhkan

Pengujian baru sebaiknya menggunakan `Completer`, fake storage yang bisa gagal per operasi, dan repository spy. Gunakan controller/guard asli untuk perilaku yang sedang diuji; jangan meng-override controller menjadi selalu sukses.

| Skenario | Assertion minimum |
| --- | --- |
| Login tertahan, lalu logout, kemudian login lama sukses | Tetap signed out; tidak ada token sisa |
| Restore tertahan, logout, restore lama sukses | Tidak membuka sesi lagi |
| Storage write login selesai setelah clear logout | Token stale tidak tertinggal |
| Double-submit login / retry restore | Maksimal satu operasi aktif sesuai kontrak |
| SigningIn/signingOut mengakses `/club/garuda` | Route data tidak terbuka |
| Retry unavailable dengan restore tertahan | Satu klik menghasilkan tepat satu restore |
| Restore mengembalikan NetworkTimeoutFailure | Unavailable, bukan signed out karena kredensial |
| Tanpa session scope membaca snapshot | Repository tidak dipanggil |
| Akun A fetch tertahan, pindah ke B | Tidak menampilkan data A; cancellation terbukti |
| Token kosong/acak/expired/revoked | Tidak ada fallback sukses ke Garut Kota |
| Wrapper storage read/delete melempar | Error tidak disembunyikan; cleanup tidak diklaim sukses |
| Profil saat snapshot loading/error | Identitas dan logout tetap dapat digunakan |
| Tarogong Kidul membuka/salin rekap | Nama wilayah dan isi sesuai Tarogong Kidul |
| Production dengan adapter demo / environment salah | Konfigurasi ditolak |
| Logout di tengah navigasi/tab/detail | Tidak ada kilasan data/identitas fallback atau restore ulang |

### Apa yang sudah dan belum dibuktikan oleh test dalam ZIP

- Test scope berurutan merupakan awal yang baik, tetapi tidak menguji respons tertahan, request cancellation, snapshot tanpa sesi, atau semua state transisi.
- Test logout controller memeriksa signed-out dan kenaikan generation; belum membuktikan hasil lama tidak memulihkan sesi.
- Test token storage saat ini memeriksa fake, bukan wrapper secure storage/platform asli.
- Test error profil memeriksa tombol dan dialog; test logout lain memakai fake controller. Keduanya berguna untuk UI, tetapi bukan bukti cleanup/revocation nyata.
- Beberapa test lama masih menggunakan boolean session lama; migrasikan agar test menjaga kontrak aplikasi aktif, bukan compatibility path.
- Tidak ditemukan dalam kode test yang diperiksa skenario revocation/expiry terkontrol atau production configuration gate.

Jalankan setelah perbaikan pada lingkungan Flutter proyek:

```bash
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Tambahkan build target yang benar sesuai platform pilot. Jangan menafsirkan command di atas sebagai sudah dijalankan oleh reviewer.

## 8. Urutan kerja yang disarankan: patch penutup Tahap A

1. **Satukan sumber auth:** hapus login/logout boolean lama, pindahkan preferences, migrasikan test.
2. **Tutup guard semua phase dan rapikan ownership bootstrap:** startup/retry satu pemilik; logout screen tidak me-restore sesi.
3. **Perbaiki race login/restore/logout dan storage:** epoch, single-flight, commit/clear terkoordinasi, disposal handling. Tulis failing regression test terlebih dahulu pada mesin Flutter.
4. **Tutup fetch tanpa sesi dan lengkapi lifecycle scope:** no fallback, cancellation, delayed-response test, reset state sensitif.
5. **Buat environment gate:** demo eksplisit, staging/production yang belum dikonfigurasi ditolak; jangan menunggu backend untuk ini.
6. **Perketat fake dan storage errors:** unknown/expired/revoked/timeout tersedia; real wrapper diuji terhadap failure.
7. **Rapikan metadata dan label:** sumber mock, await reload, rekap kecamatan dinamis, reason unavailable, kontak/README akurat.

**Definition of Done revisi Tahap A:** demo tetap berfungsi, auth punya satu sumber kebenaran, semua state non-signed-in tertutup, logout tidak dapat dibatalkan hasil asynchronous lama, data tidak di-fetch tanpa sesi, konfigurasi non-demo tidak fallback, fake menguji failure, dan ada hasil analyze/test dari lingkungan Flutter.

**Boleh dimulai paralel:** pertanyaan Tahap B kepada pembimbing/SICABOR tentang IdP, pemilik akun, username/SK, assignment kecamatan, platform pilot, serta kontrak `/me`. Jangan menunda diskusi tersebut demi seluruh kosmetik UI.

**Kesimpulan akhir:** implementasi ini layak dilanjutkan dan banyak fondasi audit awal sudah ditangani. Namun keberhasilan happy path multi-akun belum sama dengan isolasi sesi yang aman. Fokus revisi berikutnya pada lifecycle dan batas akses, bukan menambah JWT/SDK/backend sebelum kontraknya kokoh.
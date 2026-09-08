<aside>
🔐

**Kesimpulan:** aplikasi sudah memiliki fondasi prototipe Flutter yang dapat dilanjutkan, tetapi login saat ini belum merupakan autentikasi server. Prioritas berikutnya adalah membangun batas autentikasi, siklus hidup sesi, dan otorisasi kecamatan—bukan sekadar mengganti akun demo dengan token. Autentikasi nyata dapat dikerjakan lebih dahulu sementara data olahraga tetap mock, tanpa menunggu seluruh integrasi SICABOR.

</aside>

**Tanggal audit:** 8 September 2026 · **Versi pada sumber:** 0.1.0+1 · **Fokus:** kesiapan autentikasi, sesi, otorisasi, serta integrasi API.

## 1. Ringkasan eksekutif

- **Pertahankan fondasi yang sudah baik:** Riverpod, go_router dengan guard terpusat, interface repository data, model Freezed, serta pengujian login/keluar. Tidak perlu menulis ulang seluruh aplikasi.
- **Pisahkan autentikasi dari data SICABOR:** bangun `AuthRepository` dan state sesi eksplisit. Gunakan layanan identitas resmi jika tersedia; untuk mobile, arah utama yang disarankan adalah OpenID Connect dengan Authorization Code + PKCE melalui browser sistem.
- **Jangan membawa mekanisme demo ke data nyata:** kredensial tertanam, sesi berupa boolean, profil/kecamatan hardcoded, dan repository yang tidak terikat identitas belum cukup untuk melindungi data atlet. Semua pembatasan kecamatan dan dokumen harus ditegakkan server.
- **Target milestone terdekat:** login nyata di staging, profil dari server, restore sesi, refresh yang aman, logout yang membersihkan data, serta pengujian gagal-login/expiry/akses lintas kecamatan. Dataset klub dan atlet boleh tetap sintetis dan diberi label yang benar.

### Arti “standar industri” dalam dokumen ini

Bukan sertifikasi dan bukan sekadar memakai JWT, Firebase, atau secure storage. Artinya: protokol yang sesuai platform, server sebagai sumber kepercayaan, least privilege, pengelolaan sesi lengkap, perlindungan rahasia, pemulihan akun, pengujian negatif, dan proses rilis yang dapat diaudit. OWASP MASVS, RFC OAuth, OWASP Cheat Sheets, dan NIST digunakan sebagai acuan teknis; tidak otomatis berarti aplikasi telah memenuhi semua kontrol atau tingkat assurance tertentu.

## 2. Lingkup, metode, dan batas audit

### 2.1 Sumber yang diperiksa

1. Arsip `app-kok-koni-main.zip`, terutama `lib/`, `test/`, konfigurasi Android/iOS/web, `pubspec.yaml`, `pubspec.lock`, dan README.
2. Wireframe `Wireframe_KOK (3).pdf` yang diberikan: acuan read-only, satu kecamatan per akun, entitas klub/atlet/pelatih/official, serta pertanyaan hak akses dokumen.
3. Dokumentasi resmi protokol keamanan dan paket Flutter, dicantumkan pada bagian referensi.

**Identitas arsip untuk reproduksi:** SHA-256 `a90f0c2606a393ba773f1c2a1c893a477382a372a84b96fd1035e7baa58bea25`.

Nomor baris dalam temuan mengacu pada isi ZIP ini, bukan revisi repository yang lebih baru. Arsip berisi 31 file Dart di `lib/`, termasuk 2 file generated, dan 18 file `*_test.dart`. Angka ini menunjukkan inventaris, bukan persentase coverage.

### 2.2 Yang dilakukan dan yang belum dilakukan

**Dilakukan:** pembacaan kode, penelusuran jalur login–router–repository–logout, pemeriksaan konfigurasi native, pembacaan assertion pengujian, serta pemeriksaan statis dan perhitungan sederhana atas generator data demo.

**Belum dilakukan:** menjalankan `flutter analyze`, `flutter test`, build APK/IPA/web, pengujian pada perangkat, inspeksi trafik, audit backend/IdP, pemindaian dependency advisory menyeluruh, atau penetration test. Flutter dan Dart tidak tersedia di lingkungan audit. Pernyataan README bahwa proyek pernah diuji bukan hasil eksekusi ulang audit ini.

**Konsekuensi:** temuan kode dinyatakan sebagai fakta statis atau risiko migrasi. Tidak ada klaim bahwa server SICABOR memiliki kerentanan, bahwa data resmi telah bocor, atau bahwa semua pengujian lulus. Potongan kode rekomendasi adalah rancangan untuk diadaptasi dan diuji, bukan patch yang sudah diterapkan pada ZIP.

### 2.3 Asumsi kerja

- SICABOR belum menyediakan kontrak autentikasi/API yang dapat diperiksa dalam bahan audit.
- Data saat ini adalah ilustrasi; nomor kontak dan identitas yang tertulis di UI belum dianggap terverifikasi.
- KOK memantau data olahraga secara read-only. Login, logout, pemulihan akun, dan pengelolaan sesi tetap boleh mengubah state autentikasi; read-only tidak berarti seluruh HTTP harus GET.
- Android/iOS adalah target mobile, tetapi web harus dibahas karena direktori web ada dan README mengarahkan penggunaan Chrome.
- Default awal untuk dokumen sensitif adalah **status kelengkapan saja**, sampai kewenangan membuka berkas disepakati.

## 3. Peta keadaan aplikasi saat ini

### 3.1 Arsitektur yang benar-benar ada

```
main.dart
  └─ inisialisasi SharedPreferences
     └─ ProviderScope
        └─ KokApp / GoRouter
           ├─ LoginPage
           │   └─ SessionController.signIn(SK, password, remember)
           │      ├─ bandingkan dengan kredensial demo di kode
           │      ├─ simpan/hapus remembered_sk
           │      └─ state = true
           └─ halaman terlindungi oleh boolean
               └─ DataView → snapshotProvider
                   └─ DemoKokRepository.fetch()
                       └─ dataset lokal

Dio provider sudah didefinisikan, tetapi belum dipakai untuk login
atau mengambil dataset tersebut.
```

### 3.2 Stack dan kesiapan

| Area | Bukti pada kode | Keadaan |
| --- | --- | --- |
| State management | `flutter_riverpod`; `core/session.dart` | Sesi `Notifier<bool>`; data `FutureProvider` |
| Navigasi | `app.dart:19–94` | go_router, redirect global, lima tab dengan indexed stack |
| HTTP | `data/repository.dart:11–22` | Dio, timeout koneksi 15 detik dan respons 20 detik; belum ada request API |
| Sumber data | `data/repository.dart:24–153` | Provider selalu membuat `DemoKokRepository` |
| Persistensi | `main.dart:7–15`; `session.dart:17–23` | SharedPreferences hanya untuk nomor SK yang diingat |
| Identitas pengguna | `home_page.dart:107–118`; `profile_page.dart:614–646` | Nama, kecamatan, dan label akses hardcoded |
| Model domain | `data/models.dart:6–65` | Klub, orang olahraga, pengurus, snapshot; belum ada principal/session auth |
| Pengujian | `test/repository_test.dart`; `test/app_test.dart`; `test/profile_page_test.dart` | Assertion demo tersedia; belum menguji token/server |
| Native release | `android/app/build.gradle.kts:28–33` | Release memakai signing config debug |
| Target web | `web/`; README | Ada; strategi keamanan browser belum diimplementasikan |

Versi yang **terkunci** dalam `pubspec.lock`: Riverpod 3.4.3, go_router 17.5.0, Dio 5.11.1, dan shared_preferences 2.5.5. Ini berbeda dari batas minimum/caret di `pubspec.yaml`. Lockfile mensyaratkan Dart `>=3.12.2 <4.0.0` dan Flutter `>=3.44.0`; README menyebut Flutter 3.44.4 / Dart 3.12.2. Tidak ada penilaian “bebas kerentanan” hanya dari nomor versi.

### 3.3 Status fitur di luar autentikasi

- Sudah ada alur beranda, cabor, klub, detail anggota klub, pencarian, pengurus KOK, dan profil.
- Generator demo menghasilkan 5 klub, 125 atlet, 10 pelatih, 5 official, dan 5 pengurus KOK. Semua tetap sintetis, bukan angka resmi.
- Tab **Anggota** sekarang adalah kepengurusan KOK, bukan direktori gabungan atlet/pelatih/official. README `37` menyebutnya keputusan penyesuaian; jangan dianggap otomatis sebagai bug terhadap wireframe.
- Implementasi memakai Garut Kota, sementara contoh PDF menggunakan Cibeunying Kaler. Ini perbedaan konteks contoh, bukan bukti pelanggaran scope.
- Beberapa fungsi berbagi telah berupa **salin ke clipboard**, misalnya `club_detail_page.dart:208–217` dan rekap profil. Ini bukan native share sheet atau unduh PDF.
- ID SICABOR pada detail atlet dibentuk dari ID mock (`athlete_detail_page.dart:234`) dan riwayat dibuat lokal (`653–657`). Saat migrasi, jangan menyajikan fallback rekaan sebagai data resmi jika field API belum tersedia.

## 4. Temuan audit autentikasi dan risiko migrasi

### Cara membaca prioritas

- **P0 — penghalang penggunaan data nyata:** harus ditutup sebelum aplikasi dipakai dengan akun/data produksi.
- **P1 — wajib untuk pilot autentikasi yang andal:** dikerjakan bersama integrasi auth staging.
- **P2 — penyempurnaan/hardening:** setelah fondasi utama berjalan; sebagian tetap menjadi syarat rilis sesuai platform dan risiko.

Prioritas ini adalah urutan pekerjaan, **bukan skor CVSS**. Mekanisme mock memang wajar pada demo; yang berbahaya adalah menganggapnya cukup ketika data nyata mulai digunakan.

### F-01 · Login memvalidasi kredensial di client, bukan server — P0

**Bukti:** `lib/core/session.dart:15–25`; kredensial demo juga tampil di `login_page.dart:369–377` dan README `17`.

```dart
// Kode saat ini: hanya validasi demo lokal.
Future<bool> signIn(String sk, String password, bool remember) async {
  if (sk.trim() != 'DEMO-001' || password != 'kokgarut123') return false;
  // Menyimpan preferensi nomor SK...
  state = true;
  return true;
}
```

**Dampak:** siapa pun yang memperoleh aplikasi bisa membaca/menganalisis kredensial demo. Tidak ada pembuktian identitas oleh server, identitas individual, MFA, pencabutan akses, atau audit login server.

**Rekomendasi:** pertahankan hanya dalam build demo terpisah; implementasikan adapter auth nyata. Hapus tampilan akun demo dari build produksi dan pastikan produksi tidak dapat fallback ke demo ketika konfigurasi/API gagal. Memindahkan password demo ke `.env`, `--dart-define`, obfuscation, atau hash di Flutter **bukan** perbaikan autentikasi.

### F-02 · State sesi hanya boolean; belum ada lifecycle token — P0

**Bukti:** `core/session.dart:7–13,24–28`.

`build() => false` berarti sesi dimulai dalam keadaan keluar. Tidak ada access token, refresh token, expiry, restore, status akun, atau validasi `/me`.

**Yang penting:** tidak ditemukan penyimpanan token plaintext di SharedPreferences karena token memang belum ada. Session-in-memory ini sesuai demo; bukan persistent login yang “rusak”.

**Rekomendasi:** state eksplisit `bootstrapping`, `signedOut`, `signingIn`, `signedIn`, `temporarilyUnavailable`, `signingOut`; simpan principal terverifikasi dan session generation. Token dikelola service internal, tidak diumbar ke seluruh provider/widget. Jika nanti ada token tersimpan, keberadaannya saja tidak boleh langsung menghasilkan `signedIn`.

### F-03 · Guard navigasi sudah ada, tetapi bukan batas keamanan data — P0

**Bukti:** `app.dart:25–29` mengalihkan pengguna yang belum masuk ke `/login`, termasuk route detail di luar shell.

**Yang sudah baik:** guard global, perubahan sesi memicu refresh router, dan router/notifier di-dispose (`89–92`). Test `app_test.dart:295–306` memeriksa logout lalu akses `/club/garuda` kembali ke login.

**Batasnya:** aplikasi yang dimodifikasi masih dapat melewati UI. Tidak ada server yang memeriksa apakah pengguna boleh membaca suatu objek. Menyembunyikan tombol edit juga tidak membuat API read-only.

**Rekomendasi:** server wajib memeriksa token/sesi, status akun, role/permission, serta kecamatan pada **setiap endpoint dan objek**. Client guard dipertahankan untuk UX, bukan menggantikan kontrol itu.

### F-04 · Identitas dan kecamatan belum berasal dari akun terautentikasi — P0

**Bukti:** `home_page.dart:107–118`, `profile_page.dart:614–646`; `data/models.dart` belum memiliki model pengguna auth atau assignment kecamatan.

Label “Pak Asep”, “Garut Kota”, dan “AKSES READ-ONLY” tidak dibaca dari `/me` atau klaim yang diverifikasi. `SportPerson.role` adalah kategori atlet/pelatih/official, **bukan role otorisasi pengguna aplikasi**.

**Rekomendasi:** server menerbitkan principal dengan `userId`, nama tampilan, status akun, assignment kecamatan, dan permission. Nomor SK menjadi atribut administratif/identifier sesuai keputusan institusi, bukan secret atau dasar otorisasi tunggal. Model domain olahraga tetap dipisahkan dari pengguna login.

### F-05 · Cache data tidak mengikuti perubahan sesi/akun — P0 saat data nyata digunakan

**Bukti:** `data/repository.dart:24–29`: `snapshotProvider` hanya bergantung pada `repositoryProvider`; `core/session.dart:28`: logout hanya mengubah boolean.

**Fakta statis:** tidak ada dependency identitas atau invalidasi snapshot saat logout. Provider snapshot tidak dideklarasikan auto-dispose. Data dapat tetap hidup pada ProviderScope yang sama.

**Risiko migrasi:** setelah akun A keluar lalu akun B masuk, snapshot lama bisa digunakan kembali jika pola ini dipertahankan. Ini **belum merupakan kebocoran lintas akun yang diuji**, karena sekarang hanya ada satu identitas demo dan dataset yang sama.

**Rekomendasi:** namespace cache berdasarkan `(environment, userId, districtId, sessionGeneration)`, batalkan request lama, invalidasi seluruh provider sensitif, dan reset navigation stack/cache gambar ketika keluar atau berpindah principal. Tolak respons terlambat dari sesi lama.

### F-06 · Logout hanya lokal dan tombolnya bergantung pada pemuatan data — P1

**Bukti:** `core/session.dart:28`; `profile_page.dart:60–125` menempatkan tombol keluar di dalam callback sukses `DataView`; `shared/widgets.dart:11–38` mengganti konten dengan loading/error ketika snapshot belum tersedia atau gagal.

**Dampak:** pada initial load/error tanpa data, kontrol keluar dapat tidak ditampilkan. Nanti, gangguan SICABOR tidak boleh membuat pengguna kesulitan menutup sesi. Logout saat ini juga tidak dapat mencabut sesi server karena sesi server belum dibuat.

**Rekomendasi:** tampilkan identitas akun, keamanan akun, dan tombol keluar di luar dependency data olahraga. Logout harus segera mengunci UI dan membersihkan lokal, sambil mencoba pencabutan server dengan timeout. Bedakan keberhasilan keluar lokal dari pencabutan server yang gagal/offline; jangan mengklaim semua sesi telah dicabut.

### F-07 · “Ingat Saya” sebenarnya hanya “Ingat nomor SK” — P1

**Bukti:** `session.dart:18–23`; `login_page.dart:20–24,313–314`; pengaturan hapus SK tersedia di `profile_page.dart:946–985`.

**Yang sudah baik:** password tidak ditulis ke preferences; pengguna dapat menghapus identifier tersimpan.

**Masalah:** label memberi kesan sesi akan bertahan setelah restart, padahal tidak. Kegagalan preferensi juga terikat pada proses login; `setString/remove` mengembalikan status boolean yang saat ini tidak diperiksa.

**Rekomendasi:** ubah menjadi “Ingat nomor SK di perangkat ini”. Bila diperlukan, sediakan kebijakan “Tetap masuk” yang terpisah untuk refresh token, dengan default konservatif untuk perangkat bersama. Penyimpanan preferensi yang gagal tidak semestinya mengubah kredensial benar menjadi “salah”; sebaliknya kegagalan secure storage pada sesi persisten harus ditangani eksplisit, bukan fallback plaintext.

### F-08 · Form memiliki dasar UX yang baik, tetapi belum siap error autentikasi nyata — P1

**Bukti:** `login_page.dart:34–56,175–176,227–232,280–283,337–365`.

**Sudah ada:** validasi kosong, password disembunyikan, suggestions/autocorrect dimatikan, controller di-dispose, tombol loading/disabled, pengecekan `mounted`, dan autofill hint username.

**Belum ada:** pemetaan invalid credentials vs timeout/offline/429/server failure, password autofill hint, pemulihan akun, dan proteksi operasi ganda pada controller auth. `_submit()` belum diawali guard `_busy`; pemanggilan tombol dan keyboard sudah dibatasi, tetapi service tetap perlu melindungi diri.

**Rekomendasi:** pesan login gagal tetap generik; jangan mengungkap apakah SK terdaftar. Beri pesan jaringan berbeda agar pengguna tidak mengganti password akibat timeout. Tambahkan `AutofillGroup`, `AutofillHints.password`, dukungan paste/password manager, serta single-flight operasi login. Validasi login jangan memakai aturan pembuatan password baru yang dapat memblokir akun lama; kebijakan panjang/kekuatan ditegakkan saat aktivasi/reset di server/IdP.

### F-09 · Dio baru konfigurasi dasar; kanal API terautentikasi belum ada — P0

**Bukti:** `data/repository.dart:11–29`.

Belum ada kontrak endpoint, parser response auth, attachment Bearer token, refresh, penanganan 401/403, validasi base URL produksi, atau pemisahan public/auth/API client. `SICABOR_BASE_URL` tidak memiliki nilai default URL dan mengisinya tidak mengganti repository demo.

**Rekomendasi:** gunakan client terpisah untuk token endpoint dan resource API; attachment token hanya ke origin API yang diizinkan. Tetapkan timeout connect/send/receive, TLS valid, redaksi log, retry maksimum satu untuk pembacaan setelah refresh, serta fail-closed bila konfigurasi production tidak lengkap. Jangan menambahkan interceptor token ke semua URL termasuk foto eksternal.

### F-10 · Beberapa label mengklaim sinkronisasi SICABOR yang belum terjadi — P1

**Bukti:** `repository.dart:119` memakai `DateTime.now()` sebagai `loadedAt`; `home_page.dart:245–281` menamainya “Terakhir Tersinkron SICABOR”; `profile_page.dart:705–741` menampilkan status tersinkron dan snackbar sukses segera setelah invalidate.

**Kontradiksi:** `shared/widgets.dart:128` sudah mengatakan data demo belum terhubung SICABOR, tetapi label lain menyatakan sebaliknya. Snackbar belum menunggu keberhasilan fetch.

**Rekomendasi:** bedakan `dataSource = mock/sicabor`, `loadedAt`, dan `lastSyncedAt` yang berasal dari server. Saat mock gunakan “Data demo dimuat …”. Setelah auth nyata tetapi data belum nyata, gunakan “Autentikasi staging aktif · data olahraga demo”. Keberhasilan login tidak boleh diartikan keberhasilan sinkronisasi SICABOR.

### F-11 · Konfigurasi native belum siap distribusi autentikasi nyata — P1 / syarat rilis

**Bukti:** `android/app/build.gradle.kts:28–33` memakai debug signing untuk release. `android/app/src/main/AndroidManifest.xml` belum mendeklarasikan INTERNET; permission tersebut ada pada manifest debug/profile. `ios/Runner/Info.plist` belum memiliki callback scheme OIDC.

**Batas kesimpulan:** manifest hasil merge dan binary tidak dibangun. Maka belum dibuktikan apakah dependency nantinya menambahkan permission; jangan mengandalkan itu secara implisit.

**Rekomendasi:** tambahkan INTERNET ke manifest utama, verifikasi merged release manifest, signing produksi, environment/flavor, kebijakan backup, secure storage native, dan callback autentikasi. Pertahankan validasi TLS default; tidak ada alasan menambahkan `badCertificateCallback` yang menerima semua sertifikat. Activity launcher yang `exported=true` adalah kebutuhan normal launcher, bukan otomatis kerentanan.

### F-12 · Pengujian sudah ada, tetapi cakupannya masih kontrak demo — P1

**Bukti:** `repository_test.dart:190–208` memeriksa password salah/benar, hanya key `remembered_sk`, dan boolean setelah logout. `app_test.dart:256–308` memeriksa alur UI dan guard. `profile_page_test.dart:338–385` memeriksa perubahan boolean.

Nama test “revokes session” saat ini berarti **mengubah sesi lokal**, bukan bukti revocation server. Tidak ditemukan folder `integration_test/` atau workflow `.github/` dalam arsip; pipeline di luar ZIP tetap mungkin ada.

**Rekomendasi:** pertahankan tes tersebut sebagai tes demo dan tambah kontrak auth, expiry/refresh/rotation, concurrent 401, logout saat request berjalan, cache lintas akun, serta otorisasi lintas kecamatan pada backend. Jangan menyebut coverage keamanan lengkap tanpa bukti eksekusi.

### F-13 · Data pribadi, media, dan recovery membutuhkan kebijakan akses eksplisit — P0 sebelum berkas nyata

**Bukti:** PDF menanyakan hak melihat dokumen; model memuat status dokumen/foto; `athlete_detail_page.dart:408–413` menggunakan `Image.network` langsung. Kontak helpdesk di `profile_page.dart:302–325` berupa string hardcoded.

**Risiko:** read-only tetap memberi akses baca data pribadi, termasuk atlet usia muda. Loader gambar tidak otomatis memakai interceptor Dio. Link foto/berkas permanen dan ekspor dapat menjadi jalur di luar batas otorisasi. Kontak contoh tidak boleh dijadikan jalur reset akun resmi.

**Rekomendasi:** akses status dokumen sebagai default; berkas asli hanya setelah permission terpisah disetujui. Untuk media privat gunakan endpoint terotorisasi atau signed URL berumur pendek dari server setelah pengecekan scope, batasi cache, dan jangan menambahkan token pada arbitrary host. Verifikasi helpdesk sebelum mengaktifkan pemulihan akun; jangan meminta password/OTP melalui pesan pribadi.

## 5. Arsitektur target yang disarankan

### 5.1 Rekomendasi utama: auth nyata, data olahraga boleh tetap mock

Pisahkan dua keputusan berikut:

- **Siapa yang mengautentikasi pengguna?** Identity provider/layanan auth resmi.
- **Dari mana data olahraga berasal?** Untuk sementara mock; berikutnya SICABOR melalui API yang disetujui.

Dengan pemisahan ini, pengujian autentikasi tidak harus menunggu semua endpoint klub/atlet selesai. Jangan membuat seolah-olah data mock menjadi terlindungi secara rahasia hanya karena UI sudah meminta token—data yang dibundel di aplikasi tetap dapat diekstrak.

```
Flutter Android/iOS ── browser sistem ── Identity Provider
         │          Authorization Code + PKCE / OIDC
         │
         └─ access token khusus audience API KOK
               ↓
          API/Gateway KOK
          ├─ validasi identitas, sesi, permission
          ├─ /me dan assignment kecamatan
          ├─ pembatasan tiap objek dan laporan
          └─ adapter SICABOR / fixture sintetis staging
               ↓
          SICABOR (setelah kontrak disepakati)
```

Gateway KOK adalah rekomendasi **jika** API SICABOR belum menyediakan boundary otorisasi yang dibutuhkan. Jika SICABOR sudah mendukung validasi identitas dan scope per pengguna dengan baik, tambahan gateway tidak wajib. Kredensial integrasi service-to-service SICABOR, bila diperlukan, hanya berada di backend/secret manager—bukan APK, IPA, atau JavaScript.

### 5.2 Pilihan autentikasi dan keputusan yang realistis

| Kondisi | Pilihan | Konsekuensi |
| --- | --- | --- |
| Institusi/SICABOR mempunyai IdP OIDC yang disetujui | Integrasi IdP tersebut dengan Code + PKCE | Pilihan utama; identitas dan lifecycle akun tidak diduplikasi |
| Belum ada IdP, tetapi boleh menyediakan layanan auth | IdP matang/managed yang disetujui; tenant staging dengan akun sintetis | Autentikasi bisa dibangun sekarang; kebijakan data/biaya/operasi harus disetujui |
| Kontrak resmi hanya menyediakan login kredensial first-party | Adapter login API khusus dengan session service backend | Bisa dilakukan, tetapi backend harus mengurus hashing, throttling, reset, revocation, dan MFA; bukan login lokal |
| Belum ada layanan auth maupun keputusan institusi | Refactor interface + fake yang menguji seluruh state | Disebut “siap diintegrasikan”, bukan autentikasi produksi |

Jangan otomatis memilih Firebase/Supabase/Keycloak/penyedia lain hanya karena SDK mudah. Konfirmasikan kepemilikan akun, sinkronisasi pengguna, lokasi pemrosesan data, lifecycle pengurus, dan bagaimana API KOK memvalidasi token penyedia tersebut. Hindari membuat dua basis password yang nantinya sulit disatukan.

**Untuk mobile berbasis OAuth:** gunakan Authorization Code + PKCE, bukan implicit flow, bukan resource-owner password grant, dan bukan client credentials sebagai login pengguna. OIDC menambahkan lapisan identitas; OAuth sendiri terutama mengatur akses. Jangan menyimpan `client_secret` di mobile. RFC 8252 dan RFC 9700 menjadi dasar pilihan ini.

### 5.3 Web bukan salinan strategi secure storage mobile

`flutter_appauth` menargetkan Android/iOS/macOS, bukan Chrome. Jangan memasangnya lalu menganggap login web selesai.

Untuk web produksi, arah yang disarankan adalah **BFF (backend-for-frontend)**: proses OIDC dan token dikelola backend, browser memakai cookie sesi `HttpOnly`, `Secure`, dan `SameSite` yang sesuai alur. Terapkan CSRF token/pemeriksaan Origin untuk request yang mengubah state, CORS allowlist, dan kebijakan cache. Cookie HttpOnly mengurangi pencurian token melalui JavaScript, tetapi tidak membuat XSS tidak berbahaya.

Jangan menganggap `flutter_secure_storage` di web setara Keychain/Keystore; implementasi web berbasis WebCrypto/local storage tetap berada dalam konteks browser. Jika web hanya untuk demo, dokumentasikan batas itu dan jangan mendistribusikan build web berisi data nyata sebelum jalur auth web siap.

### 5.4 Akun individual, bukan password kecamatan bersama

Interpretasi yang disarankan atas “1 akun KOK = 1 kecamatan” adalah **setiap akun individual ditugaskan ke satu kecamatan**, bukan seluruh pengurus berbagi satu kredensial. Beberapa akun individual boleh memiliki assignment kecamatan yang sama jika kebijakan institusi mengizinkan.

Server perlu membedakan:

- `userId`: identitas stabil orang/pengguna.
- `districtId`: assignment wilayah yang ditetapkan administrator.
- `role/permissions`: kewenangan aplikasi, bukan peran atlet/pelatih.
- `accountStatus` dan masa tugas: aktif, dinonaktifkan, berakhir.
- `sessionId`: sesi/perangkat yang bisa dicabut secara individual.

Nomor SK dapat berubah karena periode kepengurusan atau dipakai oleh beberapa nama dalam satu surat. Konfirmasi dahulu sebelum menjadikannya username unik. Jangan mengizinkan pengguna memilih kecamatan saat login lalu menerima pilihan itu sebagai otorisasi.

## 6. Kontrak backend minimum yang perlu disepakati

<aside>
📌

Semua nama endpoint, field, permission, dan TTL di bawah adalah **usulan kontrak**, bukan endpoint SICABOR yang sudah ada. Untuk OIDC, authorization/token/revocation endpoint mengikuti discovery dan kontrak IdP; jangan mencampurnya dengan endpoint login custom tanpa desain yang jelas.

</aside>

### 6.1 Resource API dan principal

| Operasi usulan | Keperluan | Aturan utama |
| --- | --- | --- |
| `GET /v1/me` | Profil pengguna dan assignment kecamatan | Token valid, akun aktif, identitas diambil dari server |
| `GET /v1/clubs` | Daftar klub wilayah pengguna | Filter tenant dilakukan server, bukan hanya client |
| `GET /v1/people/{id}` | Detail orang olahraga | Cek keanggotaan objek pada kecamatan yang diizinkan |
| `GET /v1/session` atau informasi sesi dalam `/me` | Status sesi jika arsitektur memerlukannya | Tidak menganggap JWT belum expired berarti akun pasti masih aktif |
| `POST /v1/session/logout` | Pencabutan sesi aplikasi saat ini, jika gateway memiliki sesi | Semantik idempotent; tidak mencabut semua perangkat secara diam-diam |
| Endpoint daftar/cabut sesi | Kelola perangkat dan penanganan perangkat hilang | Reauthentication/MFA sesuai sensitivitas |

Contoh response `/me`:

```json
{
  "id": "usr_example_001",
  "display_name": "Koordinator Contoh",
  "account_status": "active",
  "district": {
    "id": "district_example_001",
    "name": "Garut Kota"
  },
  "roles": ["kok_viewer"],
  "permissions": [
    "clubs:read",
    "people:read",
    "documents:status:read"
  ]
}
```

Contoh ini sengaja tidak memberi permission membuka dokumen atau mengekspor data. Tambahkan `reports:export` atau `documents:read` hanya setelah disetujui. Objek JSON lokal untuk UX ini bukan bukti otorisasi; server tetap memeriksa setiap request.

### 6.2 Jika terpaksa memakai login API kredensial first-party

Usulan alternatif: `POST /v1/auth/login`, `POST /v1/auth/refresh`, `POST /v1/auth/logout`, dan recovery/activation endpoint. Flutter mengirim identifier/password melalui HTTPS ke auth service yang sah, bukan ke repository mock. Ini desain first-party tersendiri; jangan mengimplementasikannya sebagai OAuth password grant yang dilarang RFC 9700.

Login mengembalikan access token, jenis token, waktu kedaluwarsa, refresh token bila kebijakan mengizinkan, dan informasi sesi. Schema final harus mencakup satuan waktu, format UTC, kode error, serta apakah MFA sudah selesai. Bila MFA diperlukan, response challenge **belum** boleh memberi akses data normal.

### 6.3 Semantik error yang konsisten

| Kondisi | Perilaku yang diharapkan |
| --- | --- |
| Kredensial salah / akun tak dikenal / dinonaktifkan pada login publik | Pesan generik dan jalur respons yang tidak mudah membocorkan keberadaan akun |
| Access token tidak valid/kedaluwarsa | `401`; client mengikuti kontrak refresh, maksimal satu retry |
| Identitas valid tetapi permission tidak cukup | `403`; jangan melakukan refresh loop |
| Objek di luar kecamatan | `404` atau `403` konsisten sesuai kebijakan anti-enumerasi; tanpa isi objek |
| Rate limit | `429`, `Retry-After` sesuai kebijakan; pembatasan server tetap berlaku meski client dimodifikasi |
| Refresh OIDC tak berlaku | Error token endpoint seperti `invalid_grant`; hapus sesi lokal dan minta masuk ulang |
| Timeout, jaringan putus, atau layanan 5xx | Status sementara; jangan otomatis menghapus refresh token yang mungkin masih sah |
| Secure storage rusak/tidak dapat diakses | Gagal secara eksplisit; tidak membuka data atau fallback ke preferences |

Gunakan `request_id` untuk dukungan, tetapi jangan menampilkan stack trace, token, password, atau rincian database kepada pengguna.

## 7. Siklus hidup sesi yang harus menjadi kontrak

### 7.1 Startup dan restore

1. Mulai pada `bootstrapping`; belum tampilkan data pribadi.
2. Baca konfigurasi platform/environment dan secure storage. Kegagalan baca bukan sama dengan token valid.
3. Bila tidak ada refresh token, tampilkan login. “Ingat nomor SK” hanya boleh mengisi identifier.
4. Bila ada token persisten, lakukan refresh/restore sesuai protokol, kemudian panggil `/me` untuk memperoleh identitas dan assignment terkini.
5. Set `signedIn` hanya setelah kontrak token dan principal terpenuhi. Bila refresh ditolak secara definitif, bersihkan sesi. Jika jaringan sementara gagal, tampilkan layar retry/keluar tanpa membuka cache sensitif.
6. Pemulihan deep link, jika ditambahkan, hanya ke route internal allowlist; jangan menerima URL eksternal bebas dari parameter `from`.

### 7.2 Access token dan refresh token

- Access token berumur pendek; contoh awal untuk diskusi adalah 5–15 menit, **bukan angka wajib standar**.
- Access token idealnya di memori; refresh token, jika dikeluarkan dan sesi persisten disetujui, disimpan di secure storage native.
- Server menentukan idle expiry, absolute expiry, dan reauthentication berdasarkan risiko. Contoh kebijakan pilot: sesi maksimal satu hari kerja sebelum reauthentication; angka final harus disepakati, bukan ditanam sebagai asumsi SICABOR.
- Untuk public client OAuth yang menerima refresh token, gunakan rotation atau sender-constraining sesuai RFC 9700. Jalur awal yang lebih sederhana: rotation dengan reuse detection pada server.
- Refresh token lama yang sudah dipakai tidak boleh terus berlaku tanpa kebijakan replay yang jelas. Simpan hubungan token family di server; revokasi family bila reuse terdeteksi. Tangani rotation dengan transaksi atomik.
- Jangan memakai ID token sebagai Bearer token resource API. Jangan menganggap decoding JWT tanpa verifikasi sebagai validasi keamanan.

### 7.3 Concurrent request dan respons terlambat

Satu access token kedaluwarsa dapat menyebabkan banyak request menerima 401 bersamaan. Hanya satu refresh boleh berjalan untuk satu sesi. Request lainnya menunggu hasil yang sama. Setelah token berubah, request yang terlambat menerima 401 dari token lama tidak perlu memulai rotation tambahan jika token baru sudah tersedia.

Setiap login/logout/pergantian akun harus mengubah **session generation**. Sebelum memasang token, menulis secure storage, atau mempublikasikan data hasil request, pastikan generation masih sama. Serialisasikan perubahan penyimpanan/token agar refresh lama tidak menulis ulang token setelah logout. Single-flight saja tidak menyelesaikan race ini.

Retry otomatis paling aman dibatasi pada GET/HEAD yang replayable. Jangan otomatis mengulang unggahan, POST laporan, atau transaksi auth tanpa kontrak idempotency.

### 7.4 Logout yang benar

1. Tandai proses keluar dan naikkan generation segera agar operasi lama tidak dapat memulihkan sesi.
2. Simpan referensi sementara ke identitas sesi/token yang perlu dicabut; jangan mengirimkannya ke log.
3. Batalkan request, hilangkan akses data, bersihkan token memori, secure storage, provider data, navigation state, dan cache sensitif. Tangani kegagalan penghapusan storage secara eksplisit.
4. Coba revocation/logout server dengan timeout melalui client yang tidak memicu auto-refresh.
5. Tetap keluar secara lokal saat offline, tetapi nyatakan revocation remote belum terkonfirmasi. Jangan menjanjikan token yang dicuri langsung mati ketika server tidak dapat dihubungi.
6. Bila memakai SSO, bedakan logout aplikasi, revocation token, dan mengakhiri sesi browser IdP. SSO browser bisa tetap aktif setelah logout lokal; perilaku pilih akun/reauth harus ditetapkan.

Jika access token berupa JWT stateless, revocation refresh token saja tidak otomatis membatalkan access token yang belum expired. Pilih TTL pendek dan/atau pemeriksaan sesi server/introspection sesuai kebutuhan pencabutan segera.

## 8. Kontrol backend dan operasional minimum

### 8.1 Password dan pemulihan akun

Utamakan kapabilitas IdP daripada membuat sendiri. Jika backend mengelola password:

- Hash di server dengan library matang, misalnya Argon2id; contoh baseline OWASP adalah memori 19 MiB, iterasi 2, paralelisme 1, kemudian ukur dan tune terhadap kapasitas server. Jangan SHA-256/MD5 biasa, jangan enkripsi reversible untuk password.
- Gunakan salt unik yang ditangani library; pepper opsional berada di secret manager, bukan di database yang sama.
- Acuan NIST SP 800-63B-4: password single-factor minimal 15 karakter; bila hanya dipakai bersama MFA boleh minimal 8; dukung panjang maksimum setidaknya 64 karakter. Ini kebijakan saat menetapkan/mengubah password, bukan alasan membuat form login menolak password akun lama.
- Dukung passphrase, spasi, dan password manager; cek blocklist password umum/bocor. Hindari aturan komposisi sewenang-wenang dan pergantian berkala tanpa indikasi kompromi.
- Recovery memakai token acak berumur pendek, sekali pakai, tersimpan aman/hashed, dibatasi percobaannya, serta menghasilkan pesan publik generik. Recovery tidak boleh menjadi jalur yang melewati MFA tanpa pembuktian setara.
- Akun KOK idealnya dibuat/diundang admin, bukan registrasi terbuka dengan pilihan kecamatan bebas. Akun dinonaktifkan saat masa tugas berakhir; pergantian koordinator tidak dilakukan dengan menyerahkan password lama.

### 8.2 MFA, throttling, dan deteksi

- Wajibkan MFA untuk administrator pengelola akun dan pertimbangkan sebagai syarat akses data pribadi KOK. FIDO2/passkeys melalui IdP menjadi arah kuat; TOTP bisa menjadi tahap awal jika dukungan operasional tersedia.
- Biometrik lokal hanya membuka akses lokal/secret perangkat; tidak otomatis setara autentikasi server atau MFA yang diketahui server.
- Rate-limit login, reset, OTP, dan refresh; gabungkan sinyal akun dan sumber jaringan dengan perhatian pada NAT bersama. Hindari lockout permanen yang mudah dipakai untuk mengunci akun orang lain.
- Catat login berhasil/gagal, revocation, perubahan assignment, penolakan akses, dan ekspor dengan metadata minimum. Redaksi Authorization, Cookie, password, OTP, dan token di log/crash reporting.

### 8.3 Otorisasi objek dan data pribadi

Server mengambil identitas dari middleware yang memverifikasi signature/introspection, issuer, audience, expiry, dan policy algoritma; bukan dari `userId` atau `districtId` yang dikirim client. Bila role/assignment berubah, server harus mempunyai mekanisme agar akses lama berhenti sesuai SLA pencabutan.

```
Contoh pseudocode backend; bukan SQL atau endpoint SICABOR yang tersedia.

GET /v1/people/:id
  principal = requireVerifiedSession(request)
  requireActiveAccount(principal.userId)
  assignment = loadCurrentDistrictAssignment(principal.userId)
  requirePermission(principal, "people:read")

  person = database.findPerson(
    id = request.path.id,
    districtId = assignment.districtId
  )
  if person is null:
    return 404

  return allowlistedPersonFields(person)
  // Tidak otomatis menyertakan URL KTP, KK, akta, atau nomor identitas.
```

Terapkan prinsip yang sama untuk pencarian, daftar, detail klub, foto, laporan, download, dan endpoint sinkronisasi. Mengamankan daftar saja tetapi membiarkan detail by-ID terbuka merupakan celah object-level authorization.

### 8.4 Platform dan distribusi

- Android: INTERNET pada manifest utama; HTTPS; verifikasi release manifest; signing key produksi di CI/secret manager; pilih kebijakan backup/restore termasuk Android modern dan transfer antarperangkat. Uji pemulihan secure storage, bukan hanya memasang paket.
- iOS: Keychain accessibility yang sesuai, pengaturan backup/migrasi perangkat, callback OIDC, serta pengujian reinstall. Keychain dapat bertahan lintas reinstall; tetapkan kebijakan dan tesnya. Jangan menonaktifkan ATS secara global.
- Native secure storage mengurangi risiko at-rest, tetapi bukan perlindungan absolut pada perangkat yang sudah kompromi.
- Periksa cache HTTP native dan cache gambar agar token/PII tidak tertinggal. Token endpoint dan response sensitif perlu kebijakan cache yang sesuai; memasang secure storage saja tidak menjamin tidak ada salinan rahasia di tempat lain.
- Certificate pinning, device attestation, root detection, dan obfuscation dapat menjadi defense-in-depth sesuai threat model; bukan pengganti TLS standar atau otorisasi backend, dan tidak perlu didahulukan dari lifecycle sesi.

## 9. Contoh implementasi Flutter dan titik perubahan

<aside>
🧩

**Status contoh kode:** rancangan teknis, belum di-compile atau diterapkan. Contoh memisahkan potongan Dart yang dapat dijadikan komponen dari pseudocode orkestrasi yang masih perlu diimplementasikan. Nama file/provider baru adalah usulan. Tidak ada issuer, client ID, endpoint, atau kredensial SICABOR nyata yang diasumsikan tersedia.

</aside>

### 9.1 Struktur yang cukup untuk proyek kerja praktik

Tidak perlu menambahkan lapisan enterprise berlebihan. Mulai dari pemisahan domain auth, adapter, controller, dan client HTTP.

```
lib/
  core/
    config/app_config.dart
    network/authorized_read_client.dart
  features/auth/
    domain/auth_state.dart
    domain/auth_repository.dart
    data/demo_auth_repository.dart
    data/oidc_auth_repository.dart
    data/mobile_refresh_store.dart
    application/auth_controller.dart
    presentation/login_page.dart
    presentation/session_gate_page.dart
  data/
    repository.dart              # tetap interface domain olahraga
    demo_kok_repository.dart
    api_kok_repository.dart      # menyusul saat kontrak tersedia
  app.dart
  main_demo.dart
  main_staging.dart
  main_production.dart
```

Repository olahraga dan auth harus dapat dipilih secara independen pada staging. Production tetap membutuhkan kombinasi yang disetujui dan tidak boleh diam-diam mengaktifkan mock.

### 9.2 Model principal dan state tanpa mengekspos token ke UI

**Usulan `auth_state.dart`**; gunakan Dart biasa terlebih dahulu. Freezed dapat dipakai kemudian, tetapi hindari generated `toString()` yang membocorkan token pada model secret.

```dart
final class UserPrincipal {
  UserPrincipal({
    required this.id,
    required this.displayName,
    required this.districtId,
    required this.districtName,
    required Set<String> permissions,
  }) : permissions = Set.unmodifiable(permissions);

  final String id;
  final String displayName;
  final String districtId;
  final String districtName;
  final Set<String> permissions;
}

sealed class AuthState {
  const AuthState();
}
final class Bootstrapping extends AuthState {
  const Bootstrapping();
}
final class SignedOut extends AuthState {
  const SignedOut();
}
final class SigningIn extends AuthState {
  const SigningIn();
}
final class SignedIn extends AuthState {
  const SignedIn(this.user, this.generation);
  final UserPrincipal user;
  final int generation;
}
final class TemporarilyUnavailable extends AuthState {
  const TemporarilyUnavailable();
}
final class SigningOut extends AuthState {
  const SigningOut();
}

abstract interface class AuthRepository {
  // Null = tidak ada sesi atau sesi definitif tidak berlaku.
  // Gangguan jaringan dilempar sebagai failure bertipe, bukan null.
  Future<UserPrincipal?> restore();

  // Untuk adapter OIDC: membuka browser sistem, bukan menerima password.
  // Baru sukses setelah identitas/assignment dari /me diterima.
  Future<UserPrincipal> signIn({required bool persistSession});

  // Keluar lokal harus tetap dijalankan.
  // Hasil bool hanya menyatakan revocation remote terkonfirmasi.
  Future<bool> signOut();
}
```

`AuthController` berbasis Riverpod mengelola state di atas dan membedakan failure yang dapat dicoba lagi dari sesi yang sudah ditolak. Parser `/me` harus menolak ID/assignment kosong, status akun yang tidak diizinkan, atau bentuk JSON salah. Jangan menggantinya dengan pengguna “Pak Asep” sebagai fallback.

Bila dipilih login kredensial first-party, gunakan adapter/interface khusus `signInWithCredentials(identifier, password)`; jangan memaksa password diteruskan ke implementasi OIDC. Pada OIDC, layar lokal cukup menjelaskan identitas aplikasi dan tombol “Masuk dengan akun resmi”; input password berada di IdP.

### 9.3 Guard router yang mengerti startup dan gangguan sesi

**Potongan fungsi murni untuk `app.dart`**, menggantikan keputusan boolean di redirect. Definisi state berasal dari contoh sebelumnya.

```dart
String? authRedirect(AuthState auth, String location) {
  if (auth is Bootstrapping || auth is SigningOut) {
    return location == '/session' ? null : '/session';
  }
  if (auth is TemporarilyUnavailable) {
    return location == '/session-unavailable'
        ? null
        : '/session-unavailable';
  }
  if (auth is! SignedIn) {
    return location == '/login' ? null : '/login';
  }
  const gates = {'/login', '/session', '/session-unavailable'};
  return gates.contains(location) ? '/home' : null;
}
```

Daftarkan route `/session` dan `/session-unavailable`. Layar unavailable menyediakan “Coba lagi” dan “Keluar”, bukan menampilkan snapshot lama. Hubungkan perubahan `authProvider` ke `refreshListenable` seperti pola yang sudah ada; **jangan membangun ulang GoRouter setiap token di-refresh**. Perubahan access token biasa tidak harus mereset navigasi, sedangkan pergantian principal/generation perlu membuang state pengguna lama.

Contoh belum mempertahankan tujuan deep link sesudah login; itu sengaja ditunda agar tidak memperkenalkan open redirect. Callback OIDC ditangani integrasi native/SDK dan tidak boleh ditelan guard sebagai route login biasa. Jika recovery page lokal ditambahkan, masukkan route publiknya secara eksplisit dan tetap lindungi route data.

### 9.4 Secure storage: refresh token saja, terpisah dari preferences

Tambahkan paket setelah memeriksa kompatibilitas SDK dan changelog, lalu commit `pubspec.lock` hasil resolusi:

```bash
flutter pub add flutter_secure_storage
flutter pub add flutter_appauth
```

`flutter_appauth` hanya dipasang/digunakan pada jalur mobile yang sesuai; web memerlukan adapter berbeda. Jangan mengikuti contoh lama `encryptedSharedPreferences: true` secara otomatis: dokumentasi flutter_secure_storage saat audit menjelaskan perubahan cipher default dan tidak lagi merekomendasikan opsi lama tersebut.

**Usulan `mobile_refresh_store.dart`:**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RefreshTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

final class MobileRefreshTokenStore implements RefreshTokenStore {
  MobileRefreshTokenStore(this.storage, {required this.namespace});

  // Instance dikonfigurasi di composition root sesuai Android/iOS.
  final FlutterSecureStorage storage;
  // Namespace stabil: environment + issuer/client yang disetujui.
  final String namespace;
  String get _key => 'kok.$namespace.refresh_token.v1';

  @override
  Future<String?> read() => storage.read(key: _key);

  @override
  Future<void> write(String token) {
    if (token.isEmpty) throw ArgumentError('Empty refresh token');
    return storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() => storage.delete(key: _key);
}
```

**Belum diselesaikan oleh wrapper ini:** konfigurasi accessibility Keychain, kebijakan Android backup/transfer, serialization operasi write/clear, migrasi versi, serta failure handling. Controller harus mengelolanya. Jangan menangkap error penyimpanan lalu menyimpan token ke SharedPreferences. Jangan memakai `deleteAll()` tanpa pertimbangan jika secure storage juga berisi secret aplikasi lain.

Pada Android, dokumentasi versi paket yang diperiksa menyebut minimum SDK 23; cocokkan dengan hasil konfigurasi Flutter/Gradle yang dipilih. Pada iOS pilih accessibility yang membatasi token ke perangkat/keadaan unlock sesuai kebutuhan; uji di perangkat asli. Jika pengguna tidak memilih sesi persisten, jangan menulis refresh token ke disk.

### 9.5 Titik integrasi OIDC menggunakan AppAuth

**Contoh fungsi pertukaran token saja**, bukan implementasi `AuthRepository` lengkap. `issuer`, `clientId`, `redirectUri`, dan scope harus berasal dari konfigurasi deployment terpercaya serta terdaftar di IdP. Fungsi ini tidak menerima issuer dari input pengguna/deep link.

```dart
import 'package:flutter_appauth/flutter_appauth.dart';

Future<AuthorizationTokenResponse> authorizeMobile({
  required FlutterAppAuth appAuth,
  required String issuer,
  required String clientId,
  required String redirectUri,
  required List<String> approvedScopes,
}) async {
  final issuerUri = Uri.parse(issuer);
  if (issuerUri.scheme != 'https' ||
      issuerUri.host.isEmpty ||
      issuerUri.userInfo.isNotEmpty ||
      clientId.isEmpty ||
      !approvedScopes.contains('openid')) {
    throw StateError('Konfigurasi OIDC tidak valid');
  }

  final result = await appAuth.authorizeAndExchangeCode(
    AuthorizationTokenRequest(
      clientId,
      redirectUri,
      issuer: issuer,
      scopes: approvedScopes,
      // Tidak ada clientSecret untuk public native client.
    ),
  );

  final access = result.accessToken;
  final expires = result.accessTokenExpirationDateTime;
  if (access == null || access.isEmpty || expires == null ||
      !expires.isAfter(DateTime.now())) {
    throw StateError('Respons token tidak memenuhi kontrak aplikasi');
  }
  return result; // Jangan print/log object ini.
}
```

Pemeriksaan expiry di sini hanya sanity check client untuk kontrak contoh, **bukan verifikasi token oleh server**. SDK menangani alur authorization/PKCE; verifikasi konfigurasi S256, state/nonce, exact redirect URI, dan perilaku validasi OIDC pada kombinasi SDK/IdP yang dipilih. Jangan menulis sendiri generator PKCE atau melewati validasi SDK untuk membuat login “berhasil”.

Setelah fungsi ini: coordinator memeriksa generation, mengelola token secara internal, memanggil `/me` pada resource API dengan access token, menyimpan refresh token sesuai policy, kemudian mempublikasikan `SignedIn`. Jika principal ditolak, jangan membuka halaman data. Jika sesi persisten disyaratkan tetapi refresh token tidak diterbitkan, tangani sebagai kontrak/policy yang belum terpenuhi; jangan membuat refresh token sendiri.

Scope seperti `openid`, `profile`, dan scope API KOK harus disetujui; `offline_access` hanya bila IdP mendukung dan sesi persisten memang diminta. Audience resource API harus dikonfigurasi sesuai IdP—menambahkan nama scope sendiri tidak menjamin token diterima backend.

**Setup callback native:** daftarkan redirect URI persis di IdP dan aplikasi; utamakan app-claimed HTTPS link jika didukung deployment, atau private-use scheme yang unik sesuai panduan native. Lengkapi manifest receiver/Gradle placeholder Android dan URL types/associated domains iOS sesuai mekanisme yang dipilih. Uji pembatalan browser, cold start, warm start, dan kembali dari MFA. Manifest Android saat ini mempunyai `taskAffinity=""`; dokumentasi AppAuth mencatat kasus callback terkait konfigurasi tersebut, sehingga uji sebelum mengubahnya—bukan menghapusnya tanpa verifikasi.

### 9.6 Client GET berotorisasi dengan satu kesempatan refresh

Untuk proyek read-only, wrapper GET eksplisit dapat lebih mudah diuji daripada interceptor besar yang mencoba mengulang semua request. Contoh berikut menggunakan Dio yang **khusus resource API**, tanpa interceptor refresh lain dan tanpa logging token.

**Kontrak `ApiSession` wajib diimplementasikan oleh coordinator; contoh ini tidak mengimplementasikan rotation server.**

```dart
import 'package:dio/dio.dart';

abstract interface class ApiSession {
  int get generation;
  String? get accessToken;

  // Wajib: single-flight per sesi, cek generation, dan reuse token baru
  // bila rejectedToken sudah digantikan oleh refresh request lain.
  // invalid_grant => tutup sesi; jaringan gagal => failure sementara.
  Future<String> refreshAfter401({
    required String rejectedToken,
    required int expectedGeneration,
  });

  // Tidak boleh menutup sesi baru akibat respons dari sesi lama.
  Future<void> expireIfCurrent(int expectedGeneration);
}

final class SessionChanged implements Exception {}
final class SignInRequired implements Exception {}

final class AuthorizedReadClient {
  AuthorizedReadClient({
    required this.dio,
    required this.apiOrigin,
    required this.session,
  });

  final Dio dio;
  // Origin HTTPS terpercaya, mis. https://api.example.org/.
  // Host contoh bukan alamat API SICABOR.
  final Uri apiOrigin;
  final ApiSession session;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final uri = apiOrigin.resolve(path);
    if (uri.scheme != 'https' ||
        uri.host != apiOrigin.host || uri.port != apiOrigin.port ||
        uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw ArgumentError('Tujuan API tidak diizinkan');
    }

    final generation = session.generation;
    var token = session.accessToken;
    if (token == null || token.isEmpty) throw SignInRequired();

    for (var attempt = 0; attempt < 2; attempt++) {
      if (session.generation != generation) throw SessionChanged();
      try {
        final response = await dio.get<T>(
          uri.toString(),
          queryParameters: query,
          cancelToken: cancelToken,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            followRedirects: false,
            validateStatus: (s) => s != null && s >= 200 && s < 300,
          ),
        );
        if (session.generation != generation) throw SessionChanged();
        return response;
      } on DioException catch (error) {
        if (session.generation != generation) throw SessionChanged();
        if (error.response?.statusCode != 401) rethrow;
        if (attempt == 1) {
          await session.expireIfCurrent(generation);
          rethrow;
        }
        token = await session.refreshAfter401(
          rejectedToken: token,
          expectedGeneration: generation,
        );
        if (token.isEmpty) throw SignInRequired();
      }
    }
    throw StateError('Unreachable');
  }
}
```

Konfigurasi Dio yang menyertai wrapper: connect/send/receive timeout, `Accept: application/json`, validasi sertifikat default, dan disposal saat scope layanan berakhir. Wrapper menolak redirect agar header auth tidak mengikuti tujuan tak terduga; server API sebaiknya memberi URL final. Contoh ini tidak ditujukan untuk token endpoint atau browser BFF, tidak memeriksa schema bisnis, dan belum mengimplementasikan cancellation seluruh request saat logout. Tambahkan hal itu pada coordinator/repository.

Untuk resource API yang membedakan penyebab 401, sesuaikan keputusan refresh dengan kode error atau `WWW-Authenticate` yang disepakati. Respons 403 dan error jaringan tidak memicu refresh di contoh. Bug konfigurasi audience/scope tidak boleh “diperbaiki” dengan loop refresh tanpa batas.

### 9.7 Single-flight dan generation: jangan hanya menambahkan interceptor 401

**Helper Dart untuk menggabungkan operasi yang sedang berjalan:**

```dart
final class SingleFlight<T> {
  Future<T>? _pending;

  Future<T> run(Future<T> Function() operation) {
    final pending = _pending;
    if (pending != null) return pending;
    final future = Future<T>.sync(operation).whenComplete(() {
      _pending = null;
    });
    _pending = future;
    return future;
  }
}
```

Buat helper ini per sesi/generation, bukan satu flight global yang dapat dipakai lintas akun. Ia menghindari refresh bersamaan tetapi **belum** melindungi race logout, perubahan akun, atau penulisan secure storage. Kontrak coordinator harus mengikuti urutan berikut:

```
PSEUDOCODE refreshAfter401(rejectedToken, expectedGeneration):
  tolak jika generation berubah atau sesi tidak aktif
  jika accessToken sudah berbeda dan masih layak dipakai:
    kembalikan accessToken terbaru

  gabungkan dalam single-flight milik generation tersebut:
    ulangi pengecekan generation dan token
    baca refresh token aktif dari memori internal
    lakukan refresh melalui token client terpisah
    jika invalid_grant/revoked: expireIfCurrent(generation)
    jika timeout/5xx: laporkan failure sementara, bukan invalid credentials

    dalam antrean perubahan token/storage yang sama dengan logout:
      cek generation lagi
      simpan refresh token pengganti jika sesi persisten
      cek generation lagi setelah await storage
      jika berubah: bersihkan hasil tulis stale, jangan publish
      pasang access token dan expiry baru di memori
    kembalikan access token baru

PSEUDOCODE logout:
  generation bertambah segera; phase = signingOut
  blokir login baru sampai cleanup lokal selesai
  batalkan request; jangan terima hasil generation sebelumnya
  melalui antrean perubahan token/storage yang sama:
    hapus secret lokal; reset cache data dan navigasi
  coba revokasi sesi remote yang lama dengan timeout
  phase = signedOut; laporkan status remote secara terpisah
```

Bila server sudah merotasi refresh token tetapi response hilang karena jaringan terputus, client mungkin masih memegang token lama. Jangan membuat retry agresif; sepakati penanganan dengan IdP/server. Bila tidak ada recovery protokol yang aman, masuk ulang lebih baik daripada menerima ulang token yang seharusnya sudah dicabut.

### 9.8 Cache akun dan logout yang tidak bergantung data SICABOR

Pada `snapshotProvider`, tambahkan dependency scope sesi yang valid, bukan dependency token mentah yang berubah setiap refresh. Scope mencakup environment, user ID, district ID, dan generation; jika signed out, fetch harus berhenti.

```
PSEUDOCODE provider data terautentikasi:
  scope = watch(currentAuthenticatedScopeProvider)
  jika scope tidak ada: kembalikan keadaan unauthenticated
  buat CancelToken; cancel ketika provider di-dispose
  hasil = repository.fetch(scope, cancelToken)
  jika scope/generation berubah: abaikan hasil
  publikasikan hasil hanya ke cache milik scope tersebut
```

Ini membutuhkan perubahan signature `KokRepository.fetch()` yang sekarang tanpa parameter. `districtId` dalam scope client dipakai untuk cache/UX; server tetap menentukan wilayah berdasarkan principal, bukan mempercayai parameter tersebut. Gunakan provider family/auto-dispose atau session-scoped container yang benar-benar dibuang saat logout. Sekadar menambahkan `autoDispose` tidak cukup jika masih ada listener aktif.

Pisahkan komposisi profil menjadi:

```
ProfilePage
  ├─ profil pengguna dari AuthState / meProvider
  ├─ tombol keamanan akun dan Keluar (selalu tersedia)
  └─ DataView untuk ringkasan olahraga saja
```

Jangan menempatkan tombol Keluar di dalam callback sukses pemuatan snapshot, sebagaimana kode sekarang.

### 9.9 Perbaikan kecil yang dapat dilakukan sebelum server tersedia

**Label dan form:** ganti teks “Ingat Saya” menjadi “Ingat nomor SK di perangkat ini”; tambahkan guard `_busy` di awal `_submit()`; pertahankan pengecekan `mounted`. Untuk jalur login password first-party, tambahkan:

```dart
// Potongan konfigurasi field password, bukan form lengkap.
TextFormField(
  controller: _password,
  obscureText: _hidden,
  autofillHints: const [AutofillHints.password],
  enableSuggestions: false,
  autocorrect: false,
  textInputAction: TextInputAction.done,
  onFieldSubmitted: (_) {
    if (!_busy) _submit();
  },
  validator: (value) => value == null || value.isEmpty
      ? 'Kata sandi wajib diisi.'
      : null,
)
```

Bungkus pasangan identifier/password dalam `AutofillGroup`, jangan melarang paste, dan jangan trim password secara diam-diam. Clear controller saat alur selesai/dibatalkan sesuai UX; Dart string tidak memberi jaminan penghapusan memori kriptografis. Perbaiki area sentuh checkbox menjadi setidaknya target 44 px sesuai wireframe; ukuran 24 px dengan shrinkWrap pada kode sekarang perlu ditinjau.

**Label data:** `DateTime.now()` pada demo berarti waktu memuat fixture, bukan sinkronisasi. Snackbar sukses refresh baru ditampilkan setelah fetch selesai; untuk data mock gunakan kata “dimuat ulang”, bukan “disinkronkan ke SICABOR”.

**Pagar produksi:** jangan memakai `assert` sebagai satu-satunya kontrol karena assert hilang pada release.

```dart
void validateProductionConfiguration({
  required String environment,
  required bool usesDemoAuth,
  required bool usesMockData,
  required Uri apiBase,
  required Set<String> approvedHosts,
}) {
  if (environment != 'production') return;
  if (usesDemoAuth || usesMockData ||
      apiBase.scheme != 'https' ||
      apiBase.userInfo.isNotEmpty ||
      !approvedHosts.contains(apiBase.host)) {
    throw StateError('Konfigurasi produksi ditolak');
  }
}
```

Nilai environment wajib divalidasi sebagai enum/allowlist di composition root agar salah eja `production` tidak melewati pemeriksaan. Snippet ini harus dipasangkan dengan entrypoint/flavor production dan pemeriksaan CI; **bukan** batas keamanan server. `--dart-define` aman untuk konfigurasi publik seperti base URL/client ID, bukan untuk menyembunyikan secret.

## 10. Roadmap implementasi yang disarankan

Urutan berikut berdasarkan dependency, bukan estimasi tanggal selesai. Pekerjaan backend dapat dilakukan bersama pembimbing/tim SICABOR; satu mahasiswa tidak harus mengimplementasikan identity provider dari nol.

### Tahap A · Rapikan boundary tanpa menunggu SICABOR

**Pemilik utama:** pengembang Flutter.

- [ ]  Pisahkan demo/staging/production dan singkirkan default fallback demo dari production.
- [ ]  Buat `AuthRepository`, model principal, state auth, dan adapter demo yang hanya berada pada jalur demo.
- [ ]  Tambahkan startup gate dan penanganan auth unavailable.
- [ ]  Pisahkan identitas akun dan tombol keluar dari `DataView`.
- [ ]  Buat cache/session generation dan desain pembatalan request.
- [ ]  Perbaiki label Ingat SK, status data mock, snackbar refresh, dan kontak yang belum terverifikasi.
- [ ]  Tambahkan fake auth yang bisa mengembalikan success, rejection, timeout, expiry, dan revocation untuk test.

**Kriteria selesai:** demo tetap berfungsi, tetapi fitur auth sudah mempunyai kontrak terpisah dan pengujian state. Build produksi salah konfigurasi ditolak. Belum boleh disebut login nyata.

### Tahap B · Sepakati identitas dan kontrak pilot

**Pemilik utama:** pengembang + pembimbing/pemilik sistem + tim backend/IdP.

- [ ]  Putuskan akun individual dan kebijakan nomor SK sebagai identifier.
- [ ]  Tentukan OIDC resmi atau alternatif login API first-party; tulis keputusan arsitektur singkat.
- [ ]  Sediakan tenant/env staging, akun uji sintetis, client ID, redirect URI, serta audience/scope API.
- [ ]  Sepakati `/me`, assignment kecamatan, error, TTL, refresh, logout, revocation, dan recovery.
- [ ]  Putuskan platform pilot pertama; jika web akan dipakai nyata, siapkan jalur BFF/adapter web.
- [ ]  Tetapkan permission dokumen/ekspor dan SLA penonaktifan akun.

**Kriteria selesai:** kontrak dapat diuji dan tidak mengandung endpoint tebakan. Ada pihak yang bertanggung jawab atas lifecycle akun dan insiden login.

### Tahap C · Vertical slice autentikasi nyata, data olahraga tetap sintetis

**Pemilik utama:** Flutter + backend/IdP.

- [ ]  Login melalui auth staging yang nyata.
- [ ]  `/me` menjadi sumber profil/kecamatan.
- [ ]  Native secure storage terkonfigurasi, restore dan refresh berjalan.
- [ ]  401/403/429/offline dibedakan; refresh single-flight dan retry dibatasi.
- [ ]  Logout membersihkan storage/cache, tidak menunggu keberhasilan data SICABOR.
- [ ]  Uji dua akun dari kecamatan berbeda pada endpoint fixture backend terotorisasi.
- [ ]  UI jelas membedakan “auth staging” dari “data olahraga demo”.

**Kriteria selesai:** bukan sekadar halaman login berhasil; satu alur end-to-end login → `/me` → resource terotorisasi → expiry/refresh → logout terbukti. Endpoint fixture server diperlukan untuk menguji otorisasi; mock lokal saja tidak dapat membuktikannya.

### Tahap D · Penutupan risiko sebelum akun/data nyata

**Pemilik utama:** Flutter + backend/operasional.

- [ ]  MFA, recovery, undangan/aktivasi akun, dan penonaktifan diuji.
- [ ]  Rotasi/reuse detection dan revocation sesi server diuji.
- [ ]  Logging teredaksi, audit akses, serta monitoring tersedia.
- [ ]  Release signing, HTTPS, manifest, callback, backup/reinstall, dan perangkat fisik diverifikasi.
- [ ]  Semua endpoint data/media/ekspor menjalankan permission dan pembatasan kecamatan.
- [ ]  Tidak ada kredensial demo, fake success, fixture pribadi, atau secret service-to-service pada artefak produksi.

**Kriteria selesai:** daftar pengujian kritis lulus dengan bukti; pemilik sistem menyetujui pilot data nyata. Audit ini sendiri bukan persetujuan rilis.

### Tahap E · Integrasi data SICABOR dan hardening lanjutan

Ganti adapter data setelah kontrak tersedia: DTO/mapping, pagination, metadata sinkron server, dan akses media. Pertahankan boundary auth yang sudah diuji. Offline-first, biometrik lokal, certificate pinning, attestation, native share/PDF, serta penyempurnaan visual dapat menyusul berdasarkan risiko/kebutuhan—bukan menggantikan Tahap A–D.

### Peta file yang paling dulu berubah

| File saat ini | Perubahan utama | Temuan terkait |
| --- | --- | --- |
| `lib/core/session.dart` | Ganti boolean dengan controller/state auth; pisahkan adapter demo | F-01, F-02 |
| `lib/features/login_page.dart` | Panggil auth abstraction; error/UX sesuai pilihan OIDC atau first-party | F-07, F-08 |
| `lib/app.dart` | Guard stateful startup; reset scope/navigasi saat identitas berubah | F-03, F-05 |
| `lib/data/repository.dart` | Pisah demo/API, session-scoped cache, cancellation, client auth | F-05, F-09 |
| `lib/features/profile_page.dart` | `/me`, logout independen, label sinkron yang jujur | F-04, F-06, F-10 |
| `lib/features/home_page.dart` | Nama/wilayah dari principal; sumber dan timestamp data jelas | F-04, F-10 |
| Android/iOS config | Network permission, callback, storage, backup, signing | F-11 |
| `test/`  • `integration_test/`  • CI | Tambah auth lifecycle dan skenario negatif | F-12 |

## 11. Rencana pengujian dan bukti penerimaan

Semua skenario berikut adalah **pengujian yang harus ditambahkan/dijalankan**, bukan hasil lulus audit ini.

| Skenario | Hasil wajib | Lapisan |
| --- | --- | --- |
| Startup tanpa token | Login; tidak fetch data pribadi | Unit/widget |
| SK diingat, tanpa sesi | Identifier terisi tetapi tetap signed out | Unit/widget |
| Token tersimpan tetapi revoked | Dibersihkan; tidak ada kilasan data lama | Unit/integrasi |
| Startup offline dengan token | Layar retry/keluar; tidak menganggap password salah | Unit/perangkat |
| Kredensial salah atau akun tak dikenal | Pesan publik generik; server rate limit bekerja | Backend/integrasi |
| Pengguna membatalkan OIDC | Kembali ke login; bukan fake success | Perangkat |
| Issuer/audience/signature/expiry salah | Ditolak server; tidak memberi akses data | Backend |
| 401 bersamaan dari banyak GET | Hanya satu refresh per token/generation; retry terbatas | Unit/integrasi |
| 401 terlambat untuk token lama | Gunakan token baru yang sudah ada; hindari rotation berlebih | Unit |
| Retry tetap 401 | Berhenti; sesi ditutup sesuai kontrak | Unit |
| 403, 429, timeout, 5xx | Tidak menjadi refresh loop atau error kredensial palsu | Unit/integrasi |
| Refresh token lama dipakai ulang | Server mendeteksi reuse dan menerapkan revocation family | Backend |
| Logout ketika refresh sedang berjalan | Tidak ada token/response yang menghidupkan sesi kembali | Unit/integrasi |
| Akun A keluar, akun B masuk | Cache/navigasi/foto A tidak tampil pada B | Widget/perangkat |
| Snapshot initial load gagal | Tombol keluar tetap dapat digunakan | Widget |
| Storage write/delete gagal | Tidak fallback plaintext; status cleanup dilaporkan | Unit/perangkat |
| Akun kecamatan A meminta objek B | Ditolak pada list/detail/search/media/report | Backend/API |
| Role read-only mencoba mutation | Server menolak meskipun request dibuat di luar aplikasi | Backend/API |
| MFA/reset/undangan token replay | Ditolak; tidak membuka sesi hanya dengan challenge | Backend/integrasi |
| Akun dinonaktifkan saat masih login | Akses berhenti sesuai SLA revocation yang disepakati | Backend/integrasi |
| Token hendak dikirim ke host lain | Client menolak; tidak ada Authorization bocor | Unit/proxy |
| Rilis native dan reinstall/backup | Callback, storage, logout, dan restore sesuai policy | Perangkat |
| Production tanpa konfigurasi sah | Build/startup gagal tertutup; tidak masuk demo | CI |

### Contoh regression test yang dapat langsung ditambahkan untuk demo sekarang

Tes ini membuktikan bahwa mengingat nomor SK tidak sama dengan memulihkan sesi. Masukkan pada file test dengan import yang sesuai. Ia memakai API yang sudah ada di proyek; belum dijalankan dalam audit.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kok_app/core/session.dart';

void main() {
  test('Remembered SK does not restore a demo session', () async {
    SharedPreferences.setMockInitialValues({
      'remembered_sk': 'DEMO-001',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(prefs.getString('remembered_sk'), 'DEMO-001');
    expect(container.read(sessionProvider), isFalse);
    expect(prefs.getKeys(), {'remembered_sk'});
  });
}
```

Setelah refactor, pertahankan arti tes tetapi sesuaikan assertion ke `SignedOut` dan fake `AuthRepository`. Gunakan fake clock untuk expiry, fake storage yang bisa gagal, HTTP mock untuk 401/429, dan delayed response untuk race logout. Fixture otomatis tidak boleh menggunakan password produksi.

### Perintah validasi yang perlu dijalankan di lingkungan Flutter

```bash
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build apk --release
```

Sesudah flavor/entrypoint diterapkan, sesuaikan command build dengan target staging/production dan konfigurasi yang sah. Build iOS dilakukan pada macOS/Xcode. Build/test web terpisah wajib bila web menjadi target rilis. Simpan output CI, versi SDK, lockfile, hasil pengujian perangkat, serta hasil pengujian endpoint server; APK berhasil dibangun bukan bukti autentikasi aman.

## 12. Keputusan yang harus dibawa ke pembimbing/tim SICABOR

| Pertanyaan | Mengapa menentukan implementasi | Default sementara yang aman |
| --- | --- | --- |
| Siapa pemilik identitas akun KOK dan apakah ada OIDC/SSO? | Menentukan adapter, issuer, serta lifecycle akun | Jangan membuat identity database produksi baru tanpa persetujuan |
| Apakah nomor SK unik per individu dan tetap lintas periode? | Mencegah akun bersama/identifier tidak stabil | Pakai user ID stabil; SK sebagai atribut sampai jelas |
| Apakah beberapa pengurus memiliki akun pada kecamatan yang sama? | Audit individual dan assignment | Akun individual; satu assignment aktif per akun |
| Siapa yang boleh membuat/menonaktifkan akun? | Offboarding dan penyalahgunaan akses | Provisioning/undangan oleh admin resmi |
| Berapa lama sesi boleh bertahan dan kapan MFA diperlukan? | Storage, expiry, reauth, usability | Sesi konservatif; tanpa offline data sensitif |
| Apakah KOK boleh melihat isi KTP/KK/akta atau hanya status? | Permission dan distribusi data pribadi | Status saja |
| Apakah laporan boleh diekspor/dibagikan, dan kepada siapa? | Read-only tidak membatasi penyebaran hasil baca | Ekspor dibatasi sampai policy disepakati |
| Apakah web dipakai sebagai aplikasi nyata atau preview? | Menentukan BFF/cookie vs native token storage | Web tetap demo sampai strategi auth-nya siap |
| Apa SLA pencabutan akses setelah akun dinonaktifkan? | JWT stateless tidak otomatis langsung revoked | Tentukan TTL dan pemeriksaan sesi server secara eksplisit |
| Siapa helpdesk recovery dan bagaimana verifikasi identitasnya? | Recovery dapat menjadi titik terlemah | Jangan aktifkan kontak contoh untuk reset |

## 13. Checklist “autentikasi siap pilot”

- [ ]  Tidak ada validasi kredensial produksi di Flutter atau secret backend di binary.
- [ ]  Identitas dan kecamatan berasal dari auth/API yang sah.
- [ ]  Server menolak akses lintas kecamatan dan operasi tanpa permission.
- [ ]  Startup/restore tidak membuka data hanya karena token tersimpan.
- [ ]  Access token, refresh token, expiry, rotation, dan error memiliki kontrak yang diuji.
- [ ]  Tidak ada loop refresh atau retry yang menggandakan operasi.
- [ ]  Logout membersihkan lokal dan tidak dapat dibatalkan oleh respons request lama.
- [ ]  Pencabutan sesi remote dan keterbatasan offline dijelaskan dengan benar.
- [ ]  Ganti akun tidak menampilkan cache akun sebelumnya.
- [ ]  Password/OTP/token tidak berada di preferences, log, crash report, clipboard, atau URL.
- [ ]  Pemulihan akun, MFA, dan penonaktifan memiliki prosedur serta pemilik yang jelas.
- [ ]  Rilis native/web yang dipakai telah diuji, bukan hanya widget preview.
- [ ]  Label UI membedakan autentikasi staging, data mock, dan sinkronisasi SICABOR nyata.
- [ ]  Ada bukti pengujian dan persetujuan pemilik sistem sebelum data pribadi dipakai.

**Urutan paling disarankan:** refactor auth boundary → sepakati IdP/kontrak → login nyata + `/me` → restore/refresh/logout + isolasi cache → otorisasi server dan pengujian negatif → baru integrasi data SICABOR lebih luas. Prioritas ini meningkatkan kesiapan autentikasi tanpa menghambat demo UI yang sudah dibuat.

## 14. Referensi teknis

Rujukan berikut digunakan untuk rekomendasi, bukan sebagai klaim bahwa aplikasi sudah mematuhinya. Dokumentasi paket dapat berubah; pin versi, baca changelog, dan verifikasi API pada saat implementasi.

1. RFC 8252 — OAuth 2.0 for Native Apps: external user-agent, PKCE, public native client, dan redirect URI.
2. RFC 9700 — Best Current Practice for OAuth 2.0 Security: larangan resource-owner password grant, pembatasan privilege, refresh token rotation/sender-constraining, dan replay detection.
3. OWASP Authentication Cheat Sheet: pesan generik, throttling, pemulihan, password manager, dan monitoring.
4. OWASP Password Storage Cheat Sheet: penyimpanan hash password dan parameter Argon2id.
5. OWASP Mobile Application Security Verification Standard: kerangka storage, authentication/authorization, network, platform, dan privacy untuk mobile.
6. NIST SP 800-63B-4: pedoman autentikator, panjang password, blocklist, dan tidak memaksakan pergantian periodik tanpa alasan kompromi.
7. flutter_appauth: API authorization/refresh, platform yang didukung, konfigurasi callback, dan catatan cache native.
8. flutter_secure_storage: penyimpanan native, konfigurasi Android/iOS, backup, migrasi, serta batas implementasi web.

### Catatan audit tambahan di luar prioritas auth

`home_page.dart:47–50` memiliki special case ketika `expired == 5` yang menampilkan “4 klub · 3 cabor”. Generator demo saat ini membuat satu pelatih kedaluwarsa pada masing-masing lima klub dengan cabor berbeda (`repository.dart:94–103`). Jadi subtitle itu tidak mengikuti data; gunakan jumlah klub/cabor yang sudah dihitung, tanpa cabang hardcoded. Ini temuan konsistensi data terpisah, bukan alasan menunda pekerjaan autentikasi.

**Status akhir dokumen:** audit statis dan blueprint implementasi. Source ZIP tidak dimodifikasi; belum ada backend, akun, deployment, atau integrasi autentikasi yang dibuat oleh audit ini.
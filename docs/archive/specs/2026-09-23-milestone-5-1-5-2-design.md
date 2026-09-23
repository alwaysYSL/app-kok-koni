# Milestone 5.1 dan 5.2 — Desain penyelesaian integrasi mock SICABOR

**Tanggal:** 23 September 2026  
**Basis:** [audit enam spesifikasi](../audits/2026-09-23-audit-spesifikasi-integrasi-sicabor.md), [kontrak API KOK SICABOR](../../api/api-kok-sicabor.md), source `f97db01`.  
**Tujuan:** menutup celah sesi, error, akurasi data, dan fidelitas mock sebelum aplikasi diuji terhadap API resmi.

## 1. Batas pekerjaan

Milestone **5.1** menyelesaikan integritas sesi dan respons API: permintaan lama tidak boleh memutus sesi baru atau mengotori state baru; `/profile` harus valid sebelum sesi disimpan; timeout dan respons non-JSON harus jelas; 403 dengan kode khusus harus diperlakukan sesuai kontrak. Milestone **5.2** memperbaiki data yang ditampilkan, filter/pencarian, detail Klub/Atlet, dan mock server agar pengujian lokal benar-benar menguji jalur HTTP remote.

Keduanya dapat dijalankan tanpa URL resmi. Validasi respons nyata, perubahan kontrak backend, rilis Play Store, dan fitur Pelatih/Official baru berada di luar ruang lingkup ini. Endpoint Pelatih/Official yang sudah ada tetap ditampilkan sesuai keadaan data saat ini.

## 2. Keputusan desain utama

| Topik | Keputusan | Alasan |
|---|---|---|
| Identitas sesi request | `AuthSessionTokens` memiliki revisi monotonik yang naik pada `replace` dan `clear`. `ApiClient` menaruh revisi pada `RequestOptions.extra` setiap request bertoken. Interceptor hanya mengakhiri sesi jika revisi request masih sama dengan revisi aktif. | Token dari request lama dapat tiba setelah akun berganti; membandingkan revisi juga aman bila string token kebetulan dipakai ulang. Nilainya tidak dikirim ke server atau log. |
| 401/403 | 401 selalu mengakhiri **sesi request yang masih aktif**. 403 `MEMBER_NOT_FOUND`, `MEMBER_INACTIVE`, `NOT_KOK` juga mengakhiri sesi aktif. `NO_SUBDISTRICT` mempertahankan sesi dan menampilkan `message` server tanpa tombol retry otomatis. | Mengikuti tabel kode error kontrak. Semua error tetap diteruskan ke caller untuk pemetaan UI. |
| Alasan logout paksa | `AuthSignedOut.errorMessage` diisi pesan aman: 401 “Sesi berakhir. Silakan masuk kembali”; `MEMBER_INACTIVE` memakai `message` server; dua kode fatal lain memakai pesan Indonesia yang jelas. Logout manual tidak menampilkan alasan error. | Pengguna tidak kehilangan konteks saat dikembalikan ke login. |
| Response `/profile` | Pada login/restore, `success:true` belum cukup. `member.id > 0`, `username` dan `name` tidak kosong, `type == admin_kok`, `status == 1`, `scope.subdistrict_id > 0`, `subdistrict_name` tidak kosong, dan objek `summary` hadir wajib valid sebelum commit token. Respons tidak lengkap menjadi kegagalan profil yang aman. | Mencegah sesi dengan identitas/kecamatan nol atau kosong. Perubahan kecamatan saat sesi berjalan tetap perlu uji API resmi. |
| Timeout dan format | Auth `Dio` memakai `connectTimeout`/`receiveTimeout` dari `DeploymentProfile`. Respons yang diharapkan JSON tetapi berisi HTML/teks dipetakan ke `ApiConfigurationException`; prioritas 401 tetap dijaga agar token kedaluwarsa tidak disamarkan sebagai masalah URL. | Restore offline mempunyai batas waktu; URL yang salah tidak menjadi cast error mentah. |
| State daftar | Keenam jalur `catch` pada Cabor/Atlet/Klub mengecek `DataRequestContext` **dan** generation sebelum menulis state. `loadFirstPage` karena filter baru mengosongkan item/total lama; error filter menampilkan error, bukan hasil query sebelumnya. `loadMore` mempertahankan item yang sudah cocok dengan filter. | Memisahkan hasil lama dari query atau sesi baru. |
| UI error | Satu pemetaan presentasi untuk `NO_SUBDISTRICT`, error konfigurasi, timeout/offline, dan error server. Halaman remote memakai pesan dan izin retry yang sama; demo tidak berubah. | Kontrak tidak boleh ditafsirkan berbeda di tiap layar. |
| Mock token | Hanya token yang diterbitkan oleh instance server diterima. Simpan `issuedAt`/`expiresAt`, masa berlaku 24 jam, dan gunakan jam injeksi untuk test. Token tak dikenal/kedaluwarsa → `401 INVALID_TOKEN`; akun yang kemudian tidak ada → `403 MEMBER_NOT_FOUND`. | Mock harus membedakan token tidak sah dari akun sah yang berubah. |
| Kredensial mock | Hapus password universal yang saat ini di-hardcode dan dicetak saat startup. Akun uji memakai kredensial sintetis khusus mock. Jika tim backend menyatakan nilai lama pernah sah di SICABOR, rotasi/pencabutan adalah pekerjaan backend terpisah. | Repo tidak boleh menjadi sumber kredensial yang berpotensi nyata. Tidak menuliskan ulang nilainya di dokumen baru. |
| Grafik Cabor | Tetap gunakan halaman Cabor yang telah dimuat; beri keterangan “berdasarkan cabor yang sudah dimuat (X dari Y)”. Judul daftar tidak memakai kata “Aktif” tanpa filter status. | Tidak menambah request agregasi dan tidak mengklaim peringkat seluruh cabor. |
| Waktu Beranda | Pada mode remote, hilangkan teks “Terakhir Dimuat ... WIB” yang dihitung saat build; tampilkan status sumber “Data SICABOR”. | API tidak menyediakan waktu pembaruan dan `DateTime.now()` saat rebuild bukan waktu fetch. |
| SK Klub | URL `http`/`https` yang valid dibuka melalui `url_launcher` dengan browser eksternal. Jika gagal, tampilkan pesan dan aksi salin tautan sebagai fallback. | Memenuhi aksi “buka berkas” tanpa menganggap setiap URL valid. |

## 3. Milestone 5.1 — alur dan kriteria

### 3.1 Penanganan respons lintas sesi

`AuthSessionTokens.revision` dimulai dari 0 dan naik setiap kali token diganti atau dibersihkan, termasuk bootstrap, logout, login, dan restore. `ApiClient` merekam revisi ketika menyusun request yang mengirim Bearer token. `AuthSessionInterceptor` membaca revisi tersebut dari request yang gagal. Bila tidak ada revisi, token sudah berubah, atau revisinya berbeda, interceptor meneruskan error ke caller tanpa memanggil logout. Bila masih sama, 401 dan kode 403 fatal dikirim ke `AuthController` bersama `errorCode` dan `message`. Jangan mencatat token atau kredensial dalam log/test output.

Pengujian wajib mencakup: A mengirim request, A logout, B login, lalu request A menerima 401 dan 403 fatal; B tetap signed-in. Dua request aktif yang sama-sama menerima 401 hanya menghasilkan satu pembersihan credential. 403 `NO_SUBDISTRICT`, 404, 500, timeout, dan pembatalan request tidak mengakhiri sesi.

### 3.2 Kegagalan daftar lintas sesi

`CaborPaginationController`, `AthletePaginationController`, dan `ClubPaginationController` sudah menjaga jalur sukses. Tambahkan pemeriksaan konteks di `catch` untuk `loadFirstPage` dan `loadMore`; jangan bergantung pada generation saja karena rebuild konteks tidak selalu menaikkannya. Test memakai `ProviderContainer` yang sama, akun A → B, dan `Completer` yang menyelesaikan error request A setelah B aktif. State B harus tetap initial/hasil B tanpa error A.

### 3.3 Validasi login dan restore

`RemoteAuthRepository` memeriksa field wajib respons `/profile` sebelum mengembalikan `AuthResult.success`. Respons invalid tidak boleh menulis token ke `AuthSessionTokens` atau secure storage melalui controller. Auth client mendapat timeout yang sama dengan data client. Test menutup profil tanpa `member`, tanpa `summary`, tanpa `scope`, `type` bukan `admin_kok`, `status` bukan aktif, kecamatan kosong, dan koneksi yang timeout. Demo auth tetap lulus tanpa perubahan perilaku.

### 3.4 Error yang dapat dipahami pengguna

Tambah `ApiConfigurationException` untuk respons non-JSON atau URL API yang jelas salah. Pemetaan UI membedakan:

| Error | Teks/aksi |
|---|---|
| 401 sesi aktif | Redirect login dengan pesan sesi berakhir; tidak retry token lama. |
| 403 `MEMBER_INACTIVE` | Logout dan tampilkan `message` server di layar login. |
| 403 `MEMBER_NOT_FOUND` / `NOT_KOK` | Logout dengan pesan Indonesia yang sesuai. |
| 403 `NO_SUBDISTRICT` | Tampilkan `message` server + arahan hubungi admin; sesi tetap aktif; tanpa retry. |
| Respons non-JSON | “Respons server bukan JSON. Periksa alamat API.”; tanpa retry data otomatis. |
| Timeout/offline/5xx | Tampilkan pesan ramah dan tombol coba lagi; sesi tetap aktif. |

Gunakan pemetaan yang sama minimal di Beranda, Cabor, daftar/detail Atlet, daftar/detail Klub, dan Profil. Untuk 404 detail, pertahankan tampilan “tidak ditemukan” tanpa mengungkap kemungkinan data di luar kecamatan.

**5.1 selesai bila:** semua skenario di atas punya test yang gagal sebelum perbaikan dan lulus sesudahnya; `flutter analyze` dan suite Flutter lulus; akun B tidak dapat diputus oleh respons A; tidak ada respons salah bentuk yang membuat sesi valid; pesan 403 sesuai kontrak.

## 4. Milestone 5.2 — alur dan kriteria

### 4.1 Mock server dan panduan uji

Pisahkan penyimpanan sesi dari dataset `MockData` sehingga satu instance `SicaborMockServer` memiliki sesi sendiri. Token acak tidak dapat ditebak dan kadaluwarsa tepat setelah 24 jam menurut jam injeksi. Tidak ada fallback decoding username dari token; restart server membuat token lama tidak sah. Bind default CLI ke `127.0.0.1`; akses HP fisik memerlukan `--host=0.0.0.0` yang sengaja dipilih saat berada di jaringan pengujian. Password uji yang tersisa harus jelas sintetis. Jangan cetak password atau header Authorization di log.

[README mock](../../../scripts/mock_server/README.md) harus menunjukkan `APP_ENV=staging`, `AUTH_MODE=remote`, **`DATA_MODE=remote`**, dan `API_BASE_URL` ke `/api/v1/kok`. Contoh emulator, desktop, dan HP fisik memakai port aktual dari CLI (default 8088, atau port eksplisit); akses HTTP lokal di Android harus didokumentasikan sebagai konfigurasi **debug/staging saja**, sementara production tetap HTTPS. Uji HTTP sungguhan dari klien ke mock untuk login, `/profile`, paging Cabor lebih dari 25, daftar/detail Atlet–Klub, logout/restart, 401/403, dan dua akun kecamatan berbeda.

### 4.2 Beranda dan Cabor

Beranda menampilkan `totalCaborFromClub` sebagai “cabor dengan klub” dan `totalCaborFromAthlete` sebagai “cabor dengan atlet”; jumlah klub/atlet tetap berasal dari `totalClub`/`totalAthlete`. Cabor menampilkan “Cabang Olahraga” tanpa klaim aktif, dan grafik memakai keterangan jumlah cabor yang sudah dimuat dari `items.length` terhadap `meta.total`. Saat filter pertama gagal, jangan tampilkan statistik/item dari filter lama sebagai hasil filter baru. Mode remote tidak menampilkan jam “Terakhir Dimuat” dari waktu build.

### 4.3 Atlet

Saat pengguna mengetik lalu menghapus pencarian dalam 500 ms, timer lama dibatalkan sebelum query kosong dimuat. Perlakuan yang sama berlaku pada pencarian Klub di detail Cabor dan layar daftar Klub yang memakai debounce. Kartu atlet remote menampilkan `code` dan `statusLabel` di samping nama/cabor/klub. Tombol “Hubungi pengurus klub” pada detail atlet remote dihilangkan sampai ada data kontak yang benar; nama/kode klub tetap terlihat sebagai informasi. Mode demo mempertahankan fitur yang memang tersedia.

### 4.4 Klub

`management.dataAvailable == false` menampilkan “Belum tercatat di sistem”, sedangkan `dataAvailable == true` dan daftar kosong menampilkan hasil kosong biasa. Keterangan `totalAthleteInClub` menjelaskan total seluruh kecamatan. `state.total` hanya disebut jumlah hasil lokal **untuk filter saat ini** setelah loading selesai; perbedaan kedua angka tidak otomatis dianggap semata perbedaan wilayah. Berkas SK yang valid membuka browser; kegagalan membuka menyediakan pilihan salin.

**5.2 selesai bila:** test mock menolak token palsu/kedaluwarsa, contoh `DATA_MODE=remote` benar-benar mengambil data via HTTP mock, metrik/grafik dan keterangan jumlah memakai istilah kontrak, pencarian cepat tidak mengembalikan query lama, keadaan personel kosong/parsial terbaca benar, dan suite Flutter serta analyzer lulus. Tidak ada klaim kompatibilitas API resmi sebelum Milestone 6.

## 5. Pemetaan audit dan pekerjaan

| Temuan audit | Tahap |
|---|---|
| 1, 4–7, 14: sesi, error, validasi profil, timeout, format | 5.1 |
| 2–3, 8–13: mock, angka/UI, pencarian, Klub/Atlet | 5.2 |
| Panduan mock `DATA_MODE=demo` dan asal password universal | 5.2; konfirmasi provenance dengan pemilik backend sebagai tindak lanjut terpisah |

Dokumen ini adalah desain untuk implementasi berikutnya, bukan bukti bahwa perbaikannya sudah diterapkan. Rincian urutan file, test, dan perintah ada di [rencana implementasi](../plans/2026-09-23-milestone-5-1-5-2-plan.md).

# Tinjauan kesiapan KOK sebelum integrasi SICABOR dan Play Store

Tanggal: 12 September 2026. Basis kode: commit `1ce17f5`. Ini hasil peninjauan, bukan perubahan implementasi atau persetujuan spesifikasi oleh KONI.

**Mulai dari menyepakati cakupan rilis pertama selama 30–45 menit bersama pembimbing/pihak KOK. Setelah itu, prioritaskan ketepatan status data dan sambungan lifecycle refresh token.**

Penilaian: proyek sudah memiliki prototipe frontend yang cukup lengkap dan fondasi integrasi yang berguna. Namun, belum tepat menyebutnya siap produksi atau tinggal mengganti mock dengan URL API. Pekerjaan berikutnya perlu berpusat pada kebenaran data, alur pengguna yang tuntas, dan pengujian Android release.

## 1. Acuan dan hasil pemeriksaan

Wireframe awal 11 halaman dipakai sebagai acuan kebutuhan: pemantauan read-only, satu kecamatan per akun KOK, ringkasan, pencarian/filter, detail orang/klub, perhatian berkas/lisensi, kontak pengurus, laporan PDF/bagikan. Slide eksplorasi bukan otomatis kewajiban fitur. Instruksi tindak lanjut di PDF diperlakukan sebagai isi spesifikasi awal, bukan perintah untuk mengubah aplikasi sekarang.

Perubahan dari pengguna menjadi acuan terbaru: **Anggota berarti pengurus KOK**, atlet/pelatih/official tetap berada dalam klub, dan Cabor menjadi modul tersendiri. Perubahan ini konsisten dengan struktur navigasi sekarang. Daftar gabungan anggota pada wireframe tidak perlu dikembalikan.

| Pemeriksaan | Bukti pada sesi audit ini |
| --- | --- |
| Analisis statis | `flutter analyze --no-pub`: lulus, tidak ada masalah. |
| Suite proyek | `flutter test --no-pub --reporter expanded`: 382 lulus, 1 dilewati; yang dilewati adalah render preview opt-in. |
| Probe tambahan | Empat probe terpisah mereproduksi status verifikasi/dokumen keliru, refresh lintas pergantian token tanpa cancellation, HTTP 422 dianggap offline, dan production menerima HTTP. Probe mengassert perilaku bermasalah saat ini; hasil lulus bukan berarti masalah sudah diperbaiki. |
| Visual | Semua halaman PDF dirender/dibaca. Preview widget terbaru dibuat terpisah; beranda, detail orang/klub, dan profil diperiksa. Tidak dilakukan uji interaktif pada ponsel fisik. |
| Android | Gradle dan manifest sumber diperiksa, termasuk merged manifest release yang sudah tersedia. Tidak membuat AAB/release baru atau memvalidasi signing melalui Play Console. |

Flutter dijalankan melalui `dart.exe` dan `flutter_tools.snapshot` SDK terpasang karena wrapper/cache membutuhkan akses di luar sandbox. APPDATA alat diarahkan ke `.task-appdata` yang sudah ada. Kode aplikasi dan tes repository tidak diubah.

Ada masalah pada alat preview: setelah memaksa state `AuthTemporarilyUnavailable`, `test/preview_test.dart` memanggil helper login tanpa memulihkan state yang mengizinkan login. Render awal menghasilkan halaman gangguan sesi untuk nama file home/detail, tetapi tes tetap lulus. Salinan harness audit diperbaiki untuk memulihkan state signed-in sebelum mengambil preview. Tambahkan assertion identitas halaman ketika memperbaiki harness repository; jangan memakai sukses render sebagai bukti halaman yang benar.

Bukti audit tersimpan di [folder hasil audit](<C:/Users/Yasrul/.codex/visualizations/2026/09/12/01a09520-003d-7043-9a61-d452c8bfda8f/kok-review>), termasuk [log tes](<C:/Users/Yasrul/.codex/visualizations/2026/09/12/01a09520-003d-7043-9a61-d452c8bfda8f/kok-review/flutter-test.log>) dan [probe reproduksi](<C:/Users/Yasrul/.codex/visualizations/2026/09/12/01a09520-003d-7043-9a61-d452c8bfda8f/kok-review/audit_probes_test.dart>).

## 2. Kesesuaian dengan kebutuhan terbaru

| Bagian | Status dan pekerjaan tersisa |
| --- | --- |
| Navigasi, Anggota, Cabor | Lima tab sudah sesuai perubahan. Konfirmasi periode kepengurusan, kebutuhan cabor tanpa klub, serta apakah role kabupaten memang termasuk rilis KOK. |
| Beranda, daftar, detail, perhatian | Alur tersedia. Perlu membedakan verifikasi, kelengkapan, lisensi, dan data belum diketahui; statistik harus memakai definisi yang sama di semua halaman. |
| Pencarian lintas entitas | Klub, atlet, pelatih, cabor tersedia. Official ikut hasil kategori Semua, tetapi belum punya filter khusus. Pengurus KOK belum masuk pencarian global; tentukan apakah ini kebutuhan tambahan. Chip belum memuat jumlah per kategori seperti wireframe. |
| Dokumen dan koordinasi | Status dokumen klub tersedia, file belum dibuka. Kontak klub/helpdesk berupa sheet informasi. Berbagi klub menyalin clipboard; tombol berbagi orang hanya menampilkan snackbar. Hak membaca berkas asli masih perlu keputusan. |
| Laporan dan sesi | Rekap ada sebagai teks clipboard; PDF dan Android share sheet belum tersedia. Session guard, storage, dan adapter remote tersedia, tetapi endpoint sengaja belum diimplementasikan. |

Fondasi yang layak dipertahankan: pemisahan `AuthRepository`/`KokRepository`, composition root, model immutable, token sensitif di secure storage, access token di memori, lifecycle logout, pemisahan environment, dan penjagaan respons lama di provider. Tidak perlu mengganti Riverpod/GoRouter atau mengulang arsitektur dari awal.

## 3. Lima kelompok temuan yang harus diprioritaskan

### 1. P1 — Status data dapat memberi kepastian palsu

Di [detail orang](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/features/athlete_detail/athlete_detail_page.dart:325>), badge menjadi “terverifikasi” bila tidak ada berkas kurang/lisensi kedaluwarsa, tanpa mengecek `person.verified`. Di [checklist dokumen](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/features/athlete_detail/athlete_detail_page.dart:463>), empat dokumen tetap dianggap ada selama namanya tidak tercantum dalam `missingDocuments`; `requiredDocuments` dan `completedDocuments` belum dipakai.

**Reproduksi:** orang dengan `verified: false` dan tanpa informasi dokumen tampil “terverifikasi” serta “4 dari 4”. Ini langsung berkaitan dengan fungsi utama KOK sebagai pemantau kualitas data.

Perbaikan yang disarankan: pisahkan status verifikasi, kelengkapan dokumen, dan lisensi. Sediakan status belum diketahui/tidak tersedia. Gunakan data dokumen eksplisit, bukan ketiadaan daftar kekurangan sebagai bukti lengkap. Default [model](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/data/models.dart:50>) `verified: true`, lisensi tidak kedaluwarsa, dan periode pengurus `2025–2029` perlu ditinjau agar field yang absen tidak berubah menjadi fakta resmi.

Rapikan makna angka pada paket pekerjaan yang sama: detail klub menghitung orang yang membutuhkan perhatian tetapi melabelinya “berkas kurang”; profil melabeli seluruh pelatih sebagai “Pelatih Terverifikasi”; beranda menghitung orang dari semua role untuk label “Atlet berkas kurang”. Bedakan jumlah orang, jumlah dokumen, total pelatih, dan pelatih terverifikasi. Verifikasi tidak otomatis sama dengan kelengkapan.

Data identitas juga harus jujur: semua role diberi awalan `ATL-`, pelatih atlet dipilih dari pelatih pertama di klub, dan alamat orang yang kosong dapat diganti alamat klub tanpa label pembeda. Gunakan ID/relasi yang sah atau tanda belum tersedia. Status dokumen klub sekarang selalu berwarna hijau meskipun nilai statusnya bebas; buat pemetaan status yang aman.

**Selesai jika:** contoh data kosong, belum diverifikasi, dokumen ditolak, lisensi tidak diketahui, serta orang tanpa relasi pelatih menampilkan keadaan yang benar dan statistik antarhalaman konsisten.

### 2. P1 — Lifecycle refresh belum terhubung utuh ke pengelolaan sesi

[ApiClient](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/core/network/api_client.dart:106>) sudah menyatukan beberapa respons 401 menjadi satu proses refresh. Namun, hasil refresh hanya mengganti token di memori. Belum ada jalur untuk menyimpan refresh token hasil rotasi melalui pengelolaan credential yang sama dengan login. [Restore](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/core/auth/presentation/auth_controller.dart:342>) juga belum menyimpan token baru jika backend merotasinya saat restore.

Jika SICABOR memakai rotasi refresh token, aplikasi bisa berhasil refresh saat berjalan tetapi mencoba token lama setelah ditutup/dibuka. Ini bergantung pada kontrak backend; tetap bisa dipersiapkan dengan fake repository sekarang. Kegagalan refresh permanen/401 terakhir juga perlu diteruskan ke state sesi dan router. Saat ini exception jaringan belum terhubung ke invalidasi sesi terpusat.

**Reproduksi tambahan:** refresh akun A dimulai, token bridge dikosongkan/diganti akun B, lalu refresh A selesai; token A menimpa token B bila pemanggil tidak memberi cancellation. Provider sudah memiliki cancellation dan pengecekan respons lama, sehingga ini bukan bukti kebocoran data pada aplikasi demo yang sedang berjalan. Ini celah pada kontrak ApiClient yang perlu ditutup sebelum adapter remote dipakai. Gunakan identitas/generasi sesi untuk mengesahkan hasil refresh, serta batasi single-flight pada sesi tersebut.

Petakan 400/422, 429, format respons salah, offline, timeout, 401, 403, dan 5xx secara berbeda. Probe menunjukkan HTTP 422 saat ini menjadi `NetworkOfflineException`. Cancellation domain juga belum dihubungkan ke `Dio.CancelToken`; respons bisa ditolak setelah selesai, tetapi request jaringan belum benar-benar dibatalkan.

**Selesai jika:** login → 401 → refresh → simpan rotasi → restart berhasil; refresh ditolak memulihkan layar login; timeout tidak menghapus sesi yang masih dapat dipulihkan; logout/pergantian akun saat refresh tidak menghidupkan kembali token lama. Tes ini tidak memerlukan endpoint SICABOR nyata.

### 3. P1 sebelum API — Provider granular tersedia tetapi belum digunakan oleh layar

[DataView](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/shared/widgets.dart:7>) tetap mengambil `snapshotProvider`; detail klub/orang, pengurus, dan helpdesk masih dibaca dari snapshot. Referensi provider granular ditemukan pada deklarasi dan tes, bukan konsumsi halaman. Jadi keberadaan interface belum sama dengan migrasi UI yang selesai.

Mulai dari detail klub dan detail orang: gunakan provider yang sudah ada, tampilkan loading/error/not-found per resource, dan buktikan halaman detail bekerja walau orang itu tidak ada dalam daftar ringkas awal. Berikutnya daftar/filter memakai query dan pagination internal jika volume data memang memerlukannya. Pertahankan ringkasan sebagai ringkasan; jangan menghitung total seluruh kecamatan dari satu halaman hasil paginasi.

Snapshot penuh tidak otomatis bermasalah pada dataset kecil. Ukur dengan dataset realistis dan sepakati batas ukuran sebelum refactor besar. Yang pasti saat ini, struktur UI bergantung pada semua data tersedia sekaligus. Cabor juga diturunkan dari nama cabor pada klub; cabor tanpa klub tidak muncul. Jika diperlukan direktori cabor resmi, siapkan model ber-ID stabil dan sumber data tersendiri setelah maknanya disepakati.

Periksa pula scope pada fixture granular ketika mulai dipakai: detail demo mencari ID di kumpulan beberapa scope. Konteks request yang tidak berubah belum membuktikan resource itu milik kecamatan yang benar. Uji ID kecamatan lain; backend tetap wajib memeriksa scope dan hak akses pada setiap endpoint.

**Selesai jika:** detail hanya membutuhkan resource terkait, scope tetap konsisten, empty list bukan error, daftar panjang dapat dimuat bertahap bila dibutuhkan, dan satu bagian gagal tanpa meruntuhkan semua layar.

### 4. P2 — Aksi akhir pengguna dan informasi sumber belum tuntas

Implementasikan laporan kecamatan per cabor berisi klub/atlet/pelatih/official, identitas wilayah, dan tanggal data; format perlu disepakati lebih dahulu. Model laporan, render PDF dari fixture, simpan/bagikan dengan share sheet Android dapat dikerjakan sebelum API. Gunakan label/watermark demo pada hasil fixture. Tentukan data yang boleh ikut ekspor; untuk rilis awal, rekap agregat biasanya cukup.

Kontak perlu menjadi alur yang tuntas: pilih aksi resmi yang dibutuhkan, misalnya WhatsApp/telepon/email, dengan penanganan tidak ada aplikasi tujuan atau kontak kosong. Jangan menambahkan viewer dokumen sensitif sebelum hak akses disepakati; status dokumen saja bisa menjadi cakupan rilis pertama yang sah. Read-only tetap mengizinkan laporan/kontak tanpa menambah CRUD.

Pisahkan waktu data diperbarui di sumber, waktu berhasil ditarik aplikasi, dan waktu percobaan refresh. `loadedAt` sekarang adalah waktu pemuatan; itu belum membuktikan sinkronisasi SICABOR. Simpan keadaan fresh/stale/offline dan konversi waktu sebelum memberi label WIB. Label demo pada profil/footer masih statis; render berdasarkan mode/sumber data. Beranda sekarang baru menampilkan catatan demo di bagian bawah, sehingga indikator ringkas di area status lebih mudah terlihat.

**Selesai jika:** setiap tombol melakukan aksi yang dijanjikan; laporan cocok dengan scope dan angka layar; refresh gagal tidak menampilkan waktu sukses baru; data kosong, data lama, dan data demo dapat dibedakan.

### 5. P1 sebelum distribusi — Konfigurasi Android belum memenuhi jalur release

[Manifest utama](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/android/app/src/main/AndroidManifest.xml:1>) tidak memiliki `android.permission.INTERNET`; izin ini ada di manifest debug/profile, dan tidak ditemukan pada merged manifest release yang diperiksa. Koneksi API pada build release memerlukan izin tersebut. Dokumentasi Flutter juga meminta pemeriksaan izin internet pada manifest release. [Panduan Android Flutter](https://docs.flutter.dev/deployment/android).

[Build release](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/android/app/build.gradle.kts:32>) masih menggunakan signing debug. Siapkan upload key, Play App Signing, dan pipeline AAB dengan pengelolaan kunci di luar repository. ID aplikasi sudah `id.konigarut.kok_app`; konfirmasi kepemilikannya sebelum publikasi pertama. Ikon launcher masih scaffold menurut README dan aset perlu difinalkan.

[DeploymentProfile](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/core/config/deployment_profile.dart:25>) benar menolak demo ketika `APP_ENV=production`, tetapi default semua define masih demo; build release biasa belum otomatis berarti build production. Pipeline rilis harus mewajibkan konfigurasi production/remote/remote dan URL yang benar. Probe juga membuktikan production menerima `http://`; batasi production ke HTTPS.

CI saat ini sudah menjalankan analyze/test dan APK debug, tetapi trigger tidak mencakup perubahan `android/**` dan belum mencakup pull request atau validasi AAB release. Perluas jalur pemeriksaan sesuai rilis. Jangan menganggap APK yang berhasil dibangun sebagai bukti API release berfungsi.

**Selesai jika:** AAB yang ditandatangani benar dapat dipasang melalui jalur pengujian Play, varian yang diuji sesuai environment tujuan, izin/target SDK benar, dan login/jaringan/secure storage berfungsi di perangkat nyata.

## 4. Urutan kerja yang disarankan

Estimasi berikut untuk satu pengembang yang sudah mengenal proyek, termasuk tes terarah. Ini kisaran kerja aktif, tidak termasuk menunggu keputusan KONI, backend, atau review Google.

| Urutan | Hasil kerja | Perkiraan | Batas selesai |
| --- | --- | --- | --- |
| 1 | Spesifikasi v1 ringkas dan keputusan yang belum disepakati | 30–45 menit diskusi, 2–3 jam dokumentasi | Ada definisi pengguna/scope, fitur wajib, dokumen, laporan, dan pemilik rilis. |
| 2 | Ketepatan domain dan lifecycle refresh | 2–4 hari | Kasus pada temuan 1–2 memiliki regression test dan lulus. |
| 3 | Hubungkan provider ke UI dan tambahkan mock skenario gagal | 2–4 hari | Detail tidak bergantung seluruh snapshot; 401/403/404/offline/empty teruji; volume besar dicoba. |
| 4 | Tuntaskan laporan/kontak/status data | 2–3 hari | Pengurus bisa menyelesaikan alur pemantauan → koordinasi → laporan menggunakan fixture. |
| 5 | Validasi Android release dan siapkan pengujian pengguna | 2–4 hari | Build pengujian tersedia, checklist ponsel lulus, dokumen rilis siap. Aktivasi production menunggu API/UAT. |

Dengan kapasitas sekitar 3–4 jam per hari, rentangkan jadwal mengikuti waktu aktual. Jangan menjadikan kelima tahap sebagai satu pekerjaan besar. Kerjakan satu batas selesai setiap kali. Penentuan pemilik akun Play, dokumen privasi, dan calon tester dapat mulai di tahap 1 supaya tidak menunggu sampai implementasi selesai.

Belum perlu menambah notifikasi, CRUD, chat, analitik kompleks, atau database offline. Untuk tahap awal, sepakati dulu perilaku saat offline. Jika cache diperlukan, pisahkan berdasarkan environment/akun/scope dan tentukan pembersihan setelah logout. Kebutuhan offline-first penuh tetap keputusan produk, bukan syarat otomatis Play Store.

## 5. Lima hal untuk dibawa ke pembimbing dan tim SICABOR

1. **Pengguna dan kewenangan:** apakah hanya akun KOK satu kecamatan, siapa penerbit akun/SK, apakah role kabupaten masuk aplikasi ini, bagaimana pergantian pengurus serta akun dinonaktifkan. Tab pengurus KOK berbeda dari anggota klub. KOK tetap tidak menyunting atau memverifikasi data bila read-only dipertahankan.
2. **Autentikasi:** bentuk login, access/refresh token, masa berlaku, rotasi, restore, revoke/logout, pemulihan kata sandi melalui admin atau sistem, dan kode kegagalan. Jangan menganggap desain Bearer/refresh internal sudah merupakan kontrak resmi SICABOR.
3. **Entitas dan pencarian:** ID stabil, relasi klub–cabor–orang–wilayah, orang dengan beberapa peran/klub, periode pengurus, definisi aktif/terverifikasi, query/filter/sort/pagination dan sumber total agregat. Minta contoh respons normal, kosong, field absen, dan relasi tidak tersedia.
4. **Dokumen dan privasi:** KOK melihat status saja atau isi berkas, field pribadi yang benar-benar diperlukan, akses foto/kontak, masa berlaku URL file, serta isi laporan yang boleh dibagikan. NIK sudah tersedia pada model tetapi tidak otomatis perlu diminta/ditampilkan. Backend harus membatasi data yang dikirim, bukan hanya UI menyembunyikannya.
5. **Sinkronisasi dan operasional:** timestamp sumber, frekuensi pembaruan, toleransi data lama, sandbox/base URL, kontak resmi bantuan, SLA/maintenance bila ada, dan pemilik aplikasi setelah kerja praktik selesai.

Siapkan tabel kebutuhan data per halaman dan contoh JSON internal sekarang; tandai dengan jelas sebagai fixture/usulan. DTO API terpisah baru dibuat sesuai dokumen resmi. Jangan membuat endpoint atau skema SICABOR seolah-olah sudah disepakati.

## 6. Persiapan Play Store

Ketentuan web diperiksa pada 12 September 2026; periksa lagi Play Console pada waktu unggah.

1. **Pemilik publikasi dan akses reviewer.** Sepakati akun penerbit, akses pemeliharaan, kontak dukungan, identitas merek, serta penguasaan upload key. Untuk aplikasi instansi, kepemilikan dan serah terima harus jelas. Karena aplikasi memerlukan login, sediakan akun reviewer yang aktif dan instruksi akses dalam Play Console, idealnya dengan data uji yang diizinkan dan fitur yang representatif. Akun demo lokal yang terlihat pada layar login tidak menggantikan akses reviewer untuk build production. [Persyaratan akses aplikasi](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en-GB).
2. **AAB, API target, kompatibilitas.** Publikasikan AAB melalui Play App Signing. Sejak 31 Agustus 2026, aplikasi Android mobile baru/update harus menargetkan Android 16/API 36 atau lebih tinggi. SDK lokal serta merged manifest lama yang diperiksa sudah menunjukkan target 36, jadi verifikasi hasil AAB final; jangan langsung menyimpulkan target SDK masih kurang. Uji juga native library Flutter/plugin pada perangkat/emulator 16 KB. [Target API Google Play](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [kompatibilitas 16 KB](https://developer.android.com/guide/practices/page-sizes).
3. **Privasi dan App content.** Siapkan halaman kebijakan privasi publik dan akses dari dalam aplikasi, Data safety sesuai aliran data/SDK aktual, kontak privasi, aturan retensi, rating konten, target audiens, serta deklarasi iklan sesuai kenyataan. Read-only bukan berarti tidak mengakses data pribadi. Tidak perlu menyebut aplikasi ditujukan kepada anak hanya karena terdapat atlet anak; tetapkan audiens berdasarkan pengguna aplikasi. [Kebijakan User Data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).
4. **Penghapusan akun sesuai alur yang benar.** Persyaratan penghapusan di dalam dan luar aplikasi berlaku jika pengguna dapat membuat akun dari aplikasi, termasuk alur yang relevan pada kebijakan. KOK saat ini login dengan akun yang disediakan; jangan menambahkan penghapusan akun tanpa memastikan model penerbitan akun/ketentuan tersebut. Tetap tentukan kanal permintaan penghapusan data dan retensinya bersama pemilik sistem. Menghapus SK tersimpan/logout bukan penghapusan akun backend. [Penjelasan penghapusan akun](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
5. **Testing, listing, dan serah terima.** Mulai dari internal testing, lanjut UAT pengurus. Akun developer personal yang dibuat setelah 13 November 2023 memerlukan closed test minimal 12 tester yang terus opted-in selama 14 hari sebelum mengajukan akses production; memenuhi durasi bukan persetujuan otomatis. Siapkan ikon/screenshot final, deskripsi fitur yang benar-benar tersedia, catatan feedback, pre-launch report, pemantauan crash/ANR, dan penanggung jawab perbaikan setelah rilis. [Ketentuan pengujian Google Play](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

## 7. Kriteria siap sebelum dan sesudah API

| Sebelum API tersedia | Sesudah API tersedia, sebelum production |
| --- | --- |
| Cakupan v1 dan kebutuhan data tercatat; keputusan terbuka jelas | Kontrak resmi, DTO/mapping, dan endpoint diuji di staging |
| Mock mencakup data kosong/parsial/besar dan kegagalan jaringan | Otorisasi lintas kecamatan/role terbukti dari server |
| Status data benar; refresh lifecycle lulus dengan fake backend | Login, rotasi, revoke dan pemulihan sesi terbukti dengan backend nyata |
| PDF/kontak/navigasi berfungsi dalam demo; indikator sumber jujur | Laporan dan statistik dicocokkan dengan data sumber serta UAT pengurus |
| Jalur build pengujian Android, dokumen rilis, dan tester siap | AAB production, privasi/App content, akses reviewer, testing dan persetujuan rilis siap |

Uji perangkat perlu mencakup lima kelompok: alur kerja pengurus; akun/scope dan restart; offline/timeout/refresh; layar kecil/font besar/TalkBack/keyboard; serta instalasi/update/backup-restore/secure storage pada build release. Suite yang ada sudah memiliki pengujian lebar 320 px dan skala teks 1,3 untuk detail klub, tetapi itu belum menggantikan pengujian perangkat.

Dokumen [rencana integrasi lama](<F:/Kuliah Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/rencana-kesiapan-integrasi-api.md:149>) perlu diperbarui: masih menyebut repository hanya satu method sekaligus memberi status 100% pada beberapa area yang baru fondasinya. Ganti persentase dengan bukti dan kriteria selesai. Simpan keputusan perubahan wireframe, hasil UAT, dan keterbatasan integrasi sebagai bahan laporan kerja praktik.

**Langkah berikutnya, kurang dari dua menit:** salin lima topik pada bagian 5 ke agenda konsultasi, lalu tandai satu keputusan pertama: “Rilis v1 tetap read-only, satu akun KOK satu kecamatan, dan dokumen hanya status atau juga isi berkas?”

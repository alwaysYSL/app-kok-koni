# Rancangan polish UI KOK berbasis kontrak SICABOR

Tanggal: 24 September 2026
Status: Disetujui pengguna pada 24 September 2026

## Latar dan tujuan

Aplikasi KOK mempertahankan karakter visual rancangan Figma, tetapi integrasi mode server mengubah data yang benar-benar tersedia. Rancangan lama menonjolkan sinkronisasi, kelengkapan berkas, lisensi, dan pengurus. Kontrak [API KOK SICABOR](../../api/api-kok-sicabor.md) saat ini menyediakan data baca saja tentang akun dan ringkasan kecamatan, cabor, klub, serta atlet. Data resmi kepengurusan KOK belum tersedia.

Tujuan polish adalah membuat aplikasi terasa sebagai **pandangan kondisi olahraga kecamatan dan pintu masuk untuk menemukan data**, dengan struktur informasi dan tampilan yang konsisten. Setiap angka, status, dan tindakan pada mode server harus dapat ditelusuri ke kontrak API. Screenshot di `ui-screenshot-figma/` menjadi acuan karakter visual, bukan sumber kebenaran untuk fitur yang belum didukung.

## Batas pekerjaan

- Fokus pada pengalaman mode `remote` yang dapat diuji melalui mock server lokal. Mode demo tetap dipertahankan untuk contoh data dan kebutuhan peninjauan visual, tetapi diberi penanda bahwa isinya contoh.
- Tidak menambah endpoint, field, atau makna data pada kontrak API SICABOR. Mock server tidak menyediakan endpoint kepengurusan KOK fiktif.
- Tidak menampilkan angka pelatih, official, verifikasi berkas, lisensi, riwayat sinkronisasi, atau anggota KOK sebagai data resmi jika kontrak tidak menyediakannya.
- Perilaku autentikasi, isolasi wilayah akun, dan penanganan 401/403 yang sudah ada tetap menjadi dasar.

## Arsitektur informasi dan navigasi

Navigasi utama tetap lima menu: **Beranda, Cabor, Klub, Anggota, Profil**. Label **Anggota** mengarah ke kepengurusan KOK, sesuai permintaan eksplisit tim KONI Garut. Atlet ditemukan dari pintu masuk Beranda dan dari Detail Cabor; daftar atlet umum menjadi halaman tersendiri tanpa menggantikan menu Anggota.

Setiap halaman daftar memakai satu judul ringkas. Beranda tidak membutuhkan judul tambahan karena header kecamatan sudah mengidentifikasi halaman. Cabang Olahraga memakai judul `Cabang Olahraga`; Klub memakai `Klub` dengan aksi urut di kanan; Anggota memakai `Kepengurusan KOK`; Profil memakai judul `Akun`. Jumlah hasil dan nama kecamatan berada dalam keterangan di bawah judul atau dekat daftar, bukan disisipkan pada judul yang berubah selama memuat atau menyaring data. Judul bagian dalam konten yang hanya mengulang judul halaman dihilangkan.

Pintu masuk pencarian di Beranda mempunyai tiga pilihan dengan tujuan yang eksplisit: **Jelajahi Cabor**, **Cari Klub**, dan **Cari Atlet**. Pilihan tersebut menuju daftar yang sesuai. UI tidak menjanjikan satu pencarian gabungan karena API tidak menyediakan endpoint gabungan, dan `/cabor` tidak mempunyai parameter `search`. Rute pencarian lama, bila tetap dipakai, hanya menjadi pemilih tujuan yang sama; tidak menampilkan input pencarian lintas entitas yang tidak berfungsi.

## Bahasa visual bersama

- Biru KONI menjadi warna navigasi, tautan, dan tindakan utama. Variasi warna cabor atau klub dipakai pada header detail dan aksen kecil. Bidang konten dan komponen daftar tetap mengikuti satu sistem visual.
- Detail Cabor dan Detail Klub memakai header berwarna, lalu **bidang konten putih yang menumpang pada bagian bawah header dengan kedua sudut atas membulat**. Tab berbentuk pil berada di dalam bidang putih. Referensi bentuknya ialah transisi header ke tab pada screenshot Detail Klub Figma yang diberikan pengguna.
- Token awal untuk implementasi: radius bidang konten atas sekitar 28 dp, kartu 16 dp, dan wadah tab 18 dp; jarak dasar kelipatan 8 dp. Nilai akhir diuji pada ukuran layar kecil agar bidang membulat dan tab tidak terpotong.
- Gaya judul, kartu, avatar/fallback gambar, chip filter, badge status, serta ruang kosong antarbagian digunakan ulang lintas halaman. Status informatif memakai warna tenang; merah dipakai hanya untuk galat atau perhatian yang didukung data, bukan untuk setiap nilai kosong.
- Teks kondisi data memakai makna yang tetap: `Belum tercatat di sistem` untuk `data_available: false`, `Tidak ada hasil` untuk penyaringan nihil, dan pesan gagal beserta aksi coba lagi hanya untuk kegagalan yang dapat dicoba ulang.

## Rancangan halaman

### Beranda

Header menampilkan identitas kecamatan dari `scope` dan identitas akun yang benar-benar tersedia. Nama contoh seperti `Pak Asep` tidak menjadi fallback pada mode server. Ringkasan menampilkan total cabor, klub, dan atlet dari `/profile`, serta atlet yang **belum tercatat di klub** sebagai konteks data. Angka `total_cabor` dipakai langsung tanpa menjumlahkan dua asal cabor.

Setelah ringkasan, tiga pintu masuk navigasi di atas mengantar pengguna ke direktori. `kontingen` hanya tampil bila tersedia. `data_notes` dari server ditampilkan tanpa mengubah isi atau urutannya; agar tidak mendominasi Beranda, catatan dapat ditempatkan dalam bagian penjelasan yang dapat dibuka. Atribusi memakai `Data SICABOR` dan aksi muat ulang yang nyata. Tidak ada waktu sinkronisasi, persentase berkas, modul lisensi, atau kartu perhatian berbasis data demo pada mode server.

### Daftar Cabor

Halaman ini menjadi direktori. Header ringkas menunjukkan kecamatan dan total cabor dari metadata daftar atau ringkasan. Tiap baris menampilkan nama cabor, induk organisasi bila ada, jumlah klub, dan jumlah atlet dalam kecamatan akun. Logo `null` atau URL yang gagal dimuat memakai fallback yang konsisten.

Filter sumber memakai nilai kontrak `/cabor`: `all`, `club`, `athlete`, dengan label **Semua**, **Ada Klub**, **Ada Atlet**. Pilihan tersebut dapat saling beririsan; UI tidak menggambarkannya sebagai kategori eksklusif. Pengurutan memakai opsi API yang relevan, terutama nama, jumlah atlet, dan jumlah klub. Grafik sebaran yang saat ini hanya merangkum item pagination yang sudah dimuat dikeluarkan dari halaman ini agar direktori tidak tampak seperti analisis keseluruhan wilayah.

### Detail Cabor

Header menunjukkan nama cabor, induk organisasi bila ada, dan kecamatan. Angka utama hanyalah `total_athlete` dan `total_club` dari item cabor yang sudah teridentifikasi. Keduanya dibatasi kecamatan. Di bawah transisi bidang putih membulat terdapat tab **Atlet** sebagai awal dan **Klub** sebagai tab kedua. Keduanya memakai endpoint daftar yang difilter dengan `id_cabor`, pagination, pencarian dan filter yang memang tersedia bagi entitas masing-masing.

Mode server tidak menampilkan tab Pelatih, angka pelatih buatan `0`, persentase kelengkapan berkas, atau grafik usia/berkas tanpa data. Keadaan kosong spesifik: cabor bisa memiliki atlet tanpa klub, atau klub tanpa atlet. Jika halaman dibuka langsung sebelum item cabor teridentifikasi, UI memuat identitasnya melalui daftar `/cabor` yang tersedia; selama itu angka tidak ditampilkan sebagai nol. Bila ID tidak ditemukan setelah penelusuran daftar, tampilkan keadaan tidak ditemukan.

### Daftar Klub

Daftar menonjolkan nama klub, cabor, lokasi **sekretariat**, dan status dari `/club`. Pencarian nama/kode, filter status, pengurutan, dan pagination mengikuti kontrak. Jumlah anggota dari `total_athlete_in_club` bila ditampilkan selalu berlabel **atlet terdaftar di klub** dan diberi konteks bahwa cakupannya lintas kecamatan. Jumlah tersebut tidak dijumlahkan atau dibandingkan langsung dengan total atlet cabor.

### Detail Klub

Header berwarna menampilkan identitas klub dan badge status. Bidang putih dengan sudut atas membulat memuat tab **Info → Pengurus → Atlet**. Urutan ini menempatkan identitas yang paling lengkap lebih dulu, lalu data kepengurusan yang mungkin parsial, lalu keanggotaan atlet yang saat ini jarang tercatat.

Tab Info mengelompokkan identitas, SK bila ada, kontak, alamat sekretariat, dan alamat tempat latihan. Jika tempat latihan berada di kecamatan lain, label alamat tetap jelas. Tab Pengurus menampilkan `management`, `officials`, dan `coaches` sesuai blok data: `data_available: false` ditulis sebagai belum tercatat, sedangkan `partial: true` dijelaskan sebagai data belum lengkap. Kepengurusan klub tidak pernah dipakai sebagai kepengurusan KOK.

Tab Atlet menampilkan hanya atlet yang berdomisili di kecamatan akun sesuai `/athlete?id_club=...`. `filter_warning` dari server ditampilkan dekat daftar. Bila total anggota klub lintas kecamatan lebih besar dari hasil lokal, penjelasan cakupan tampil tanpa menyiratkan kesalahan aplikasi.

### Daftar dan Detail Atlet

Daftar Atlet umum dapat dibuka langsung dari Beranda dan mengambil `/athlete` tanpa mengharuskan keanggotaan klub. Pencarian nama/kode serta filter jenis kelamin dan status mengikuti kontrak. Saat datang dari Detail Cabor atau Detail Klub, filter konteks cabor/klub diterapkan lewat parameter yang tersedia. Kartu atlet memuat nama, kode, cabor, status, dan klub bila tercatat. Nilai `club: null` diberi label netral **klub belum tercatat**.

Detail Atlet mengelompokkan identitas, cabor dan klub, domisili, serta data kontak/fisik yang tersedia. Field kosong tidak menjadi klaim status berkas. Tidak ada checklist dokumen, tombol menghubungi klub yang tidak didukung, atau indikator verifikasi fiktif. Atlet dari kecamatan lain maupun ID yang tidak ada menghasilkan tampilan tidak ditemukan sesuai respons 404.

### Anggota KOK

Menu utama tetap ada. Selama belum ada data resmi, mode server menampilkan judul dan kecamatan akun, lalu pesan: **Data susunan pengurus KOK resmi belum tersedia di aplikasi.** Halaman tidak menampilkan jumlah, jabatan, periode SK, ataupun orang contoh seolah data resmi. Data contoh lokal boleh dipakai pada mode demo dengan penanda contoh yang jelas. Saat sumber resmi kelak disepakati, integrasinya memerlukan keputusan kontrak dan pekerjaan terpisah.

### Profil/Akun

Akun berfokus pada identitas pengguna, kecamatan, status, dan kontingen jika ada. Rekap data kecamatan tetap dapat diakses bila izin ekspor tersedia, tetapi ringkasan angka besar tidak diulang sebagai dashboard kedua. Pengaturan, informasi aplikasi, dan keluar akun mengikuti pola visual bersama. Teks sinkronisasi terakhir tidak muncul tanpa timestamp dari API.

## Aliran data, kondisi, dan kesalahan

`/profile` menjadi sumber ringkasan Beranda dan identitas wilayah. `/cabor`, `/club`, serta `/athlete` menjadi sumber daftar dan detail yang didukung kontrak. Angka daftar memakai `meta.total`, bukan jumlah item yang baru dimuat. Perubahan filter mengosongkan hasil lama selama permintaan baru diproses sehingga daftar dari kriteria sebelumnya tidak tampak sebagai hasil terbaru.

Loading, daftar kosong, hasil filter kosong, data belum tercatat, data parsial, 404, galat jaringan, 401, dan 403 mempunyai presentasi yang berbeda. 401 mengakhiri sesi; 403 mengikuti alasan server; 404 detail menunjukkan tidak ditemukan. `filter_warning`, `data_notes`, dan `partial` tetap terlihat dengan bahasa yang sesuai. Aksi coba lagi hanya ditampilkan untuk permintaan yang memang layak diulang.

## Mock server dan verifikasi rancangan

Mock server tetap replika kontrak SICABOR. Tidak ada endpoint pencarian gabungan, verifikasi dokumen, pelatih cabor, atau pengurus KOK baru. Penyempurnaan terbatas pada fixture dan pengujian:

1. Tambahkan pemeriksaan bahwa `summary` tiap akun konsisten dengan daftar cabor, klub, dan atlet yang dihasilkan, termasuk jumlah atlet tanpa klub.
2. Dokumentasikan skenario akun yang sudah ada: Garut Kota untuk campuran klub/atlet, Limbangan untuk cabor dan atlet tanpa klub, Tarogong Kidul untuk variasi klub, serta akun error untuk penanganan sesi. Tetapkan contoh cabor dengan klub tanpa atlet, atlet tanpa klub, kepengurusan parsial, alamat latihan lintas kecamatan, dan `filter_warning`.
3. Siapkan fixture gambar yang dapat dimuat secara lokal untuk memeriksa logo/foto, sekaligus fixture logo `null` atau URL gagal untuk memeriksa fallback. Respons tetap menggunakan bentuk URL string atau `null` yang diizinkan kontrak; foto atlet tetap berupa URL.
4. Verifikasi alur HTTP mock, pencarian/filter/pagination, pembatasan kecamatan, dan keadaan UI pada layar kecil. Periksa bahwa contoh visual tidak berubah menjadi klaim data resmi pada mode server.

## Urutan implementasi yang diusulkan

1. Rapikan token visual, komponen bersama, judul halaman, dan transisi header ke bidang konten membulat.
2. Susun ulang Beranda, pintu masuk pencarian, dan Daftar Atlet umum.
3. Rapikan Daftar/Detail Cabor, lalu Daftar/Detail Klub dan Detail Atlet.
4. Rapikan Anggota KOK, Akun, dan seluruh loading/empty/error states.
5. Lengkapi fixture mock dan verifikasi kontrak serta screenshot pada beberapa skenario akun.

Rincian langkah kode, pembagian perubahan, dan perintah pengujian dicatat dalam rencana implementasi di `docs/archive/plans/`.

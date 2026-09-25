# Perapihan UI aplikasi KOK berbasis SICABOR

Tanggal: 25 September 2026  
Status: Rancangan hasil diskusi, menunggu tinjauan akhir pengguna

## Tujuan dan batasan

Rancang tampilan aplikasi agar kembali memiliki rasa visual yang konsisten dengan referensi `ui-screenshot-figma/`. Alur, arti statistik, cakupan kecamatan, filter, isi tab, dan sumber data SICABOR tetap berlaku. Perubahan yang telah disetujui di luar pemolesan murni adalah penempatan daftar Atlet di menu bawah, akses Kepengurusan KOK dari Profil, cuplikan klub nyata di Beranda, dan pembersihan aset logo. Tidak ada perubahan kontrak API atau arti data.

Fokus rancangan adalah mode SICABOR. Komponen visual bersama dan susunan menu bawah boleh dipakai pada mode demo, tetapi data dan fitur khusus demo tetap berfungsi pada mode demo. Jangan menampilkan data demo atau fitur yang tidak tersedia dari SICABOR seolah-olah merupakan data resmi. Khususnya, kelengkapan berkas, lisensi pelatih, riwayat sinkronisasi, dan data resmi kepengurusan KOK belum mendukung tampilan seperti contoh Figma. `data_notes` dari `/profile` tetap ditampilkan sebagai informasi server, bukan sebagai daftar tindakan "Perlu Perhatian".

## Bahasa visual bersama

- Pertahankan dasar desain Figma: bidang konten terang, kartu putih, tipografi yang jelas, hero biru KOK, dan jarak yang lapang. Satu sistem warna, radius, shadow, padding, badge, dan ikon berlaku di seluruh layar.
- Kartu daftar Cabor, Klub, dan Atlet memakai gaya bersama yang mengikuti `Surface` saat ini: sudut sekitar 18 dp, shadow lembut, padding dan jarak antarkartu yang seragam. Kartu tetap putih; perbedaan isi tiap entitas tetap dipertahankan.
- Warna status memiliki arti sendiri, misalnya aktif, tidak aktif, dan error. Warna merek tidak menggantikan arti warna status.
- Periksa rancangan pada lebar 320 dan 390 dp. Nama panjang dapat membungkus pada kartu atau dipotong secara terkendali pada header ringkas. Filter dan aksi tidak boleh terpotong tanpa petunjuk yang jelas.
- Keadaan awal, kosong, hasil filter kosong, gagal memuat, serta gagal memuat halaman berikutnya memakai pola tipografi dan jarak yang konsisten. Tombol "Reset filter" hanya untuk hasil filter kosong; "Coba lagi" hanya untuk kegagalan yang dapat dicoba ulang. Penanganan 401/403 dan sesi kedaluwarsa tetap mengikuti perilaku aplikasi saat ini.

## Warna dan identitas halaman detail

- Detail Cabor selalu menggunakan palet biru KOK untuk hero, tab aktif, dan aksen pendukung. Identitas warna berdasarkan jenis cabor dihapus.
- Detail Klub menggunakan warna dominan dari logo klub untuk hero dan penanda tab aktif. Ekstraksi mengabaikan latar transparan atau putih dan menyesuaikan kecerahan agar teks tetap terbaca. Jika logo tidak tersedia, gagal dimuat, atau tidak menghasilkan warna yang layak, gunakan biru KOK. Pemuatan dan analisis logo tidak boleh menahan tampilan detail; biru KOK dapat tampil terlebih dahulu lalu berganti halus ketika warna valid siap. Warna hasil logo tidak diterapkan pada kartu daftar Klub. Kartu konten detail tetap putih dengan warna teks aplikasi.
- Detail Atlet menggunakan biru KOK. Struktur tampilannya mengikuti referensi `detail-atlet-binamuda-v2.png`, bukan varian detail atlet yang menaruh semua identitas di hero.

## Navigasi dan Beranda

Menu bawah menjadi **Beranda · Cabor · Klub · Atlet · Profil**. Daftar Atlet menjadi tujuan langsung dengan pencarian di dalam daftar; saat dibuka sebagai tab utama, tidak ada tombol kembali. Rute daftar dan detail Atlet yang sudah ada tetap dapat dicapai dari Cabor, Klub, serta tautan internal tanpa merusak navigasi kembali. Kepengurusan KOK diakses dari Profil. Gerak, indikator aktif, ikon, dan label menu bawah dibuat seragam. Pencarian global tidak dijadikan pintu masuk pada mode SICABOR karena API menyediakan pencarian per-entitas, bukan endpoint global.

Beranda berisi hero identitas akun dan kecamatan yang ringkas, kartu ringkasan `Data SICABOR` yang sedikit bertumpang tindih dengan hero, cuplikan hingga tiga klub di kecamatan, lalu `Catatan Data SICABOR` dari `data_notes`. Tiga tombol direktori besar dan bar pencarian di hero dihilangkan karena tujuan utama sudah ada di menu bawah. Cuplikan klub memakai data nyata dari `/club` sesuai cakupan sekretariat kecamatan dan tautan "Lihat semua" menuju daftar Klub. Bila jumlah klub nol, tampilkan keterangan kosong yang ringkas. Pemuatan atau kegagalan cuplikan klub ditangani pada seksi itu sendiri agar ringkasan dari `/profile` tetap terlihat. `data_notes` ditampilkan dengan kalimat dan urutan yang diberikan server. Ringkasan angka tetap berasal dari `/profile` dan mempertahankan arti masing-masing metrik.

Bagian "Perlu Perhatian" pada desain Figma tidak ditampilkan dalam mode SICABOR sampai API menyediakan data tindak lanjut yang sesuai. `data_notes` tetap bersifat informatif dan tidak memakai gaya peringatan merah.

## Daftar Cabor, Klub, dan Atlet

### Cabor

Judul, jumlah hasil, dan kecamatan memiliki hirarki yang jelas. Filter sumber `Semua`, `Ada Klub`, dan `Ada Atlet` tetap tersedia. Urutan disajikan melalui satu kontrol "Urutkan". Kartu tetap putih; biru KOK hanya sebagai aksen kecil. Urutan isi kartu adalah logo atau ikon pengganti di kiri, nama dan induk organisasi, kemudian jumlah klub dan atlet. URL `logo` dari SICABOR bisa kosong atau gagal dimuat; gunakan fallback dalam wadah berukuran sama. Nilai nol tetap ditampilkan sebagai data yang sah.

### Klub

Kartu menonjolkan logo, nama, status, dan cabor, lalu lokasi sekretariat secara singkat dan jumlah atlet terdaftar di klub. Nama ketua cukup tampil pada detail Klub. Label jumlah atlet tetap menegaskan bahwa angka adalah keanggotaan yang tercatat dan dapat mencakup atlet lintas kecamatan; data keanggotaan SICABOR juga masih jarang terisi. Pencarian, filter status, dan urutan yang sudah ada tetap bekerja; gaya kontrol diseragamkan dengan daftar lain.

### Atlet

Sebagai menu utama, judul halaman cukup "Atlet" tanpa tombol kembali. Pencarian nama atau kode tetap di atas daftar. Tombol "Filter" membuka bottom sheet berisi jenis kelamin dan status, dengan aksi "Reset" dan "Terapkan" serta penanda saat filter aktif. Ini menggantikan deretan chip panjang pada layar sempit tanpa mengubah pilihan filter. Kartu menampilkan foto, nama yang boleh dua baris, cabor, informasi klub atau keterangan belum tercatat, kode, dan status dengan ukuran teks terbaca.

Daftar Atlet mempertahankan pagination API yang sudah ada: 25 item per permintaan dan pemuatan lanjutan saat mendekati akhir daftar. Tidak ada nomor halaman. Tampilkan indikator kecil saat memuat lebih banyak, aksi coba lagi bila pemuatan lanjutan gagal, dan akhir daftar yang jelas.

## Halaman detail

### Klub

Komposisi mengikuti Figma: logo besar di tengah hero, nama dominan, kode/cabor sebagai informasi sekunder, badge status, serta statistik SICABOR di bagian bawah hero. Statistik nol tetap tampil tenang dan tidak menjadi pesan error. Keterangan perbedaan cakupan antara total anggota klub lintas kecamatan dan daftar atlet lokal tetap tersedia. Bagian konten terang berisi tab `Info · Pengurus · Atlet` dan data yang sekarang digunakan. Animasi perpindahan tab dipertahankan.

### Cabor dan perilaku scroll detail

Hero Cabor lebih ringkas daripada hero Klub, memuat nama, induk organisasi, kecamatan, dan dua statistik yang sekarang ada. Kedua halaman memakai pola scroll yang sama: hero dan bidang konten putih bergerak ke atas; setelah hero keluar, bilah header ringkas tetap terlihat di atas tab yang menempel. Nama klub atau cabor muncul secara halus dan berukuran sesuai ruang di antara tombol kembali dan aksi yang tersedia. Judul panjang menjadi satu baris dengan ellipsis. Hanya bilah header dan tab yang menempel; pencarian, filter, dan daftar ikut bergulir. Perpindahan tab tidak boleh menghilangkan hasil pencarian atau membuat posisi scroll melompat secara tidak terduga. Animasi pindah tab tetap ada.

### Atlet

Pertahankan susunan v2: hero, foto yang menumpang batas hero, kartu identitas putih, lalu bagian data fisik serta kontak/alamat. Perbaiki ukuran foto, kesejajaran label dan nilai, keterbacaan nama klub/alamat panjang, shadow, dan jarak. Badge status mengikuti status SICABOR, bukan kelengkapan berkas pada Figma.

Bagian **Data Fisik** menjadi satu kartu tanpa tiga kotak statistik di dalamnya. Ilustrasi vektor tubuh manusia yang netral berwarna biru berada di kiri. Tiga garis penunjuk halus mengarah ke data Tinggi Badan, Berat Badan, dan Golongan Darah di kanan; garis berfungsi sebagai ilustrasi, bukan penunjuk ukuran anatomis. Angka lebih menonjol daripada label. Nilai yang tidak tersedia tetap memiliki baris dengan tanda `—`. Komposisi mengikuti sketsa yang diberikan pengguna dan harus muat pada 320 dp tanpa menutup atau memotong teks.

## Profil, Kepengurusan, dan Login

Profil mempertahankan kartu identitas akun sebagai fokus. Susunan berikutnya: `Organisasi` berisi tautan Kepengurusan KOK dengan penanda "Belum tersedia" pada mode SICABOR; `Data & Utilitas` berisi status data SICABOR serta rekap kecamatan jika akun memiliki akses; `Aplikasi` berisi Pengaturan, Tentang, dan Keluar. Tautan Kepengurusan membuka halaman penjelasan yang sudah ada pada mode SICABOR; pada mode demo, data kepengurusan demo tetap dapat dilihat dari tautan ini. Riwayat sinkronisasi seperti contoh Figma tidak ditampilkan pada mode SICABOR karena API tidak menyediakan datanya.

Login mempertahankan komposisi hero biru dan formulir putih. Perapihannya terbatas pada ukuran hero di layar kecil, jarak field, tombol, dan pesan gagal masuk. Label input tetap `Username` sesuai autentikasi SICABOR, bukan `Nomor SK` dari contoh Figma. Pemilih akun demo hanya muncul pada mode demo.

Aset logo KONI pada `assets/branding/logo-koni.png` dan `assets/logo-koni.png` telah dibersihkan secara presisi: bagian putih dalam kata `GARUT` menjadi transparan, tanpa perubahan piksel di luar area kata tersebut.

## Verifikasi rancangan saat implementasi

Periksa tampilan mode SICABOR pada 320 dan 390 dp dengan data mock yang mewakili kecamatan memiliki klub dan tidak memiliki klub, logo tersedia/kosong/gagal dimuat, nama panjang, statistik nol, atlet tanpa klub, filter kosong, serta error jaringan. Periksa scroll detail Klub/Cabor dengan tab sticky dan header ringkas; animasi pergantian tab; keyboard pada pencarian; pagination Atlet; status navigasi lima menu; serta informasi yang tersedia atau tidak tersedia dari API. Pastikan gagal memuat cuplikan klub tidak menghilangkan ringkasan Beranda dan palet logo gagal kembali ke biru KOK. Pemeriksaan ini memvalidasi UI lokal, bukan kompatibilitas server produksi yang masih memerlukan lingkungan resmi.

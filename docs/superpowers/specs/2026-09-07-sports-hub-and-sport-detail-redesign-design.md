# Spesifikasi Desain: Redesain Halaman Induk Cabor (SportsPage) & Pembuatan Detail Cabor Mandiri (SportDetailPage)

Tanggal: 2026-09-07  
Status: Approved  

---

## 1. Latar Belakang & Masalah

Di dalam arsitektur data Koordinator Organisasi Kecamatan (KOK) KONI Garut, Cabang Olahraga (Cabor) berfungsi sebagai **dimensi silang** yang menghubungkan klub, atlet, pelatih, dan official se-Kecamatan Garut Kota.

Kondisi saat ini:
1. **Halaman Induk Cabor (`/sports` - Tab 2)**: Tampilan masih berupa daftar vertikal datar sederhana tanpa visualisasi analitik potensi atau pemetaan sebaran atlet di kecamatan sebagaimana dieksplorasi pada Dokumen Wireframe Slide 9 (*"Satu angka + sebaran cabor"*).
2. **Halaman Detail Cabor (`/sport/:name`)**: Belum memiliki modul detail mandiri. Rute ini hanya dialihkan ke `ClubsPage(sport: ...)` yang sekadar menampilkan daftar klub. Akibatnya, Koordinator KOK tidak memiliki sarana untuk melihat daftar atlet cabor tersebut lintas klub, daftar pelatih cabor, komposisi piramida usia pembinaan bibit atlet, ataupun kualitas kepatuhan dokumen berkas pada cabor tersebut.

Solusi:
* Meningkatkan **`SportsPage`** dengan visualisasi grafik sebaran atlet per cabor menggunakan pustaka **`fl_chart`**.
* Membangun modul mandiri **`SportDetailPage`** dengan identitas visual bertema warna cabor dinamis, kartu statistik melayang, kartu grafik dwimode (Kelompok Usia vs Kualitas Berkas), serta 3 tab konten terintegrasi (**Klub**, **Atlet**, dan **Pelatih & Official**).

---

## 2. Sasaran & Batasan Desain

### Sasaran (Goals)
1. **Visualisasi Potensi Kecamatan**: Menyajikan grafik sebaran proporsi atlet antar-cabor di halaman induk cabor menggunakan `fl_chart`.
2. **Detail Cabor Khusus & Mandiri**: Menggantikan rute `ClubsPage` dengan `SportDetailPage` mandiri yang menyajikan data komprehensif cabor.
3. **Analitik Dwimode (Opsi C)**: Memberikan fasilitas evaluasi regenerasi bibit muda (*Kelompok Usia*) dan kepatuhan administratif (*Status Berkas*) di halaman detail cabor.
4. **Navigasi Terpadu**: Menyediakan 3 tab konten (*Klub*, *Atlet*, *Pelatih & Official*) dengan fitur pencarian dan filter kelompok usia di tab atlet.
5. **Konsistensi Visual & Identitas Tema Dinamis**:
   - Palet warna header cabor dinamis mengikuti cabang olahraga masing-masing (`SportBrandPaletteResolver`).
   - Aksen latar dekorasi lingkaran konsentris (`BrandHeaderPatternPainter`).
   - Tombol kembali standar konsisten `Icons.chevron_left` (`size: 28`).
   - Warna teks judul kartu standar `KokColors.cardTitle` (`#141414`).

### Batasan (Constraints)
- Tidak merusak struktur 5 tab navigasi utama (`/home`, `/sports`, `/clubs`, `/committee`, `/profile`).
- Mode *read-only* sesuai prinsip KOK: tidak ada operasi manipulasi data (CRUD), hanya filter, pencarian, dan pembagian/rekapitulasi data.
- Menjaga target sentuh minimum $\ge 44\text{px}$ dan responsive di layar 320px – 420px.
- Kualitas kode: `flutter analyze` 0 issues dan `flutter test` 100% lulus.

---

## 3. Arsitektur Teknis & Dependensi

### A. Dependensi Baru
* Menambahkan paket **`fl_chart: ^1.2.0`** ke `pubspec.yaml`.

### B. Resolver Palet Tema Dinamis Cabor (`SportBrandPaletteResolver`)
Dibuat resolver terpusat di `lib/features/sport_detail/sport_brand_palette.dart` atau di dalam modul cabor:
* **Bulu Tangkis**:
  - `headerStart`: `#6D28D9` (Deep Violet)
  - `headerEnd`: `#4C1D95`
  - `softAccent`: `#DDD6FE`
  - `badgeBackground`: `#F5F3FF`
* **Sepak Bola**:
  - `headerStart`: `#1D4ED8` (Royal Blue)
  - `headerEnd`: `#1E3A8A`
  - `softAccent`: `#DBEAFE`
  - `badgeBackground`: `#EFF6FF`
* **Pencak Silat**:
  - `headerStart`: `#C2410C` (Rust Orange)
  - `headerEnd`: `#9A3412`
  - `softAccent`: `#FFEDD5`
  - `badgeBackground`: `#FFF7ED`
* **Bola Voli**:
  - `headerStart`: `#0284C7` (Sky Cyan)
  - `headerEnd`: `#0369A1`
  - `softAccent`: `#E0F2FE`
  - `badgeBackground`: `#F0F9FF`
* **Renang**:
  - `headerStart`: `#0F766E` (Aquatic Teal)
  - `headerEnd`: `#115E59`
  - `softAccent`: `#CCFBF1`
  - `badgeBackground`: `#F0FDFA`
* **Default / Fallback**:
  - `headerStart`: `#1B4FA0` (KONI Blue)
  - `headerEnd`: `#123A75`

---

## 4. Rincian Antarmuka Pengguna (UI/UX Specification)

### A. Halaman Induk Cabor (`lib/features/sports_page.dart`)
1. **Header Eksekutif**:
   - Berlatar gradasi navy dengan dekorasi `CustomPaint(painter: const BrandHeaderPatternPainter())`.
   - Menampilkan label `"DIREKTORI CABANG OLAHRAGA"`, judul tebal `"5 Cabang Olahraga Aktif"`, dan subjudul `"Pemetaan potensi pembinaan atlet & klub se-Kecamatan Garut Kota"`.
2. **Kartu Analitik Sebaran Atlet Kecamatan (`fl_chart`)**:
   - Latar kartu putih dengan border-radius 20px dan drop shadow halus.
   - Judul seksi: `"SEBARAN ATLET PER CABANG OLAHRAGA"`.
   - Menggunakan **Horizontal Bar Chart** (atau Donut Chart) dari `fl_chart`.
   - Tiap batang cabor diwarnai dengan warna khas cabor (`SportBrandPaletteResolver`).
   - Tooltip interaktif menampilkan jumlah atlet dan persentase dari total seluruh atlet kecamatan saat disentuh.
3. **Search Bar Direktori**:
   - `TextField` dengan ikon kaca pembesar, border radius 12px, placeholder *"Cari cabang olahraga..."*, dan tombol clear saat ada kueri.
4. **Daftar Kartu Cabor**:
   - Avatar cabor dengan ikon resmi dan warna latar lembut.
   - Nama cabor tebal (`KokColors.cardTitle`, 16sp).
   - Baris metrik: Chip `X Klub`, `Y Atlet`, `Z Pelatih`.
   - Mini progress bar kelengkapan berkas cabor tersebut.
   - Ikon panah chevron kanan (`Icons.chevron_right`, `color: KokColors.bluePrimary`).
   - Mengetuk kartu: memicu `context.push('/sport/${Uri.encodeComponent(sport)}')`.

### B. Halaman Detail Cabor Mandiri (`lib/features/sport_detail/sport_detail_page.dart`)
1. **Header Dinamis Khas Cabor**:
   - Gradasi header dari `palette.headerStart` ke `palette.headerEnd`.
   - Dilengkapi `BrandHeaderPatternPainter` untuk aksen pola busur lingkaran konsentris.
   - Tombol kembali di pojok kiri atas: `Icons.chevron_left` (`size: 28`, putih).
   - Tombol share di pojok kanan atas: `Icons.share_outlined` (putih).
   - Ikon cabang olahraga berukuran 48px di dalam kontainer lingkaran ber-border putih 2px.
   - Nama cabor tebal (24sp, putih) dan teks `"Kecamatan Garut Kota"`.
2. **Kartu Statistik Cabor Melayang**:
   - `Transform.translate(offset: Offset(0, -32))` dengan border radius 20px dan shadow lembut.
   - 4 kolom metrik:
     * **Klub**: Jumlah klub terdaftar di cabor ini.
     * **Atlet**: Total atlet terdaftar.
     * **Pelatih**: Total pelatih pembina.
     * **Berkas Lengkap**: Rasio/persentase atlet yang berkasnya lengkap.
3. **Kartu Analitik Dwimode `fl_chart`**:
   - Header kartu dengan segment toggle/choice chip:
     * **Mode 1 — "Kelompok Usia"**:
       - Grafik batang (`BarChart`) atau Donut (`PieChart`) `fl_chart` yang memetakan sebaran atlet: **U-14**, **U-16**, **U-18**, dan **Senior**.
       - Menunjukkan komposisi piramida regenerasi bibit muda.
     * **Mode 2 — "Status Berkas"**:
       - Donut chart (`PieChart`) `fl_chart` hijau untuk berkas lengkap/terverifikasi dan merah untuk berkas kurang.
       - Disertai ringkasan dokumen yang paling sering kurang (KK, Akta, Surat Sehat).
4. **Tiga Tab Navigasi Konten (`TabBar`)**:
   - **Tab 1: Klub**:
     * Menampilkan daftar klub pada cabor tersebut.
     * Setiap kartu memuat nama klub, desa/kelurahan, jumlah atlet, status aktif/pasif, dan penanda berkas.
     * Mengetuk kartu membuka `ClubDetailPage` (`/club/:id`).
   - **Tab 2: Atlet**:
     * Menampilkan seluruh atlet cabor tersebut lintas klub.
     * Dilengkapi search input nama atlet dan filter chip kelompok usia (Semua, U-14, U-16, U-18, Senior).
     * Setiap baris menampilkan avatar inisial, nama tebal, nama klub, kelompok usia, dan badge status verifikasi berkas (hijau lengkap / merah berkas kurang).
     * Mengetuk kartu membuka `AthleteDetailPage` (`/person/:id`).
   - **Tab 3: Pelatih & Official**:
     * Menampilkan daftar pelatih dan official cabor tersebut.
     * Memuat nama, klub naungan, lisensi kepelatihan, dan status masa berlaku lisensi (hijau aktif / merah kedaluwarsa).
     * Mengetuk kartu membuka `AthleteDetailPage` (`/person/:id`).
5. **Aksi Bawah**:
   - Tombol sticky/floating *"Salin Rekapitulasi Cabor"* untuk membagikan ringkasan data cabor ke WhatsApp/KONI.

### C. Pembaruan Router (`lib/app.dart`)
- Mengubah konfigurasi rute `/sport/:name`:
  ```dart
  GoRoute(
    path: '/sport/:name',
    builder: (_, s) => SportDetailPage(sport: s.pathParameters['name']!),
  ),
  ```

---

## 5. Rencana Pengujian (Testing & Verification)

1. **Unit & Widget Test**:
   - `test/sports_page_test.dart`:
     * Render header dan horizontal bar/donut chart `fl_chart`.
     * Fungsionalitas pencarian nama cabor.
     * Navigasi mengetuk kartu cabor mengarahkan ke `/sport/:name`.
   - `test/sport_detail_test.dart`:
     * Render header dengan tema warna dinamis cabor dan pola busur konsentris.
     * Render kartu statistik 4 metrik.
     * Interaksi kartu analitik `fl_chart` dan pergantian toggle dwimode (Kelompok Usia $\leftrightarrow$ Status Berkas).
     * Pergantian tab (Klub, Atlet, Pelatih).
     * Filter chip kelompok usia di tab atlet.
     * Tombol kembali `Icons.chevron_left` (`size: 28`).
2. **Integration Test (`test/app_test.dart`)**:
   - Alur navigasi: Dari Tab Cabor $\rightarrow$ masuk ke Detail Cabor $\rightarrow$ memeriksa metrik & grafik $\rightarrow$ beralih ke Tab Atlet $\rightarrow$ mengetuk salah satu atlet $\rightarrow$ masuk ke `AthleteDetailPage` $\rightarrow$ kembali ke `SportDetailPage` $\rightarrow$ kembali ke `SportsPage`.
3. **Golden Previews (`test/preview_test.dart`)**:
   - `previews/cabor.png`: Tampilan baru direktori cabor dengan grafik sebaran atlet kecamatan.
   - `previews/detail-cabor.png`: Tampilan baru detail cabor mandiri dengan grafik kelompok usia dan tab konten.
4. **Analisis Statis**:
   - `flutter analyze` dengan 0 issues.
   - `flutter test` dengan 100% lulus.

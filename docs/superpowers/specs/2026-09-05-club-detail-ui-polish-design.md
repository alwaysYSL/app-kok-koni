# Spesifikasi Desain: Pemolesan UI Detail Klub dan Identitas Warna Klub

**Tanggal:** 2026-09-05  
**Topik:** Pemolesan halaman detail klub berdasarkan referensi Figma dan fondasi identitas visual dinamis per klub  
**Status:** Disetujui pengguna

---

## 1. Latar Belakang

Halaman `ClubDetailPage` saat ini masih tersusun dari komponen Material standar berupa `AppBar`, kartu ringkasan, `TabBar`, kolom pencarian, dan kartu anggota generik. Komposisi tersebut belum mengikuti referensi visual berikut:

- `ui-screenshot-figma/detail-klub-garuda-atlet.png`
- `ui-screenshot-figma/detail-klub-cibeunying-atlet.png`
- `ui-screenshot-figma/detail-klub-binamuda-atlet.png`

Ketiga referensi menggunakan struktur halaman yang sama, tetapi mempunyai warna hero header dan aksen tab berbeda berdasarkan identitas klub. Aplikasi direncanakan menerima logo klub dari SICABOR dan kelak dapat menghasilkan warna antarmuka dari warna dominan logo tersebut.

Pada tahap ini logo dan ekstraksi warna SICABOR belum tersedia. Implementasi pertama karena itu memakai logo/foto fallback serta warna demo per klub, sambil menyediakan kontrak data dan resolver agar integrasi logo dan warna otomatis dapat ditambahkan tanpa merombak halaman.

## 2. Tujuan

1. Memoles seluruh halaman detail klub agar mengikuti struktur dan kualitas visual referensi Figma.
2. Memoles keempat tab: Atlet, Pelatih, Official, dan Dokumen.
3. Menampilkan identitas warna yang berbeda untuk setiap klub melalui satu resolver terpusat.
4. Menyiapkan field opsional untuk logo, foto anggota, dan metadata identitas klub yang nantinya berasal dari SICABOR.
5. Menjaga makna warna status tetap konsisten dan tidak terpengaruh oleh warna klub.
6. Menjaga halaman dapat digunakan tanpa logo, foto, metadata tambahan, atau konfigurasi warna.
7. Memastikan halaman responsif pada lebar 320 px dan 390 px serta tidak mengalami overflow.

## 3. Batas Scope

### Termasuk

- Hero header klub dengan warna atau gradasi sesuai palette klub.
- Logo klub dengan fallback ikon cabor atau inisial.
- Identitas, status, kekurangan berkas, dan statistik personel klub.
- Segmented tab untuk Atlet, Pelatih, Official, dan Dokumen.
- Daftar anggota yang disesuaikan dengan perannya.
- Bottom sheet filter untuk pencarian, kelompok, dan status.
- Kartu dokumen klub yang bersifat read-only.
- Tombol share yang menyalin ringkasan klub ke clipboard pada versi demo.
- Resolver warna dengan fallback bertingkat.
- Data demo dengan beberapa variasi warna klub.
- Unit test, widget test, dan golden preview untuk variasi visual utama.

### Ditunda

- Pengunduhan dan analisis logo untuk mengekstrak warna dominan.
- Penyimpanan cache palette hasil ekstraksi.
- Integrasi native share sheet.
- Membuka atau mengunduh dokumen SICABOR.
- Unggah, edit, atau mutasi data SICABOR.

## 4. Pendekatan Arsitektur

Halaman detail klub dipindahkan dari `lib/features/detail_pages.dart` ke feature terpisah agar tanggung jawab visual, filtering, dan branding tidak menumpuk di satu file. `detail_pages.dart` tetap menampung halaman detail orang dan `MissingPage`.

Struktur target:

```text
lib/features/club_detail/
├── club_detail_page.dart
├── club_brand_palette.dart
├── club_detail_header.dart
├── club_detail_tabs.dart
├── club_people_tab.dart
├── club_document_tab.dart
└── club_person_card.dart
```

Pembagian tanggung jawab:

- `club_detail_page.dart`: mengambil data klub, menghitung ringkasan, menyusun scroll dan tab, serta menangani klub yang tidak ditemukan.
- `club_brand_palette.dart`: parsing warna, perhitungan kontras, pembuatan gradasi, dan urutan fallback palette.
- `club_detail_header.dart`: hero header, tombol navigasi/share, identitas klub, badge, dan statistik.
- `club_detail_tabs.dart`: segmented tab dan kontainer panel putih.
- `club_people_tab.dart`: state pencarian/filter untuk satu peran dan empty state.
- `club_person_card.dart`: kartu anggota reusable dengan metadata dan status sesuai peran.
- `club_document_tab.dart`: daftar informasi dokumen read-only.

Tidak ada perubahan terhadap `ThemeData` global. Warna klub hanya diterapkan di subtree halaman detail melalui `ClubBrandPalette` dan parameter eksplisit pada komponen khusus.

## 5. Model Data

Model data tidak menyimpan objek Flutter seperti `Color`. Warna tetap berupa string hex agar serializable dan tidak mengikat data layer ke framework UI.

Field opsional yang ditambahkan pada `Club`:

```text
logoUrl: String?
brandPrimaryHex: String?
brandSecondaryHex: String?
foundedYear: int?
registrationNumber: String?
```

Field opsional yang ditambahkan pada `SportPerson`:

```text
photoUrl: String?
gender: String?
age: int?
```

Semua field baru bersifat opsional agar payload SICABOR lama atau data demo yang belum lengkap tetap dapat diparsing. Informasi kosong tidak digantikan dengan data resmi buatan. UI menyembunyikan metadata opsional yang tidak tersedia, kecuali metadata klub yang perlu konteks dapat memakai label eksplisit seperti `Tahun berdiri belum tersedia`.

Dokumen klub belum dibuat menjadi kontrak repository baru pada tahap ini. Tab Dokumen menampilkan informasi read-only dari data yang sudah ada atau placeholder status `Belum tersedia`. Model dokumen formal baru ditambahkan ketika kontrak SICABOR telah diketahui.

## 6. Resolver Identitas Warna

`ClubBrandPaletteResolver` menerima `Club` dan menghasilkan nilai semantik berikut:

```text
ClubBrandPalette
├── headerStart
├── headerEnd
├── foreground
├── selectedTab
├── softAccent
└── fallbackAvatar
```

Urutan resolusi:

1. `brandPrimaryHex` dan `brandSecondaryHex` valid dari data klub.
2. Konfigurasi warna demo berdasarkan ID klub.
3. Warna tematik cabang olahraga.
4. Warna default KOK.

Jika hanya warna utama tersedia, resolver membentuk warna kedua dengan menyesuaikan luminansi tanpa mengubah hue identitas secara ekstrem. Resolver menentukan `foreground` terang atau gelap berdasarkan luminansi dan rasio kontras. Untuk warna yang terlalu terang, khususnya amber atau kuning, bagian gradasi di belakang teks digelapkan agar teks dan ikon tetap terbaca.

Nilai hex yang tidak valid tidak melempar exception ke UI dan langsung beralih ke fallback berikutnya. Warna status merah dan hijau tidak berasal dari palette klub.

Ekstraksi logo pada tahap berikutnya dapat dimasukkan sebagai sumber palette tersimpan di antara warna eksplisit dan fallback demo. Ekstraksi tidak akan dijalankan di dalam method `build` atau pada setiap pembukaan halaman.

## 7. Struktur Visual

### 7.1 Hero Header

- Memenuhi lebar halaman tanpa `AppBar` putih standar.
- Menggunakan gradasi vertikal `headerStart` ke `headerEnd`.
- Tombol kembali di kiri dan tombol share di kanan menggunakan `foreground`.
- Logo berukuran sekitar 88–104 px; fallback berupa ikon cabor atau inisial klub.
- Nama klub menjadi fokus utama, rata tengah, maksimal dua baris.
- Cabor, tahun berdiri, nomor registrasi/SK, dan kelurahan berada di bawah nama.
- Badge status aktif/pasif dan badge kekurangan berkas memakai warna semantik.
- Statistik Atlet, Pelatih, dan Official dibagi menjadi tiga kolom dengan pemisah vertikal.
- Header dapat mengecil ketika konten digulir. Dalam keadaan ringkas, nama klub tetap terlihat.

### 7.2 Panel dan Segmented Tab

- Panel konten putih sedikit menimpa bagian bawah hero.
- Sudut kiri dan kanan atas panel sekitar 24–28 px.
- Segmented tab berada di bagian atas panel dan tetap terlihat ketika daftar panjang digulir.
- Keempat tab mempunyai lebar seimbang.
- Tab aktif menggunakan `selectedTab` dengan teks putih atau `foreground` yang sudah memenuhi kontras.
- Tab tidak aktif memakai permukaan putih atau abu sangat muda dan teks abu gelap.
- Pada lebar 320 px, ukuran teks dan padding menyesuaikan agar label `Dokumen` tidak terpotong.

### 7.3 Tab Atlet

Header daftar menampilkan jumlah dan rentang kelompok atlet di kiri serta tombol `Filter` di kanan. Tombol membuka bottom sheet berisi:

- pencarian nama;
- pilihan kelompok yang dibentuk dari data aktual;
- status berkas lengkap atau belum lengkap;
- tombol reset filter.

Kartu atlet menampilkan foto atau inisial, nama, gender, usia, kelompok, dan indikator status. Metadata gender atau usia yang tidak tersedia dihilangkan tanpa meninggalkan separator kosong. Kartu dengan dokumen kurang memakai badge merah `berkas`; kartu lengkap memakai ikon centang. Seluruh kartu dapat ditekan untuk menuju halaman detail orang.

### 7.4 Tab Pelatih

Kartu pelatih menggunakan komponen orang yang sama. Metadata utamanya adalah kelompok atau lisensi. Lisensi kedaluwarsa menggunakan badge merah. Filter hanya menawarkan kelompok/lisensi dan status yang relevan dengan data pelatih.

### 7.5 Tab Official

Kartu official menampilkan foto/inisial, nama, dan jabatan atau kelompok dari field `group`. Status verifikasi tetap menggunakan indikator semantik. Filter hanya menampilkan pilihan yang tersedia pada data official.

### 7.6 Tab Dokumen

Tab Dokumen menampilkan kartu read-only untuk SK Klub dan Kepengurusan. Setiap kartu memuat nama dokumen, status tersedia/belum tersedia, serta metadata nomor atau masa berlaku hanya jika data tersebut ada. Tidak ada aksi unggah atau edit. Catatan kepemilikan data SICABOR berada di bagian paling bawah.

## 8. Interaksi dan State

- `snapshotProvider` tetap menjadi sumber data utama.
- State lokal halaman mencakup tab aktif, pencarian, dan filter per peran.
- Filter tiap tab terpisah; filter Atlet tidak memengaruhi Pelatih atau Official.
- Perpindahan tab mempertahankan state filter masing-masing selama halaman masih hidup.
- Tab yang kosong menampilkan empty state dan tombol reset jika kekosongan disebabkan filter.
- Tombol share menyalin ringkasan nama klub, cabor, dan kelurahan ke clipboard, lalu menampilkan snackbar `Info klub disalin`.
- Logo dan foto jaringan menggunakan fallback ketika URL kosong, proses memuat gagal, atau respons gambar tidak valid.

Struktur scroll menggunakan header yang dapat mengecil dan tab yang tetap terlihat:

```text
Posisi awal
[ Hero lengkap                   ]
[ Segmented tabs                ]
[ Konten tab                    ]

Setelah digulir
[ Header ringkas: nama klub     ]
[ Segmented tabs tetap terlihat]
[ Konten tab                    ]
```

## 9. Error Handling dan Aksesibilitas

- ID klub tidak ditemukan menggunakan `MissingPage`.
- Repository gagal dimuat menampilkan pesan kegagalan dan tombol coba lagi dari alur `DataView`.
- Hex invalid, logo gagal, dan foto gagal selalu mempunyai fallback visual.
- Nama klub panjang dibatasi dua baris dan tidak boleh overflow.
- Ikon interaktif mempunyai tooltip dan semantic label.
- Area tap tombol dan kartu sekurang-kurangnya mengikuti target sentuh Material.
- Kontras teks/ikon terhadap hero dan tab aktif diuji melalui fungsi resolver.
- Ukuran teks sistem yang membesar tidak boleh menyebabkan exception atau overflow pada jalur utama.

## 10. Pengujian

### Unit test

- Parsing format warna hex yang didukung dan penolakan input invalid.
- Urutan fallback resolver.
- Pemilihan foreground terang/gelap berdasarkan kontras.
- Pembentukan gradasi aman dari warna terang.
- Filter nama, kelompok, dan status untuk setiap peran.
- Perhitungan jumlah Atlet, Pelatih, Official, dan kekurangan berkas.

### Widget test

- Keempat tab dapat dibuka dan menampilkan jenis data yang tepat.
- Filter, pencarian, dan reset bekerja tanpa memengaruhi tab lain.
- Kartu anggota membuka route detail orang.
- Logo/foto fallback tampil ketika URL kosong atau gagal.
- Tombol share menyalin ringkasan dan menampilkan snackbar.
- Klub berbeda menghasilkan aksen visual berbeda.
- Lebar 320 px dan 390 px tidak menghasilkan overflow atau exception.
- Nama klub dan metadata opsional panjang tidak merusak layout.

### Golden preview

- Garuda dengan palette ungu/navy.
- Klub bulu tangkis dengan palette merah.
- Bina Muda dengan palette amber yang telah dikoreksi kontrasnya.
- Preview utama `previews/detail-klub.png` diperbarui.

### Verifikasi akhir

```text
flutter analyze
flutter test
flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true
```

Golden hasil render diperiksa secara visual pada lebar 390 px. Widget test responsif secara terpisah memverifikasi lebar 320 px.

## 11. File yang Diperkirakan Berubah Saat Implementasi

- `lib/app.dart`
- `lib/data/models.dart`
- `lib/data/models.freezed.dart`
- `lib/data/models.g.dart`
- `lib/data/repository.dart`
- `lib/features/detail_pages.dart`
- `lib/features/club_detail/club_detail_page.dart`
- `lib/features/club_detail/club_brand_palette.dart`
- `lib/features/club_detail/club_detail_header.dart`
- `lib/features/club_detail/club_detail_tabs.dart`
- `lib/features/club_detail/club_people_tab.dart`
- `lib/features/club_detail/club_document_tab.dart`
- `lib/features/club_detail/club_person_card.dart`
- test unit/widget terkait detail klub
- `test/app_test.dart`
- `test/preview_test.dart`
- golden preview detail klub

Tahap pertama tidak menambahkan dependency produksi baru.

## 12. Kriteria Selesai

1. Halaman awal detail klub secara visual mengikuti hierarki referensi Figma.
2. Garuda, klub bulu tangkis demo, dan Bina Muda menampilkan palette yang berbeda.
3. Seluruh tab dapat digunakan dan tidak hanya menjadi placeholder kosong.
4. Warna status tetap konsisten terlepas dari warna klub.
5. Halaman tetap berguna ketika semua field opsional dan URL gambar tidak tersedia.
6. Tidak ada overflow pada lebar 320 px dan 390 px.
7. Seluruh test lulus dan `flutter analyze` tidak melaporkan issue.
8. Golden preview baru telah diperiksa secara visual terhadap referensi.


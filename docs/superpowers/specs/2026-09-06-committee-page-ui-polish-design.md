# Spesifikasi Desain: Pemolesan UI Menu Anggota (Kepengurusan KOK)

Dokumen ini mendefinisikan spesifikasi desain dan arsitektur untuk memoles antarmuka **Menu Anggota (Kepengurusan KOK)** (`/committee`) pada aplikasi KOK KONI Garut agar presisi, mewah, dan konsisten dengan sistem desain aplikasi (Plus Jakarta Sans, soft shadow, custom borders, tombol sortir konsisten dengan Menu Klub, dan modal bottom sheet detail profil pengurus).

---

## 1. Latar Belakang & Ruang Lingkup
Menu "Anggota" pada bilah navigasi bawah didedikasikan untuk menampilkan informasi **Anggota Kepengurusan KOK** (Koordinator Olahraga Kecamatan Garut Kota).

Sebelumnya halaman ini menggunakan ubin `Surface` dasar dengan layout standar bawaan. Pembaruan ini bertujuan untuk:
1. Memoles tampilan visual secara menyeluruh agar memiliki sentuhan premium (bebas kesan template bawaan).
2. Menyediakan tombol sortir yang konsisten dengan Menu Klub (kotak rounded 10px ber-ikon `Icons.swap_vert` dengan modal sortir 4 opsi).
3. Menyediakan search bar modern dan filter chips divisi (Semua, Pengurus Inti, Pembinaan).
4. Menghadirkan kartu pengurus (`CommitteeMemberCard`) dengan avatar inisial berwarna tematik, tipografi navy `#0C2464`, dan badge jabatan.
5. Menyempurnakan interaksi detail pengurus menggunakan modal bottom sheet modern berkonsep "Digital ID Card Pengurus".

---

## 2. Struktur Visual & Komponen UI

### 2.1 Header AppBar & Sortir Terpusat
- **Judul AppBar Dinamis**:
  - `Anggota KOK (${filteredMembers.length})` (misal: `Anggota KOK (5)`).
  - Menggunakan tipografi tebal `FontWeight.w700`, ukuran 20–21sp, warna `#17191D`.
- **Tombol Sortir Kanan Atas**:
  - Kontainer kotak *rounded* ber-radius 10px, ukuran 40x40px, latar putih, border `Color(0xFFE5E7EB)`.
  - Ikon `Icons.swap_vert` berwarna `#17191D`.
  - Saat ditekan, memunculkan modal bottom sheet *"Urutkan Pengurus"* dengan 4 opsi:
    1. `defaultStructure` — *Struktur Jabatan (Ketua → Wakil → Sekretaris → Bendahara → Pembinaan)*
    2. `nameAsc` — *Nama (A → Z)*
    3. `nameDesc` — *Nama (Z → A)*
    4. `divisionAsc` — *Bidang / Divisi (A → Z)*
  - Menampilkan ikon centang biru `Icons.check_rounded` pada opsi yang sedang aktif.

### 2.2 Kartu Wilayah & Kepengurusan (Header Card)
- Kontainer putih melengkung *rounded 20px*, padding 16–18px, *soft elevation*:
  - **Badge Status Kapsul**: `KEPENGURUSAN KOK` (latar biru muda `#E8F0FE`, teks biru navy `#1B4F9E`, tebal, radius 8px).
  - **Judul Wilayah**: `Kecamatan Garut Kota` (tebal navy `Color(0xFF0C2464)`, font size 21–22sp).
  - **Subjudul**: `${totalMembers} pengurus · Periode 2025–2029` (warna abu-abu `#6B7280`, font size 13sp).

### 2.3 Search Bar Modern & Filter Chips Divisi
- **Search Bar**:
  - Kontainer ber-radius 14px, latar putih, border `Color(0xFFE5E7EB)`.
  - Prefix ikon pencarian `Icons.search`, placeholder *"Cari nama atau jabatan..."*.
  - Menghapus outline bawaan TextField saat fokus agar menyatu rapi.
- **Filter Chips Divisi**:
  - Baris chips horizontal yang dihasilkan secara dinamis dari daftar divisi pengurus:
    - `Semua ${totalCount}`
    - `Pengurus inti`
    - `Koordinator Pembinaan` (atau bidang terkait lainnya)
  - **Gaya Visual**:
    - **Aktif**: Latar solid biru `Color(0xFF1B4F9E)`, teks putih tebal (*w600*), radius 20px.
    - **Inaktif**: Latar putih, border `Color(0xFFE5E7EB)`, teks abu-abu `#374151`, radius 20px.

### 2.4 Kartu Pengurus (`CommitteeMemberCard`)
- Kontainer kartu melengkung *rounded 16px*, latar putih, padding 14–16px, bayangan halus `BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))`.
- **Tata Letak**:
  1. **Kiri**: Circle avatar (radius ~22px) berlatar biru muda `Color(0xFFE8F0FE)` memuat inisial huruf nama pengurus berwarna navy `Color(0xFF0C2464)` dengan bobot tebal.
  2. **Tengah (Kolom Informasi)**:
     - Nama pengurus: Tebal navy `Color(0xFF0C2464)`, ukuran 15–16sp (*w700*).
     - Jabatan: Teks biru tegas `Color(0xFF1B4F9E)`, ukuran 13sp (*w600*).
     - Bidang & Periode: Teks abu-abu `Color(0xFF6B7280)`, ukuran 12sp.
  3. **Kanan**: Ikon chevron `Icons.chevron_right` berwarna `Color(0xFF9CA3AF)`.
- **Interaksi**: Mengetuk kartu membuka modal bottom sheet profil detail pengurus.

### 2.5 Modern Bottom Sheet Detail Pengurus ("Digital ID Card")
- Menampilkan modal bottom sheet dengan sudut atas rounded 24px:
  - *Drag handle* abu-abu di bagian atas.
  - Avatar lingkaran profil besar (diameter 64px) dengan inisial tebal navy.
  - Nama lengkap pengurus (tebal navy 20sp, *w700*).
  - Badge kapsul jabatan (misal `Ketua KOK` berlatar `#E8F0FE` dengan teks `#1B4F9E`).
  - Permukaan detail (*Surface container*) memuat baris-baris terstruktur:
    - *Jabatan*: `m.position`
    - *Bidang*: `m.division`
    - *Periode*: `m.period`
    - *Wilayah Tugas*: `Kecamatan Garut Kota`
  - Catatan resmi verifikasi sistem: *"Status kepengurusan terdaftar pada SK KOK Garut Kota."*
  - Tombol aksi *"Tutup"* berwarna navy/biru untuk kemudahan pengguna.

---

## 3. Arsitektur Kode & Data

1. **Enum Opsi Sortir**:
   - Definisikan enum `CommitteeSortOption`:
     ```dart
     enum CommitteeSortOption {
       defaultStructure,
       nameAsc,
       nameDesc,
       divisionAsc,
     }
     ```
2. **Logika Filtering & Sorting**:
   - Menggabungkan query pencarian teks, filter divisi/bidang, dan pengurutan `CommitteeSortOption`.
3. **Berkas yang dimodifikasi**:
   - `lib/features/committee_page.dart`: Implementasi UI baru, `CommitteeMemberCard`, dan modal detail.
   - `test/committee_page_test.dart` (atau `test/app_test.dart`): Pengujian fungsionalitas rendering, pencarian, pengurutan, filter divisi, dan modal detail.
   - `test/preview_test.dart`: Regenerasi golden preview `previews/anggota.png`.

---

## 4. Rencana Verifikasi
- Menjalankan `flutter analyze` untuk memastikan 0 issues lint.
- Menjalankan `flutter test` untuk memverifikasi seluruh test suite lulus 100%.
- Memverifikasi tampilan golden preview `previews/anggota.png`.

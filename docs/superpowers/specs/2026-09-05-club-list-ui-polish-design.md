# Spesifikasi Desain: Pemolesan UI Menu Klub (Daftar Klub)

**Tanggal:** 2026-09-05  
**Topik:** Pemolesan UI Daftar Klub Sesuai `ui-screenshot-figma/daftar-klub.png` & Penambahan Opsi Sortir  
**Status:** Disetujui Pengguna  

---

## 1. Latar Belakang & Tujuan
1. Memoles tampilan layar Daftar Klub (`ClubsPage`) agar presisi sesuai acuan desain Figma `ui-screenshot-figma/daftar-klub.png`.
2. Menghilangkan redundansi kontrol sortir:
   - Teks `"A → Z"` di baris ringkasan dihapus, sehingga baris ringkasan bersih hanya menampilkan jumlah klub dan cabor.
   - Tombol sortir di header kanan atas dibuat berupa kotak rounded ber-border yang membuka menu modal bottom sheet / pop-up pilihan sortir lengkap.
3. Mengganti chip filter standar dengan kapsul filter modern: tombol `"Semua"` (biru solid saat default/reset) dan dropdown filter untuk `"Cabor"`, `"Status"`, dan `"Kelurahan"`.
4. Menyempurnakan kartu klub (*Club Card*) dengan avatar cabor berbentuk kotak melengkung (*rounded square* 12px) bertema warna cabor, garis pemisah putus-putus (*dashed line divider*), rekap personel klub, dan badge peringatan berkas.

---

## 2. Struktur Visual & Komponen

### A. Header / AppBar
- **Latar Belakang**: Putih bersih (`Colors.white`) dengan garis pemisah bawah tipis.
- **Judul**: `"Klub (<Jumlah>)"` — Font Plus Jakarta Sans, tebal (`FontWeight.w700`), warna `#17191D`.
- **Tombol Sortir (Kanan Atas)**:
  - Kontainer kotak rounded (`BorderRadius.circular(10)`), ukuran ~40x40px, border abu-abu lembut `#E5E7EB`.
  - Ikon: `Icons.swap_vert` berwarna navy pekat.
  - Aksi saat di-tap: Membuka modal/menu pilihan sortir dengan opsi:
    1. **Nama (A → Z)** — *Default*
    2. **Nama (Z → A)**
    3. **Jumlah Atlet Terbanyak**
    4. **Status (Aktif Terlebih Dahulu)**

### B. Search Bar & Horizontal Filter Chips
- **Search Bar**:
  - Kontainer putih ber-radius 14px dengan border halus `#E5E7EB`.
  - Prefix icon: `Icons.search_rounded` warna `#9E9E9E`.
  - Placeholder: `"Cari nama klub..."`.
  - Tombol hapus (close icon) jika kolom tidak kosong.
- **Horizontal Filter Chips**:
  - **Chip "Semua"**: Kapsul melengkung 20px. Berwarna biru solid (`#1B4F9E`) dengan teks putih saat aktif (tidak ada filter aktif). Berfungsi mereset seluruh filter saat ditekan.
  - **Chip "Cabor v"**: Kapsul putih ber-border dengan ikon panah dropdown `Icons.keyboard_arrow_down_rounded`.
  - **Chip "Status v"**: Kapsul dengan opsi `Aktif` / `Pasif`.
  - **Chip "Kel. v"**: Kapsul dengan opsi daftar kelurahan.
  - Chip yang sedang aktif memiliki aksen latar biru muda lembut (`#EAF0FB`) dan teks biru.

### C. Baris Ringkasan Data
- Menampilkan teks: `"<X> klub · <Y> cabor"` (font Plus Jakarta Sans, warna abu-abu netral `#727782`, ukuran 13pt).
- Teks `"A → Z"` di baris ini **dihapus** sesuai keputusan desain untuk mencegah redundansi.

### D. Kartu Klub (Club Card)
- **Kontainer Kartu**:
  - Permukaan putih bersih, sudut melengkung `BorderRadius.circular(18)`, margin bawah 12px, bayangan lembut (*soft elevation*).
- **Bagian Atas**:
  - **Avatar Cabor**: Kotak rounded 12px dengan warna tematik cabor (misal: biru untuk sepak bola, navy untuk bulu tangkis, merah gelap untuk silat, teal untuk renang, amber untuk voli) berisi ikon Material cabor yang relevan.
  - **Identitas Klub**:
    - Nama Klub: Tebal 15-16pt, navy gelap (`#0C2464`).
    - Subteks: `"<Cabor> · <Kelurahan>"` (abu-abu `#757575`, 12-13pt).
  - **Badge Status**:
    - Aktif: Kapsul biru muda lembut (`#E8F0FE`) dengan teks biru `#1B4F9E`, tebal 11-12pt.
    - Pasif: Kapsul abu-abu lembut (`#F1F3F5`) dengan teks abu-abu `#757575`, tebal 11-12pt.
- **Pemisah Tengah**:
  - Garis putus-putus (*dashed line*) halus berwarna `#E5E7EB` yang digambar secara kustom.
- **Bagian Bawah**:
  - **Kiri**: Ringkasan personel: `"<X> atlet · <Y> pelatih · <Z> official"` (abu-abu `#727782`, 12pt).
  - **Kanan**: Jika terdapat atlet dengan berkas kurang, ditampilkan badge merah lembut: `"<N> berkas"` (`#FFEAEA`, teks `#D32F2F`, radius 8px).

---

## 3. Integrasi & Pengujian
1. **Pembaruan Fungsi Sorting**:
   - Memperbarui fungsi `filterClubs` di `lib/data/repository.dart` untuk mendukung mode sorting baru (`SortOption`: `nameAsc`, `nameDesc`, `athletesDesc`, `statusActiveFirst`).
2. **Pengujian Unit & Widget**:
   - Memperbarui `test/repository_test.dart` dan `test/app_test.dart` untuk memvalidasi mode sortir dan interaksi tombol baru.
   - Memperbarui golden screenshot `previews/klub.png`.
   - Memastikan `flutter analyze` 0 issues dan `flutter test` 100% lulus.

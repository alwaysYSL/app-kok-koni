# Spesifikasi Desain: Pemolesan Halaman Induk Cabor (SportsPage Clean Redesign)

Tanggal: 2026-09-07  
Status: Approved  

---

## 1. Latar Belakang & Masalah

Setelah implementasi awal `SportsPage`, terdapat beberapa catatan evaluasi kritis pada antarmuka:
1. **Hero Banner Biru Berlebihan**: Menghabiskan ~150px tinggi layar vertikal hanya untuk menampilkan judul *"5 Cabang Olahraga Aktif"*.
2. **Kepadatan & Pola "Card di dalam Card"**: Kartu grafik sebaran atlet terasa sesak karena menumpuk kartu bar chart di atas kartu ringkasan abu-abu bertingkat.
3. **Ukuran Teks Terlalu Kecil**: Terdapat teks sumbu dan label di bawah 12px yang sulit dibaca di perangkat mobile.
4. **Search Bar Redundant**: Dalam skala 1 kecamatan, jumlah cabor aktif berkisar antara 3 hingga 10 cabor, sehingga search bar tidak dibutuhkan dan hanya membuang ruang layar.
5. **Garis Progress Bar Repetitif pada Direktori**: Progress bar hijau panjang yang membentang di setiap kartu cabor terasa kaku, monoton, dan memakan ruang baris ekstra.

---

## 2. Sasaran & Batasan Desain

### Sasaran (Goals)
1. **Vertical Space Efficiency**: Menghilangkan hero banner biru besar dan search bar untuk menghemat ~200px tinggi layar, sehingga kartu cabor pertama langsung terlihat di layar pertama (*above the fold*).
2. **Keterbacaan Prima ($\ge 12\text{px}$)**: Menetapkan batas minimum ukuran teks $\ge 12\text{px}$ di seluruh komponen.
3. **Grafik Sebaran Atlet Horizontal (Format A)**:
   - Batang grafik horizontal dengan nama cabor lengkap di sisi kiri (tanpa disingkat).
   - Angka atlet langsung tertera di ujung kanan batang.
   - Tanpa kartu ringkasan bertumpuk di bawahnya.
   - Menampilkan Top 5 cabor secara default, dengan tombol ekspansi jika cabor $> 5$.
4. **Direktori Cabor Bersih & Sinyal Masalah Terarah (Opsi 2)**:
   - Menghapus progress bar hijau panjang horizontal.
   - Menampilkan chip metrik ringkas: `X Klub`, `Y Atlet`, `Z Pelatih`.
   - Menampilkan badge peringatan merah `⚠ X atlet berkas kurang` hanya jika cabor tersebut memiliki kekurangan berkas. Jika lengkap, kartu dibiarkan bersih.

### Batasan (Constraints)
- Tidak ada teks dengan ukuran font di bawah 12px.
- Warna teks judul kartu wajib `KokColors.cardTitle` (`#141414`).
- Mempertahankan struktur 5 tab navigasi bawah tanpa perubahan.
- `flutter analyze` 0 issues dan `flutter test` 100% lulus.

---

## 3. Rincian Antarmuka Pengguna (UI/UX Specification)

### A. Header Ringkas (Model 1)
- Padding horizontal: 16px, vertical: 12px.
- **Sisi Kiri**:
  * Judul: `"Cabang Olahraga Aktif"` (18sp, `FontWeight.w800`, `KokColors.cardTitle`).
  * Subjudul: `"Kecamatan Garut Kota"` (13sp, `KokColors.textSecondary`).
- **Sisi Kanan**:
  * Badge kapsul berlatar `KokColors.pale`: `"$totalSports Cabor · $totalAthletes Atlet"` (12.5sp, `FontWeight.w700`, `KokColors.bluePrimary`).

### B. Kartu Grafik Sebaran Atlet Horizontal
- Kontainer kartu tunggal berlatar putih dengan border-radius 16px, border `Color(0xFFE5E7EB)`, dan padding 16px.
- **Header Kartu**:
  * Label: `"SEBARAN ATLET PER CABANG OLAHRAGA"` (12.5sp, `FontWeight.w700`, `KokColors.textSecondary`, `letterSpacing: 0.5`).
- **Daftar Batang Horizontal**:
  * Menampilkan baris cabor terurut dari jumlah atlet terbanyak ke terkecil.
  * Setiap baris:
    - Nama cabor (13.5sp, `FontWeight.w600`, `KokColors.cardTitle`, lebar tetap ~90px, teks lengkap).
    - Batang horizontal setinggi 12px dengan border-radius 6px, berwarnakan `palette.chartColor` cabor dari `SportBrandPaletteResolver`.
    - Teks angka atlet: `"$count atlet"` (13sp, `FontWeight.w700`, `KokColors.cardTitle`, lebar ~55px rata kanan).
    - Tap pada baris memicu navigasi `context.push('/sport/${Uri.encodeComponent(sport)}')`.
  * **Logika Ekspansi (Jika Cabor > 5)**:
    - Default menampilkan 5 cabor teratas.
    - Jika total cabor $> 5$, tampilkan tombol teks di bawah batang: `"Tampilkan ${allSports.length - 5} cabor lainnya ▾"`.
    - Saat diketuk, daftar membuka seluruh cabor secara mulus.

### C. Direktori Cabang Olahraga
- Label seksi: `"Direktori cabor"` (16sp, `FontWeight.w700`, `KokColors.cardTitle`).
- **Setiap Kartu Cabor**:
  * `Surface` kartu berlatar putih dengan border-radius 16px dan padding 14px.
  * Baris 1:
    - `SportAvatar(sport)` dengan ikon resmi dan soft accent cabor di kiri.
    - Kolom teks:
      * Nama Cabor (16sp, `FontWeight.w700`, `KokColors.cardTitle`).
      * Row Chip Metrik:
        - `Container` kapsul halus: `"$clubCount Klub"` (12sp, `KokColors.textSecondary`).
        - `Container` kapsul halus: `"$athleteCount Atlet"` (12sp, `KokColors.textSecondary`).
        - `Container` kapsul halus: `"$coachCount Pelatih"` (12sp, `KokColors.textSecondary`).
    - Ikon `Icons.chevron_right` (`size: 20`, `KokColors.bluePrimary`) di kanan.
  * Baris 2 (Hanya jika `missingAthletes > 0`):
    - Padding top 8px.
    - Badge peringatan berlatar merah muda (`#FEF2F2`):
      `Icons.warning_amber_rounded` (14px, `#DC2626`) + teks `"$missingAthletes atlet berkas kurang"` (12sp, `#DC2626`, `FontWeight.w600`).
  * Tap kartu: `context.push('/sport/${Uri.encodeComponent(sport)}')`.

---

## 4. Rencana Pengujian (Testing & Verification)

1. **Unit & Widget Test (`test/sports_page_test.dart`)**:
   - Verifikasi render header ringkas: teks `"Cabang Olahraga Aktif"` dan badge cabor.
   - Verifikasi tidak adanya Search Bar di halaman.
   - Verifikasi render horizontal bars dengan nama cabor lengkap dan teks $\ge 12\text{px}$.
   - Verifikasi kartu direktori cabor dengan chip metrik dan badge peringatan berkas kurang.
   - Verifikasi navigasi tap kartu cabor ke `/sport/:name`.
2. **Pengujian Integrasi (`test/app_test.dart`)**:
   - Memastikan seluruh skenario navigasi aplikasi tetap berjalan mulus 100%.
3. **Golden Preview**:
   - Memperbarui screenshot `previews/cabor.png`.
4. **Analisis Statis**:
   - `flutter analyze` dengan 0 issues.
   - `flutter test` dengan 100% lulus.

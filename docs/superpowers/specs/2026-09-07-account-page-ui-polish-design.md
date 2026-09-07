# Spesifikasi Desain: Pemolesan UI Halaman Akun / Profil Koordinator KOK

- **Tanggal**: 2026-09-07
- **Fokus**: Pemolesan komprehensif Halaman Akun (`/profile`) menjadi pusat profil dan utilitas operasional Koordinator KOK Kecamatan Garut Kota, mengadopsi bahasa desain modern konsisten, aksen garis lengkung lingkaran minimalis pada kartu profil, seksi sinkronisasi data SICABOR, seksi utilitas koordinator (ekspor rekap data & kontak helpdesk KONI), serta custom dialog konfirmasi keluar (*anti-template*).

---

## 1. Arsitektur Halaman & Alur Navigasi

- **Lokasi Berkas**: `lib/features/profile_page.dart`
- **Rute**: `/profile` (diakses via tab `Akun` / `Profil` pada navigation bar bawah atau navigasi langsung).
- **Komponen Data**:
  - `ref.watch(snapshotProvider)`: Mengakses data statistik dan entri data kecamatan (cabor, klub, atlet, pelatih, official, loadedAt).
  - `ref.read(sessionProvider.notifier)`: Menangani `signOut()`.
  - `ref.read(preferencesProvider)`: Menangani preferensi lokal (misal: `remembered_sk`).

---

## 2. Rincian Antarmuka Pengguna & Komponen Visual

### 2.1 AppBar
- Judul: `Akun` (tebal navy `#0C2464`, 20sp, font KokSans).
- CenterTitle: `false` atau diselaraskan dengan standar halaman lain (`Anggota`, `Klub`).
- Latar: Putih bersih `#FFFFFF` dengan elevasi 0 dan border bawah sangat halus `#F1F5F9`.

### 2.2 Kartu Profil Koordinator (Executive Minimalist Card)
- **Kontainer**:
  - Gradasi Royal Navy: `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF07237B), Color(0xFF03144B)])`.
  - Border radius: `24px`.
  - Padding: `EdgeInsets.all(20)`.
  - Drop shadow: `BoxShadow(color: Color(0xFF07237B).withValues(alpha: 0.20), blurRadius: 16, offset: Offset(0, 6))`.
- **Aksen Dekoratif Garis Lingkaran Minimalis**:
  - Digambar menggunakan CustomPainter khusus `AccountProfileCardPainter`:
    - Menggambar 2 busur kurva lingkaran konsentris putih tipis (`Colors.white.withValues(alpha: 0.08)` dan `0.05`), tanpa dot matrix agar kartu profil tetap bersih, elegan, dan berwibawa.
- **Elemen Profil**:
  - **Avatar**: Lingkaran inisial `PA` (radius 28px, latar biru `#1E3A8A`, border putih tipis 1.5px dengan opacity 0.4, teks putih tebal 20sp).
  - **Nama**: `Pak Asep` (putih, 22sp, `FontWeight.w800`).
  - **Jabatan & Wilayah**: `Koordinator · Kec. Garut Kota` (putih ber-opacity 0.75, 12sp, `FontWeight.w500`).
  - **Badge Status**: Kapsul kecil berlatar hitam/emas semi-transparan dengan border emas `#F59E0B` halus, memuat teks `AKSES READ-ONLY` (emas `#FBBF24`, 10sp, `FontWeight.w700`, `letterSpacing: 0.6`).

---

### 2.3 Seksi 1: SINKRONISASI DATA SICABOR
- **Header Seksi**: `SINKRONISASI DATA SICABOR` (abu-abu `#6B7280`, 12sp, tebal, uppercase).
- **Kartu Status**:
  - Kontainer putih rounded 16px, border `#E5E7EB`, soft shadow.
  - Baris Status:
    - Dot indikator hijau aktif (radius 4px).
    - Teks: `Terakhir sinkron: ${jam}:${menit} · ${totalEntri} entri data` (tebal navy `#0C2464`, 14sp).
    - Tombol Refresh: `IconButton` bulat berlatar biru lembut `#E8F0FE` dengan ikon `Icons.sync_rounded` biru `#1B4F9E`, memicu penyegaran snapshot repository (`ref.invalidate(snapshotProvider)`) dengan umpan balik snackbar halus *"Data berhasil disinkronkan ulang"*.
  - Pemisah halus: `DashedDivider` abu-abu.
  - Subteks / Info Sinkronisasi:
    - `Status koneksi: Data lokal tersinkronisasi dengan SICABOR Kabupaten Garut.` (12sp, abu-abu `#6B7280`).

---

### 2.4 Seksi 2: UTILITAS KOORDINATOR
- **Header Seksi**: `UTILITAS KOORDINATOR` (abu-abu `#6B7280`, 12sp, tebal, uppercase).
- **Item 1: Ekspor Rekap Data Kecamatan**:
  - Ikon: Lembar dokumen spreadsheet (`Icons.summarize_outlined` atau `Icons.description_outlined`) di dalam avatar lingkaran biru `#E8F0FE` dengan ikon `#1B4F9E`.
  - Judul: `Rekap Data Kecamatan` (tebal navy `#0C2464`, 15sp).
  - Subtitle: `Ringkasan cabor, klub, dan atlet untuk laporan` (abu-abu `#6B7280`, 12sp).
  - Trailing: `Icon(Icons.chevron_right, color: Color(0xFF9CA3AF))`.
  - **Aksi Tap**: Membuka modal bottom sheet modern (*"Rekapitulasi Data KOK Garut Kota"*):
    - Kartu ringkasan angka: Total Cabor, Total Klub, Total Atlet, Total Pelatih, Total Berkas Kurang.
    - Tombol *"Salin Teks Rekapitulasi"* (menyalin teks terformat ke clipboard untuk dibagikan via WhatsApp/pesan).
- **Item 2: Kontak Helpdesk KONI Kabupaten**:
  - Ikon: Chat / Bantuan (`Icons.support_agent_rounded` atau `Icons.headset_mic_outlined`) di dalam avatar lingkaran hijau muda `#D1FAE5` dengan ikon `#059669`.
  - Judul: `Helpdesk KONI Kabupaten` (tebal navy `#0C2464`, 15sp).
  - Subtitle: `Kontak koordinasi data dan administrasi KOK` (abu-abu `#6B7280`, 12sp).
  - Trailing: `Icon(Icons.chevron_right, color: Color(0xFF9CA3AF))`.
  - **Aksi Tap**: Membuka modal bottom sheet rincian kontak sekretariat KONI Kabupaten Garut (nomor WhatsApp, telepon, email resmi, dan alamat sekretariat).

---

### 2.5 Seksi 3: PENGATURAN & APLIKASI
- **Header Seksi**: `PENGATURAN & APLIKASI` (abu-abu `#6B7280`, 12sp, tebal, uppercase).
- **Item 1: Pengaturan Aplikasi**:
  - Ikon: Gear (`Icons.settings_outlined`) dalam lingkaran ungu muda `#EDE9FE` dengan ikon `#6D28D9`.
  - Judul: `Pengaturan Aplikasi` (tebal navy `#0C2464`, 15sp).
  - Subtitle: `Preferensi sesi & memori nomor SK` (abu-abu `#6B7280`, 12sp).
  - **Aksi Tap**: Membuka modal bottom sheet pengaturan preferensi lokal (menampilkan status nomor SK tersimpan dan tombol *"Hapus Nomor SK Tersimpan"*).
- **Item 2: Tentang Aplikasi**:
  - Ikon: Info (`Icons.info_outline_rounded`) dalam lingkaran oranye muda `#FFEDD5` dengan ikon `#EA580C`.
  - Judul: `Tentang Aplikasi` (tebal navy `#0C2464`, 15sp).
  - Subtitle: `KOK Garut · Versi 0.1.0 (Prototipe)` (abu-abu `#6B7280`, 12sp).
  - **Aksi Tap**: Membuka modal bottom sheet informasi aplikasi: logo KOK, versi, informasi legalitas kerja sama KONI Garut & Dispora, serta deskripsi hak cipta data.

---

### 2.6 Tombol Keluar (Logout) & Custom Confirmation Dialog
- **Tombol di Halaman**:
  - Tombol outline merah ber-radius 16px: `OutlinedButton.icon(icon: Icon(Icons.logout_rounded, color: Color(0xFFDC2626)), label: Text('Keluar dari Akun', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)))`.
  - Border: `Color(0xFFFCA5A5)`.
  - Latar: `Color(0xFFFEF2F2)` (merah sangat muda).
- **Custom Floating Modal Confirmation Dialog**:
  - Tidak menggunakan `AlertDialog` bawaan Flutter.
  - Ditampilkan via `showGeneralDialog` atau `showDialog` dengan `Dialog` ber-radius `24px` dan padding `24px`.
  - **Ikon Bulat Merah (Atas)**: Kontainer lingkaran diameter 60px berlatar `#FEE2E2` dengan ikon `Icons.logout_rounded` berukuran 28px warna `#DC2626`.
  - **Judul**: `Keluar dari Akun?` (tebal navy `#0C2464`, 19sp, rata tengah).
  - **Deskripsi**: `Sesi Anda akan berakhir. Anda perlu memasukkan kembali nomor SK KOK untuk masuk ke aplikasi.` (abu-abu `#4B5563`, 13sp, rata tengah, height 1.4).
  - **Aksi Tombol Berdampingan**:
    - Tombol `Batal`: Tombol abu-abu muda (`#F3F4F6`), teks `#374151` tebal 14sp, rounded 14px, tinggi 48px, expanded.
    - Tombol `Ya, Keluar`: Tombol merah solid (`#DC2626`), teks putih tebal 14sp, rounded 14px, tinggi 48px, expanded. Menjalankan `ref.read(sessionProvider.notifier).signOut()`.

---

### 2.7 Footer Note
- Teks penjelas di bawah:
  `Data keanggotaan dikelola SICABOR — hubungi admin kabupaten untuk perubahan data akun.` (rata tengah, abu-abu `#9CA3AF`, 11sp, height 1.4).

---

## 3. Kriteria Keberhasilan & Pengujian

1. **Kelengkapan Fitur & Interaksi**:
   - Kartu profil menampilkan identitas Pak Asep dengan background lengkung lingkaran konsentris minimalis.
   - Seksi Sinkronisasi menampilkan waktu sinkronisasi nyata dari snapshot repository dan tombol refresh berfungsi.
   - Seksi Utilitas Koordinator membuka modal Rekapitulasi Data Kecamatan dan Kontak Helpdesk KONI.
   - Seksi Pengaturan & Tentang Aplikasi membuka modal dialog masing-masing dengan interaksi lengkap.
   - Tombol Keluar memicu Custom Dialog konfirmasi non-template.
2. **Kualitas Kode**:
   - `flutter analyze`: 0 issues / linter errors.
   - `flutter test`: 100% tests pass (termasuk unit & widget tests baru di `test/profile_page_test.dart` dan regresi `test/app_test.dart`).
   - Golden screenshot `previews/profil.png` terbarui secara akurat.

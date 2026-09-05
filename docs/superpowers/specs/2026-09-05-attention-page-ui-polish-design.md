# Spesifikasi Desain: Pemolesan UI Halaman Perlu Perhatian

Dokumen ini mendefinisikan spesifikasi desain dan arsitektur untuk memoles antarmuka **Halaman Perlu Perhatian** (`/attention`) pada aplikasi KOK KONI Garut agar presisi dan selaras dengan acuan desain Figma di `ui-screenshot-figma/perlu-perhatian.png`.

---

## 1. Latar Belakang & Tujuan
Halaman "Perlu Perhatian" menyajikan daftar atlet dan pelatih yang memiliki catatan khusus terkait integritas data (dokumen belum lengkap seperti KK, Akta Kelahiran, Surat Sehat, atau lisensi pelatih kedaluwarsa).

Halaman sebelumnya berada di dalam `lib/features/detail_pages.dart` dengan tampilan chip standar dan ubin sederhana. Pembaruan ini bertujuan untuk:
1. Mengekstrak implementasi menjadi fitur independen di `lib/features/attention_page.dart`.
2. Menghadirkan antarmuka modern yang presisi mengikuti Figma `ui-screenshot-figma/perlu-perhatian.png`.
3. Menampilkan indikator counter dinamis pada header dan filter chips.
4. Menggunakan kartu khusus ber-`DashedDivider` dengan highlight merah untuk deskripsi masalah dan ikon peringatan.

---

## 2. Struktur Visual & Komponen UI

### 2.1 Header / AppBar
- **Tombol Kembali**:
  - Menggunakan panah kiri standar navigasi GoRouter / Pop.
- **Judul Dinamis**:
  - `Perlu Perhatian (${filteredPeople.length})`
  - Contoh: `Perlu Perhatian (13)` pada tab "Semua", `Perlu Perhatian (8)` pada tab "Berkas Atlet", dan `Perlu Perhatian (5)` pada tab "Lisensi".
- **Aksi Kanan (Tombol Info)**:
  - Kotak *rounded* ber-radius 10px, padding 8px, border tipis `#E5E7EB`.
  - Memuat ikon `Icons.info_outline` (warna navy `#0C2464` atau `#374151`).
  - Saat ditekan, menampilkan modal bottom sheet / dialog *"Informasi Kualitas Data"* yang menjelaskan kriteria berkas atlet dan lisensi pelatih yang memerlukan koordinasi dengan klub.

### 2.2 Filter Chips Bar
- Terletak tepat di bawah AppBar dengan tata letak horizontal (*scrollable* atau *wrap*):
  1. **Semua ${totalCount}** (default: `Semua 13`)
  2. **Berkas Atlet ${docCount}** (default: `Berkas Atlet 8`)
  3. **Lisensi ${licenseCount}** (default: `Lisensi 5`)
- **Gaya Visual**:
  - **Aktif**: Bentuk kapsul *rounded* 20px, latar solid biru `Color(0xFF1B4F9E)`, teks putih dengan bobot tebal (*w600*).
  - **Inaktif**: Bentuk kapsul *rounded* 20px, latar putih, border `Color(0xFFE5E7EB)`, teks abu-abu gelap `Color(0xFF374151)`.
- **Integrasi Query Parameter**:
  - Menerima `type` dari URL / query parameters:
    - `'documents'` $\rightarrow$ otomatis memilih filter "Berkas Atlet".
    - `'license'` $\rightarrow$ otomatis memilih filter "Lisensi".
    - `null` atau `'all'` $\rightarrow$ memilih filter "Semua".

### 2.3 Subheader
- Teks deskripsi pembuka di atas daftar kartu:
  - Copywriting: *"Temuan kualitas data untuk koordinasi"*
  - Gaya: Warna `Color(0xFF6B7280)`, ukuran 13sp, bobot reguler (*w400*).

### 2.4 Kartu Perlu Perhatian (`AttentionCard`)
- Kontainer putih (`Color(0xFFFFFFFF)`), *border radius* 16px, padding vertikal 14px, padding horizontal 16px.
- Bayangan lembut (*soft drop shadow*): `BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))`.
- **Struktur Kartu**:
  1. **Baris Atas (Informasi Personil)**:
     - **Avatar**: Lingkaran profil berdiameter 40px (menampilkan inisial nomor urut / foto personil dengan latar lembut).
     - **Kolom Teks**:
       - Nama personil (bold navy `Color(0xFF0C2464)`, font size 15sp, *w700*).
       - Subjudul: `${club.name} · ${club.sport} ${person.group}` (warna `Color(0xFF6B7280)`, font size 12sp).
     - **Ikon Chevron Kanan**: `Icons.chevron_right` warna abu-abu lembut `Color(0xFF9CA3AF)`.
     - *Interaktivitas*: Mengetuk kartu menavigasikan pengguna ke halaman detail personil (`/person/${person.id}`).
  2. **Pemisah**:
     - `DashedDivider(color: Color(0xFFE5E7EB), dashWidth: 5, dashSpace: 3, strokeWidth: 1)` dengan padding vertikal 10–12px.
  3. **Baris Bawah (Detail Peringatan Masalah)**:
     - **Sisi Kiri (Teks Isu)**:
       - Teks merah `Color(0xFFDC2626)` (*w500*, font size 13sp).
       - Untuk atlet dengan berkas kurang: `"${person.missingDocuments.join(' & ')} kurang"`.
       - Untuk pelatih dengan lisensi kedaluwarsa: `"Lisensi kedaluwarsa"`.
     - **Sisi Kanan (Ikon Peringatan)**:
       - Ikon lingkaran tanda seru `Icons.error_outline` berwarna merah `Color(0xFFDC2626)` ukuran 18–20sp.

### 2.5 Catatan Kaki (Footer)
- Terletak di bagian bawah daftar kartu:
  - Copywriting: *"Tindak lanjuti temuan di atas dengan menghubungi ketua pengurus klub bersangkutan."*
  - Gaya: Warna abu-abu `Color(0xFF6B7280)`, ukuran 12sp, teks rata tengah (*center-aligned*).

---

## 3. Arsitektur Perubahan Kode

1. **[Berkas Baru] `lib/features/attention_page.dart`**:
   - `class AttentionPage extends StatefulWidget`
   - `class AttentionCard extends StatelessWidget`
   - Logika ekstraksi metadata klub (`findClub(p.clubId)`) untuk memformat subjudul nama klub dan cabor.
2. **[Perubahan] `lib/app.dart`**:
   - Impor `AttentionPage` dari `package:kok_app/features/attention_page.dart`.
3. **[Pembersihan] `lib/features/detail_pages.dart`**:
   - Menghapus definisi `AttentionPage` lama sehingga berkas ini hanya menangani `ClubDetailPage` dan `PersonDetailPage`.
4. **[Pengujian & Preview]**:
   - `test/app_test.dart`: Memperbarui dan menambahkan tes filter `AttentionPage`, counter, dan navigasi detail.
   - `test/preview_test.dart`: Menambahkan entri `'perlu-perhatian': '/attention'` untuk golden visual capture.

---

## 4. Rencana Verifikasi
- Menjalankan `flutter analyze` untuk memastikan tidak ada issue lint (0 warning/error).
- Menjalankan `flutter test` untuk memverifikasi 100% lulus pada seluruh test suite.
- Menjalankan regenerasi golden screenshot untuk `previews/perlu-perhatian.png` dan memverifikasi kesesuaian visual dengan Figma.

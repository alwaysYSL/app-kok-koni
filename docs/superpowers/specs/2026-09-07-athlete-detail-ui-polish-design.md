# Spesifikasi Desain: Pemolesan UI Detail Atlet (Warna Dinamis Klub & Layout v2)

Dokumen ini mendefinisikan spesifikasi desain dan arsitektur untuk memoles antarmuka **Detail Atlet / Personil** (`/person/:id`) pada aplikasi KOK KONI Garut agar presisi mengikuti acuan desain Figma `ui-screenshot-figma/detail-atlet-binamuda-v2.png` serta mengintegrasikan sistem **warna dinamis klub** (`ClubBrandPaletteResolver`).

---

## 1. Latar Belakang & Ruang Lingkup
Sebelumnya halaman detail atlet berada di `lib/features/detail_pages.dart` dengan tata letak dasar. Pada pembaruan ini:
1. Halaman detail personil diekstrak ke modul terisolasi di `lib/features/athlete_detail/athlete_detail_page.dart`.
2. Menerapkan sistem warna dinamis setiap klub menggunakan `ClubBrandPaletteResolver.resolve(club)`:
   - Header gradient (`headerStart` $\rightarrow$ `headerEnd`)
   - Tombol aksi utama & progress bar kelengkapan dokumen
   - Background avatar fallback & aksen ikon
3. Mempertahankan independensi warna status (hijau untuk lengkap/terverifikasi, merah untuk masalah berkas/lisensi).
4. Menghadirkan struktur visual baru (Layout v2):
   - Header melengkung dengan tombol kembali dan tombol bagikan.
   - Kartu profil melayang menimpa header (*overlapping card*) dengan avatar lingkaran ber-border putih tebal.
   - Grid detail personil ber-ikon dan pemisah vertikal halus (*vertical divider*).
   - Seksi "KELENGKAPAN BERKAS" dengan progress bar dinamis dan badge kapsul `✓ ada` / `belum`.
   - Seksi "RIWAYAT" rekam jejak atlet.
   - Tombol mengambang di bawah (*sticky bottom button*): *"Hubungi pengurus klub"*.

---

## 2. Arsitektur Warna & Data Flow

```text
Route (/person/:id)
   │
   ├──> Ambil SportPerson (id == :id)
   │      │
   │      └──> Ambil clubId ──> Ambil Club (id == clubId)
   │                              │
   │                              └──> ClubBrandPaletteResolver.resolve(club)
   │                                      │
   │                                      └──> ClubBrandPalette:
   │                                            - headerStart, headerEnd
   │                                            - foreground (kontras aman)
   │                                            - selectedTab / primaryAccent
   │                                            - softAccent
   │                                            - fallbackAvatar
```

### Aturan Warna Semantik:
- **Identitas Klub**:
  - Latar header gradasi (`headerStart` $\rightarrow$ `headerEnd`).
  - Latar tombol "Hubungi pengurus klub" (`headerStart` atau warna kontras yang aman).
  - Indikator aktif progress bar kelengkapan berkas.
  - Aksen lembut lingkaran ikon detail (`softAccent`).
  - Latar avatar inisial fallback (`fallbackAvatar`).
- **Status Verifikasi (Independen)**:
  - `terverifikasi` $\rightarrow$ Latar hijau lembut (`Color(0xFFD1FAE5)`), teks hijau (`Color(0xFF059669)`).
  - `berkas kurang` / `lisensi kedaluwarsa` $\rightarrow$ Latar merah lembut (`Color(0xFFFEE2E2)`), teks merah (`Color(0xFFDC2626)`).

---

## 3. Struktur Visual & Komponen UI

### 3.1 Header & AppBar
- **Latar Belakang**: Gradasi linier vertikal/diagonal dari `palette.headerStart` ke `palette.headerEnd` dengan tinggi ~180–200px.
- **Tombol Kembali**: Ikon `<` chevron/arrow berwarna `palette.foreground`.
- **Judul**: `Detail Atlet` (atau `Detail ${person.role}`) berwarna `palette.foreground` (*FontWeight.w700*, 18–20sp).
- **Aksi Kanan**: Tombol `Icons.share_outlined` berwarna `palette.foreground`.

### 3.2 Kartu Profil Melayang (Overlapping Profile Card)
- Kontainer putih (`Colors.white`), `BorderRadius.circular(24)`, padding 20px, margin horizontal 16px.
- Mengapung menimpa perbatasan header biru/warna klub (*negative translation* / padding).
- **Avatar Lingkaran Mengapung**:
  - Diameter 84–90px, ditempatkan di tengah atas kartu, menonjol keluar kartu dengan *border* putih tebal (3–4px) dan bayangan halus.
  - Menampilkan foto atlet jika ada (`person.photoUrl`), atau inisial nama dengan latar `palette.fallbackAvatar`.
- **Identitas**:
  - Nama atlet di tengah: Tebal navy `Color(0xFF0C2464)`, font size 20sp, *w700*.
  - Subteks ID: `ID SICABOR · ATL-${person.id}` atau `ID DEMO · ${person.id}` (abu-abu `#6B7280`, 12sp).
- **Badge Status**:
  - Kapsul *rounded* 12px di bawah ID.
- **Pemisah**:
  - `DashedDivider(color: Color(0xFFE5E7EB))` dengan padding vertikal 14px.
- **Grid Rincian Informasi**:
  - Baris informasi terstruktur:
    1. **Klub**: `club.name`
    2. **Cabor**: `club.sport`
    3. **Kelompok**: `${person.group}`
    4. **Lahir / Usia**: `${person.age != null ? '${person.age} tahun' : '16 tahun'}`
    5. **Alamat**: `${club.village}, Kec. Garut Kota`
    6. **Pelatih**: Nama pelatih klub terkait (dicari dari `people.where(role == 'Pelatih')`).
  - Setiap baris memiliki:
    - Lingkaran ikon kecil (28px) berlatar `palette.softAccent` dengan ikon tematik.
    - Label field (abu-abu `#6B7280`, 13sp).
    - Garis vertikal halus pemisah (`Container(width: 1, height: 14, color: Color(0xFFE5E7EB))`).
    - Nilai field (tebal navy `#0C2464` / `#1F2937`, 13.5sp).

### 3.3 Seksi "KELENGKAPAN BERKAS"
- Judul Seksi: `KELENGKAPAN BERKAS` (uppercase, bold navy `Color(0xFF0C2464)`, 12sp).
- Kartu putih `BorderRadius.circular(16)`, padding 16px.
- **Header Rekap**:
  - Teks `Kelengkapan dokumen` dan di sisi kanan `${completeCount} dari ${totalDocs}` (bold navy).
- **Progress Bar**:
  - Baris progres dengan tinggi 6px, radius 3px, latar belakang abu-abu `#E5E7EB`, dan isi progres berwarna `palette.headerStart` (atau `palette.selectedTab`).
- **Daftar Dokumen**:
  - 4 item dokumen wajib: *KTP / KIA*, *Kartu Keluarga*, *Akta kelahiran*, *Surat sehat*.
  - Status `✓ ada`: Kapsul biru/hijau muda berteks `✓ ada`.
  - Status `belum`: Kapsul oranye/merah muda berteks `belum`.
- Jika personil adalah **Pelatih**:
  - Menampilkan baris status lisensi kepelatihan (misal: *Lisensi C - Aktif / Kedaluwarsa*).

### 3.4 Seksi "RIWAYAT" (Rekam Jejak Atlet)
- Judul Seksi: `RIWAYAT` (uppercase, bold navy `Color(0xFF0C2464)`, 12sp).
- Kartu putih `BorderRadius.circular(16)`, padding 16px.
- Daftar riwayat berformat timeline:
  - Titik bullet lingkaran berwarna `palette.headerStart` dengan ring luar lembut.
  - Tahun (misal `2026`, `2025`, `2024`).
  - Deskripsi capaian / kegiatan (misal: *Porkab Garut U-16*, *Kejuaraan Antar Klub*, *Masuk Klub ${club.name}*).

### 3.5 Sticky Bottom Action Bar
- Tombol mengambang di bagian bawah layar:
  - `FilledButton.icon` dengan teks `"Hubungi pengurus klub"` dan ikon chat/telepon `Icons.chat_bubble_outline`.
  - Warna tombol: `palette.headerStart` (dengan koreksi kontras otomatis terhadap teks putih).
  - Aksi: Membuka modal kontak pengurus klub terkait (nama sekretariat, nomor kontak simulasi, tombol kirim pesan).

---

## 4. Arsitektur Berkas & Pemisahan Modul

1. **[Berkas Baru] `lib/features/athlete_detail/athlete_detail_page.dart`**:
   - `class AthleteDetailPage extends StatelessWidget` (alias `PersonDetailPage`).
   - Komponen sub-widget:
     - `_AthleteHeader`
     - `_AthleteProfileCard`
     - `_DocumentChecklistCard`
     - `_AthleteMilestoneCard`
     - `_ClubContactModal`
2. **[Perubahan] `lib/app.dart`**:
   - Mengarahkan rute `/person/:id` untuk menggunakan `AthleteDetailPage` dari `package:kok_app/features/athlete_detail/athlete_detail_page.dart`.
3. **[Pembersihan] `lib/features/detail_pages.dart`**:
   - Menghapus class `PersonDetailPage` lama dan menyisakan `MissingPage` (atau ekspor ulang untuk backward compatibility).
4. **[Pengujian & Preview]**:
   - `test/athlete_detail_test.dart`: Pengujian komprehensif pewarnaan dinamis, render dokumen, profil atlet, dan aksi tombol kontak.
   - `test/preview_test.dart`: Memperbarui dan menambahkan preview visual atlet dengan berbagai warna klub (misal Voli Bina Muda dan Garuda Muda).

---

## 5. Rencana Verifikasi
- Menjalankan `flutter analyze` memastikan 0 issues.
- Menjalankan `flutter test` memastikan seluruh test suite 100% lulus.
- Memverifikasi golden capture detail atlet.

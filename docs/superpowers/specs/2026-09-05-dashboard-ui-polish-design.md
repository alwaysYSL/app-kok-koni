# Spesifikasi Desain: Pemolesan UI Dashboard (Beranda) & Migrasi Font Plus Jakarta Sans

**Tanggal:** 2026-09-05  
**Topik:** Pemolesan UI Beranda Berdasarkan `ui-screenshot-figma/beranda-varian-2-belum-sinkron.png` & Penerapan Font Plus Jakarta Sans  
**Status:** Disetujui Pengguna  

---

## 1. Latar Belakang & Tujuan
1. Mengganti font global aplikasi dari Roboto (`KokSans`) ke **Plus Jakarta Sans** untuk memberikan kesan modern, rapi, dan sesuai dengan desain antarmuka kontemporer.
2. Memoles tampilan Beranda (Dashboard) agar presisi mengikuti acuan desain Figma `ui-screenshot-figma/beranda-varian-2-belum-sinkron.png`.
3. Menghadirkan **Header Biru** bernuansa gradasi dengan aksen kurva dekoratif dan dot matrix (selaras dengan layar login) serta kartu avatar koordinator.
4. Menghadirkan **Floating Card Statistik** yang melayang (*overlapping*) menimpa bagian bawah header, lengkap dengan indikator sinkronisasi, tombol muat ulang, angka statistik atlet berdampingan dengan badge persentase verifikasi, siluet pelari/atlet (bukan maskot), pemisah halus, dan 3 kolom metrik pelatih/klub/official.
5. Menyempurnakan seksi **"Perlu Perhatian"** dan **"Klub di kecamatan"** dengan tautan `"lihat semua >"`, badge merah bernomor, serta kartu klub yang elegan.

---

## 2. Struktur Visual & Komponen

### A. Font Global: Plus Jakarta Sans
- Berkas font: `assets/fonts/PlusJakartaSans.ttf` (didukung weight 400 Regular hingga 700+ Bold).
- Dikonfigurasikan pada `pubspec.yaml` sebagai font family utama `KokSans` atau `PlusJakartaSans`.
- Diterapkan pada `lib/core/theme.dart` sebagai `fontFamily` global aplikasi.

### B. Header Biru & Identitas Wilayah
- **Latar Belakang**:
  - Gradasi biru tua royal (`#07237B`) ke navy pekat (`#03144B`) dengan aksen garis kurva lengkung emas/cyan dan dot matrix.
- **Elemen Identitas**:
  - Logo KONI Garut di dalam lingkaran putih (*circular badge*).
  - Teks:
    - `"KOORDINATOR ORGANISASI KECAMATAN"` (kecil, uppercase, putih transparan).
    - `"Kec. Garut Kota"` (font Plus Jakarta Sans, tebal 18-20pt, putih).
    - `"Pak Asep · Koordinator"` (putih lembut 70%, 12-13pt).
  - Kanan: Avatar inisial `"PA"` dalam lingkaran navy berborder tipis.

### C. Floating Card Statistik (Melayang Menimpa Header)
- **Container**:
  - Melayang sebagian (*negative top margin* / *stack overlap*) menimpa bagian bawah header biru.
  - Latar belakang putih bersih, `BorderRadius.circular(24)`, bayangan lembut (*box shadow* `Offset(0, 10)`, blur 25, opacity 0.06).
  - Padding dalam: 20px.
- **Baris Atas**:
  - Titik indikator abu-abu/hijau + teks: `"Terakhir Tersinkron SICABOR · <Jam:Menit>"`.
  - Tombol refresh sirkular/rounded di kanan atas dengan aksi memuat ulang data.
- **Highlight Utama (Atlet)**:
  - Angka tebal besar (misal `125`), ukuran 36-38pt, navy gelap (`#0C2464`).
  - Label berdampingan: `"ATLET"` (uppercase, tebal, 13-14pt, `#0C2464`).
  - Badge kapsul di bawahnya: `"117 terverifikasi 94%"` (latar biru pastel muda `#E8F0FE`, teks biru `#1B4F9E`, radius 12px).
  - Sisi kanan: **Grafis Siluet Atlet/Pelari** (stylized runners silhouette graphic dengan warna biru/navy elegan, bukan maskot).
- **Garis Pemisah**:
  - Divider horizontal 1px abu-abu halus (`#F0F2F5`).
- **3 Kolom Statistik Bawah**:
  - **PELATIH**: Angka tebal (22-24pt), label uppercase `"PELATIH"` (11pt), keterangan `"10 berlisensi"` (11pt abu-abu).
  - **KLUB**: Angka tebal (22-24pt), label uppercase `"KLUB"` (11pt), keterangan `"4 aktif · 1 pasif"` (11pt abu-abu).
  - **OFFICIAL**: Angka tebal (22-24pt), label uppercase `"OFFICIAL"` (11pt), keterangan `"5 cabor"` (11pt abu-abu).

### D. Seksi "Perlu Perhatian"
- Judul seksi: `"Perlu Perhatian"` dengan link `"lihat semua >"` di kanan yang mengarahkan ke halaman perhatian (`/attention`).
- Card 1: Badge lingkaran merah `(8)` + judul `"Atlet berkas kurang"` + subteks klub & cabor terkait + ikon panah chevron.
- Card 2: Badge lingkaran merah `(5)` + judul `"Lisensi pelatih kedaluwarsa"` + subteks klub & cabor terkait + ikon panah chevron.

### E. Seksi "Klub di kecamatan"
- Judul seksi: `"Klub di kecamatan"` dengan link `"lihat semua >"` di kanan yang mengarahkan ke tab/halaman klub (`/clubs`).
- Kartu klub: Ikon cabor dalam kotak rounded 12px, nama klub tebal, detail cabor dan jumlah atlet, serta chevron panah.

---

## 3. Integrasi & Pengujian
1. **Pembaruan Aset & Tema**:
   - Daftarkan `PlusJakartaSans.ttf` di `pubspec.yaml`.
   - Update `lib/core/theme.dart` agar menggunakan Plus Jakarta Sans secara konsisten.
2. **Kesesuaian Widget Test & Responsivitas**:
   - Pastikan layout tetap responsif tanpa *render overflow* pada viewport sempit (320px) maupun tablet/desktop.
   - Pastikan seluruh test suite `test/app_test.dart` dan `test/preview_test.dart` berjalan sukses 100%.

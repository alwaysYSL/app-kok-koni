# Spesifikasi Desain: Pembenahan Jarak Hero Detail Klub & Aksen Dekoratif Background Header

- **Tanggal**: 2026-09-07
- **Fokus**:
  1. Merapikan jarak vertikal antara 3 angka statistik di hero Detail Klub ke kartu putih di bawahnya agar presisi sesuai acuan Figma (~24px).
  2. Menambahkan ornamen dekoratif background header (garis lingkaran konsentris dan matriks titik putih / dot matrix) pada Header Detail Klub dan Header Detail Atlet sesuai gaya visual Beranda dan Figma.

---

## 1. Latar Belakang & Analisis Masalah

### 1.1 Evaluasi Jarak Hero Detail Klub
- Pada implementasi sebelumnya di [`lib/features/club_detail/club_detail_page.dart`](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/features/club_detail/club_detail_page.dart):
  - `SliverAppBar` menggunakan `expandedHeight: 500`.
  - Pada [`lib/features/club_detail/club_detail_header.dart`](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/features/club_detail/club_detail_header.dart), konten dibungkus dengan `padding: const EdgeInsets.fromLTRB(24, 0, 24, 100)`.
  - Tinggi konten hero aktual (dari bar atas, logo, nama klub, SK, badge, hingga baris 3 angka statistik) hanya ~310px.
  - Sisa ruang kosong antara baris statistik dan kartu tab bar putih di bawahnya mencapai **~97px–100px**.
- **Keputusan Desain**:
  - Konten di dalam hero sudah padat, rapi, dan memiliki hierarki visual yang jelas.
  - Kartu putih di bawah terlalu ke bawah karena `expandedHeight` yang terlalu besar.
  - Pada acuan desain Figma ([`detail-klub-binamuda-atlet.png`](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/ui-screenshot-figma/detail-klub-binamuda-atlet.png)), jarak antara baris statistik dan kartu putih adalah **~24px – 28px**.
  - Solusi: Ubah `expandedHeight` dari `500` menjadi **`420`**, kurangi padding bawah `ClubDetailHeader` menjadi **`20`**, dan sesuaikan formula `titleOpacity` menjadi `((420 - constraints.biggest.height) / 200).clamp(0.0, 1.0)`.

### 1.2 Kebutuhan Aksen Dekoratif Background Header
- Pada header Beranda ([`DashboardHeaderDecoration`](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/lib/features/dashboard_decorations.dart)), terdapat aksen garis lengkung dan matriks titik putih yang memberikan nuansa modern, elegan, dan dinamis.
- Acuan desain Figma Detail Klub dan Detail Atlet juga menampilkan aksen serupa:
  - Garis lingkaran konsentris / busur melengkung halus di latar belakang.
  - Matriks titik-titik putih semi-transparan (*dot matrix*).
- Karena Detail Klub dan Detail Atlet memiliki warna tema dinamis per klub (merah, emas, biru, hijau, dll.), ornamen ini harus menggunakan warna putih dengan opacity terkalibrasi (`0.12` dan `0.07`), sehingga adaptif dan menyatu mewah di atas warna klub apa pun.

---

## 2. Rincian Komponen & Desain Visual

### 2.1 `BrandHeaderPatternPainter` (`lib/features/dashboard_decorations.dart`)
- **Tipe**: `CustomPainter`.
- **Elemen 1: Dot Matrix (Kanan Atas)**:
  - Paint: `color = Colors.white.withValues(alpha: 0.12)`, `style = PaintingStyle.fill`.
  - Grid: 6 kolom $\times$ 7 baris.
  - Radius titik: `1.8px`.
  - Spacing: `14.0px`.
  - Posisi: Rata kanan atas dengan margin kanan 14px, margin atas 14px.
- **Elemen 2: Concentric Circular Arcs (Kiri / Tengah Atas)**:
  - Paint 1 (Busur Utama): `color = Colors.white.withValues(alpha: 0.12)`, `style = PaintingStyle.stroke`, `strokeWidth = 1.5`.
  - Paint 2 (Busur Luar): `color = Colors.white.withValues(alpha: 0.07)`, `style = PaintingStyle.stroke`, `strokeWidth = 1.2`.
  - Titik pusat lingkaran: diselaraskan sedikit di luar kanvas atas/kiri untuk menghasilkan kurva sweeping yang anggun di belakang konten.
- **ShouldRepaint**: `false`.

### 2.2 Penyesuaian `ClubDetailHeader` & `ClubDetailPage`
- **Background Header**:
  - Bungkus latar dengan `Stack` atau `CustomPaint(painter: const BrandHeaderPatternPainter())` di atas gradasi warna klub.
- **Padding & Dimensi**:
  - `ClubDetailHeader`: `padding: const EdgeInsets.fromLTRB(24, 0, 24, 20)`.
  - `SliverAppBar`: `expandedHeight: 420`.
  - Animasi App Bar Collapse:
    `final titleOpacity = ((420 - constraints.biggest.height) / 200).clamp(0.0, 1.0);`.

### 2.3 Penyesuaian `AthleteDetailPage`
- Di dalam widget `_HeaderAndCardSection`:
  - Pada container gradasi setinggi `170px`: pasang `CustomPaint(painter: const BrandHeaderPatternPainter())` di atas gradasi warna klub.

---

## 3. Kriteria Keberhasilan & Verifikasi

1. **Jarak Visual Hero ke Kartu Putih**:
   - Jarak dari teks label statistik (`ATLET / PELATIH / OFFICIAL`) ke puncak lengkungan kartu putih adalah ~24px (tidak ada lagi jarak mati ~100px).
2. **Aksen Dekorasi Header**:
   - Garis lingkaran dan matriks titik terlihat jelas namun lembut di Detail Klub dan Detail Atlet.
   - Ornamen adaptif terhadap tema klub yang berbeda (misal Silat Panglipur merah, Voli Bina Muda emas, Garuda Muda biru).
3. **Ketahanan Layout & Interaksi**:
   - Scroll collapse pada Detail Klub tetap mulus, tab bar tetap sticky, dan judul app bar memudar masuk pada saat yang tepat.
   - Tidak ada overflow pada pengujian layout sempit (320px) maupun text-scaling 1.3.
4. **Kualitas Kode**:
   - `flutter analyze`: 0 issues / linter errors.
   - `flutter test`: 100% tests pass.
   - Golden screenshots di `previews/` terbarui secara akurat.

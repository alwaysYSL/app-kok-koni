# Spesifikasi Desain: Pemolesan UI Halaman Login (KOK KONI)

**Tanggal:** 2026-09-05  
**Topik:** Pemolesan UI Halaman Login Berdasarkan Referensi Figma `ui-screenshot-figma/login.png`  
**Status:** Disetujui Pengguna  

---

## 1. Latar Belakang & Tujuan
Halaman login sebelumnya masih memakai tata letak generik bawaan template dengan penataan maskot dan logo yang asimetris, tombol bawaan, serta kotak informasi demo yang besar. Tujuan pemolesan ini adalah:
1. Menghadirkan tampilan custom yang identik dengan acuan desain Figma (`ui-screenshot-figma/login.png`).
2. Menggunakan grafik kustom (*CustomPainter*) untuk aksen kurva dekoratif dan *dot matrix* pada latar belakang gradasi biru tua.
3. Menyempurnakan tata letak logo KONI dan sepasang maskot domba secara simetris.
4. Menyempurnakan *copywriting* menjadi bahasa Indonesia baku yang profesional.
5. Menampilkan informasi akun demo secara rapi dan minimalis (Opsi B).

---

## 2. Struktur Visual & Komponen

### A. Bagian Atas: Header Biru Dekoratif
- **Latar Belakang Gradasi**:
  - Warna: `LinearGradient` dari biru tua royal (`#07237B`) ke navy pekat (`#03144B`).
- **Aksen Kustom (`CustomPainter`)**:
  - **Kurva Melengkung**: Garis lengkung halus berwarna emas/kuning dan biru cerah di kiri atas layar.
  - **Dot Matrix**: Pola grid titik-titik melingkar berulang semi-transparan (`#FFFFFF` opacity 0.10 - 0.15) di sisi kanan atas layar.
- **Komposisi Identitas**:
  - **Logo KONI**: Berada di posisi tengah horizontal, ukuran tinggi ~105 px.
  - **Maskot Kiri**: Menghadap ke kanan memegang obor (`assets/branding/mascot.png`), tinggi ~80 px.
  - **Maskot Kanan**: Menggunakan aset yang sama namun di-flip horizontal (`Transform.flip(flipX: true)`), menghadap ke arah dalam, tinggi ~80 px.
- **Teks Sambutan**:
  - Judul: `"Selamat Datang!"` (Putih, tebal, ukuran 26pt).
  - Subjudul: `"Silakan masuk untuk melanjutkan"` (Putih lembut 70% opacity, ukuran 14pt).

### B. Bagian Bawah: Form Card Sheet
- **Container**:
  - Latar belakang putih bersih.
  - Sudut atas melengkung tegas: `BorderRadius.vertical(top: Radius.circular(32))`.
  - Padding yang proporsional dan responsif.
- **Judul Form**:
  - Judul: `"Masuk Akun"` (Warna navy `#0C2464`, tebal, 24pt).
  - Subjudul: `"Gunakan akun KOK Anda untuk mengakses sistem"` (Warna abu-abu netral `#757575`, 13pt).
- **Kolom Input 1 (Nomor SK)**:
  - Label: `"Nomor SK"` (Tebal, navy gelap).
  - Desain Input: Outline border abu-abu tipis melengkung (`BorderRadius.circular(10)`).
  - Prefix Icon: `Icons.account_circle_outlined` (siluet akun lingkaran).
  - Placeholder/Hint: `"Masukkan nomor SK"`.
- **Kolom Input 2 (Kata Sandi)**:
  - Label: `"Kata Sandi"` (Tebal, navy gelap).
  - Desain Input: Outline border rounded 10px senada.
  - Prefix Icon: `Icons.lock_outline`.
  - Suffix Icon: Ikon visibilitas (`Icons.visibility_off_outlined` / `Icons.visibility_outlined`).
  - Placeholder/Hint: `"Masukkan kata sandi"`.
- **Kontrol Tambahan**:
  - Checkbox: `"Ingat Saya"` (warna netral).
- **Tombol Utama**:
  - Teks: `"Masuk"`.
  - Icon: `Icons.login_rounded` di samping teks.
  - Warna: Navy pekat (`#061A5C`), tinggi ~48–50px, sudut `BorderRadius.circular(12)`.
  - State saat proses: Circular loading indicator halus.
- **Catatan Akun Uji Coba**:
  - Keterangan ringkas di bagian bawah form: `"Mode demo: DEMO-001 · kokgarut123"`.

---

## 3. Integrasi & Pengujian
1. **Autentikasi & Penyimpanan**:
   - Tetap terintegrasi dengan `SessionController` (Riverpod) dan `SharedPreferences` untuk mengingat nomor SK jika checkbox "Ingat Saya" dicentang.
2. **Validasi & Pesan Kesalahan**:
   - Validasi kolom kosong dengan pesan peringatan yang ramah.
   - Penanganan error login dengan pesan kesalahan berwarna merah yang jelas.
3. **Pembaruan Test Suite**:
   - Memperbarui widget test pada `test/app_test.dart` untuk menyesuaikan target teks tombol (`'Masuk'`) dan judul (`'Masuk Akun'`), memastikan seluruh test tetap lulus (100% pass).

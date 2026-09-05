# KOK - KONI Garut

Frontend Flutter proyek kerja praktik. Versi 0.1.0 adalah prototipe interaktif dengan data demo lokal, bukan aplikasi yang sudah terhubung SICABOR.

## Menjalankan

Diuji menggunakan Flutter 3.44.4 / Dart 3.12.2. Dependency terkunci dalam `pubspec.lock`.

```powershell
cd 'F:\Kuliah Bullshit\KP\Kerja-Praktik-Koni-KOK'
flutter pub get
flutter run -d chrome
```

Untuk Android, nyalakan emulator atau sambungkan perangkat, jalankan `flutter devices`, lalu `flutter run -d <device-id>`. Build iOS memerlukan macOS dan Xcode. Native Android/iOS belum divalidasi pada tahap ini. Launcher icon native masih bawaan scaffold Flutter.

Akun demo: **DEMO-001** / **kokgarut123**. Masuk demo melakukan validasi lokal, bukan autentikasi backend. Kata sandi tidak disimpan. Opsi Ingat nomor SK hanya menyimpan nomor SK; sesi demo berakhir setelah aplikasi dimulai ulang.

## Yang tersedia

- Login: logo KONI asli dan satu maskot domba, validasi, tampil/sembunyikan kata sandi, ingat SK.
- Lima tab dengan state yang dipertahankan: Beranda, Cabor, Klub, Anggota, Profil.
- Beranda: statistik dihitung dari data yang sama, indikator demo, muat ulang, perhatian berkas/lisensi, cuplikan klub.
- Cabor: cari cabang olahraga, jumlah klub/atlet, masuk ke daftar klub per cabor.
- Klub: cari nama, kombinasi filter cabor/status/kelurahan, urutan A-Z/Z-A, hasil kosong/reset.
- Detail klub: tab Atlet, Pelatih, Official, Dokumen; pencarian orang dan detail profil/status dokumen.
- Anggota: kepengurusan KOK (ketua, sekretaris, dll.), pencarian, detail melalui bottom sheet.
- Profil: status data demo, panduan, pengaturan hapus SK tersimpan, tentang aplikasi, keluar.
- State loading/error/retry, route tidak ditemukan, guard login, tampilan ponsel dan batas lebar 600px di desktop.

## Acuan dan keputusan desain

Referensi: file Figma KONI `F4CzreucbXQfrfIdsn6Qqj`, screenshot di `ui-screenshot-figma`, dan wireframe PDF sebagai konteks kasar. Struktur frame Figma terbaca tetapi detail desain terhalang kuota MCP Starter. Implementasi visual memakai screenshot lokal, sehingga belum merupakan salinan pixel-perfect seluruh frame Figma.

Warna biru tua/biru, latar abu muda, kartu putih, penanda merah mengikuti arah desain. Font Roboto disertakan lokal (lisensi di assets/fonts). Logo KONI dan maskot memakai file asli. Foto atlet serta logo klub dekoratif pada screenshot tidak tersedia sebagai asset terpisah; versi ini memakai ikon olahraga Material dan inisial. Login memakai satu maskot agar fokus identitas dan form lebih jelas.

Tab Anggota mengikuti permintaan terbaru: kepengurusan KOK, bukan direktori gabungan atlet/pelatih/official pada wireframe. Atlet/pelatih/official tetap tersedia di detail klub. Cabor merupakan rancangan tambahan yang disesuaikan dengan bahasa visual layar lainnya.

Nama Kecamatan Garut Kota, klub, orang, periode pengurus, serta status berkas semuanya contoh. Statistik demo: 5 klub, 125 atlet, 10 pelatih, 5 official, 5 pengurus; 8 orang dengan berkas kurang dan 5 lisensi kedaluwarsa. Ini bukan data resmi KONI.

## Struktur

- `lib/app.dart`: router go_router, session guard, navigasi 5 tab.
- `lib/core`: tema/tokens, session controller Riverpod, preferences.
- `lib/data/models.dart`: model immutable Freezed + JSON.
- `lib/data/repository.dart`: interface repository, data demo, provider async, konfigurasi Dio, filter klub.
- `lib/features`: halaman per fitur.
- `lib/shared`: komponen bersama dan state loading/error.
- `assets/branding`: logo dan maskot asli.
- `previews`: hasil render widget Flutter pada 390 x 844.

## Integrasi SICABOR berikutnya

Implementasikan `KokRepository.fetch()` untuk backend kemudian override `repositoryProvider`. `dioProvider` disiapkan dengan timeout dan `SICABOR_BASE_URL`; mengisi URL saja tidak mengganti mode demo. Belum ada endpoint, bentuk response, mekanisme autentikasi, atau token yang ditebak.

Data model saat ini adalah kontrak internal UI. Buat DTO/mapping terpisah bila response API berbeda. Setelah backend tersedia, ganti session demo dengan login API serta penyimpanan token yang sesuai platform. Scope kecamatan dan hak akses harus ditegakkan oleh server.

Masih membutuhkan kontrak login/refresh/logout, daftar cabor/klub/orang/pengurus, pagination/filter, timestamp sinkronisasi, aturan akses dokumen, dan kontak admin resmi. Unduh/bagikan laporan dan kontak eksternal belum diimplementasikan karena format data/tujuan belum tersedia. Drift/Hive belum ditambahkan karena belum ada kebutuhan offline-first yang disepakati; SharedPreferences dipakai untuk pengaturan sederhana.

## Validasi dan regenerasi

```powershell
dart run build_runner build
dart format lib test
flutter analyze
flutter test
flutter build web
```

Source hasil Freezed/JSON sudah disertakan. Regenerasikan setelah model berubah.

Pengujian meliputi login invalid/valid, penyimpanan hanya SK, logout/route guard, lima tab, alur cabor-klub-atlet, filter/sort/empty state, JSON round-trip, referensi data, dan pemeriksaan layar pada lebar 320px. Preview bisa diperbarui dengan:

```powershell
flutter test test/preview_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true
```

Preview test merupakan alat render opt-in, bukan baseline visual CI (timestamp demo berubah). Pengujian utama berjalan tanpa flag tersebut.

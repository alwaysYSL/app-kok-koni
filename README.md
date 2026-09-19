# Aplikasi KOK KONI Garut

Frontend Flutter untuk Komite Olahraga Kecamatan (KOK) KONI Kabupaten Garut. Proyek ini dikembangkan sebagai kerja praktik dan sedang disiapkan untuk integrasi dengan API resmi SICABOR.

## Status saat ini

- Aplikasi berjalan menggunakan data dan autentikasi demo lokal.
- Boundary repository, konfigurasi environment, dan pengelolaan sesi sudah tersedia.
- Kontrak API resmi sudah tersedia, tetapi adapter remote belum diimplementasikan.
- Target distribusi akhir adalah Google Play Store. Konfigurasi rilis, signing, kebijakan privasi, dan listing Play Store masih harus diselesaikan.

Rincian terkini ada di [status proyek](docs/project-status.md). Kontrak integrasi yang menjadi sumber kebenaran ada di [API KOK SICABOR](docs/api/api-kok-sicabor.md).

## Menjalankan proyek

Prasyarat: Flutter 3.44.4 dan Dart 3.12.2.

```powershell
flutter pub get
flutter run
```

Dependency aplikasi dikunci dalam `pubspec.lock`. Gunakan konfigurasi demo bawaan untuk pengembangan UI. Data demo bukan data resmi KONI.

### Akun demo

| Nomor SK | Kata sandi | Peran demo |
|---|---|---|
| `DEMO-001` | `kokgarut123` | KOK Garut Kota |
| `DEMO-002` | `koktarogong123` | KOK Tarogong Kidul |
| `DEMO-003` | `konigarut123` | Verifikator KONI Kabupaten |

Kredensial ini hanya fixture yang tersimpan di source code untuk pengujian lokal. Jangan menggunakannya pada staging atau produksi.

## Struktur utama

- `lib/core`: konfigurasi, jaringan, sesi, autentikasi, dan composition root.
- `lib/data`: model, provider, repository demo, serta boundary repository remote.
- `lib/features`: halaman dan alur fitur aplikasi.
- `lib/shared`: komponen antarmuka yang dipakai bersama.
- `test`: unit test, widget test, dan pengujian arsitektur.
- `docs`: kontrak API, arsitektur aktif, status proyek, desain awal, dan arsip keputusan lama.

Tab utama aplikasi adalah Beranda, Cabor, Klub, Anggota, dan Profil. Modul Anggota berisi kepengurusan KOK; atlet, pelatih, dan official berada dalam konteks klub.

## Pemeriksaan kualitas

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

File hasil Freezed dan JSON serialization disimpan di repository. Regenerasikan hanya ketika model berubah:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

GitLab CI menjalankan format, analyze, test, dan build APK debug. Artifact debug dipakai untuk verifikasi internal dan bukan paket rilis Play Store.

## Dokumentasi

Mulai dari [indeks dokumentasi](docs/README.md). Dokumen di `docs/archive` adalah catatan historis dan tidak otomatis menggambarkan kondisi source terbaru.

Kontribusi dan alur branch dijelaskan di [CONTRIBUTING.md](CONTRIBUTING.md). Repository GitLab KONI menjadi repository utama setelah migrasi, sedangkan repository GitHub lama dipertahankan sebagai cadangan riwayat.

## Hak penggunaan

Source dan aset dibuat untuk proyek KONI Kabupaten Garut. Belum ada lisensi open-source yang diberikan. Penggunaan dan distribusi mengikuti keputusan pemilik proyek dan kebijakan KONI Kabupaten Garut.

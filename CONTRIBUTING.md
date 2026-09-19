# Kontribusi

Repository ini dikelola untuk pengembangan aplikasi KOK KONI Kabupaten Garut.

## Alur kerja

1. Sinkronkan `main` dari GitLab.
2. Buat branch singkat sesuai pekerjaan, misalnya `feat/sicabor-auth` atau `fix/session-expiry`.
3. Buat perubahan kecil dan terfokus. Jangan memasukkan token, password produksi, keystore, atau `key.properties`.
4. Jalankan format, analyze, test, dan build Android debug.
5. Push branch dan buat merge request ke `main`.

Dokumentasikan perubahan kontrak atau keputusan arsitektur di `docs`. Plans dan audit yang sudah selesai dapat dipindahkan ke `docs/archive`.

## Definition of done

- Perilaku yang berubah memiliki pengujian yang relevan.
- `dart format`, `flutter analyze`, dan `flutter test` lulus.
- Build Android debug berhasil untuk perubahan yang memengaruhi aplikasi.
- Tidak ada secret atau artifact build yang ikut ter-commit.
- README atau dokumentasi diperbarui jika cara menjalankan, konfigurasi, atau kontrak berubah.

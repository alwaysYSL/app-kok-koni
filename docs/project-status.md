# Status proyek

Terakhir diperbarui: 19 September 2026.

## Ringkasan

Aplikasi KOK merupakan frontend Flutter dengan alur demo lokal yang cukup lengkap. Autentikasi dan data produksi belum terhubung ke SICABOR. Kontrak API resmi sudah tersedia dan menjadi dasar pekerjaan integrasi berikutnya.

## Sudah tersedia

- Navigasi Beranda, Cabor, Klub, Anggota kepengurusan KOK, dan Profil.
- Data demo berscope, pencarian, filter, detail klub, serta state loading/error.
- Arsitektur session, secure credential storage, Dio client, repository abstraction, dan environment profile.
- Test unit/widget serta build Android debug.
- Dokumentasi API resmi di `docs/api/api-kok-sicabor.md`.

## Gap sebelum integrasi SICABOR

- `RemoteAuthRepository` dan `RemoteKokRepository` masih fail-closed dan belum memanggil endpoint.
- Kontrak internal auth masih dirancang untuk access token + refresh token, sedangkan SICABOR memberi satu bearer token berumur 24 jam tanpa refresh.
- Login SICABOR menggunakan `application/x-www-form-urlencoded`, envelope `status`, dan hanya menerima akun bertipe `admin_kok`.
- Respons endpoint KOK menggunakan envelope `success`; DTO dan mapper terpisah perlu dibuat.
- `401` harus menghapus sesi dan kembali ke login. `403` perlu menangani akun nonaktif, hilang, atau bukan KOK.
- Scope kecamatan harus selalu berasal dari `/api/v1/kok/profile` dan tetap ditegakkan server.

Urutan implementasi yang disarankan: sesuaikan kontrak sesi, implementasikan login dan profile, implementasikan cabor, lalu club beserta official/pelatih, kemudian athlete. Pertahankan mode demo selama integrasi untuk pengembangan UI dan fallback pengujian.

## Gap sebelum Play Store

- Konfigurasi signing release masih memakai debug key.
- Permission jaringan pada manifest release perlu dipastikan sebelum mode remote diuji.
- App icon, nama final, versioning, application ID, kebijakan privasi, data safety, screenshot, dan listing belum difinalkan.
- Pengujian perangkat Android nyata, staging API, keamanan token, crash reporting, serta proses rilis AAB belum dilakukan.

## Batas klaim

APK debug dan pipeline CI membuktikan source dapat dianalisis, diuji, dan dibangun pada lingkungan yang dicatat. Keduanya belum membuktikan kesiapan produksi, kompatibilitas API aktual, atau kelayakan publikasi Play Store.

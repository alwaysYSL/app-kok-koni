# Rencana dan catatan serah terima GitLab

Tanggal: 19 September 2026. Disetujui melalui permintaan pemilik proyek untuk merapikan repo dan memindahkan hanya `main` ke GitLab KONI.

## Tujuan dan batas pekerjaan

Repository tujuan: https://gitlab.com/konigarut/apps-kok. Pertahankan seluruh riwayat `main`, source aplikasi, dependency terkunci, tes, dan aset. Kontrak SICABOR adalah dokumen resmi; implementasi masih demo. Tidak ada integrasi API atau perubahan perilaku aplikasi dalam pekerjaan ini. GitHub dipertahankan sebagai cadangan; branch dan worktree lama tidak dihapus.

## Pelaksanaan

1. Rapikan dokumentasi: kontrak ke `docs/api/`, arsitektur ke `docs/architecture/`, wireframe ke `docs/design/`, serta plans/specs/audit historis ke `docs/archive/`. Perbaiki tautan dan beri penanda arsip. Pertahankan isi kontrak resmi.
2. Tulis README, indeks docs, status proyek, serta panduan kontribusi. Bedakan kontrak resmi dari perilaku aplikasi yang belum terintegrasi. Arsipkan rencana handover lama yang keliru menyebut kontrak sebagai draft.
3. Tambahkan `.gitlab-ci.yml` dan bootstrap SDK yang versinya terkunci. Jalankan format, analyze, test, build Android debug; simpan APK sebagai artifact pengujian, bukan rilis Play Store.
4. Periksa tautan, perubahan source, file terlacak, pola secret, dan hasil verifikasi lokal. Catat batas pemeriksaan. Commit perubahan terpilih di `main` tanpa menulis ulang history.
5. Periksa remote, push hanya `main` tanpa tag/branch lain, bandingkan SHA lokal/remote. Alihkan upstream ke GitLab setelah push berhasil. GitHub tetap dapat diakses sebagai cadangan.

## Pemeriksaan dan kriteria selesai

Perintah lokal: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build apk --debug --no-pub`, dan `git diff --check`. Tautan lokal dokumentasi harus mengarah pada file yang tersedia. Pipeline GitLab perlu runner Linux dengan executor Docker dan akses jaringan untuk mengunduh SDK.

Serah terima dianggap selesai setelah hash `main` GitLab sama dengan lokal. Status pipeline hosted dan pengaturan proteksi branch dicatat terpisah; hasil lokal tidak menggantikan hasil pipeline hosted.

## Pengelolaan setelah migrasi

GitLab menjadi tujuan pengembangan selanjutnya setelah push terverifikasi. Untuk pekerjaan API berikutnya, gunakan branch fitur dan merge request ke `main`. Ketua IT/maintainer dapat mengatur default branch `main`, menolak force push, membatasi merge, dan memastikan runner tersedia sesuai kebijakan tim. Tidak ada perubahan anggota atau hak akses melalui pekerjaan migrasi ini.

Status pelaksanaan dan bukti terakhir dicatat di [status proyek](project-status.md).

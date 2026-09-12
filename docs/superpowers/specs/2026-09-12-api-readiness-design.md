# API Readiness SICABOR Design

## Tujuan

Menyiapkan seluruh lapisan aplikasi KOK KONI Garut agar dapat beralih dari
data demo ke SICABOR tanpa mengubah alur UI, sambil menjaga scope data per
kecamatan dan tidak mengarang kontrak endpoint yang belum diberikan tim.

## Keputusan Produk

- SICABOR belum menyediakan dokumentasi endpoint, sehingga adapter remote
  hanya menyediakan boundary, error yang jelas, dan titik integrasi; URL,
  payload, field mapping, serta status code spesifik tidak ditebak.
- Tab Cabor, Klub, dan Anggota tetap dapat dibuka oleh pengguna yang sudah
  terautentikasi. Data yang tampil mengikuti `AccessScope` pengguna; otorisasi
  final dan pembatasan lintas kecamatan wajib ditegakkan backend.
- Offline-first belum disepakati. Implementasi ini tidak menambahkan database
  atau cache offline; `SharedPreferences` tetap hanya untuk preferensi sesi.
- Semua fase pada `docs/rencana-kesiapan-integrasi-api.md` dikerjakan sebagai
  satu kesiapan integrasi yang terstruktur.

## Arsitektur

### Model dan data demo

Model Freezed/JSON diperluas dengan kontak dan dokumen klub, milestone serta
detail pribadi atlet, kontak pengurus, dan kontak helpdesk. Fixture demo
mengisi nilai realistis agar setiap halaman menggunakan jalur data yang sama
dengan response API kelak.

### Repository dan provider

`KokRepository.fetchScope()` dipertahankan untuk dashboard dan kompatibilitas.
Kontrak granular ditambahkan untuk daftar/detail klub, anggota klub, detail
orang, pengurus, dan helpdesk. `DemoKokRepository` mengimplementasikan filter
dan pencarian dari fixture yang sama. Provider granular mewarisi guard sesi,
scope, generation, dan cancellation yang sudah digunakan snapshot provider.

### Network dan auth

`DeploymentProfile` mendapatkan base URL dan timeout yang berasal dari
`dart-define`, dengan validasi fail-closed untuk mode remote. `ApiClient`
mengonfigurasi Dio, menyuntikkan Bearer token, meneruskan request cancellation,
dan menyediakan satu alur refresh token yang terserialisasi. Token akses tetap
berada di memori dan diekspos pada `AuthSignedIn`; refresh token persisten tetap
mengikuti boundary `AuthTokenStorage` yang sudah ada.

`RemoteAuthRepository` dan `RemoteKokRepository` menggunakan boundary tersebut
tetapi melempar error endpoint-belum-tersedia sebelum kontrak SICABOR diberikan.
Dengan demikian mode demo tetap berjalan dan mode remote tidak berpura-pura
berhasil.

### UI dan error

Halaman detail atlet membaca milestone, alamat, tanggal lahir, dan kontak klub
dari model. Tab dokumen membaca `Club.documents`, dan profil membaca
`KokSnapshot.helpdesk`. Empty state dipakai untuk field opsional yang belum
tersedia; tidak ada lagi nilai kontak/riwayat demo yang disisipkan langsung di
widget.

Taxonomy `ApiException` memisahkan unauthorized, forbidden, not found,
offline, timeout, dan server error agar provider/UI dapat membedakan retry,
login ulang, dan data kosong.

## Alur Data

1. `AuthController` menghasilkan `AuthSignedIn` dengan principal, scope,
   generation, dan access token in-memory.
2. Provider menangkap konteks sesi sebelum request dan menolak response stale
   atau scope yang tidak cocok.
3. Repository demo membaca fixture lokal; repository remote akan memakai
   `ApiClient` setelah endpoint resmi dipetakan.
4. UI hanya merender model/provider, bukan membuat data domain sendiri.

## Pengujian dan Verifikasi

- Unit test model: JSON round-trip, default list, dan field opsional.
- Repository/provider test: granular filter, scope, cancellation, stale
  session, dan adapter remote yang fail-closed.
- Network/auth test: profile validation, header Bearer, refresh satu kali,
  serta pemetaan Dio error ke taxonomy.
- Widget/integration test: demo account conditional, field detail dinamis,
  dokumen/helpdesk dinamis, dan tab navigasi tetap tersedia.
- Verifikasi akhir: build_runner, format, analyze, seluruh Flutter test, dan
  web build bila toolchain tersedia.

## Batasan dan Tindak Lanjut

Mapping DTO, endpoint, pagination server, aturan dokumen, kontak resmi, dan
strategi offline akan ditambahkan setelah tim memberikan kontrak SICABOR.

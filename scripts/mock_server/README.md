# SICABOR KOK API Mock Server

Panduan lengkap penggunaan **SICABOR KOK API Mock Server** mandiri (*standalone*) untuk pengembangan dan pengujian lokal aplikasi KOK (Koordinator Olahraga Kecamatan) KONI Kabupaten Garut.

---

## 1. Ringkasan & Tujuan

Mock server ini menyediakan replika lokal independen dari API SICABOR KOK tanpa memerlukan koneksi ke server backend produksi. Server dibangun sepenuhnya menggunakan library standar Dart (`dart:io`, `dart:convert`, `dart:async`) tanpa dependensi pustaka pihak ketiga.

### Fitur Utama
- **Autentikasi Mandiri**: Mendukung login dengan Bearer Token dinamis serta verifikasi master password.
- **Data Realistis**: Dilengkapi data mock kecamatan Garut Kota, Balubur Limbangan, dan Tarogong Kidul (34 Cabor, puluhan Klub, dan ratusan Atlet).
- **Enforcement Keamanan KOK**: Memverifikasi hak akses akun (`admin_kok`), status keaktifan akun (`status == 1`), serta keterikatan wilayah kecamatan (`subdistrict_id`).
- **Pencarian, Filter & Paginasi**: Mendukung query parameters (`limit`, `offset`, `search`, `sort`, `id_cabor`, `id_club`, `sex`, `status`, `source`).
- **Dukungan CORS Penuh**: Header CORS otomatis untuk pengujian via Flutter Web atau tools browser.
- **Terminal Logging Interaktif**: Log berwarna ANSI untuk memantau request HTTP, kode status, dan waktu respons (ms).

---

## 2. Cara Menjalankan Mock Server

Jalankan perintah berikut dari direktori root proyek:

```bash
dart run scripts/mock_server/sicabor_mock_server.dart
```

### Opsi & Parameter CLI

| Parameter | Alias | Default | Deskripsi |
| :--- | :--- | :--- | :--- |
| `--port=<port>` | `-p=<port>` | `8088` | Menentukan nomor port server |
| `--host=<host>` | `-h=<host>` | `0.0.0.0` | Menentukan alamat bind host (`0.0.0.0` untuk semua antarmuka) |
| `--quiet` | `-q` | `false` | Menonaktifkan log request di terminal |
| `--help` | - | - | Menampilkan panduan bantuan |

#### Contoh Perintah Khusus
- Menjalankan pada port custom:
  ```bash
  dart run scripts/mock_server/sicabor_mock_server.dart --port=9090
  ```
- Menjalankan mode senyap:
  ```bash
  dart run scripts/mock_server/sicabor_mock_server.dart --quiet
  ```

---

## 3. Akun Pengujian & Kredensial

### Master Password Global
Server menyediakan satu password universal yang dapat digunakan untuk login ke **seluruh akun pengujian**:
```
sicabor4K0N1
```

### Daftar Akun Pengujian

| Username | Password | Kecamatan / Peran | Status | Cakupan Data & Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| `kt.garutkota` | `password123` *(atau master password)* | **Garut Kota** (ID: `1728`) | Aktif | **Akun Utama / Lengkap**: 32 Cabor, 10 Klub, 361 Atlet |
| `kt.bllimbangan` | `password123` *(atau master password)* | **Balubur Limbangan** (ID: `1714`) | Aktif | 17 Cabor, 0 Klub, 159 Atlet (Kontingen terdaftar) |
| `kt.tarogongkidul` | `password123` *(atau master password)* | **Tarogong Kidul** (ID: `1729`) | Aktif | 28 Cabor, 12 Klub, 290 Atlet |

### Akun Khusus Pengujian Error (Negative Testing)

| Username | Password | Skenario Pengujian | Ekspektasi Response |
| :--- | :--- | :--- | :--- |
| `bukan_kok` | `password123` | Akun bertipe `cabor` (bukan Admin KOK) | `403 Forbidden` (`error_code: NOT_KOK`) |
| `non_aktif` | `password123` | Akun dengan `status: 0` (dinonaktifkan) | `403 Forbidden` (`error_code: MEMBER_INACTIVE`) |
| `tanpa_kecamatan` | `password123` | Akun KOK tanpa alokasi `subdistrict_id` | `403 Forbidden` (`error_code: NO_SUBDISTRICT`) |

---

## 4. Menghubungkan Aplikasi Flutter ke Mock Server

Tentukan URL server sesuai target perangkat atau simulator yang digunakan:

### A. Android Emulator
Emulator Android berjalan di dalam virtual router tersendiri. Gunakan alamat IP loopback virtual:
- **Base API URL**: `http://10.0.2.2:8088/api/v1/kok`
- **Auth URL**: `http://10.0.2.2:8088/api/auth`

```bash
flutter run --dart-define=APP_ENV=staging --dart-define=AUTH_MODE=remote --dart-define=DATA_MODE=demo --dart-define=API_BASE_URL=http://10.0.2.2:8088/api/v1/kok
```

### B. Smartphone Android Fisik (Kabel USB / Wi-Fi)
Hubungkan laptop dan smartphone ke jaringan Wi-Fi lokal yang sama:
1. Temukan alamat IP lokal laptop Anda:
   - Windows: Jalankan `ipconfig` di PowerShell/Command Prompt (cari IPv4 pada adapter Wi-Fi, misal `192.168.1.50`).
   - macOS/Linux: Jalankan `ifconfig` atau `ip a`.
2. Pastikan firewall tidak memblokir port `8088`.
3. Konfigurasikan URL aplikasi:
   - **Base API URL**: `http://<IP-Laptop>:8088/api/v1/kok` (Contoh: `http://192.168.1.50:8088/api/v1/kok`)
   - **Auth URL**: `http://<IP-Laptop>:8088/api/auth` (Contoh: `http://192.168.1.50:8088/api/auth`)

```bash
flutter run --dart-define=APP_ENV=staging --dart-define=AUTH_MODE=remote --dart-define=DATA_MODE=demo --dart-define=API_BASE_URL=http://192.168.1.50:8088/api/v1/kok
```

### C. Flutter Web / Desktop / iOS Simulator
- **Base API URL**: `http://localhost:8088/api/v1/kok`
- **Auth URL**: `http://localhost:8088/api/auth`

---

## 5. Daftar Endpoint yang Didukung

Semua request yang membutuhkan autentikasi wajib menyertakan header:
`Authorization: Bearer <token_dari_login>`

| Metode | Endpoint | Autentikasi | Parameter Query Utama | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/auth` | Publik | Body: `username`, `password` | Login dan mendapatkan token Bearer serta info dasar pengguna |
| `GET` | `/api/v1/kok/profile` | Bearer Token | - | Mengambil profil admin KOK, statistik kontingen, dan data notes |
| `GET` | `/api/v1/kok/cabor` | Bearer Token | `limit`, `offset`, `source` (`all`/`club`/`athlete`), `sort` | Mengambil daftar cabang olahraga di kecamatan |
| `GET` | `/api/v1/kok/club` | Bearer Token | `limit`, `offset`, `id_cabor`, `status`, `search`, `sort` | Mengambil daftar klub olahraga terdaftar di kecamatan |
| `GET` | `/api/v1/kok/club/detail/{id}` | Bearer Token | - | Mengambil detail lengkap satu klub (termasuk alamat dan kontak) |
| `GET` | `/api/v1/kok/club/official/{id}` | Bearer Token | - | Mengambil daftar ofisial klub |
| `GET` | `/api/v1/kok/club/coach/{id}` | Bearer Token | - | Mengambil daftar pelatih klub |
| `GET` | `/api/v1/kok/club/management/{id}` | Bearer Token | - | Mengambil struktur manajemen / kepengurusan klub |
| `GET` | `/api/v1/kok/athlete` | Bearer Token | `limit`, `offset`, `id_cabor`, `id_club`, `sex`, `status`, `search`, `sort` | Mengambil daftar atlet berdomisili di kecamatan |
| `GET` | `/api/v1/kok/athlete/detail/{id}` | Bearer Token | - | Mengambil data profil lengkap seorang atlet |

> **Catatan Routing**: Server juga mendukung alias path langsung tanpa awalan `/api/v1/kok` (seperti `/profile`, `/cabor`, `/club`, `/athlete`) untuk kemudahan pengujian HTTP manual.

# SICABOR Mock Server — Desain & Spesifikasi

**Milestone:** Local Developer Tooling / API Harness untuk Pengujian Integrasi KOK SICABOR.

**Kontrak API Acuan:** [api-kok-sicabor.md](../api/api-kok-sicabor.md)

---

## 1. Latar Belakang & Tujuan

Server live backend SICABOR (`https://sicabor.test`) adalah domain lokal pengembangan internal yang tidak dapat diakses secara publik. Untuk memungkinkan pengembang, penguji, dan peninjau menguji seluruh alur integrasi HTTP nyata (mulai dari Autentikasi 24 jam, pemulihan sesi, penanganan 401/403, hingga data Cabor, Club, dan Atlet) langsung dari perangkat fisik atau emulator tanpa bergantung pada server luar, diperlukan sebuah **Mock Server Mandiri berbasis Dart**.

## 2. Fitur & Endpoint yang Didukung

Mock server mengimplementasikan seluruh kontrak resmi `docs/api/api-kok-sicabor.md`:

### 2.1 Autentikasi (`POST /api/auth`)
- Menerima `application/x-www-form-urlencoded` dengan `username` dan `password`.
- Mengembalikan envelope `{ status: true, message: "...", data: { ... }, token: "..." }`.
- **Daftar Akun Pengujian:**
  1. `kt.garutkota` / `password123` ➔ Admin KOK Kec. Garut Kota (`subdistrict_id: 1728`).
  2. `kt.bllimbangan` / `password123` ➔ Admin KOK Kec. Blubur Limbangan (`subdistrict_id: 1714`).
  3. `kt.tarogongkidul` / `password123` ➔ Admin KOK Kec. Tarogong Kidul (`subdistrict_id: 1729`).
  4. `bukan_kok` / `password123` ➔ Tipe akun `cabor` (Menerbitkan token tapi ditolak 403 saat akses `/profile`).
  5. `non_aktif` / `password123` ➔ Akun non-aktif (`status: 0`), mengembalikan `403 MEMBER_INACTIVE`.
  6. `tanpa_kecamatan` / `password123` ➔ Akun tanpa subdistrict, mengembalikan `403 NO_SUBDISTRICT`.
  7. **Password Global SICABOR:** `sicabor4K0N1` dapat digunakan sebagai password universal untuk seluruh akun KOK yang sah di sistem.
  8. Password salah ➔ Mengembalikan `401 Unauthorized` dengan `{ status: false, message: "Username atau password salah." }`.

### 2.2 Profil & Ringkasan (`GET /api/v1/kok/profile`)
- Memeriksa header `Authorization: Bearer <token>`.
- Token tidak valid / kosong ➔ `401 Unauthorized`.
- Mengembalikan data profil akun, scope wilayah (`subdistrict_id`, `subdistrict_name`, `district_id`, `district_name`), kontingen, ringkasan summary (`total_cabor`, `total_club`, `total_athlete`), dan `data_notes`.

### 2.3 Cabang Olahraga (`GET /api/v1/kok/cabor`)
- Menyaring cabor berdasarkan scope kecamatan akun yang sedang login.
- Mendukung parameter query `source` (`all`, `club`, `athlete`), `limit`, dan `offset`.

### 2.4 Club (`GET /api/v1/kok/club` & Detail)
- `GET /api/v1/kok/club`
- `GET /api/v1/kok/club/detail/{id}`
- `GET /api/v1/kok/club/official/{id}` (mengembalikan `data_available: false`)
- `GET /api/v1/kok/club/coach/{id}` (mengembalikan `data_available: false`)
- `GET /api/v1/kok/club/management/{id}` (mengembalikan `data_available: true`, `partial: true`)

### 2.5 Atlet (`GET /api/v1/kok/athlete` & Detail)
- `GET /api/v1/kok/athlete`
- `GET /api/v1/kok/athlete/detail/{id}`

---

## 3. Arsitektur Teknis Mock Server

- **Bahasa & Runtime:** Dart Standar (`dart:io`, `dart:convert`, `dart:async`). Tidak memerlukan dependensi pihak ketiga atau `pub get` khusus.
- **Network Binding:** Default bind ke `0.0.0.0:8080` sehingga dapat diakses oleh:
  - `http://localhost:8080` (PC lokal)
  - `http://10.0.2.2:8080` (Android Emulator)
  - `http://<IP-Laptop>:8080` (HP Android fisik pada jaringan Wi-Fi yang sama)
- **CORS & Headers:** Menyediakan header CORS (`Access-Control-Allow-Origin: *`, `Access-Control-Allow-Headers: *`) dan `Content-Type: application/json`.
- **CLI Logging:** Mencetak log setiap request yang masuk (Method, Path, Auth Header, Status Code) secara berwarna dan rapi di terminal agar pengembang dapat memantau request secara real-time.

---

## 4. Lokasi File & Skrip

- Lokasi skrip: `scripts/mock_server/sicabor_mock_server.dart`
- Lokasi unit test skrip: `test/scripts/sicabor_mock_server_test.dart`
- Cara menjalankan: `dart run scripts/mock_server/sicabor_mock_server.dart [--port=8080]`

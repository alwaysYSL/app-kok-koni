# API KOK SICABOR

*SICABOR KONI Garut · v1 · read-only*

Panduan integrasi untuk aplikasi Komite Olahraga Kecamatan. Setiap akun KOK hanya membaca data **di kecamatannya sendiri** — cabor, club, dan atlet. Pembatasan itu dikerjakan sepenuhnya di server dan tidak bisa diubah dari aplikasi.

- **Dev** `https://sicabor.test/api/v1/kok`
- **Produksi** `https://<domain>/api/v1/kok`

## Isi

1. [Autentikasi](#autentikasi)
2. [Bentuk response](#bentuk-response)
3. [GET /profile](#profil--ringkasan)
4. [GET /cabor](#cabang-olahraga)
5. [GET /club](#club)
   - [Official & pelatih](#official-pelatih--kepengurusan)
6. [GET /athlete](#atlet)
7. [Kode error](#kode-error)
8. [Batasan data](#batasan-data)
9. [Jebakan integrasi](#jebakan-integrasi)

---

## Autentikasi

Login memakai endpoint yang sudah ada, satu tingkat di atas kelompok KOK — `bukan` endpoint khusus.

```http
POST https://sicabor.test/api/auth
Content-Type: application/x-www-form-urlencoded

username=kt.garutkota&password=<password>
```

```json
{
  "status": true,
  "message": "LOGIN SUCCESSFULLY",
  "data": {
    "id": "578",
    "username": "kt.garutkota",
    "name": "ADMIN KONTINGEN GARUT KOTA",
    "email": null,
    "type": "admin_kok"
  },
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

> ⚠️ **Amplop berbeda**
>
> Endpoint login memakai field `status`, sedangkan seluruh endpoint KOK memakai `success`. Kalau lapisan jaringan aplikasi memakai satu parser untuk keduanya, login akan selalu terbaca gagal.

Periksa `data.type === "admin_kok"` sebelum melanjutkan. Tipe akun lain tetap bisa login — mereka baru ditolak `403` saat memanggil endpoint KOK.

### Memakai token

```http
Authorization: Bearer <token>
```

Skema `Bearer` wajib ditulis. Header berisi token telanjang ditolak `401`.

### Masa berlaku

Token berlaku **24 jam** sejak diterbitkan. **Tidak ada refresh token dan tidak ada endpoint perpanjangan** — saat kedaluwarsa, satu-satunya jalan adalah login ulang.

Perlakukan `401` sebagai sinyal tunggal: hapus token tersimpan, kembalikan pengguna ke layar login, jangan coba ulang permintaan dengan token yang sama.

> ℹ️ **Perubahan akun berlaku seketika**
>
> Server mengambil ulang data akun dari database pada **setiap** permintaan, bukan mempercayai isi token. Akun yang dinonaktifkan atau dipindahkan kecamatannya langsung berubah perilakunya tanpa menunggu token kedaluwarsa, jadi aplikasi harus siap menerima `403` di tengah sesi yang tadinya berjalan normal.

---

## Bentuk response

Seluruh endpoint KOK memakai satu amplop yang sama. Tidak ada pengecualian, jadi cukup satu parser.

```json
{
  "success": true,
  "message": "Berhasil mengambil data.",
  "scope": {
    "subdistrict_id": 1728,
    "subdistrict_name": "Garut Kota",
    "district_id": 126,
    "district_name": "Garut"
  },
  "meta": { "limit": 25, "offset": 0, "total": 361 },
  "data": []
}
```

| Bagian | Isi |
|---|---|
| `success` | Boolean. Ada di response sukses **dan** gagal |
| `message` | Kalimat berbahasa Indonesia, aman ditampilkan ke pengguna |
| `scope` | Kecamatan yang sedang dilihat. Selalu ada di setiap response sukses |
| `meta` | Paging dan catatan. Hanya pada endpoint daftar |
| `data` | Array untuk daftar, object untuk detail. Tidak pernah berganti tipe |

> ℹ️ **Penamaan wilayah**
>
> `subdistrict` berarti **kecamatan**, `district` berarti **kabupaten/kota**. Konsisten di seluruh API, termasuk di dalam `secretariat` dan `domicile`.

### Paging

| Parameter | Default | Batas |
|---|---|---|
| `limit` | `25` | 1–100 |
| `offset` | `0` | ≥ 0 |

Berbasis offset, bukan halaman. Nilai di luar batas **dijepit, bukan ditolak**: `limit=99999` menjadi `100`, `limit=-5` dan `limit=abc` menjadi `25`, `offset=abc` menjadi `0`. Permintaan tetap `200`.

`meta.total` adalah jumlah seluruh baris yang cocok, bukan jumlah baris yang dikirim. Hitung sendiri jumlah halaman dari `total` dan `limit`.

### Bentuk gagal

```json
{
  "success": false,
  "message": "Endpoint ini hanya dapat diakses oleh akun KOK.",
  "error_code": "NOT_KOK"
}
```

Bercabanglah pada `error_code`, jangan pada teks `message` — teksnya bisa berubah, kodenya tidak.

> ⚠️ **Status code menang**
>
> Library REST yang dipakai server punya jalur error internal sendiri yang tidak memakai amplop di atas. Periksa HTTP status code lebih dulu, baru `success`.

---

## Profil & ringkasan

```http
GET /profile
```

*Tersaring otomatis ke kecamatan akun · tanpa parameter*

Layar pertama aplikasi. Mengembalikan identitas akun, kecamatan yang dipegang, dan ringkasan seluruh cakupan data — cukup untuk mengisi dashboard tanpa memanggil endpoint lain.

```json
{
  "success": true,
  "message": "Berhasil mengambil data.",
  "scope": {
    "subdistrict_id": 1714,
    "subdistrict_name": "Blubur Limbangan",
    "district_id": 126,
    "district_name": "Garut"
  },
  "data": {
    "member": {
      "id": 560,
      "username": "kt.bllimbangan",
      "name": "ADMIN KONTINGEN BL.LIMBANGAN",
      "email": null,
      "type": "admin_kok",
      "status": 1,
      "status_label": "Aktif"
    },
    "kontingen": { "id": 3, "code": "KGPK-0044", "name": "Balubur Limbangan" },
    "summary": {
      "total_cabor": 17,
      "total_cabor_from_club": 0,
      "total_cabor_from_athlete": 17,
      "total_club": 0,
      "total_athlete": 159,
      "total_athlete_without_club": 159
    },
    "data_notes": [ "…" ]
  }
}
```

| Field `summary` | Arti |
|---|---|
| `total_cabor` | Gabungan unik cabor dari club **dan** atlet. Ini angka yang ditampilkan ke pengguna |
| `total_cabor_from_club` | Cabor yang punya club di kecamatan ini |
| `total_cabor_from_athlete` | Cabor yang punya atlet berdomisili di kecamatan ini |
| `total_club` | Club yang beralamat sekretariat di kecamatan ini |
| `total_athlete` | Atlet yang berdomisili di kecamatan ini |
| `total_athlete_without_club` | Bagian dari `total_athlete` yang belum tercatat di club mana pun |

`total_cabor` **bukan** penjumlahan dua kolom di bawahnya — satu cabor bisa muncul di keduanya. Jangan menghitungnya sendiri di aplikasi.

`kontingen` bisa `null` kalau akun belum punya baris kontingen; hanya untuk ditampilkan, tidak dipakai menyaring data. `data_notes` adalah array kalimat siap tampil yang menjelaskan batasan data — render apa adanya, jangan hardcode jumlah atau urutannya.

---

## Cabang olahraga

```http
GET /cabor
```

*Diturunkan dari club dan atlet di kecamatan — cabor tidak punya kecamatan sendiri*

| Parameter | Nilai | Default |
|---|---|---|
| `limit` | 1–100 | `25` |
| `offset` | ≥ 0 | `0` |
| `source` | `all \| club \| athlete` | `all` |
| `sort` | `name \| code \| athlete \| club` | `name` |

```json
{
  "meta": {
    "limit": 1, "offset": 0, "total": 32,
    "source": "all",
    "derived_from": "club_or_athlete",
    "note": "Cabor tidak memiliki data kecamatan sendiri; …"
  },
  "data": [
    {
      "id": 9,
      "code": "KGCB-0010",
      "name": "ARUNG JERAM",
      "group_name": "FAJI",
      "logo": null,
      "status": 1,
      "status_label": "Aktif",
      "total_club": 0,
      "total_athlete": 15
    }
  ]
}
```

### Kenapa daftarnya diturunkan

Cabor adalah data tingkat kabupaten — di database ia **tidak punya kolom kecamatan**. Jadi “cabor di kecamatan ini” disusun server dari dua arah: cabor yang punya club di sini, digabung dengan cabor yang punya atlet berdomisili di sini.

> ⚠️ **Jangan pakai source=club sebagai default**
>
> Perbedaannya besar dan bukan kasus tepi. Untuk Blubur Limbangan, `source=club` mengembalikan **0 cabor** padahal kecamatan itu punya 159 atlet yang tersebar di 17 cabor. Layarnya akan terlihat rusak di banyak kecamatan.

- **Blubur Limbangan** — **0 / 17** — dari club / dari atlet · union 17
- **Garut Kota** — **5 / 31** — dari club / dari atlet · union 32

`total_club` dan `total_athlete` dihitung **dalam kecamatan ini saja**, jadi aman ditampilkan sebagai angka di kartu cabor. Nilai `0` pada `total_club` itu wajar. `logo` bernilai `null` kalau belum diunggah — siapkan gambar pengganti.

---

## Club

```http
GET /club
GET /club/detail/{id}
```

*Milik kecamatan berdasarkan `alamat sekretariat`, bukan tempat latihan*

| Parameter | Nilai | Default |
|---|---|---|
| `limit` | 1–100 | `25` |
| `offset` | ≥ 0 | `0` |
| `id_cabor` | integer | — |
| `status` | `0 \| 1 \| 2 \| 3` | semua status |
| `search` | nama & kode, maks 100 karakter | — |
| `sort` | `name \| code \| since \| status` | `name` |

Kalau `status` tidak dikirim, **semua status ikut tampil** — termasuk club yang belum aktif.

```json
{
  "meta": { "limit": 1, "offset": 0, "total": 10 },
  "data": [
    {
      "id": 29,
      "code": "KGCL-0029",
      "name": "BAJA FIGHT ACADEMY",
      "logo": "https://sicabor.test/alassets/upload/logo/baja_fight_academy-logo.png",
      "cabor": { "id": 22, "code": "KGCB-0023", "name": "MUAYTHAI" },
      "head_name": "Djaka umaran",
      "phone": "089630325024",
      "email": "bajafight@gmail.com",
      "since": "2022",
      "no_sk": "",
      "status": 0,
      "status_label": "Belum Aktif",
      "secretariat": {
        "address": "Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman",
        "subdistrict_id": 1728,
        "subdistrict_name": "Garut Kota",
        "district_id": 126,
        "district_name": "Kabupaten Garut"
      },
      "total_athlete_in_club": 0
    }
  ]
}
```

> ⚠️ **total_athlete_in_club tidak dibatasi kecamatan**
>
> Angka ini menjawab “berapa atlet terdaftar di club ini”, termasuk atlet yang berdomisili di kecamatan lain — karena club-nya sendiri sudah dipastikan milik kecamatan pengguna. Itu sebabnya namanya berbeda dari `total_athlete` pada endpoint cabor, yang justru dibatasi kecamatan. Jangan menjumlahkan keduanya.

### Detail club

Seluruh field daftar, ditambah:

| Field | Isi |
|---|---|
| `training` | Alamat tempat latihan, struktur sama dengan `secretariat` |
| `file_sk` | URL berkas SK, `null` kalau belum diunggah |
| `officials` | Blok official club |
| `coaches` | Blok pelatih club |
| `management` | Blok kepengurusan club |

Alamat latihan bisa berada di **kecamatan berbeda** dari sekretariat. Kalau aplikasi menampilkan kecamatan club, ambil dari `secretariat` — itu yang menentukan kepemilikan. Pada endpoint detail, `data` berupa **object**, bukan array.

Ada satu club yang kolom kecamatannya kosong di database. Club itu tidak akan muncul di kecamatan mana pun — bukan bug aplikasi, melainkan data yang belum dilengkapi di sisi admin.

---

## Official, pelatih & kepengurusan

```http
GET /club/official/{id}
GET /club/coach/{id}
GET /club/management/{id}
```

*Club divalidasi milik kecamatan lebih dulu · tersedia juga sebagai blok di `/club/detail`*

> ⚠️ **Baca sebelum membangun layarnya**
>
> Ketiga endpoint sudah aktif dan kontraknya final, tetapi dua di antaranya mengembalikan daftar kosong — bukan karena kesalahan, melainkan karena sistem **belum mencatat data tersebut**.

| Blok | `data_available` | Sumber | Catatan |
|---|---|---|---|
| `officials` | `false` | — | Belum ada tabel official club di sistem |
| `coaches` | `false` | Data pelatih | Query sudah nyata; masih 0 baris di seluruh sistem |
| `management` | `true` | Nama ketua club | Baru satu orang, ditandai `partial` |

### Saat data belum ada

```json
{
  "success": true,
  "message": "Data official club belum tercatat di sistem.",
  "meta": {
    "limit": 25, "offset": 0, "total": 0,
    "data_available": false,
    "reason": "NOT_RECORDED_IN_SYSTEM"
  },
  "data": []
}
```

Statusnya tetap `200` dengan `success: true`. Daftar kosong di sini adalah jawaban yang sah, bukan kegagalan.

### Saat kepengurusan terisi

```json
{
  "meta": {
    "total": 1,
    "data_available": true,
    "partial": true,
    "source": "club.head_name"
  },
  "data": [
    {
      "id": null,
      "name": "Djaka umaran",
      "role": "Ketua",
      "phone": "089630325024",
      "email": "bajafight@gmail.com",
      "photo": null,
      "source": "club.head_name"
    }
  ]
}
```

`id` sengaja `null` — orang ini tidak punya baris sendiri di sistem, namanya tersimpan sebagai teks pada data club. Jangan jadikan `id` sebagai kunci daftar.

### Yang harus ditampilkan aplikasi

- **`data_available: false`** — tampilkan “Belum tercatat di sistem”. Kondisi ini permanen sampai data mulai diisi; jangan tampilkan tombol muat ulang atau pesan galat.
- **`data_available: true` tetapi `data` kosong** setelah penyaringan — barulah itu hasil pencarian yang nihil.
- **`partial: true`** — beri keterangan bahwa daftarnya belum lengkap. Satu nama ketua tanpa penjelasan akan terbaca seolah club itu memang hanya punya satu pengurus.

> ℹ️ **Saat datanya nanti terisi**
>
> Kontrak URL dan bentuk response **tidak akan berubah**. Yang berubah hanya isi `data` dan nilai `data_available`. Aplikasi yang sudah menangani kedua keadaan di atas tidak perlu dirilis ulang.

---

## Atlet

```http
GET /athlete
GET /athlete/detail/{id}
```

*Berdasarkan `domisili` atlet, bukan lokasi club-nya*

| Parameter | Nilai | Default |
|---|---|---|
| `limit` | 1–100 | `25` |
| `offset` | ≥ 0 | `0` |
| `id_cabor` | integer | — |
| `id_club` | integer | — |
| `sex` | `l \| p` | — |
| `status` | `0 \| 1 \| 2 \| 3` | semua status |
| `search` | nama, kode & NIK | — |
| `sort` | `name \| code \| datecreated` | `name` |

```json
{
  "meta": {
    "limit": 1, "offset": 0, "total": 361,
    "scope_basis": "athlete_domicile",
    "note": "Daftar ini berisi atlet yang berdomisili di kecamatan ini. …"
  },
  "data": [
    {
      "id": 2375,
      "code": "KGAT-002281",
      "name": "Abimanyu Alfathir Kumara",
      "sex": "l",
      "sex_label": "Laki-Laki",
      "pob": "Garut",
      "dob": "2005-08-03",
      "age": 21,
      "photo": "https://sicabor.test/alassets/upload/profile/…jpg",
      "status": 1,
      "status_label": "Aktif",
      "cabor": { "id": 15, "code": "KGCB-0016", "name": "PANJAT TEBING" },
      "club": null,
      "domicile": {
        "subdistrict_id": 1728,
        "subdistrict_name": "Garut Kota",
        "district_id": 126,
        "district_name": "Kabupaten Garut",
        "village": "mUARA SANDING"
      }
    }
  ]
}
```

`photo` selalu berisi URL — kalau atlet belum mengunggah foto, server mengembalikan avatar bawaan, bukan `null`. `club` bernilai `null` untuk sebagian besar atlet.

### Filter `id_club`

Saat `id_club` dikirim, `meta` mendapat blok tambahan:

```json
"filter_warning": {
  "code": "CLUB_MEMBERSHIP_SPARSE",
  "message": "Keanggotaan club pada data atlet belum lengkap. …"
}
```

Dua hal terjadi sekaligus di filter ini, dan keduanya memangkas hasil:

1. Keanggotaan club pada data atlet **hampir belum terisi**.
2. Keanggotaan club **melintasi batas kecamatan** — anggota yang berdomisili di kecamatan lain tidak akan muncul, karena pengguna KOK memang tidak boleh melihat warga kecamatan lain.

> ⚠️ **Tampilkan spanduk, bukan layar kosong**
>
> Akibatnya `/athlete?id_club=X` hampir selalu mengembalikan angka lebih kecil daripada `total_athlete_in_club` pada endpoint club. Itu perilaku yang benar, tetapi bukan yang diharapkan orang — tanpa penjelasan, pengguna akan menyimpulkan aplikasinya rusak.

### Detail atlet

Seluruh field daftar, ditambah `phone`, `email`, `height`, `weight`, `blood_type`, dan `address`. `data` berupa **object**. Atlet dari kecamatan lain dijawab `404` `ATHLETE_NOT_FOUND`, sama seperti atlet yang memang tidak ada.

---

## Kode error

| HTTP | error_code | Arti | Tindakan di aplikasi |
|---|---|---|---|
| `401` | `INVALID_TOKEN` | Token tidak ada, rusak, kedaluwarsa, atau tanpa skema `Bearer` | Hapus token, arahkan ke login. Jangan coba ulang |
| `403` | `MEMBER_NOT_FOUND` | Akun pemilik token sudah tidak ada | Paksa logout |
| `403` | `MEMBER_INACTIVE` | Akun dinonaktifkan | Paksa logout, tampilkan `message` |
| `403` | `NOT_KOK` | Akun valid tetapi bukan akun KOK | Paksa logout — aplikasi ini bukan untuknya |
| `403` | `NO_SUBDISTRICT` | Akun KOK belum punya kecamatan | Tampilkan `message` apa adanya. Jangan coba ulang |
| `404` | `CLUB_NOT_FOUND` | Club tidak ada, **atau** bukan milik kecamatan pengguna | Tampilkan “tidak ditemukan” |
| `404` | `ATHLETE_NOT_FOUND` | Atlet tidak ada, **atau** bukan milik kecamatan pengguna | Tampilkan “tidak ditemukan” |
| `404` | `NOT_FOUND` | Segmen URL tidak dikenal | Bug di aplikasi — periksa penulisan URL |
| `405` | — | Metode HTTP salah | Bug di aplikasi. Semua endpoint hanya menerima `GET` |

> ℹ️ **404 dipakai secara sengaja**
>
> Server tidak membedakan “tidak ada” dari “ada tapi bukan punyamu”, karena membedakannya akan membocorkan keberadaan data tersebut. Jangan menampilkan pesan bernada “Anda tidak punya akses” untuk kasus ini.

`401` berarti masalah pada token dan selalu berujung login ulang. `403` berarti tokennya sah tetapi akunnya tidak berhak — login ulang dengan akun yang sama tidak akan menolong.

`NO_SUBDISTRICT` belum pernah terjadi pada data saat ini karena semua akun KOK sudah punya kecamatan. Tetap tangani — akun baru yang dibuat tanpa kecamatan akan memicunya.

---

## Batasan data

Empat hal berikut bukan kekurangan API, melainkan keadaan data di sistem. Semuanya akan terlihat oleh pengguna, jadi lebih baik dijelaskan di antarmuka daripada dibiarkan terbaca sebagai kerusakan.

### Atlet tanpa kecamatan tidak muncul di mana pun

Sebagian atlet belum mengisi kecamatan pada profilnya. Mereka tidak masuk ke daftar kecamatan mana pun — bukan hanya tak terlihat oleh satu KOK, tetapi oleh seluruh KOK. Kalau jumlah atlet seluruh kecamatan dijumlahkan, hasilnya lebih kecil daripada jumlah atlet di sistem.

### Keanggotaan club hampir belum terisi

- `club` pada data atlet bernilai `null` untuk sebagian besar baris
- `total_athlete_in_club` bernilai `0` untuk banyak club yang sebenarnya aktif
- filter `id_club` mengembalikan sangat sedikit hasil

Jangan menjadikan club sebagai jalur navigasi utama menuju atlet. Jalur yang andal adalah lewat cabor atau lewat daftar atlet langsung.

### Keanggotaan club melintasi kecamatan

| Angka | Cakupan |
|---|---|
| `total_athlete_in_club` | Seluruh anggota club, lintas kecamatan |
| `meta.total pada /athlete?id_club=X` | Hanya anggota yang berdomisili di kecamatan pengguna |

Kalau keduanya ditampilkan berdampingan tanpa keterangan, pengguna akan menganggapnya tidak konsisten.

### Cabor tidak punya kecamatan sendiri

Daftar cabor **diturunkan** dari club dan atlet, bukan diambil dari kolom kecamatan pada cabor. Karena itu `total_cabor` pada `/profile` bisa berubah ketika ada atlet baru didaftarkan, meski tidak ada cabor baru yang dibuat.

---

## Jebakan integrasi

### Periksa `Content-Type` sebelum `JSON.parse`

URL yang salah ketik **tidak selalu mengembalikan JSON**. Server memakai halaman 404 bawaan aplikasi web, yang berupa HTML. Endpoint KOK sudah menangkap sebagian besar kasus dan menjawabnya dengan JSON `NOT_FOUND`, tetapi salah ketik pada bagian awal URL — misalnya `api/v1/koks/…` — tidak pernah sampai ke kodenya.

Kalau `Content-Type` bukan `application/json`, perlakukan sebagai kesalahan konfigurasi URL, bukan kesalahan data.

### Parameter wilayah diabaikan, bukan ditolak

Mengirim `subdistrict_id`, `district_id`, atau nama serupa tidak berpengaruh apa pun. Server tidak pernah membacanya; cakupan selalu diambil dari akun yang login, dan permintaan tetap `200` dengan data kecamatan pengguna sendiri. Untuk menguji kecamatan lain, pakai akun KOK kecamatan tersebut.

### Nilai di luar batas dijepit, bukan ditolak

`limit`, `offset`, `sort`, `source`, `sex`, dan `status` tidak pernah menyebabkan galat — nilai tak dikenal jatuh ke default secara diam-diam. Konsekuensinya: salah tulis nama parameter **tidak akan ketahuan** dari response. Kalau hasil penyaringan terasa aneh, periksa ejaan parameternya lebih dulu.

### Tidak ada pembatasan laju

Server belum menerapkan rate limit; batas `limit` maksimum 100 adalah satu-satunya rem. Hindari memanggil endpoint daftar di dalam perulangan atau pada setiap ketikan pencarian — beri jeda pada kotak pencarian, dan muat halaman berikutnya hanya saat pengguna menggulir.

### Selalu gunakan HTTPS

Permintaan ke `http://` dijawab redirect `301`, dan sebagian HTTP client menghilangkan header `Authorization` saat mengikuti redirect. Di lingkungan lokal sertifikatnya belum tepercaya sehingga pengujian manual memakai `curl -k` — jangan menonaktifkan verifikasi sertifikat di build yang dirilis.

### Daftar periksa sebelum rilis

- [ ] `401` memicu logout, bukan percobaan ulang
- [ ] `403 NOT_KOK` ditangani terpisah dari `401`
- [ ] `404` pada detail tampil sebagai “tidak ditemukan”, bukan “tidak punya akses”
- [ ] `data_available: false` tampil sebagai “belum tercatat”, bukan layar kosong biasa
- [ ] `filter_warning` memunculkan spanduk penjelasan
- [ ] `partial: true` pada kepengurusan diberi keterangan
- [ ] Respons non-JSON ditangani sebelum `JSON.parse`
- [ ] Verifikasi sertifikat tetap aktif di build rilis

---

*SICABOR KONI Garut · API KOK v1 · read-only* · `api/v1/kok`

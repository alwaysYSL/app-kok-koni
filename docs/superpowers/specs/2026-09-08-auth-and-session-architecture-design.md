# Desain Arsitektur Autentikasi & Manajemen Sesi Aplikasi KOK

Tanggal: 2026-09-08  
Status: Proposed  
Penulis: Pair Programming (Antigravity & User)  
Dokumen Rujukan: [docs/audit-auth.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth.md) (Temuan F-01 s/d F-13, Roadmap Tahap A)

---

## 1. Latar Belakang & Tujuan

Berdasarkan audit komprehensif pada `docs/audit-auth.md`, implementasi autentikasi saat ini pada aplikasi memiliki beberapa kelemahan fundamental:
- State sesi hanya berupa boolean sederhana (`Notifier<bool>`) di `lib/core/session.dart`.
- Kredensial dan profil pengurus di-*hardcode* di dalam kode UI (`'DEMO-001'`, `'kokgarut123'`, `"Pak Asep"`, `"Kecamatan Garut Kota"`).
- Sesi tidak disimpan di penyimpanan native aman (*secure storage*), dan tidak membedakan antara fitur "Ingat nomor SK" dengan "Tetap Masuk (Persistensi Sesi)".
- Cache data olahraga (`snapshotProvider`) tidak terikat pada identitas sesi; jika pengguna keluar atau berganti akun, cache lama masih dapat terbaca dan respons *in-flight* yang terlambat dapat menghidupkan kembali data akun sebelumnya.
- Tombol keluar (*logout*) pada `ProfilePage` ditempatkan di dalam callback sukses `DataView`; jika data gagal dimuat karena gangguan jaringan, pengguna terperangkap dan tidak dapat keluar.

### Tujuan Utama (Tahap A Roadmap Audit)
1. **Memisahkan Batasan Autentikasi (Decouple Auth Boundary)**: Menghadirkan abstraksi domain `UserPrincipal`, `AuthState`, dan kontrak `AuthRepository` yang independen dari data olahraga.
2. **Penyimpanan Kredensial Aman**: Memasang `flutter_secure_storage` dengan enkripsi hardware untuk token sesi terversi, serta memisahkan `SharedPreferences` khusus teks nomor SK yang diingat.
3. **Multi-Akun & Isolasi Cache Berbasis Sesi**: Menyediakan preset akun multi-kecamatan (Garut Kota dan Tarogong Kidul) dengan dataset olahraga mock yang berbeda, sehingga pergantian akun terbukti membersihkan cache lama dan membatalkan request yang sedang berjalan melalui *session generation counter*.
4. **Alur Startup & Pemulihan Gangguan (Non-generik)**: Menghadirkan layar *Bootstrapping* kustom (`/session`) dan layar pemulihan *Unavailable* kustom (`/session-unavailable`) dengan gaya visual KOK yang elegan.
5. **Kesiapan Integrasi SICABOR (Tahap B & C)**: Ketika API backend SICABOR siap, aplikasi cukup mengimplementasikan `SicaborHttpAuthRepository` tanpa merombak UI, router guard, maupun manajemen state.

---

## 2. Prinsip Desain & Batasan Global

1. **Konsistensi UI & Tipografi**:
   - Seluruh teks pada komponen antarmuka memiliki ukuran font $\ge 12\text{px}$ (tidak ada teks di bawah 12px).
   - Warna teks judul kartu utama menggunakan `KokColors.cardTitle` (`#141414`) dari `lib/core/theme.dart`.
   - Tombol kembali konsisten menggunakan `Icons.chevron_left` dengan `size: 28` dan warna `KokColors.cardTitle`.
   - Latar visual khas KOK menggunakan gradien Navy dan busur konsentris `BrandHeaderPatternPainter`.
2. **Keamanan Kredensial & Pesan Error (OWASP)**:
   - Tidak ada pesan error yang membocorkan keberadaan nomor SK (*prevent user enumeration*). Pesan kegagalan login selalu generik: *"Nomor SK atau kata sandi tidak sesuai"*.
   - Password controller dibungkus `AutofillGroup` dan dibersihkan saat submit selesai.
3. **Isolasi Cache Penuh**:
   - Setiap pergantian akun atau proses logout menaikkan nilai `generation counter` secara atomik.
   - `snapshotProvider` bergantung pada `SessionScope` (`userId`, `districtId`, `generation`). Respons dari generasi sebelumnya langsung diabaikan.

---

## 3. Struktur Modul & File

Modul autentikasi ditata dengan struktur Clean Architecture yang modular:

```
lib/
  ├── core/
  │    ├── auth/
  │    │    ├── domain/
  │    │    │    ├── user_principal.dart      # Model identitas & hak akses pengurus
  │    │    │    ├── auth_state.dart          # State machine siklus sesi
  │    │    │    └── auth_failure.dart        # Model error autentikasi
  │    │    ├── data/
  │    │    │    ├── auth_token_storage.dart  # Abstraksi & implementasi flutter_secure_storage
  │    │    │    ├── remembered_sk_store.dart # Penyimpanan nomor SK di SharedPreferences
  │    │    │    ├── auth_repository.dart     # Interface kontrak repository autentikasi
  │    │    │    └── demo_auth_repository.dart# Adapter multi-akun & simulasi mode kegagalan
  │    │    └── presentation/
  │    │         ├── auth_controller.dart     # State notifier pengelola sesi & generation
  │    │         ├── session_startup_page.dart     # Layar custom bootstrap (/session)
  │    │         └── session_unavailable_page.dart # Layar custom gangguan sesi (/session-unavailable)
  │    └── theme.dart
  ├── data/
  │    └── repository.dart                    # Pembaruan SessionScope & dataset per kecamatan
  ├── features/
  │    ├── login_page.dart                    # Form login aman + Quick Demo Account picker
  │    ├── profile_page.dart                  # Pemisahan profil & logout di luar DataView
  │    └── home_page.dart                     # Salam & wilayah dinamis dari UserPrincipal
  └── app.dart                                # Router guard GoRouter berbasis AuthState
```

---

## 4. Rincian Teknis Komponen

### 4.1 Domain Model & State

#### `UserPrincipal` (`lib/core/auth/domain/user_principal.dart`)
```dart
class UserPrincipal {
  final String id;
  final String skNumber;
  final String name;
  final String role;
  final String districtId;
  final String districtName;
  final Set<String> permissions;

  const UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.name,
    required this.role,
    required this.districtId,
    required this.districtName,
    required this.permissions,
  });

  bool hasPermission(String permission) => permissions.contains(permission);
}
```

#### `AuthState` (`lib/core/auth/domain/auth_state.dart`)
Mewakili siklus hidup sesi aplikasi secara diskrit:
- `AuthBootstrapping`: Aplikasi baru dibuka dan sedang memeriksa token sesi di `FlutterSecureStorage`.
- `AuthSignedOut`: Pengguna tidak memiliki sesi aktif (belum login atau telah logout).
- `AuthSigningIn`: Request login sedang diverifikasi (tombol form dinonaktifkan, indikator proses aktif).
- `AuthSignedIn`: Sesi aktif terverifikasi, memuat properti `UserPrincipal user`, `int generation`, dan opsional `String? token`.
- `AuthTemporarilyUnavailable`: Gangguan jaringan/server saat bootstrapping atau refresh token, memuat `String message` dan boolean `canRetry`.
- `AuthSigningOut`: Proses pembersihan sesi lokal, token, dan pembatalan request sedang berlangsung.

---

### 4.2 Lapisan Data & Penyimpanan Token

#### `AuthTokenStorage` (`lib/core/auth/data/auth_token_storage.dart`)
- Menggunakan paket `flutter_secure_storage: ^9.2.4`.
- Konfigurasi Android: `AndroidOptions(encryptedSharedPreferences: true)`.
- Konfigurasi iOS: `IOSOptions(accessibility: KeychainAccessibility.first_unlock)`.
- Key penyimpanan terisolasi dan terversi: `'v1_kok_refresh_token'`.
- Menangani potensi hardware Keystore failure tanpa menyebabkan crash aplikasi.

#### `RememberedSkStore` (`lib/core/auth/data/remembered_sk_store.dart`)
- Menggunakan `SharedPreferences` untuk menyimpan string `remembered_sk`.
- Terpisah secara tegas dari token sesi rahasia.

---

### 4.3 Kontrak Repository & Implementasi Multi-Akun

#### `AuthRepository` (`lib/core/auth/data/auth_repository.dart`)
```dart
abstract class AuthRepository {
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  });

  Future<AuthResult> restoreSession();

  Future<AuthResult> refreshToken(String refreshToken);

  Future<void> logout();
}
```

#### `DemoAuthRepository` (`lib/core/auth/data/demo_auth_repository.dart`)
Menyediakan akun multi-kecamatan dan simulasi kegagalan:

| Nomor SK | Kata Sandi | Pengurus & Wilayah | Peran & Hak Akses | Keterangan Uji |
|---|---|---|---|---|
| `DEMO-001` | `kokgarut123` | **Pak Asep** · Kec. Garut Kota (`garut_kota`) | Koordinator · Read-All, Export | Dataset Garut Kota (5 Cabor, 125 Atlet) |
| `DEMO-002` | `koktarogong123` | **Pak Cecep** · Kec. Tarogong Kidul (`tarogong_kidul`) | Koordinator · Read-All | Dataset Tarogong Kidul (4 Cabor, 88 Atlet) |
| `DEMO-003` | `konigarut123` | **Ibu Rina** · KONI Kab. Garut (`koni_kab`) | Verifikator · Read & Verify | Dataset Tingkat Kabupaten |
| `DEMO-TIMEOUT` | `timeout123` | - | - | Simulasi Network Timeout (503) $\rightarrow$ Uji `/session-unavailable` |
| *Lainnya* | *Sembarang* | - | - | Mengembalikan Pesan Generik: *"Nomor SK atau kata sandi tidak sesuai"* |

---

### 4.4 Isolasi Cache & Multi-District Mock Data

#### `SessionScope` & Adaptasi `lib/data/repository.dart`
```dart
class SessionScope {
  final String userId;
  final String districtId;
  final int generation;

  const SessionScope({
    required this.userId,
    required this.districtId,
    required this.generation,
  });
}

final sessionScopeProvider = Provider<SessionScope?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is AuthSignedIn) {
    return SessionScope(
      userId: authState.user.id,
      districtId: authState.user.districtId,
      generation: authState.generation,
    );
  }
  return null;
});
```

`KokRepository` membedakan fixture data berdasarkan `districtId`:
- `garut_kota`: 5 cabor (Silat, Bulu Tangkis, Sepak Bola, Bola Voli, Renang), 5 klub, 125 atlet (PS Mandala, PB Kota Intan, dll.).
- `tarogong_kidul`: 4 cabor (Sepak Bola, Bulu Tangkis, Pencak Silat, Bola Voli), 4 klub, 88 atlet (Tarogong Kidul Utama FC, PB Surya Tarogong, dll.).
- `koni_kab`: Agregat kabupaten.

Jika pengguna logout (`sessionScope == null`), provider data membatalkan pembacaan. Saat akun berganti, perbedaan `generation` dan `districtId` secara otomatis membuang cache lama dan memuat data yang sesuai.

---

### 4.5 Router Guard & Lifecycle State Navigasi (`lib/app.dart`)

GoRouter `redirect` memantau `authControllerProvider`:
```dart
redirect: (context, state) {
  final authState = ref.read(authControllerProvider);
  final isGoingToSession = state.matchedLocation == '/session';
  final isGoingToUnavailable = state.matchedLocation == '/session-unavailable';
  final isGoingToLogin = state.matchedLocation == '/login';

  if (authState is AuthBootstrapping) {
    return isGoingToSession ? null : '/session';
  }

  if (authState is AuthTemporarilyUnavailable) {
    return isGoingToUnavailable ? null : '/session-unavailable';
  }

  if (authState is AuthSignedOut) {
    return isGoingToLogin ? null : '/login';
  }

  if (authState is AuthSignedIn) {
    if (isGoingToLogin || isGoingToSession || isGoingToUnavailable) {
      return '/home';
    }
    return null;
  }

  return null;
}
```

---

### 4.6 Desain Komponen UI (Khas KOK & Teks $\ge 12\text{px}$)

#### 1. Layar Bootstrapping (`SessionStartupPage` · `/session`)
- Latar Navy KOK dengan busur konsentris `BrandHeaderPatternPainter`.
- Logo & Badge KOK/KONI Garut.
- Judul: *"SISTEM INFORMASI KOORDINATOR"* (16sp bold putih).
- Subjudul: *"Kecamatan Garut Kota · KONI Kabupaten Garut"* (13sp putih 80%).
- Indikator pemuatan halus dengan teks *"Memverifikasi sesi aman..."* (12sp).

#### 2. Layar Gangguan Sesi (`SessionUnavailablePage` · `/session-unavailable`)
- Kartu status elevasi putih bersih di atas latar abu-abu terang `KokColors.background`.
- Ikon status peringatan koneksi `Icons.wifi_off_rounded` dengan latar kuning keemasan.
- Judul: *"Koneksi Sesi Terganggu"* (18sp bold `KokColors.cardTitle`).
- Deskripsi: *"Aplikasi tidak dapat memvalidasi token sesi Anda ke server. Silakan periksa koneksi internet perangkat Anda atau masuk kembali."* (13sp).
- Tombol Utama: *"Coba Hubungkan Kembali"* (Navy solid 48px, 14sp bold).
- Tombol Sekunder: *"Masuk Ulang / Ganti Akun"* (Outlined 48px, 14sp bold).

#### 3. Pembaruan Layar Login (`LoginPage`)
- Pembungkusan form dalam `AutofillGroup`.
- Toggle visibilitas kata sandi.
- Checkbox 1: *"Ingat nomor SK di perangkat ini"* (area sentuh $\ge 44\text{px}$).
- Checkbox 2: *"Tetap Masuk"* (persistensi token sesi terenkripsi).
- Helper Cepat Akun Demo (Bottom Sheet untuk memilih Pak Asep Garut Kota, Pak Cecep Tarogong Kidul, atau Simulasi Timeout dengan satu ketukan).
- Banner peringatan merah muda jika kredensial tidak sesuai (teks 12.5sp).

#### 4. Pembaruan Layar Profil (`ProfilePage`)
- Kartu Identitas Pengurus di-render langsung dari `ref.watch(currentUserProvider)`, menampilkan nama, jabatan, nomor SK, dan wilayah kerja.
- Tombol **"Keluar dari Akun"** dan Kartu Keamanan ditempatkan di luar `DataView`. Jika pemuatan snapshot olahraga error, pengguna tetap dapat logout kapan saja.
- Dialog konfirmasi keluar: *"Apakah Anda yakin ingin keluar dari sesi [Nama]?"* (tombol Batal & Keluar).

#### 5. Pembaruan Layar Beranda (`HomePage`)
- Teks salam: *"Selamat Datang, [Nama Pengurus] · [Peran]"* dan badge wilayah memanggil `userPrincipal.districtName`.
- Ringkasan lisensi kedaluwarsa menghitung secara dinamis klub dan cabor yang terdampak tanpa hardcode.

---

## 5. Rencana Pengujian (Testing Strategy)

### 5.1 Unit Tests
- `test/auth_token_storage_test.dart`:
  - Penyimpanan, pembacaan, dan pembersihan token `v1_kok_refresh_token`.
  - Ketahanan terhadap exception native keystore.
- `test/auth_repository_test.dart`:
  - Login berhasil untuk akun Garut Kota (`DEMO-001`) dan Tarogong Kidul (`DEMO-002`).
  - Login gagal mengembalikan pesan generik tanpa membocorkan status nomor SK.
  - Simulasi timeout (`DEMO-TIMEOUT`) mengembalikan `AuthFailure.networkTimeout`.
  - Restore sesi dan pembersihan token saat logout.
- `test/auth_controller_test.dart`:
  - Transisi state: `Bootstrapping` $\rightarrow$ `SignedOut`, `SignedIn`, atau `TemporarilyUnavailable`.
  - Kenaikan `_sessionGeneration` saat login dan saat logout.
  - Pembatalan in-flight requests saat logout.
- `test/session_scope_test.dart`:
  - Tes regresi audit: *Mengingat nomor SK di SharedPreferences tidak membuka sesi secara otomatis*.
  - Pergantian akun memperbarui `SessionScope` dan mengisolasi dataset olahraga antar kecamatan.

### 5.2 Widget Tests
- `test/session_startup_page_test.dart`:
  - Verifikasi elemen visual KOK, busur konsentris, teks judul & subjudul, serta ukuran font $\ge 12\text{px}$.
- `test/session_unavailable_page_test.dart`:
  - Verifikasi kartu alert, ketukan *"Coba Hubungkan Kembali"* memanggil retry, dan ketukan *"Masuk Ulang"* memicu logout.
- `test/login_page_test.dart`:
  - Verifikasi form autofill, toggle password, checkbox "Ingat nomor SK", checkbox "Tetap Masuk", dan pemilih cepat akun demo.
- `test/profile_page_test.dart`:
  - Verifikasi profil pengguna dirender dari `currentUserProvider`.
  - Verifikasi tombol keluar tetap aktif dan dapat ditekan **saat data snapshot olahraga gagal dimuat**.
  - Verifikasi dialog konfirmasi keluar.
- `test/home_page_test.dart`:
  - Verifikasi salam dan nama wilayah dinamis dari `UserPrincipal`.

### 5.3 End-to-End Integration Tests (`test/app_test.dart`)
- **Alur 1 (Siklus Standar)**: Buka aplikasi $\rightarrow$ `/session` $\rightarrow$ `/login` $\rightarrow$ login Pak Asep $\rightarrow$ Beranda Garut Kota $\rightarrow$ Profil $\rightarrow$ Keluar $\rightarrow$ kembali ke `/login`.
- **Alur 2 (Multi-Akun & Isolasi Cache)**: Login Pak Asep (Garut Kota, 5 Cabor, 125 Atlet) $\rightarrow$ Logout $\rightarrow$ Login Pak Cecep (Tarogong Kidul, 4 Cabor, 88 Atlet) $\rightarrow$ verifikasi Beranda & Cabor menampilkan data Tarogong Kidul murni tanpa residu Garut Kota.
- **Alur 3 (Pemulihan Sesi Tersimpan)**: Simpan refresh token di storage $\rightarrow$ luncurkan aplikasi $\rightarrow$ verifikasi aplikasi langsung masuk ke Beranda tanpa menampilkan layar login.
- **Alur 4 (Penanganan Gangguan Sesi)**: Login menggunakan akun timeout $\rightarrow$ diarahkan ke `/session-unavailable` $\rightarrow$ pilih *"Masuk Ulang"* $\rightarrow$ kembali ke `/login`.

### 5.4 Golden Previews
- Memperbarui `test/preview_test.dart` untuk merekam visual resolusi tinggi:
  - `previews/session_startup.png`
  - `previews/session_unavailable.png`
  - `previews/login.png`

---

## 6. Verifikasi & Tolok Ukur Keberhasilan

1. `flutter analyze` menghasilkan **0 issues**.
2. Seluruh rangkaian pengujian unit, widget, dan integrasi (`flutter test`) lulus **100%**.
3. Golden previews berhasil ditangkap dan menampilkan desain UI khas KOK yang rapi dan konsisten.
4. Seluruh teks pada komponen UI baru maupun hasil modifikasi berukuran $\ge 12\text{px}$.
5. Seluruh temuan audit P0 & P1 pada [docs/audit-auth.md](file:///f:/Kuliah%20Bullshit/KP/Kerja-Praktik-Koni-KOK/docs/audit-auth.md) terselesaikan secara arsitektural.

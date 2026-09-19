sealed class AuthFailure {
  final String message;
  const AuthFailure(this.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.message = 'Username atau kata sandi tidak sesuai.',
  ]);
}

class NetworkTimeoutFailure extends AuthFailure {
  const NetworkTimeoutFailure([
    super.message =
        'Koneksi ke server autentikasi terputus. Silakan coba lagi.',
  ]);
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([
    super.message = 'Sesi Anda telah kedaluwarsa. Silakan masuk kembali.',
  ]);
}

class StorageErrorFailure extends AuthFailure {
  const StorageErrorFailure([
    super.message = 'Penyimpanan sesi lokal mengalami kendala.',
  ]);
}

class AccountNotKokFailure extends AuthFailure {
  const AccountNotKokFailure([
    super.message = 'Akun ini bukan akun KOK dan tidak memiliki akses.',
  ]);
}

class AccountInactiveFailure extends AuthFailure {
  const AccountInactiveFailure([
    super.message = 'Akun Anda berstatus non-aktif. Hubungi admin SICABOR.',
  ]);
}

class NoSubdistrictFailure extends AuthFailure {
  const NoSubdistrictFailure([
    super.message =
        'Akun belum memiliki kecamatan yang terdaftar. Hubungi admin.',
  ]);
}

class MemberNotFoundFailure extends AuthFailure {
  const MemberNotFoundFailure([
    super.message = 'Data akun anggota tidak ditemukan pada sistem SICABOR.',
  ]);
}

class ProfileFetchFailedFailure extends AuthFailure {
  const ProfileFetchFailedFailure([
    super.message = 'Gagal memuat data profil akun dari server.',
  ]);
}

sealed class AuthFailure {
  final String message;
  const AuthFailure(this.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.message = 'Nomor SK atau kata sandi tidak sesuai.',
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

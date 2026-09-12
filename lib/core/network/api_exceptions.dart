sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType: $message';
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Sesi tidak sah'])
    : super(message, statusCode: 401);
}

final class ForbiddenException extends ApiException {
  const ForbiddenException([String message = 'Akses ditolak'])
    : super(message, statusCode: 403);
}

final class NotFoundException extends ApiException {
  const NotFoundException([String message = 'Data tidak ditemukan'])
    : super(message, statusCode: 404);
}

final class NetworkOfflineException extends ApiException {
  const NetworkOfflineException([String message = 'Tidak ada koneksi'])
    : super(message);
}

final class ServerErrorException extends ApiException {
  const ServerErrorException(String message, {int? statusCode})
    : super(message, statusCode: statusCode);
}

final class TimeoutException extends ApiException {
  const TimeoutException([String message = 'Request timeout']) : super(message);
}

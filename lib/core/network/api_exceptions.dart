sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType: $message';
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Sesi tidak sah'])
    : super(statusCode: 401);
}

final class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Akses ditolak'])
    : super(statusCode: 403);
}

final class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Data tidak ditemukan'])
    : super(statusCode: 404);
}

final class NetworkOfflineException extends ApiException {
  const NetworkOfflineException([super.message = 'Tidak ada koneksi']);
}

final class ServerErrorException extends ApiException {
  const ServerErrorException(super.message, {super.statusCode});
}

final class TimeoutException extends ApiException {
  const TimeoutException([super.message = 'Request timeout']);
}

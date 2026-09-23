import '../core/network/api_exceptions.dart';

final class RemoteErrorPresentation {
  const RemoteErrorPresentation(this.message, {required this.canRetry});
  final String message;
  final bool canRetry;

  @override
  String toString() =>
      'RemoteErrorPresentation(message: $message, canRetry: $canRetry)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteErrorPresentation &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          canRetry == other.canRetry;

  @override
  int get hashCode => Object.hash(message, canRetry);
}

RemoteErrorPresentation describeRemoteError(Object error) {
  if (error is ForbiddenException) {
    if (error.errorCode == 'NO_SUBDISTRICT') {
      final text = error.serverMessage ?? error.message;
      return RemoteErrorPresentation(
        '$text Hubungi admin kabupaten.',
        canRetry: false,
      );
    }
    return RemoteErrorPresentation(
      error.serverMessage ?? error.message,
      canRetry: false,
    );
  }
  if (error is ApiTimeoutException ||
      error is NetworkOfflineException ||
      error is ServerErrorException) {
    return const RemoteErrorPresentation(
      'Koneksi ke server terganggu.',
      canRetry: true,
    );
  }
  if (error is ApiConfigurationException) {
    return RemoteErrorPresentation(error.message, canRetry: false);
  }
  if (error is NotFoundException) {
    return RemoteErrorPresentation(error.message, canRetry: false);
  }
  if (error is ApiException) {
    return RemoteErrorPresentation(error.message, canRetry: true);
  }
  return const RemoteErrorPresentation('Gagal memuat data.', canRetry: true);
}

import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';

final class RemoteSessionHandle {
  const RemoteSessionHandle._(this._revocationToken);
  final String _revocationToken;

  factory RemoteSessionHandle(String token) {
    if (token.trim().isEmpty || token.length > 8192) {
      throw const FormatException('Remote session handle tidak valid');
    }
    return RemoteSessionHandle._(token);
  }

  @override
  String toString() => 'RemoteSessionHandle([REDACTED])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteSessionHandle &&
          other._revocationToken == _revocationToken;

  @override
  int get hashCode => _revocationToken.hashCode;
}

enum RemoteRevocationStatus { revoked, notApplicable, failed }

final class RemoteRevocationResult {
  const RemoteRevocationResult(this.status, [this.message]);
  final RemoteRevocationStatus status;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteRevocationResult &&
          other.status == status &&
          other.message == message;

  @override
  int get hashCode => Object.hash(status, message);
}

class AuthResult {
  final UserPrincipal? user;
  final String? accessToken;
  final String? refreshToken;
  final RemoteSessionHandle? sessionHandle;
  final AuthFailure? failure;

  const AuthResult.success({
    required UserPrincipal this.user,
    this.accessToken,
    this.refreshToken,
    RemoteSessionHandle? sessionHandle,
    RemoteSessionHandle? remoteHandle,
  }) : sessionHandle = sessionHandle ?? remoteHandle,
       failure = null;

  const AuthResult.failed(AuthFailure this.failure)
    : user = null,
      accessToken = null,
      refreshToken = null,
      sessionHandle = null;

  bool get isSuccess => user != null;

  RemoteSessionHandle? get session => sessionHandle;
  RemoteSessionHandle? get remoteHandle => sessionHandle;
}

abstract interface class AuthRepository {
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  });

  Future<AuthResult> restoreSession(String refreshToken);

  Future<AuthResult> refreshToken(String refreshToken);

  Future<RemoteRevocationResult> revokeSession(RemoteSessionHandle session);
}

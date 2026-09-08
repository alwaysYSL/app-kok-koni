import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';

class AuthResult {
  final UserPrincipal? user;
  final String? accessToken;
  final AuthFailure? failure;

  const AuthResult.success({required UserPrincipal this.user, this.accessToken})
      : failure = null;

  const AuthResult.failed(AuthFailure this.failure)
      : user = null,
        accessToken = null;

  bool get isSuccess => user != null;
}

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

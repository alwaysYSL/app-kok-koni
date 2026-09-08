import 'user_principal.dart';

sealed class AuthState {
  const AuthState();
}

class AuthBootstrapping extends AuthState {
  const AuthBootstrapping();
}

class AuthSignedOut extends AuthState {
  final String? errorMessage;
  const AuthSignedOut({this.errorMessage});
}

class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

class AuthSignedIn extends AuthState {
  final UserPrincipal user;
  final int generation;
  final String? accessToken;

  const AuthSignedIn({
    required this.user,
    required this.generation,
    this.accessToken,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSignedIn &&
          user == other.user &&
          generation == other.generation &&
          accessToken == other.accessToken;

  @override
  int get hashCode => user.hashCode ^ generation.hashCode ^ accessToken.hashCode;
}

class AuthTemporarilyUnavailable extends AuthState {
  final String reason;
  final bool canRetry;

  const AuthTemporarilyUnavailable({
    required this.reason,
    this.canRetry = true,
  });
}

class AuthSigningOut extends AuthState {
  const AuthSigningOut();
}

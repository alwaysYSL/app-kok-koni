import '../data/session_metadata_store.dart';
import 'user_principal.dart';

export '../data/session_metadata_store.dart' show LocalCleanupStatus;

sealed class AuthState {
  const AuthState();
}

class AuthBootstrapping extends AuthState {
  const AuthBootstrapping();
}

class AuthSignedOut extends AuthState {
  final String? errorMessage;
  final LocalCleanupStatus cleanupStatus;

  const AuthSignedOut({
    this.errorMessage,
    this.cleanupStatus = LocalCleanupStatus.clean,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSignedOut &&
          runtimeType == other.runtimeType &&
          errorMessage == other.errorMessage &&
          cleanupStatus == other.cleanupStatus;

  @override
  int get hashCode => Object.hash(errorMessage, cleanupStatus);
}

class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

final class AuthSignedIn extends AuthState {
  final UserPrincipal user;
  final int generation;

  const AuthSignedIn({required this.user, required this.generation});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSignedIn &&
          user == other.user &&
          generation == other.generation;

  @override
  int get hashCode => Object.hash(user, generation);
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

import '../core/auth/domain/user_principal.dart';
import 'models.dart';
import 'request_cancellation.dart';

final class UnsupportedScopeException implements Exception {
  const UnsupportedScopeException(this.scope);
  final AccessScope scope;

  @override
  String toString() =>
      'UnsupportedScopeException: ${scope.type.name}:${scope.id}';
}

abstract interface class KokRepository {
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  });
}

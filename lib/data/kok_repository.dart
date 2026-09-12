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

final class KokResourceNotFoundException implements Exception {
  const KokResourceNotFoundException(this.resourceType, this.id);

  final String resourceType;
  final String id;

  @override
  String toString() => 'KokResourceNotFoundException: $resourceType:$id';
}

abstract interface class KokRepository {
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  });

  Future<List<Club>> fetchClubs(
    AccessScope scope, {
    String? sport,
    String? query,
    RequestCancellation? cancellation,
  });

  Future<Club> fetchClubDetail(
    String clubId, {
    RequestCancellation? cancellation,
  });

  Future<List<SportPerson>> fetchClubMembers(
    String clubId, {
    String? role,
    RequestCancellation? cancellation,
  });

  Future<SportPerson> fetchPersonDetail(
    String personId, {
    RequestCancellation? cancellation,
  });

  Future<List<CommitteeMember>> fetchCommittee(
    AccessScope scope, {
    RequestCancellation? cancellation,
  });

  Future<HelpdeskContact?> fetchHelpdesk({RequestCancellation? cancellation});
}

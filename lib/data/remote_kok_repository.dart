import '../core/network/api_client.dart';
import '../core/auth/domain/user_principal.dart';
import 'kok_repository.dart';
import 'models.dart';
import 'request_cancellation.dart';

final class RemoteKokRepository implements KokRepository {
  RemoteKokRepository(this._client);

  final ApiClient _client;
  ApiClient get client => _client;

  static UnimplementedError _notConfigured() => UnimplementedError(
    'Endpoint SICABOR belum dikonfigurasi; dokumentasi endpoint belum tersedia.',
  );

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) => Future<KokSnapshot>.error(_notConfigured());

  @override
  Future<List<Club>> fetchClubs(
    AccessScope scope, {
    String? sport,
    String? query,
    RequestCancellation? cancellation,
  }) => Future<List<Club>>.error(_notConfigured());

  @override
  Future<Club> fetchClubDetail(
    String clubId, {
    RequestCancellation? cancellation,
  }) => Future<Club>.error(_notConfigured());

  @override
  Future<List<SportPerson>> fetchClubMembers(
    String clubId, {
    String? role,
    RequestCancellation? cancellation,
  }) => Future<List<SportPerson>>.error(_notConfigured());

  @override
  Future<SportPerson> fetchPersonDetail(
    String personId, {
    RequestCancellation? cancellation,
  }) => Future<SportPerson>.error(_notConfigured());

  @override
  Future<List<CommitteeMember>> fetchCommittee(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) => Future<List<CommitteeMember>>.error(_notConfigured());

  @override
  Future<HelpdeskContact?> fetchHelpdesk({RequestCancellation? cancellation}) =>
      Future<HelpdeskContact?>.error(_notConfigured());
}

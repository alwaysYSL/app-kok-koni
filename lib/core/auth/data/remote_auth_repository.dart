import '../../network/api_client.dart';
import 'auth_repository.dart';

final class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._client);

  final ApiClient _client;
  ApiClient get client => _client;

  static UnimplementedError _notConfigured() => UnimplementedError(
    'Endpoint SICABOR belum dikonfigurasi; dokumentasi endpoint belum tersedia.',
  );

  @override
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  }) => Future<AuthResult>.error(_notConfigured());

  @override
  Future<AuthResult> restoreSession(String refreshToken) =>
      Future<AuthResult>.error(_notConfigured());

  @override
  Future<AuthResult> refreshToken(String refreshToken) =>
      Future<AuthResult>.error(_notConfigured());

  @override
  Future<RemoteRevocationResult> revokeSession(RemoteSessionHandle session) =>
      Future<RemoteRevocationResult>.error(_notConfigured());
}

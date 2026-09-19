import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/remote_auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/remote_kok_repository.dart';
import 'package:kok_app/core/auth/data/secure_key_val_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final client = ApiClient(
    profile: _remoteProfile,
    tokens: AuthSessionTokens(),
    dio: Dio(),
  );

  test('RemoteAuthRepository revokeSession returns notApplicable', () async {
    final repository = RemoteAuthRepository(
      dio: Dio(),
      profile: _remoteProfile,
    );

    final result = await repository.revokeSession(RemoteSessionHandle('session'));
    expect(result.status, RemoteRevocationStatus.notApplicable);
  });

  test(
    'RemoteKokRepository fail-closed pada seluruh operasi granular',
    () async {
      final repository = RemoteKokRepository(client);
      const scope = AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      );

      await expectLater(
        repository.fetchScope(scope),
        throwsA(isA<UnimplementedError>()),
      );
      await expectLater(
        repository.fetchClubs(scope),
        throwsA(isA<UnimplementedError>()),
      );
      await expectLater(
        repository.fetchClubDetail('club'),
        throwsA(isA<UnimplementedError>()),
      );
      await expectLater(
        repository.fetchClubMembers('club'),
        throwsA(isA<UnimplementedError>()),
      );
      await expectLater(
        repository.fetchPersonDetail('person'),
        throwsA(isA<UnimplementedError>()),
      );
      await expectLater(
        repository.fetchCommittee(scope),
        throwsA(isA<UnimplementedError>()),
      );
      await expectLater(
        repository.fetchHelpdesk(),
        throwsA(isA<UnimplementedError>()),
      );
    },
  );

  test(
    'staging remote composition membangun adapter remote dan api client',
    () async {
      SharedPreferences.setMockInitialValues({});
      final composition = AppComposition.fromProfile(
        _remoteProfile,
        preferences: await SharedPreferences.getInstance(),
        secureStore: _SecureStore(),
      );

      expect(composition.authRepository, isA<RemoteAuthRepository>());
      expect(composition.kokRepository, isA<RemoteKokRepository>());
      expect(composition.apiClient, isNotNull);
      expect(
        (composition.kokRepository as RemoteKokRepository).client,
        same(composition.apiClient),
      );
    },
  );
}

const _remoteProfile = DeploymentProfile(
  environment: AppEnv.staging,
  authMode: AuthMode.remote,
  dataMode: DataMode.remote,
  apiBaseUrl: 'https://api.example.test',
);

final class _SecureStore implements SecureKeyValStore {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<bool> containsKey({required String key}) async => false;
}

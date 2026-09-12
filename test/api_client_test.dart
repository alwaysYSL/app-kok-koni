import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/request_cancellation.dart';

void main() {
  test('remote profile menolak base URL kosong atau timeout non-positif', () {
    expect(
      () => const DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
      ).validate(),
      throwsStateError,
    );
    expect(
      () => const DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
        apiBaseUrl: 'https://api.example.test',
        connectTimeout: Duration.zero,
      ).validate(),
      throwsStateError,
    );
  });

  test('ApiClient inject bearer dan me-refresh sekali setelah 401', () async {
    final tokens = AuthSessionTokens()
      ..replace(accessToken: 'access-old', refreshToken: 'refresh-1');
    var requestCount = 0;
    var refreshCount = 0;
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter((options) async {
        requestCount++;
        if (requestCount == 1) {
          expect(options.headers['Authorization'], 'Bearer access-old');
          return ResponseBody.fromString(
            '',
            401,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        expect(options.headers['Authorization'], 'Bearer access-new');
        return ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final client = ApiClient(
      profile: _remoteProfile,
      tokens: tokens,
      refreshSession: (refreshToken) async {
        refreshCount++;
        expect(refreshToken, 'refresh-1');
        return _authSuccess(
          accessToken: 'access-new',
          refreshToken: 'refresh-2',
        );
      },
      dio: dio,
    );

    final response = await client.request<Map<String, dynamic>>(
      '/health',
      method: 'GET',
    );

    expect(response.data, {'ok': true});
    expect(refreshCount, 1);
    expect(tokens.refreshToken, 'refresh-2');
  });

  test(
    'ApiClient menggabungkan concurrent 401 ke satu refresh flight',
    () async {
      final tokens = AuthSessionTokens()
        ..replace(accessToken: 'access-old', refreshToken: 'refresh-1');
      final refreshGate = Completer<void>();
      var refreshCount = 0;
      var requestCount = 0;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          requestCount++;
          if (requestCount <= 2) {
            return ResponseBody.fromString(
              '',
              401,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            '{"ok":true}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = ApiClient(
        profile: _remoteProfile,
        tokens: tokens,
        refreshSession: (refreshToken) async {
          refreshCount++;
          await refreshGate.future;
          return _authSuccess(
            accessToken: 'access-new',
            refreshToken: refreshToken,
          );
        },
        dio: dio,
      );

      final first = client.request<Map<String, dynamic>>('/one', method: 'GET');
      final second = client.request<Map<String, dynamic>>(
        '/two',
        method: 'GET',
      );
      await Future<void>.delayed(Duration.zero);
      refreshGate.complete();

      await Future.wait([first, second]);
      expect(refreshCount, 1);
    },
  );

  test('ApiClient mempertahankan cancellation domain exception', () async {
    final controller = RequestCancellationController()..cancel('stop');
    final client = ApiClient(
      profile: _remoteProfile,
      tokens: AuthSessionTokens(),
      refreshSession: (_) async => _authSuccess(accessToken: 'unused'),
      dio: Dio(),
    );

    expect(
      () => client.request<void>(
        '/cancelled',
        method: 'GET',
        cancellation: controller.token,
      ),
      throwsA(isA<RequestCancelledException>()),
    );
  });

  test('ApiClient memetakan status HTTP dan error jaringan', () async {
    final statuses = <int, Type>{
      403: ForbiddenException,
      404: NotFoundException,
      500: ServerErrorException,
    };
    for (final entry in statuses.entries) {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) async => ResponseBody.fromString('', entry.key),
        );
      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        refreshSession: (_) async => _authSuccess(accessToken: 'unused'),
        dio: dio,
      );

      expect(
        () => client.request<void>('/status', method: 'GET'),
        throwsA(predicate((error) => error.runtimeType == entry.value)),
      );
    }
  });
}

const _remoteProfile = DeploymentProfile(
  environment: AppEnv.staging,
  authMode: AuthMode.remote,
  dataMode: DataMode.remote,
  apiBaseUrl: 'https://api.example.test',
);

AuthResult _authSuccess({required String accessToken, String? refreshToken}) {
  return AuthResult.success(
    user: UserPrincipal(
      id: 'u',
      skNumber: 'sk',
      fullName: 'User',
      roleTitle: 'Coordinator',
      scope: const AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      ),
    ),
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
}

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

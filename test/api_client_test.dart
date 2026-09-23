import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test(
    'ApiClient menyertakan Authorization Bearer jika token tersedia dan skipAuth false',
    () async {
      final tokens = AuthSessionTokens()
        ..replace(accessToken: 'test-token-123');
      RequestOptions? capturedOptions;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          capturedOptions = options;
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
        dio: dio,
      );

      final response = await client.request<Map<String, dynamic>>(
        '/data',
        method: 'GET',
      );

      expect(response.data, {'ok': true});
      expect(
        capturedOptions?.headers['Authorization'],
        'Bearer test-token-123',
      );
    },
  );

  test(
    'ApiClient tidak menyertakan Authorization jika skipAuth true',
    () async {
      final tokens = AuthSessionTokens()
        ..replace(accessToken: 'test-token-123');
      RequestOptions? capturedOptions;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          capturedOptions = options;
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
        dio: dio,
      );

      await client.request<Map<String, dynamic>>(
        '/public',
        method: 'GET',
        skipAuth: true,
      );

      expect(capturedOptions?.headers.containsKey('Authorization'), isFalse);
    },
  );

  test(
    'ApiClient melempar UnauthorizedException langsung saat menerima 401 tanpa retry',
    () async {
      final tokens = AuthSessionTokens()..replace(accessToken: 'expired-token');
      var requestCount = 0;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          requestCount++;
          return ResponseBody.fromString(
            '{"success":false,"message":"Sesi berakhir","error_code":"INVALID_TOKEN"}',
            401,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: tokens,
        dio: dio,
      );

      await expectLater(
        client.request<Map<String, dynamic>>('/protected', method: 'GET'),
        throwsA(
          isA<UnauthorizedException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.errorCode, 'errorCode', 'INVALID_TOKEN')
              .having((e) => e.message, 'message', 'Sesi berakhir')
              .having((e) => e.serverMessage, 'serverMessage', 'Sesi berakhir'),
        ),
      );

      expect(requestCount, 1);
    },
  );

  test(
    'ApiClient memetakan 403 dan mengekstrak error_code ke ForbiddenException',
    () async {
      final tokens = AuthSessionTokens()..replace(accessToken: 'active-token');
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"success":false,"message":"Hanya admin KOK","error_code":"NOT_KOK"}',
            403,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: tokens,
        dio: dio,
      );

      await expectLater(
        client.request<Map<String, dynamic>>('/admin-only', method: 'GET'),
        throwsA(
          isA<ForbiddenException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.errorCode, 'errorCode', 'NOT_KOK')
              .having((e) => e.message, 'message', 'Hanya admin KOK')
              .having(
                (e) => e.serverMessage,
                'serverMessage',
                'Hanya admin KOK',
              ),
        ),
      );
    },
  );

  test(
    'ApiClient melempar ApiConfigurationException saat 200 text/html',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '<html><body>Welcome</body></html>',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html; charset=utf-8'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<Map<String, dynamic>>('/html-200', method: 'GET'),
        throwsA(isA<ApiConfigurationException>()),
      );
    },
  );

  test(
    'ApiClient melempar ApiConfigurationException saat 200 text/html dengan body valid json',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"status": true}',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html; charset=utf-8'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<Map<String, dynamic>>(
          '/html-200-json-body',
          method: 'GET',
        ),
        throwsA(isA<ApiConfigurationException>()),
      );
    },
  );

  test(
    'ApiClient melempar ApiConfigurationException saat 404 text/html',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '<html>404 Not Found (Nginx)</html>',
            404,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/not-found-html', method: 'GET'),
        throwsA(isA<ApiConfigurationException>()),
      );
    },
  );

  test(
    'ApiClient tetap melempar UnauthorizedException saat 401 text/html (prioritas 401)',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '<html>401 Unauthorized</html>',
            401,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/unauthorized-html', method: 'GET'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    },
  );

  test(
    'ApiClient melempar NotFoundException saat 404 application/json',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"message":"Item tidak ditemukan"}',
            404,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/not-found-json', method: 'GET'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            'Item tidak ditemukan',
          ),
        ),
      );
    },
  );

  test(
    'ApiClient menangani response error non-JSON sebagai ApiConfigurationException',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '<html>502 Bad Gateway</html>',
            502,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          );
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/bad-gateway', method: 'GET'),
        throwsA(isA<ApiConfigurationException>()),
      );
    },
  );

  test('ApiClient mempertahankan cancellation domain exception', () async {
    final controller = RequestCancellationController()..cancel('stop');
    final client = ApiClient(
      profile: _remoteProfile,
      tokens: AuthSessionTokens(),
      dio: Dio(),
    );

    await expectLater(
      client.request<void>(
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
          (_) async => ResponseBody.fromString(
            '{"message":"Error"}',
            entry.key,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/status', method: 'GET'),
        throwsA(predicate((error) => error.runtimeType == entry.value)),
      );
    }
  });

  test('ApiClient memetakan 400 dan 422 ke BadRequestException', () async {
    for (final statusCode in [400, 422]) {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) async => ResponseBody.fromString(
            '{"message":"Bad request"}',
            statusCode,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/status', method: 'GET'),
        throwsA(
          isA<BadRequestException>().having(
            (e) => e.statusCode,
            'statusCode',
            statusCode,
          ),
        ),
      );
    }
  });

  test('ApiClient memetakan timeout ke ApiTimeoutException', () async {
    for (final timeoutType in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: timeoutType,
            message: 'Timeout occurred',
          );
        });
      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      await expectLater(
        client.request<void>('/timeout', method: 'GET'),
        throwsA(isA<ApiTimeoutException>()),
      );
    }
  });

  test(
    'Request cancellation saat in-flight membatalkan request Dio di wire dan melempar RequestCancelledException',
    () async {
      final controller = RequestCancellationController();
      var wireCancelTriggered = false;
      final fetchStartedCompleter = Completer<void>();
      final fetchResponseBodyCompleter = Completer<ResponseBody>();

      final dio = Dio()
        ..httpClientAdapter = _CancellableFakeAdapter((options, cancelFuture) {
          fetchStartedCompleter.complete();
          cancelFuture?.whenComplete(() {
            wireCancelTriggered = true;
          });
          return fetchResponseBodyCompleter.future;
        });

      final client = ApiClient(
        profile: _remoteProfile,
        tokens: AuthSessionTokens(),
        dio: dio,
      );

      final future = client.request<void>(
        '/long-running',
        method: 'GET',
        cancellation: controller.token,
      );

      await fetchStartedCompleter.future;
      controller.cancel('user abort');

      await expectLater(
        future.timeout(const Duration(milliseconds: 200)),
        throwsA(
          isA<RequestCancelledException>().having(
            (e) => e.reason,
            'reason',
            'user abort',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(wireCancelTriggered, isTrue);
    },
  );
}

const _remoteProfile = DeploymentProfile(
  environment: AppEnv.staging,
  authMode: AuthMode.remote,
  dataMode: DataMode.remote,
  apiBaseUrl: 'https://api.example.test',
);

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

final class _CancellableFakeAdapter implements HttpClientAdapter {
  _CancellableFakeAdapter(this.handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Future<void>? cancelFuture,
  )
  handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options, cancelFuture);

  @override
  void close({bool force = false}) {}
}

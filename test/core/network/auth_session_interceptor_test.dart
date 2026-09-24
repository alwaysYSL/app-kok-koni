import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/network/auth_session_interceptor.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';

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

void main() {
  group('AuthSessionInterceptor direct unit tests', () {
    test(
      '401 triggers callback with INVALID_TOKEN error code and server message when revision matches',
      () {
        var callbackCount = 0;
        String? receivedErrorCode;
        String? receivedServerMessage;

        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 1,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
            receivedErrorCode = errorCode;
            receivedServerMessage = serverMessage;
          },
        );

        final requestOptions = RequestOptions(
          path: '/test',
          extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
            data: {'message': 'Unauthorized token'},
          ),
        );

        var nextCalled = false;
        final handler = _TestErrorInterceptorHandler(
          onNext: (err) {
            nextCalled = true;
            expect(err, same(dioException));
          },
        );

        interceptor.onError(dioException, handler);

        expect(callbackCount, 1);
        expect(receivedErrorCode, 'INVALID_TOKEN');
        expect(receivedServerMessage, 'Unauthorized token');
        expect(nextCalled, isTrue);
      },
    );

    test(
      '401 with untagged request (requestRevision == null) does NOT trigger callback',
      () {
        var callbackCount = 0;

        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 1,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
          },
        );

        final requestOptions = RequestOptions(path: '/test');
        final dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
            data: {'message': 'Unauthorized token'},
          ),
        );

        var nextCalled = false;
        final handler = _TestErrorInterceptorHandler(
          onNext: (err) {
            nextCalled = true;
            expect(err, same(dioException));
          },
        );

        interceptor.onError(dioException, handler);

        expect(callbackCount, 0);
        expect(nextCalled, isTrue);
      },
    );

    test('401 when currentRevision == null does NOT trigger callback', () {
      var callbackCount = 0;

      final interceptor = AuthSessionInterceptor(
        onUnauthorizedSession: ({errorCode, serverMessage}) {
          callbackCount++;
        },
      );

      final requestOptions = RequestOptions(
        path: '/test',
        extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
      );
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {'message': 'Unauthorized token'},
        ),
      );

      var nextCalled = false;
      final handler = _TestErrorInterceptorHandler(
        onNext: (err) {
          nextCalled = true;
          expect(err, same(dioException));
        },
      );

      interceptor.onError(dioException, handler);

      expect(callbackCount, 0);
      expect(nextCalled, isTrue);
    });

    test('401 with custom error_code in body preserves that error code', () {
      var callbackCount = 0;
      String? receivedErrorCode;
      String? receivedServerMessage;

      final interceptor = AuthSessionInterceptor(
        currentRevisionProvider: () => 1,
        onUnauthorizedSession: ({errorCode, serverMessage}) {
          callbackCount++;
          receivedErrorCode = errorCode;
          receivedServerMessage = serverMessage;
        },
      );

      final requestOptions = RequestOptions(
        path: '/test',
        extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
      );
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {'error_code': 'CUSTOM_EXPIRED', 'message': 'Custom expired'},
        ),
      );

      var nextCalled = false;
      final handler = _TestErrorInterceptorHandler(
        onNext: (err) {
          nextCalled = true;
          expect(err, same(dioException));
        },
      );

      interceptor.onError(dioException, handler);

      expect(callbackCount, 1);
      expect(receivedErrorCode, 'CUSTOM_EXPIRED');
      expect(receivedServerMessage, 'Custom expired');
      expect(nextCalled, isTrue);
    });

    for (final code in ['MEMBER_NOT_FOUND', 'MEMBER_INACTIVE', 'NOT_KOK']) {
      test(
        '403 with sessionEndingCode $code triggers callback with errorCode and serverMessage',
        () {
          var callbackCount = 0;
          String? receivedErrorCode;
          String? receivedServerMessage;

          final interceptor = AuthSessionInterceptor(
            currentRevisionProvider: () => 1,
            onUnauthorizedSession: ({errorCode, serverMessage}) {
              callbackCount++;
              receivedErrorCode = errorCode;
              receivedServerMessage = serverMessage;
            },
          );

          final requestOptions = RequestOptions(
            path: '/test',
            extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
          );
          final dioException = DioException(
            requestOptions: requestOptions,
            response: Response(
              requestOptions: requestOptions,
              statusCode: 403,
              data: {'error_code': code, 'message': 'Forbidden member status'},
            ),
          );

          var nextCalled = false;
          final handler = _TestErrorInterceptorHandler(
            onNext: (err) {
              nextCalled = true;
              expect(err, same(dioException));
            },
          );

          interceptor.onError(dioException, handler);

          expect(callbackCount, 1);
          expect(receivedErrorCode, code);
          expect(receivedServerMessage, 'Forbidden member status');
          expect(nextCalled, isTrue);
        },
      );
    }

    test(
      '403 with sessionEndingCode on untagged request does NOT trigger callback',
      () {
        var callbackCount = 0;

        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 1,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
          },
        );

        final requestOptions = RequestOptions(path: '/test');
        final dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 403,
            data: {'error_code': 'MEMBER_NOT_FOUND', 'message': 'Forbidden'},
          ),
        );

        var nextCalled = false;
        final handler = _TestErrorInterceptorHandler(
          onNext: (err) {
            nextCalled = true;
            expect(err, same(dioException));
          },
        );

        interceptor.onError(dioException, handler);

        expect(callbackCount, 0);
        expect(nextCalled, isTrue);
      },
    );

    test(
      '403 with JSON string body containing session ending code triggers callback',
      () {
        var callbackCount = 0;
        String? receivedErrorCode;
        String? receivedServerMessage;

        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 1,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
            receivedErrorCode = errorCode;
            receivedServerMessage = serverMessage;
          },
        );

        final requestOptions = RequestOptions(
          path: '/test',
          extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 403,
            data:
                '{"error_code":"MEMBER_NOT_FOUND","message":"User not found"}',
          ),
        );

        var nextCalled = false;
        final handler = _TestErrorInterceptorHandler(
          onNext: (err) {
            nextCalled = true;
            expect(err, same(dioException));
          },
        );

        interceptor.onError(dioException, handler);

        expect(callbackCount, 1);
        expect(receivedErrorCode, 'MEMBER_NOT_FOUND');
        expect(receivedServerMessage, 'User not found');
        expect(nextCalled, isTrue);
      },
    );

    test('403 with NO_SUBDISTRICT does NOT trigger callback', () {
      var callbackCount = 0;

      final interceptor = AuthSessionInterceptor(
        onUnauthorizedSession: ({errorCode, serverMessage}) {
          callbackCount++;
        },
      );

      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 403,
          data: {'error_code': 'NO_SUBDISTRICT', 'message': 'Forbidden'},
        ),
      );

      var nextCalled = false;
      final handler = _TestErrorInterceptorHandler(
        onNext: (err) {
          nextCalled = true;
          expect(err, same(dioException));
        },
      );

      interceptor.onError(dioException, handler);

      expect(callbackCount, 0);
      expect(nextCalled, isTrue);
    });

    test(
      '403 without error code or unknown code does NOT trigger callback',
      () {
        var callbackCount = 0;

        final interceptor = AuthSessionInterceptor(
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
          },
        );

        final requestOptions = RequestOptions(path: '/test');

        // Unknown code
        var dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 403,
            data: {'error_code': 'SOME_OTHER_ERROR'},
          ),
        );
        var nextCalled = false;
        interceptor.onError(
          dioException,
          _TestErrorInterceptorHandler(onNext: (err) => nextCalled = true),
        );
        expect(callbackCount, 0);
        expect(nextCalled, isTrue);

        // No data / null data
        dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 403,
            data: null,
          ),
        );
        nextCalled = false;
        interceptor.onError(
          dioException,
          _TestErrorInterceptorHandler(onNext: (err) => nextCalled = true),
        );
        expect(callbackCount, 0);
        expect(nextCalled, isTrue);

        // String data not JSON
        dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 403,
            data: '<html>Forbidden</html>',
          ),
        );
        nextCalled = false;
        interceptor.onError(
          dioException,
          _TestErrorInterceptorHandler(onNext: (err) => nextCalled = true),
        );
        expect(callbackCount, 0);
        expect(nextCalled, isTrue);
      },
    );

    test(
      '404, 500, and network errors do NOT trigger callback and forward error',
      () {
        var callbackCount = 0;

        final interceptor = AuthSessionInterceptor(
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
          },
        );

        final requestOptions = RequestOptions(path: '/test');

        for (final status in [404, 500, 502, 503]) {
          final dioException = DioException(
            requestOptions: requestOptions,
            response: Response(
              requestOptions: requestOptions,
              statusCode: status,
              data: {'error_code': 'MEMBER_NOT_FOUND'},
            ),
          );
          var nextCalled = false;
          interceptor.onError(
            dioException,
            _TestErrorInterceptorHandler(onNext: (err) => nextCalled = true),
          );
          expect(callbackCount, 0);
          expect(nextCalled, isTrue);
        }

        // Network error (no response)
        final netException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
          message: 'No internet',
        );
        var nextCalled = false;
        interceptor.onError(
          netException,
          _TestErrorInterceptorHandler(onNext: (err) => nextCalled = true),
        );
        expect(callbackCount, 0);
        expect(nextCalled, isTrue);
      },
    );

    test('attachUnauthorizedHandler updates the handler successfully', () {
      final interceptor = AuthSessionInterceptor(
        currentRevisionProvider: () => 1,
      );
      var callbackCount = 0;
      String? lastCode;

      interceptor.attachUnauthorizedHandler(({errorCode, serverMessage}) {
        callbackCount++;
        lastCode = errorCode;
      });

      final requestOptions = RequestOptions(
        path: '/test',
        extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
      );
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      interceptor.onError(
        dioException,
        _TestErrorInterceptorHandler(onNext: (_) {}),
      );

      expect(callbackCount, 1);
      expect(lastCode, 'INVALID_TOKEN');
    });

    group('Session revision checks in AuthSessionInterceptor', () {
      test(
        'Stale request with older revision does NOT trigger callback on 401 and forwards error',
        () {
          var callbackCount = 0;
          final interceptor = AuthSessionInterceptor(
            currentRevisionProvider: () => 5,
            onUnauthorizedSession: ({errorCode, serverMessage}) {
              callbackCount++;
            },
          );

          final requestOptions = RequestOptions(
            path: '/test',
            extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 4},
          );
          final dioException = DioException(
            requestOptions: requestOptions,
            response: Response(
              requestOptions: requestOptions,
              statusCode: 401,
              data: {'message': 'Old session expired'},
            ),
          );

          var nextCalled = false;
          final handler = _TestErrorInterceptorHandler(
            onNext: (err) {
              nextCalled = true;
              expect(err, same(dioException));
            },
          );

          interceptor.onError(dioException, handler);

          expect(callbackCount, 0);
          expect(nextCalled, isTrue);
        },
      );

      test(
        'Stale request with older revision does NOT trigger callback on 403 session-ending error',
        () {
          var callbackCount = 0;
          final interceptor = AuthSessionInterceptor(
            currentRevisionProvider: () => 3,
            onUnauthorizedSession: ({errorCode, serverMessage}) {
              callbackCount++;
            },
          );

          final requestOptions = RequestOptions(
            path: '/test',
            extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
          );
          final dioException = DioException(
            requestOptions: requestOptions,
            response: Response(
              requestOptions: requestOptions,
              statusCode: 403,
              data: {
                'error_code': 'MEMBER_INACTIVE',
                'message': 'Member deactivated',
              },
            ),
          );

          var nextCalled = false;
          final handler = _TestErrorInterceptorHandler(
            onNext: (err) {
              nextCalled = true;
              expect(err, same(dioException));
            },
          );

          interceptor.onError(dioException, handler);

          expect(callbackCount, 0);
          expect(nextCalled, isTrue);
        },
      );

      test('Matching request revision DOES trigger callback on 401', () {
        var callbackCount = 0;
        String? receivedCode;
        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 3,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            callbackCount++;
            receivedCode = errorCode;
          },
        );

        final requestOptions = RequestOptions(
          path: '/test',
          extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 3},
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
            data: {'message': 'Unauthorized'},
          ),
        );

        var nextCalled = false;
        interceptor.onError(
          dioException,
          _TestErrorInterceptorHandler(
            onNext: (err) {
              nextCalled = true;
            },
          ),
        );

        expect(callbackCount, 1);
        expect(receivedCode, 'INVALID_TOKEN');
        expect(nextCalled, isTrue);
      });

      test(
        'Matching request revision with AuthSessionTokens instance DOES trigger callback',
        () {
          final tokens = AuthSessionTokens();
          tokens.replace(accessToken: 'token-1'); // revision = 1
          tokens.clear(); // revision = 2
          tokens.replace(accessToken: 'token-2'); // revision = 3

          var callbackCount = 0;
          String? receivedCode;
          final interceptor = AuthSessionInterceptor(
            tokens: tokens,
            onUnauthorizedSession: ({errorCode, serverMessage}) {
              callbackCount++;
              receivedCode = errorCode;
            },
          );

          final requestOptions = RequestOptions(
            path: '/test',
            extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 3},
          );
          final dioException = DioException(
            requestOptions: requestOptions,
            response: Response(
              requestOptions: requestOptions,
              statusCode: 403,
              data: {'error_code': 'MEMBER_NOT_FOUND'},
            ),
          );

          var nextCalled = false;
          interceptor.onError(
            dioException,
            _TestErrorInterceptorHandler(
              onNext: (err) {
                nextCalled = true;
              },
            ),
          );

          expect(callbackCount, 1);
          expect(receivedCode, 'MEMBER_NOT_FOUND');
          expect(nextCalled, isTrue);
        },
      );
    });
  });

  group('AuthSessionInterceptor Dio integration tests', () {
    test(
      'Dio request yielding 401 with matching revision triggers callback and throws DioException to caller',
      () async {
        var unauthorizedTriggered = false;
        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 1,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            unauthorizedTriggered = true;
          },
        );

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            return ResponseBody.fromString(
              '{"message":"Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          })
          ..interceptors.add(interceptor);

        await expectLater(
          dio.get<dynamic>(
            'https://example.com/api/test',
            options: Options(
              extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
            ),
          ),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        expect(unauthorizedTriggered, isTrue);
      },
    );

    test(
      'Dio request yielding 401 without session revision (untagged) does NOT trigger callback',
      () async {
        var unauthorizedTriggered = false;
        final interceptor = AuthSessionInterceptor(
          currentRevisionProvider: () => 1,
          onUnauthorizedSession: ({errorCode, serverMessage}) {
            unauthorizedTriggered = true;
          },
        );

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            return ResponseBody.fromString(
              '{"message":"Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          })
          ..interceptors.add(interceptor);

        await expectLater(
          dio.get<dynamic>('https://example.com/api/test'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        expect(unauthorizedTriggered, isFalse);
      },
    );

    test('Dio request yielding 200 does not trigger callback', () async {
      var unauthorizedTriggered = false;
      final interceptor = AuthSessionInterceptor(
        currentRevisionProvider: () => 1,
        onUnauthorizedSession: ({errorCode, serverMessage}) {
          unauthorizedTriggered = true;
        },
      );

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"status":"ok"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        })
        ..interceptors.add(interceptor);

      final response = await dio.get<dynamic>(
        'https://example.com/api/test',
        options: Options(
          extra: {AuthSessionInterceptor.sessionRevisionExtraKey: 1},
        ),
      );
      expect(response.statusCode, 200);
      expect(unauthorizedTriggered, isFalse);
    });
  });
}

class _TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  _TestErrorInterceptorHandler({required this.onNext});

  final void Function(DioException err) onNext;

  @override
  void next(DioException err) {
    onNext(err);
  }
}

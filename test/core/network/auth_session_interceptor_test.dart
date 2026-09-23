import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/network/auth_session_interceptor.dart';

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
    test('401 triggers callback without error code and forwards error', () {
      var callbackCount = 0;
      String? receivedErrorCode;

      final interceptor = AuthSessionInterceptor(
        onUnauthorizedSession: ({errorCode}) {
          callbackCount++;
          receivedErrorCode = errorCode;
        },
      );

      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {'message': 'Unauthorized'},
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
      expect(receivedErrorCode, isNull);
      expect(nextCalled, isTrue);
    });

    for (final code in ['MEMBER_NOT_FOUND', 'MEMBER_INACTIVE', 'NOT_KOK']) {
      test(
        '403 with sessionEndingCode $code triggers callback with errorCode',
        () {
          var callbackCount = 0;
          String? receivedErrorCode;

          final interceptor = AuthSessionInterceptor(
            onUnauthorizedSession: ({errorCode}) {
              callbackCount++;
              receivedErrorCode = errorCode;
            },
          );

          final requestOptions = RequestOptions(path: '/test');
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
          expect(nextCalled, isTrue);
        },
      );
    }

    test(
      '403 with JSON string body containing session ending code triggers callback',
      () {
        var callbackCount = 0;
        String? receivedErrorCode;

        final interceptor = AuthSessionInterceptor(
          onUnauthorizedSession: ({errorCode}) {
            callbackCount++;
            receivedErrorCode = errorCode;
          },
        );

        final requestOptions = RequestOptions(path: '/test');
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
        expect(nextCalled, isTrue);
      },
    );

    test('403 with NO_SUBDISTRICT does NOT trigger callback', () {
      var callbackCount = 0;

      final interceptor = AuthSessionInterceptor(
        onUnauthorizedSession: ({errorCode}) {
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
          onUnauthorizedSession: ({errorCode}) {
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
          onUnauthorizedSession: ({errorCode}) {
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
      final interceptor = AuthSessionInterceptor();
      var callbackCount = 0;

      interceptor.attachUnauthorizedHandler(({errorCode}) {
        callbackCount++;
      });

      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      interceptor.onError(
        dioException,
        _TestErrorInterceptorHandler(onNext: (_) {}),
      );

      expect(callbackCount, 1);
    });
  });

  group('AuthSessionInterceptor Dio integration tests', () {
    test(
      'Dio request yielding 401 triggers callback and throws DioException to caller',
      () async {
        var unauthorizedTriggered = false;
        final interceptor = AuthSessionInterceptor(
          onUnauthorizedSession: ({errorCode}) {
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

        expect(unauthorizedTriggered, isTrue);
      },
    );

    test('Dio request yielding 200 does not trigger callback', () async {
      var unauthorizedTriggered = false;
      final interceptor = AuthSessionInterceptor(
        onUnauthorizedSession: ({errorCode}) {
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

      final response = await dio.get<dynamic>('https://example.com/api/test');
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

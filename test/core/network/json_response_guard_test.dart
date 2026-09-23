import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/network/json_response_guard.dart';

void main() {
  group('requireJsonContentType', () {
    test('throws ApiConfigurationException when content-type is missing', () {
      final headers = Headers();
      expect(
        () => requireJsonContentType(headers),
        throwsA(isA<ApiConfigurationException>()),
      );
    });

    test('throws ApiConfigurationException when content-type is text/html', () {
      final headers = Headers.fromMap({
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      });
      expect(
        () => requireJsonContentType(headers),
        throwsA(
          isA<ApiConfigurationException>().having(
            (e) => e.message,
            'message',
            'Respons server bukan JSON. Periksa alamat API.',
          ),
        ),
      );
    });

    test(
      'throws ApiConfigurationException when content-type is text/plain',
      () {
        final headers = Headers.fromMap({
          Headers.contentTypeHeader: ['text/plain'],
        });
        expect(
          () => requireJsonContentType(headers),
          throwsA(isA<ApiConfigurationException>()),
        );
      },
    );

    test(
      'throws ApiConfigurationException when content-type is application/xml',
      () {
        final headers = Headers.fromMap({
          Headers.contentTypeHeader: ['application/xml'],
        });
        expect(
          () => requireJsonContentType(headers),
          throwsA(isA<ApiConfigurationException>()),
        );
      },
    );

    test('succeeds for application/json', () {
      final headers = Headers.fromMap({
        Headers.contentTypeHeader: ['application/json'],
      });
      expect(() => requireJsonContentType(headers), returnsNormally);
    });

    test('succeeds for application/json with charset', () {
      final headers = Headers.fromMap({
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      });
      expect(() => requireJsonContentType(headers), returnsNormally);
    });

    test(
      'succeeds for custom +json mime types (e.g. problem+json, vnd.api+json)',
      () {
        final headersProblem = Headers.fromMap({
          Headers.contentTypeHeader: ['application/problem+json'],
        });
        expect(() => requireJsonContentType(headersProblem), returnsNormally);

        final headersVnd = Headers.fromMap({
          Headers.contentTypeHeader: ['application/vnd.api+json'],
        });
        expect(() => requireJsonContentType(headersVnd), returnsNormally);
      },
    );
  });

  group('isJsonContentType', () {
    test('returns false for missing or non-json content types', () {
      expect(isJsonContentType(Headers()), isFalse);
      expect(
        isJsonContentType(
          Headers.fromMap({
            Headers.contentTypeHeader: ['text/html'],
          }),
        ),
        isFalse,
      );
      expect(
        isJsonContentType(
          Headers.fromMap({
            Headers.contentTypeHeader: ['application/octet-stream'],
          }),
        ),
        isFalse,
      );
    });

    test('returns true for JSON content types', () {
      expect(
        isJsonContentType(
          Headers.fromMap({
            Headers.contentTypeHeader: ['application/json'],
          }),
        ),
        isTrue,
      );
      expect(
        isJsonContentType(
          Headers.fromMap({
            Headers.contentTypeHeader: ['APPLICATION/JSON; charset=utf-8'],
          }),
        ),
        isTrue,
      );
      expect(
        isJsonContentType(
          Headers.fromMap({
            Headers.contentTypeHeader: ['application/geo+json'],
          }),
        ),
        isTrue,
      );
    });
  });
}

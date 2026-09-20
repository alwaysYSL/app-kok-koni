import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../scripts/mock_server/mock_data.dart';
import '../../scripts/mock_server/sicabor_mock_server.dart';

void main() {
  group('SicaborMockServer Integration Tests', () {
    late SicaborMockServer server;
    late int port;
    late HttpClient client;

    setUp(() async {
      server = SicaborMockServer();
      final httpServer = await server.start(
        host: '127.0.0.1',
        port: 0,
        verbose: false,
      );
      port = httpServer.port;
      client = HttpClient();
    });

    tearDown(() async {
      client.close();
      await server.stop();
    });

    Future<Map<String, dynamic>> login(
      String username,
      String password, {
      bool useJson = false,
    }) async {
      final req = await client.post('127.0.0.1', port, '/api/auth');
      if (useJson) {
        req.headers.contentType = ContentType('application', 'json');
        req.write(jsonEncode({'username': username, 'password': password}));
      } else {
        req.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
        req.write(
          'username=${Uri.encodeQueryComponent(username)}&password=${Uri.encodeQueryComponent(password)}',
        );
      }
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      return {
        'statusCode': res.statusCode,
        'headers': res.headers,
        'body': jsonDecode(body) as Map<String, dynamic>,
      };
    }

    test('OPTIONS requests respond with CORS headers', () async {
      final req = await client.open('OPTIONS', '127.0.0.1', port, '/api/auth');
      final res = await req.close();
      expect(res.statusCode, equals(200));
      expect(res.headers.value('access-control-allow-origin'), equals('*'));
      expect(
        res.headers.value('access-control-allow-methods'),
        contains('POST'),
      );
    });

    group('POST /api/auth', () {
      test('succeeds with x-www-form-urlencoded credentials', () async {
        final res = await login('kt.garutkota', 'password123');
        expect(res['statusCode'], equals(200));
        final body = res['body'] as Map<String, dynamic>;
        expect(body['status'], isTrue);
        expect(body['message'], equals('LOGIN SUCCESSFULLY'));
        expect(body['token'], isNotEmpty);
        expect(body['data']['username'], equals('kt.garutkota'));
        expect(body['data']['type'], equals('admin_kok'));
      });

      test('succeeds with json credentials', () async {
        final res = await login('kt.garutkota', 'password123', useJson: true);
        expect(res['statusCode'], equals(200));
        final body = res['body'] as Map<String, dynamic>;
        expect(body['status'], isTrue);
        expect(body['token'], isNotEmpty);
      });

      test('succeeds with global master password', () async {
        final res = await login(
          'kt.bllimbangan',
          MockData.globalMasterPassword,
        );
        expect(res['statusCode'], equals(200));
        final body = res['body'] as Map<String, dynamic>;
        expect(body['status'], isTrue);
        expect(body['data']['username'], equals('kt.bllimbangan'));
      });

      test('fails with wrong password', () async {
        final res = await login('kt.garutkota', 'wrong_pass');
        expect(res['statusCode'], equals(401));
        final body = res['body'] as Map<String, dynamic>;
        expect(body['status'], isFalse);
      });

      test('fails with unknown user', () async {
        final res = await login('unknown_user', 'password123');
        expect(res['statusCode'], equals(401));
        final body = res['body'] as Map<String, dynamic>;
        expect(body['status'], isFalse);
      });
    });

    group('Protected Endpoints Auth & Error Handling', () {
      test(
        'returns 401 INVALID_TOKEN when Authorization header is missing',
        () async {
          final req = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/profile',
          );
          final res = await req.close();
          expect(res.statusCode, equals(401));
          final body =
              jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
          expect(body['success'], isFalse);
          expect(body['error_code'], equals('INVALID_TOKEN'));
        },
      );

      test(
        'returns 401 INVALID_TOKEN when Authorization header has no Bearer prefix',
        () async {
          final loginRes = await login('kt.garutkota', 'password123');
          final token = loginRes['body']['token'] as String;

          final req = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/profile',
          );
          req.headers.set('Authorization', token); // missing Bearer
          final res = await req.close();
          expect(res.statusCode, equals(401));
          final body =
              jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
          expect(body['error_code'], equals('INVALID_TOKEN'));
        },
      );

      test('returns 403 NOT_KOK for non-admin_kok account', () async {
        final loginRes = await login('bukan_kok', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get('127.0.0.1', port, '/api/v1/kok/profile');
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(403));
        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isFalse);
        expect(body['error_code'], equals('NOT_KOK'));
      });

      test('returns 403 MEMBER_INACTIVE for inactive account', () async {
        final loginRes = await login('non_aktif', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get('127.0.0.1', port, '/api/v1/kok/profile');
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(403));
        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isFalse);
        expect(body['error_code'], equals('MEMBER_INACTIVE'));
      });

      test(
        'returns 403 NO_SUBDISTRICT for account without subdistrict',
        () async {
          final loginRes = await login('tanpa_kecamatan', 'password123');
          final token = loginRes['body']['token'] as String;

          final req = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/profile',
          );
          req.headers.set('Authorization', 'Bearer $token');
          final res = await req.close();
          expect(res.statusCode, equals(403));
          final body =
              jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
          expect(body['success'], isFalse);
          expect(body['error_code'], equals('NO_SUBDISTRICT'));
        },
      );
    });

    group('GET /api/v1/kok/profile', () {
      test('returns full profile and summary for valid KOK account', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get('127.0.0.1', port, '/api/v1/kok/profile');
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isTrue);
        expect(body['scope']['subdistrict_id'], equals(1728));
        expect(body['scope']['subdistrict_name'], equals('Garut Kota'));
        expect(body['data']['member']['username'], equals('kt.garutkota'));
        expect(body['data']['summary']['total_cabor'], equals(32));
        expect(body['data']['summary']['total_club'], equals(10));
        expect(body['data']['summary']['total_athlete'], equals(361));
      });
    });

    group('GET /api/v1/kok/cabor', () {
      test(
        'returns cabor list scoped to subdistrict with sorting and pagination',
        () async {
          final loginRes = await login('kt.garutkota', 'password123');
          final token = loginRes['body']['token'] as String;

          final req = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/cabor?limit=5&offset=0&sort=name',
          );
          req.headers.set('Authorization', 'Bearer $token');
          final res = await req.close();
          expect(res.statusCode, equals(200));

          final body =
              jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
          expect(body['success'], isTrue);
          expect(body['meta']['total'], equals(32));
          expect(body['meta']['limit'], equals(5));
          final list = body['data'] as List;
          expect(list.length, equals(5));
        },
      );

      test('supports source filter (source=club)', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get(
          '127.0.0.1',
          port,
          '/api/v1/kok/cabor?source=club',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['meta']['total'], equals(5));
      });
    });

    group('GET /api/v1/kok/club and details', () {
      test('returns club list for subdistrict', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get('127.0.0.1', port, '/api/v1/kok/club');
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isTrue);
        expect(body['meta']['total'], equals(10));
      });

      test('returns club detail for club in user subdistrict', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get(
          '127.0.0.1',
          port,
          '/api/v1/kok/club/detail/29',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isTrue);
        expect(body['data']['id'], equals(29));
        expect(body['data']['name'], equals('BAJA FIGHT ACADEMY'));
        expect(body['data']['training'], isNotNull);
        expect(body['data']['management'], isNotNull);
      });

      test(
        'returns 404 CLUB_NOT_FOUND for club in different subdistrict',
        () async {
          final loginRes = await login('kt.garutkota', 'password123');
          final token = loginRes['body']['token'] as String;

          // Club 50 is in Tarogong Kidul (1729), Garut Kota is 1728
          final req = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/club/detail/50',
          );
          req.headers.set('Authorization', 'Bearer $token');
          final res = await req.close();
          expect(res.statusCode, equals(404));

          final body =
              jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
          expect(body['success'], isFalse);
          expect(body['error_code'], equals('CLUB_NOT_FOUND'));
        },
      );

      test(
        'returns official and coach mock endpoints with data_available: false',
        () async {
          final loginRes = await login('kt.garutkota', 'password123');
          final token = loginRes['body']['token'] as String;

          // Official
          final reqOfficial = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/club/official/29',
          );
          reqOfficial.headers.set('Authorization', 'Bearer $token');
          final resOfficial = await reqOfficial.close();
          expect(resOfficial.statusCode, equals(200));
          final bodyOfficial =
              jsonDecode(await utf8.decodeStream(resOfficial))
                  as Map<String, dynamic>;
          expect(bodyOfficial['meta']['data_available'], isFalse);

          // Coach
          final reqCoach = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/club/coach/29',
          );
          reqCoach.headers.set('Authorization', 'Bearer $token');
          final resCoach = await reqCoach.close();
          expect(resCoach.statusCode, equals(200));
          final bodyCoach =
              jsonDecode(await utf8.decodeStream(resCoach))
                  as Map<String, dynamic>;
          expect(bodyCoach['meta']['data_available'], isFalse);

          // Management
          final reqMgmt = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/club/management/29',
          );
          reqMgmt.headers.set('Authorization', 'Bearer $token');
          final resMgmt = await reqMgmt.close();
          expect(resMgmt.statusCode, equals(200));
          final bodyMgmt =
              jsonDecode(await utf8.decodeStream(resMgmt))
                  as Map<String, dynamic>;
          expect(bodyMgmt['meta']['data_available'], isTrue);
          expect(bodyMgmt['meta']['partial'], isTrue);
        },
      );
    });

    group('GET /api/v1/kok/athlete and details', () {
      test('returns athlete list for subdistrict', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get(
          '127.0.0.1',
          port,
          '/api/v1/kok/athlete?limit=10',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isTrue);
        expect(body['meta']['total'], equals(361));
        final list = body['data'] as List;
        expect(list.length, equals(10));
      });

      test('includes filter_warning when id_club filter is passed', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get(
          '127.0.0.1',
          port,
          '/api/v1/kok/athlete?id_club=30',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['meta']['filter_warning'], isNotNull);
        expect(
          body['meta']['filter_warning']['code'],
          equals('CLUB_MEMBERSHIP_SPARSE'),
        );
      });

      test('returns athlete detail for athlete in user subdistrict', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get(
          '127.0.0.1',
          port,
          '/api/v1/kok/athlete/detail/2375',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(200));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isTrue);
        expect(body['data']['id'], equals(2375));
        expect(body['data']['height'], isNotNull);
        expect(body['data']['weight'], isNotNull);
      });

      test(
        'returns 404 ATHLETE_NOT_FOUND for athlete in another subdistrict',
        () async {
          final loginRes = await login('kt.bllimbangan', 'password123');
          final token = loginRes['body']['token'] as String;

          // 2375 is in Garut Kota (1728), Limbangan is 1714
          final req = await client.get(
            '127.0.0.1',
            port,
            '/api/v1/kok/athlete/detail/2375',
          );
          req.headers.set('Authorization', 'Bearer $token');
          final res = await req.close();
          expect(res.statusCode, equals(404));

          final body =
              jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
          expect(body['success'], isFalse);
          expect(body['error_code'], equals('ATHLETE_NOT_FOUND'));
        },
      );
    });

    group('Route edge cases & error handling', () {
      test('returns 404 NOT_FOUND for unrecognized route', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.get(
          '127.0.0.1',
          port,
          '/api/v1/kok/unknown_route',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(404));

        final body =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
        expect(body['success'], isFalse);
        expect(body['error_code'], equals('NOT_FOUND'));
      });

      test('returns 405 for wrong HTTP method on protected endpoint', () async {
        final loginRes = await login('kt.garutkota', 'password123');
        final token = loginRes['body']['token'] as String;

        final req = await client.post('127.0.0.1', port, '/api/v1/kok/profile');
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();
        expect(res.statusCode, equals(405));
      });
    });
  });
}

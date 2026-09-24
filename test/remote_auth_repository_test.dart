import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/remote_auth_repository.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';

void main() {
  const profile = DeploymentProfile(
    environment: AppEnv.staging,
    authMode: AuthMode.remote,
    dataMode: DataMode.remote,
    apiBaseUrl: 'https://sicabor.test/api/v1/kok',
  );

  const sampleLoginSuccessJson = '''
{
  "status": true,
  "message": "LOGIN SUCCESSFULLY",
  "data": {
    "id": "578",
    "username": "kt.garutkota",
    "name": "ADMIN KONTINGEN GARUT KOTA",
    "email": null,
    "type": "admin_kok"
  },
  "token": "jwt_token_sample_123"
}
''';

  const sampleProfileSuccessJson = '''
{
  "success": true,
  "message": "Berhasil mengambil data.",
  "scope": {
    "subdistrict_id": 1728,
    "subdistrict_name": "Garut Kota",
    "district_id": 126,
    "district_name": "Garut"
  },
  "data": {
    "member": {
      "id": 578,
      "username": "kt.garutkota",
      "name": "ADMIN KONTINGEN GARUT KOTA",
      "email": null,
      "type": "admin_kok",
      "status": 1,
      "status_label": "Aktif"
    },
    "kontingen": {
      "id": 1,
      "code": "KGPK-0001",
      "name": "Garut Kota"
    },
    "summary": {
      "total_cabor": 10,
      "total_cabor_from_club": 2,
      "total_cabor_from_athlete": 8,
      "total_club": 5,
      "total_athlete": 40,
      "total_athlete_without_club": 10
    },
    "data_notes": ["Catatan sinkronisasi data"]
  }
}
''';

  group('RemoteAuthRepository - login()', () {
    test('login 2-langkah sukses dengan staySignedIn = true', () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _MockHttpAdapter((options) async {
          requests.add(options);
          if (options.uri.path == '/api/auth' && options.method == 'POST') {
            expect(options.contentType, Headers.formUrlEncodedContentType);
            expect(options.data, {
              'username': 'kt.garutkota',
              'password': 'password123',
            });
            return ResponseBody.fromString(
              sampleLoginSuccessJson,
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          } else if (options.uri.path == '/api/v1/kok/profile' &&
              options.method == 'GET') {
            expect(
              options.headers['Authorization'],
              'Bearer jwt_token_sample_123',
            );
            return ResponseBody.fromString(
              sampleProfileSuccessJson,
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          return ResponseBody.fromString('Not Found', 404);
        });

      final repository = RemoteAuthRepository(dio: dio, profile: profile);

      final result = await repository.login(
        username: 'kt.garutkota',
        password: 'password123',
        staySignedIn: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.accessToken, 'jwt_token_sample_123');
      expect(result.sessionToken, 'jwt_token_sample_123');
      expect(result.sessionHandle, isNull);
      expect(result.user, isNotNull);
      expect(result.user?.id, '578');
      expect(result.user?.username, 'kt.garutkota');
      expect(result.user?.fullName, 'ADMIN KONTINGEN GARUT KOTA');
      expect(result.user?.roleTitle, 'Koordinator Kecamatan');
      expect(result.user?.scope.type, AccessScopeType.district);
      expect(result.user?.scope.id, '1728');
      expect(result.user?.scope.name, 'Garut Kota');

      expect(requests.length, 2);
    });

    test(
      'login 2-langkah sukses dengan staySignedIn = false menghasilkan sessionToken null',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              sampleProfileSuccessJson,
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isTrue);
        expect(result.accessToken, 'jwt_token_sample_123');
        expect(result.sessionToken, isNull);
        expect(result.user?.username, 'kt.garutkota');
      },
    );

    test(
      'login gagal jika respons login mengembalikan status false atau token kosong',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"status":false,"message":"Kredensial tidak valid"}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'wrong_password',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<InvalidCredentialsFailure>());
        expect(result.failure?.message, 'Kredensial tidak valid');
      },
    );

    test(
      'login gagal jika tipe akun bukan admin_kok (AccountNotKokFailure) tanpa memanggil profile',
      () async {
        var profileCalled = false;
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                '''
              {
                "status": true,
                "message": "LOGIN SUCCESS",
                "data": {
                  "id": "10",
                  "username": "cabor_silat",
                  "name": "Pengcab IPSI",
                  "type": "cabor"
                },
                "token": "token_cabor_123"
              }
              ''',
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            profileCalled = true;
            return ResponseBody.fromString('{}', 200);
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'cabor_silat',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountNotKokFailure>());
        expect(profileCalled, isFalse);
      },
    );

    test('login gagal jika endpoint login mengembalikan 401', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockHttpAdapter((options) async {
          return ResponseBody.fromString(
            '{"status":false,"message":"Username atau password salah"}',
            401,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final repository = RemoteAuthRepository(dio: dio, profile: profile);

      final result = await repository.login(
        username: 'wrong_user',
        password: 'password',
        staySignedIn: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<InvalidCredentialsFailure>());
      expect(result.failure?.message, 'Username atau password salah');
    });

    test(
      'login gagal jika endpoint login mengembalikan 403 dengan error_code',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":false,"message":"Akun non-aktif","error_code":"MEMBER_INACTIVE"}',
              403,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.inactive',
          password: 'password',
          staySignedIn: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountInactiveFailure>());
        expect(result.failure?.message, 'Akun non-aktif');
      },
    );

    test(
      'login timeout atau network error pada tahap 1 menghasilkan NetworkTimeoutFailure',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              message: 'Connection timeout',
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<NetworkTimeoutFailure>());
      },
    );

    test(
      'login gagal saat langkah 2 (profile) mengembalikan 403 NO_SUBDISTRICT',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":false,"message":"Belum ada kecamatan","error_code":"NO_SUBDISTRICT"}',
              403,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<NoSubdistrictFailure>());
        expect(result.failure?.message, 'Belum ada kecamatan');
      },
    );

    test(
      'login gagal saat langkah 2 (profile) mengembalikan 500 / ProfileFetchFailedFailure',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString('Internal Server Error', 500);
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal saat endpoint profile mengembalikan respons 200 text/html (ProfileFetchFailedFailure) tanpa menyimpan sesi',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '<html><body>Login Page</body></html>',
              200,
              headers: {
                Headers.contentTypeHeader: ['text/html; charset=utf-8'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.accessToken, isNull);
        expect(result.sessionToken, isNull);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal saat endpoint login mengembalikan 200 text/html',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '<html><body>Proxy Login Gateway</body></html>',
              200,
              headers: {
                Headers.contentTypeHeader: ['text/html'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<InvalidCredentialsFailure>());
      },
    );
  });

  group('RemoteAuthRepository - restoreSession()', () {
    test(
      'token kosong langsung mengembalikan SessionExpiredFailure tanpa request network',
      () async {
        var networkHit = false;
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            networkHit = true;
            return ResponseBody.fromString('{}', 200);
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final resultEmpty = await repository.restoreSession('');
        expect(resultEmpty.isSuccess, isFalse);
        expect(resultEmpty.failure, isA<SessionExpiredFailure>());

        final resultWhitespace = await repository.restoreSession('   ');
        expect(resultWhitespace.isSuccess, isFalse);
        expect(resultWhitespace.failure, isA<SessionExpiredFailure>());

        expect(networkHit, isFalse);
      },
    );

    test('restoreSession sukses saat GET /profile mengembalikan 200', () async {
      RequestOptions? capturedOptions;
      final dio = Dio()
        ..httpClientAdapter = _MockHttpAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            sampleProfileSuccessJson,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final repository = RemoteAuthRepository(dio: dio, profile: profile);

      final result = await repository.restoreSession('saved_session_token_xyz');

      expect(result.isSuccess, isTrue);
      expect(result.accessToken, 'saved_session_token_xyz');
      expect(result.sessionToken, 'saved_session_token_xyz');
      expect(result.user?.id, '578');
      expect(result.user?.username, 'kt.garutkota');
      expect(result.user?.fullName, 'ADMIN KONTINGEN GARUT KOTA');
      expect(result.user?.scope.id, '1728');
      expect(
        capturedOptions?.headers['Authorization'],
        'Bearer saved_session_token_xyz',
      );
      expect(capturedOptions?.uri.path, '/api/v1/kok/profile');
    });

    test(
      'restoreSession mengembalikan SessionExpiredFailure pada 401',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":false,"message":"Unauthenticated"}',
              401,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('expired_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<SessionExpiredFailure>());
      },
    );

    test(
      'restoreSession memetakan 403 NOT_KOK ke AccountNotKokFailure',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":false,"message":"Hanya untuk KOK","error_code":"NOT_KOK"}',
              403,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('token_not_kok');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountNotKokFailure>());
        expect(result.failure?.message, 'Hanya untuk KOK');
      },
    );

    test(
      'restoreSession mengembalikan NetworkTimeoutFailure saat timeout/offline',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
              message: 'Receive timeout',
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<NetworkTimeoutFailure>());
      },
    );

    test(
      'restoreSession gagal saat endpoint profile mengembalikan 200 text/html (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '<html><body>Error Portal</body></html>',
              200,
              headers: {
                Headers.contentTypeHeader: ['text/html'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );
  });

  group('RemoteAuthRepository - revokeSession()', () {
    test('revokeSession selalu mengembalikan notApplicable', () async {
      final dio = Dio();
      final repository = RemoteAuthRepository(dio: dio, profile: profile);

      final handle = RemoteSessionHandle('some_handle');
      final result = await repository.revokeSession(handle);

      expect(result.status, RemoteRevocationStatus.notApplicable);
    });
  });

  group('RemoteAuthRepository - Profile Response Validation', () {
    test(
      'login gagal jika profil tidak memiliki field scope (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":1,"total_cabor_from_club":0,"total_cabor_from_athlete":1,"total_club":0,"total_athlete":1,"total_athlete_without_club":1}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika profil tidak memiliki field data (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika data profil tidak memiliki map member (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika data profil tidak memiliki map summary (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika member.id bernilai 0 (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":0,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika member.username kosong (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"   ","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika member.name kosong (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika member.type profil bukan admin_kok (AccountNotKokFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"cabor","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountNotKokFailure>());
      },
    );

    test(
      'login gagal jika member.status profil bukan 1 (AccountInactiveFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":0,"status_label":"Nonaktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountInactiveFailure>());
      },
    );

    test(
      'login gagal jika scope.subdistrict_id bernilai 0 (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":0,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login gagal jika scope.subdistrict_name kosong (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"  ","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'restoreSession gagal jika profil tidak memiliki field scope (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":1,"total_cabor_from_club":0,"total_cabor_from_athlete":1,"total_club":0,"total_athlete":1,"total_athlete_without_club":1}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'restoreSession gagal jika member.type profil bukan admin_kok (AccountNotKokFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"cabor","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountNotKokFailure>());
      },
    );

    test(
      'restoreSession gagal jika member.status profil bukan 1 (AccountInactiveFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":0,"status_label":"Nonaktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<AccountInactiveFailure>());
      },
    );

    test(
      'restoreSession gagal jika scope.subdistrict_id bernilai 0 (ProfileFetchFailedFailure)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":0,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":0,"total_cabor_from_club":0,"total_cabor_from_athlete":0,"total_club":0,"total_athlete":0,"total_athlete_without_club":0}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'login timeout saat memanggil endpoint profile menghasilkan NetworkTimeoutFailure',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              message: 'Connection timeout on profile',
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<NetworkTimeoutFailure>());
      },
    );

    test(
      'login gagal dengan ProfileFetchFailedFailure jika tipe field profil tidak sesuai (misal: email berupa integer)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path == '/api/auth') {
              return ResponseBody.fromString(
                sampleLoginSuccessJson,
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","email":12345,"type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":10,"total_cabor_from_club":2,"total_cabor_from_athlete":8,"total_club":5,"total_athlete":40,"total_athlete_without_club":10}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );

    test(
      'restoreSession gagal dengan ProfileFetchFailedFailure jika tipe field profil tidak sesuai (misal: email berupa integer)',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _MockHttpAdapter((options) async {
            return ResponseBody.fromString(
              '{"success":true,"message":"OK","scope":{"subdistrict_id":1728,"subdistrict_name":"Garut Kota","district_id":126,"district_name":"Garut"},"data":{"member":{"id":578,"username":"kt.garutkota","name":"Admin","email":12345,"type":"admin_kok","status":1,"status_label":"Aktif"},"summary":{"total_cabor":10,"total_cabor_from_club":2,"total_cabor_from_athlete":8,"total_club":5,"total_athlete":40,"total_athlete_without_club":10}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final repository = RemoteAuthRepository(dio: dio, profile: profile);

        final result = await repository.restoreSession('valid_token');

        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<ProfileFetchFailedFailure>());
      },
    );
  });
}

final class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

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

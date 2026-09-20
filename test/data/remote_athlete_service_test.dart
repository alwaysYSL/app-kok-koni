import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/athlete_service.dart';
import 'package:kok_app/data/services/remote/remote_athlete_service.dart';

void main() {
  const deploymentProfile = DeploymentProfile(
    environment: AppEnv.staging,
    authMode: AuthMode.remote,
    dataMode: DataMode.remote,
    apiBaseUrl: 'https://api.example.test',
  );

  late AuthSessionTokens tokens;

  setUp(() {
    tokens = AuthSessionTokens()..replace(accessToken: 'mock-token-abc');
  });

  group('RemoteAthleteService', () {
    test(
      'fetchAthleteList calls GET /athlete with default parameters and returns PaginatedResult<Athlete>',
      () async {
        RequestOptions? capturedOptions;

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString(
              jsonEncode(_sampleAthleteListJson),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteAthleteService(client: apiClient);
        expect(service, isA<AthleteService>());

        final result = await service.fetchAthleteList();

        expect(capturedOptions?.path, '/athlete');
        expect(capturedOptions?.method, 'GET');
        expect(
          capturedOptions?.headers['Authorization'],
          'Bearer mock-token-abc',
        );
        expect(capturedOptions?.queryParameters, {
          'limit': 25,
          'offset': 0,
          'sort': 'name',
        });

        expect(result, isA<PaginatedResult<Athlete>>());
        expect(result.limit, 25);
        expect(result.offset, 0);
        expect(result.total, 2);
        expect(result.items.length, 2);
        expect(result.hasFilterWarning, isFalse);
        expect(result.filterWarning, isNull);

        final item1 = result.items[0];
        expect(item1.id, 2375);
        expect(item1.code, 'KGAT-002281');
        expect(item1.name, 'Abimanyu Alfathir Kumara');
        expect(item1.sex, 'l');
        expect(item1.sexLabel, 'Laki-Laki');
        expect(item1.pob, 'Garut');
        expect(item1.dob, '2005-08-03');
        expect(item1.age, 21);
        expect(item1.photoUrl, 'https://sicabor.test/photos/2375.jpg');
        expect(item1.status, 1);
        expect(item1.statusLabel, 'Aktif');
        expect(
          item1.cabor,
          const AthleteCabor(id: 15, code: 'KGCB-0016', name: 'PANJAT TEBING'),
        );
        expect(
          item1.club,
          const AthleteClub(id: 5, code: 'KLUB-0005', name: 'Voli Bina Muda'),
        );
        expect(
          item1.domicile,
          const AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
            village: 'Muara Sanding',
          ),
        );

        final item2 = result.items[1];
        expect(item2.id, 2376);
        expect(item2.code, 'KGAT-002282');
        expect(item2.name, 'Siti Nurhaliza');
        expect(item2.sex, 'p');
        expect(item2.sexLabel, 'Perempuan');
        expect(item2.pob, isNull);
        expect(item2.dob, isNull);
        expect(item2.age, isNull);
        expect(item2.photoUrl, 'https://sicabor.test/photos/default.png');
        expect(item2.status, 1);
        expect(item2.statusLabel, 'Aktif');
        expect(
          item2.cabor,
          const AthleteCabor(id: 15, code: 'KGCB-0016', name: 'PANJAT TEBING'),
        );
        expect(item2.club, isNull);
        expect(
          item2.domicile,
          const AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
            village: null,
          ),
        );
      },
    );

    test(
      'fetchAthleteList sends all optional filter and sort parameters correctly',
      () async {
        RequestOptions? capturedOptions;

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString(
              jsonEncode(_sampleAthleteListJson),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteAthleteService(client: apiClient);

        await service.fetchAthleteList(
          limit: 10,
          offset: 5,
          idCabor: 15,
          idClub: 5,
          sex: 'l',
          status: 1,
          search: 'Abimanyu',
          sort: 'datecreated',
        );

        expect(capturedOptions?.queryParameters, {
          'limit': 10,
          'offset': 5,
          'sort': 'datecreated',
          'id_cabor': 15,
          'id_club': 5,
          'sex': 'l',
          'status': 1,
          'search': 'Abimanyu',
        });
      },
    );

    test(
      'fetchAthleteList parses filter_warning from meta correctly',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            return ResponseBody.fromString(
              jsonEncode(_sampleAthleteListWithWarningJson),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteAthleteService(client: apiClient);
        final result = await service.fetchAthleteList(idClub: 5);

        expect(result.hasFilterWarning, isTrue);
        expect(
          result.filterWarningMessage,
          'Keanggotaan club pada data atlet belum lengkap.',
        );
        expect(result.filterWarning, {
          'code': 'CLUB_MEMBERSHIP_SPARSE',
          'message': 'Keanggotaan club pada data atlet belum lengkap.',
        });
      },
    );

    test(
      'fetchAthleteList forwards cancellation token and handles cancellation',
      () async {
        final cancellationController = RequestCancellationController()
          ..cancel('athlete list cancel');

        final dio = Dio();
        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteAthleteService(client: apiClient);

        expect(
          () => service.fetchAthleteList(
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('fetchAthleteList propagates ApiClient exceptions', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"message": "Server error", "error_code": "INTERNAL_SERVER_ERROR"}',
            500,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final apiClient = ApiClient(
        profile: deploymentProfile,
        tokens: tokens,
        dio: dio,
      );

      final service = RemoteAthleteService(client: apiClient);

      expect(
        () => service.fetchAthleteList(),
        throwsA(isA<ServerErrorException>()),
      );
    });

    test(
      'fetchAthleteDetail calls GET /athlete/detail/{id} and returns mapped AthleteDetail',
      () async {
        RequestOptions? capturedOptions;

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString(
              jsonEncode(_sampleAthleteDetailJson),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteAthleteService(client: apiClient);
        final result = await service.fetchAthleteDetail(2375);

        expect(capturedOptions?.path, '/athlete/detail/2375');
        expect(capturedOptions?.method, 'GET');
        expect(
          capturedOptions?.headers['Authorization'],
          'Bearer mock-token-abc',
        );

        expect(result, isA<AthleteDetail>());
        expect(result.id, 2375);
        expect(result.code, 'KGAT-002281');
        expect(result.name, 'Abimanyu Alfathir Kumara');
        expect(result.sex, 'l');
        expect(result.sexLabel, 'Laki-Laki');
        expect(result.pob, 'Garut');
        expect(result.dob, '2005-08-03');
        expect(result.age, 21);
        expect(result.photoUrl, 'https://sicabor.test/photos/2375.jpg');
        expect(result.status, 1);
        expect(result.statusLabel, 'Aktif');
        expect(
          result.cabor,
          const AthleteCabor(id: 15, code: 'KGCB-0016', name: 'PANJAT TEBING'),
        );
        expect(
          result.club,
          const AthleteClub(id: 5, code: 'KLUB-0005', name: 'Voli Bina Muda'),
        );
        expect(
          result.domicile,
          const AthleteDomicile(
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
            village: 'Muara Sanding',
          ),
        );
        expect(result.phone, '081234567890');
        expect(result.email, 'abimanyu@example.test');
        expect(result.height, 175);
        expect(result.weight, 68);
        expect(result.bloodType, 'O');
        expect(result.address, 'Jl. Merdeka No. 45');
      },
    );

    test(
      'fetchAthleteDetail forwards cancellation token and handles cancellation',
      () async {
        final cancellationController = RequestCancellationController()
          ..cancel('athlete detail cancel');

        final dio = Dio();
        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteAthleteService(client: apiClient);

        expect(
          () => service.fetchAthleteDetail(
            2375,
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('fetchAthleteDetail propagates 404 NotFoundException', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"message": "Atlet tidak ditemukan.", "error_code": "ATHLETE_NOT_FOUND"}',
            404,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final apiClient = ApiClient(
        profile: deploymentProfile,
        tokens: tokens,
        dio: dio,
      );

      final service = RemoteAthleteService(client: apiClient);

      expect(
        () => service.fetchAthleteDetail(9999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
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

const _sampleAthleteListJson = {
  'success': true,
  'message': 'Data atlet berhasil dimuat.',
  'scope': {
    'subdistrict_id': 1728,
    'subdistrict_name': 'Garut Kota',
    'district_id': 126,
    'district_name': 'Kabupaten Garut',
  },
  'meta': {
    'limit': 25,
    'offset': 0,
    'total': 2,
    'scope_basis': 'athlete_domicile',
    'note': 'Daftar ini berisi atlet yang berdomisili di kecamatan ini.',
  },
  'data': [
    {
      'id': 2375,
      'code': 'KGAT-002281',
      'name': 'Abimanyu Alfathir Kumara',
      'sex': 'l',
      'sex_label': 'Laki-Laki',
      'pob': 'Garut',
      'dob': '2005-08-03',
      'age': 21,
      'photo': 'https://sicabor.test/photos/2375.jpg',
      'status': 1,
      'status_label': 'Aktif',
      'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
      'club': {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
      'domicile': {
        'subdistrict_id': 1728,
        'subdistrict_name': 'Garut Kota',
        'district_id': 126,
        'district_name': 'Kabupaten Garut',
        'village': 'Muara Sanding',
      },
    },
    {
      'id': 2376,
      'code': 'KGAT-002282',
      'name': 'Siti Nurhaliza',
      'sex': 'p',
      'sex_label': 'Perempuan',
      'pob': null,
      'dob': null,
      'age': null,
      'photo': 'https://sicabor.test/photos/default.png',
      'status': 1,
      'status_label': 'Aktif',
      'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
      'club': null,
      'domicile': {
        'subdistrict_id': 1728,
        'subdistrict_name': 'Garut Kota',
        'district_id': 126,
        'district_name': 'Kabupaten Garut',
        'village': null,
      },
    },
  ],
};

const _sampleAthleteListWithWarningJson = {
  'success': true,
  'message': 'Data atlet berhasil dimuat.',
  'scope': {
    'subdistrict_id': 1728,
    'subdistrict_name': 'Garut Kota',
    'district_id': 126,
    'district_name': 'Kabupaten Garut',
  },
  'meta': {
    'limit': 10,
    'offset': 0,
    'total': 1,
    'filter_warning': {
      'code': 'CLUB_MEMBERSHIP_SPARSE',
      'message': 'Keanggotaan club pada data atlet belum lengkap.',
    },
  },
  'data': [
    {
      'id': 2375,
      'code': 'KGAT-002281',
      'name': 'Abimanyu Alfathir Kumara',
      'sex': 'l',
      'sex_label': 'Laki-Laki',
      'pob': 'Garut',
      'dob': '2005-08-03',
      'age': 21,
      'photo': 'https://sicabor.test/photos/2375.jpg',
      'status': 1,
      'status_label': 'Aktif',
      'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
      'club': {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
      'domicile': {
        'subdistrict_id': 1728,
        'subdistrict_name': 'Garut Kota',
        'district_id': 126,
        'district_name': 'Kabupaten Garut',
      },
    },
  ],
};

const _sampleAthleteDetailJson = {
  'success': true,
  'message': 'Detail data atlet berhasil dimuat.',
  'scope': {
    'subdistrict_id': 1728,
    'subdistrict_name': 'Garut Kota',
    'district_id': 126,
    'district_name': 'Kabupaten Garut',
  },
  'data': {
    'id': 2375,
    'code': 'KGAT-002281',
    'name': 'Abimanyu Alfathir Kumara',
    'sex': 'l',
    'sex_label': 'Laki-Laki',
    'pob': 'Garut',
    'dob': '2005-08-03',
    'age': 21,
    'photo': 'https://sicabor.test/photos/2375.jpg',
    'status': 1,
    'status_label': 'Aktif',
    'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
    'club': {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
    'domicile': {
      'subdistrict_id': 1728,
      'subdistrict_name': 'Garut Kota',
      'district_id': 126,
      'district_name': 'Kabupaten Garut',
      'village': 'Muara Sanding',
    },
    'phone': '081234567890',
    'email': 'abimanyu@example.test',
    'height': 175,
    'weight': 68,
    'blood_type': 'O',
    'address': 'Jl. Merdeka No. 45',
  },
};

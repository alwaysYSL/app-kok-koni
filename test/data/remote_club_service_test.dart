import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/club_service.dart';
import 'package:kok_app/data/services/remote/remote_club_service.dart';

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

  group('RemoteClubService', () {
    test(
      'fetchClubList calls GET /club with default parameters and returns PaginatedResult<Club>',
      () async {
        RequestOptions? capturedOptions;

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString(
              jsonEncode(_sampleClubListJson),
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

        final service = RemoteClubService(client: apiClient);
        expect(service, isA<ClubService>());

        final result = await service.fetchClubList();

        expect(capturedOptions?.path, '/club');
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

        expect(result, isA<PaginatedResult<Club>>());
        expect(result.limit, 25);
        expect(result.offset, 0);
        expect(result.total, 2);
        expect(result.items.length, 2);

        final item1 = result.items[0];
        expect(item1.id, 29);
        expect(item1.code, 'KGCL-0029');
        expect(item1.name, 'BAJA FIGHT ACADEMY');
        expect(item1.logoUrl, 'https://sicabor.test/logo/baja.png');
        expect(
          item1.cabor,
          const ClubCabor(id: 22, code: 'KGCB-0023', name: 'MUAYTHAI'),
        );
        expect(item1.headName, 'Djaka umaran');
        expect(item1.phone, '089630325024');
        expect(item1.email, 'bajafight@gmail.com');
        expect(item1.since, '2022');
        expect(item1.noSk, 'SK-029/2022');
        expect(item1.status, 1);
        expect(item1.statusLabel, 'Aktif');
        expect(
          item1.secretariat,
          const ClubAddress(
            address: 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
        );
        expect(item1.totalAthleteInClub, 15);

        final item2 = result.items[1];
        expect(item2.id, 30);
        expect(item2.code, 'KGCL-0030');
        expect(item2.name, 'GARUT RUNNERS');
        expect(item2.logoUrl, isNull);
        expect(
          item2.cabor,
          const ClubCabor(id: 10, code: 'KGCB-0010', name: 'ATLETIK'),
        );
        expect(item2.headName, isNull);
        expect(item2.phone, isNull);
        expect(item2.email, isNull);
        expect(item2.since, isNull);
        expect(item2.noSk, isNull);
        expect(item2.status, 0);
        expect(item2.statusLabel, 'Belum Aktif');
        expect(
          item2.secretariat,
          const ClubAddress(
            address: null,
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
        );
        expect(item2.totalAthleteInClub, 0);
      },
    );

    test(
      'fetchClubList sends all optional filter and sort parameters correctly',
      () async {
        RequestOptions? capturedOptions;

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString(
              jsonEncode(_sampleClubListJson),
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

        final service = RemoteClubService(client: apiClient);

        await service.fetchClubList(
          limit: 10,
          offset: 5,
          idCabor: 22,
          status: 1,
          search: 'BAJA',
          sort: 'datecreated',
        );

        expect(capturedOptions?.queryParameters, {
          'limit': 10,
          'offset': 5,
          'sort': 'datecreated',
          'id_cabor': 22,
          'status': 1,
          'search': 'BAJA',
        });
      },
    );

    test('fetchClubList parses filter_warning from meta correctly', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode(_sampleClubListWithWarningJson),
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

      final service = RemoteClubService(client: apiClient);
      final result = await service.fetchClubList(idCabor: 22);

      expect(result.hasFilterWarning, isTrue);
      expect(
        result.filterWarningMessage,
        'Data klub cabang olahraga ini sedang diverifikasi.',
      );
      expect(result.filterWarning, {
        'code': 'CLUB_VERIFICATION_PENDING',
        'message': 'Data klub cabang olahraga ini sedang diverifikasi.',
      });
    });

    test(
      'fetchClubList forwards cancellation token and handles cancellation',
      () async {
        final cancellationController = RequestCancellationController()
          ..cancel('club list cancel');

        final dio = Dio();
        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteClubService(client: apiClient);

        expect(
          () =>
              service.fetchClubList(cancellation: cancellationController.token),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('fetchClubList propagates ApiClient exceptions', () async {
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

      final service = RemoteClubService(client: apiClient);

      expect(
        () => service.fetchClubList(),
        throwsA(isA<ServerErrorException>()),
      );
    });

    test(
      'fetchClubDetail calls GET /club/detail/{id} and returns mapped ClubDetail',
      () async {
        RequestOptions? capturedOptions;

        final dio = Dio()
          ..httpClientAdapter = _FakeAdapter((options) async {
            capturedOptions = options;
            return ResponseBody.fromString(
              jsonEncode(_sampleClubDetailJson),
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

        final service = RemoteClubService(client: apiClient);
        final result = await service.fetchClubDetail(29);

        expect(capturedOptions?.path, '/club/detail/29');
        expect(capturedOptions?.method, 'GET');
        expect(
          capturedOptions?.headers['Authorization'],
          'Bearer mock-token-abc',
        );

        expect(result, isA<ClubDetail>());
        expect(result.id, 29);
        expect(result.code, 'KGCL-0029');
        expect(result.name, 'BAJA FIGHT ACADEMY');
        expect(result.logoUrl, 'https://sicabor.test/logo/baja.png');
        expect(
          result.cabor,
          const ClubCabor(id: 22, code: 'KGCB-0023', name: 'MUAYTHAI'),
        );
        expect(result.headName, 'Djaka umaran');
        expect(result.phone, '089630325024');
        expect(result.email, 'bajafight@gmail.com');
        expect(result.since, '2022');
        expect(result.noSk, 'SK-029/2022');
        expect(result.status, 1);
        expect(result.statusLabel, 'Aktif');
        expect(
          result.secretariat,
          const ClubAddress(
            address: 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
            subdistrictId: 1728,
            subdistrictName: 'Garut Kota',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
        );
        expect(result.totalAthleteInClub, 15);
        expect(
          result.training,
          const ClubAddress(
            address: 'GOR Ciateul',
            subdistrictId: 1729,
            subdistrictName: 'Tarogong Kidul',
            districtId: 126,
            districtName: 'Kabupaten Garut',
          ),
        );
        expect(result.fileSkUrl, 'https://sicabor.test/files/sk-029.pdf');
        expect(result.officials.dataAvailable, isFalse);
        expect(result.officials.reason, 'NOT_RECORDED_IN_SYSTEM');
        expect(result.officials.items, isEmpty);
        expect(result.coaches.dataAvailable, isFalse);
        expect(result.coaches.reason, 'NOT_RECORDED_IN_SYSTEM');
        expect(result.coaches.items, isEmpty);
        expect(result.management.dataAvailable, isTrue);
        expect(result.management.partial, isTrue);
        expect(result.management.source, 'club.head_name');
        expect(result.management.items.length, 1);
        expect(
          result.management.items[0],
          const ClubPersonnelItem(
            id: null,
            name: 'Djaka umaran',
            role: 'Ketua',
            phone: '089630325024',
            email: 'bajafight@gmail.com',
            photoUrl: null,
            source: 'club.head_name',
          ),
        );
      },
    );

    test(
      'fetchClubDetail forwards cancellation token and handles cancellation',
      () async {
        final cancellationController = RequestCancellationController()
          ..cancel('club detail cancel');

        final dio = Dio();
        final apiClient = ApiClient(
          profile: deploymentProfile,
          tokens: tokens,
          dio: dio,
        );

        final service = RemoteClubService(client: apiClient);

        expect(
          () => service.fetchClubDetail(
            29,
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      },
    );

    test('fetchClubDetail propagates 404 NotFoundException', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"message": "Klub tidak ditemukan.", "error_code": "CLUB_NOT_FOUND"}',
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

      final service = RemoteClubService(client: apiClient);

      expect(
        () => service.fetchClubDetail(9999),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('fetchClubDetail propagates 401 UnauthorizedException', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"message": "Sesi tidak sah", "error_code": "UNAUTHORIZED"}',
            401,
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

      final service = RemoteClubService(client: apiClient);

      expect(
        () => service.fetchClubDetail(29),
        throwsA(isA<UnauthorizedException>()),
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

const _sampleClubListJson = {
  'success': true,
  'message': 'Data klub berhasil dimuat.',
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
    'scope_basis': 'club_secretariat',
    'note': 'Daftar ini berisi klub yang beralamat di kecamatan ini.',
  },
  'data': [
    {
      'id': 29,
      'code': 'KGCL-0029',
      'name': 'BAJA FIGHT ACADEMY',
      'logo': 'https://sicabor.test/logo/baja.png',
      'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
      'head_name': 'Djaka umaran',
      'phone': '089630325024',
      'email': 'bajafight@gmail.com',
      'since': '2022',
      'no_sk': 'SK-029/2022',
      'status': 1,
      'status_label': 'Aktif',
      'secretariat': {
        'address': 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
        'subdistrict_id': 1728,
        'subdistrict_name': 'Garut Kota',
        'district_id': 126,
        'district_name': 'Kabupaten Garut',
      },
      'total_athlete_in_club': 15,
    },
    {
      'id': 30,
      'code': 'KGCL-0030',
      'name': 'GARUT RUNNERS',
      'logo': null,
      'cabor': {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
      'head_name': null,
      'phone': null,
      'email': null,
      'since': null,
      'no_sk': null,
      'status': 0,
      'status_label': 'Belum Aktif',
      'secretariat': {
        'address': null,
        'subdistrict_id': 1728,
        'subdistrict_name': 'Garut Kota',
        'district_id': 126,
        'district_name': 'Kabupaten Garut',
      },
      'total_athlete_in_club': 0,
    },
  ],
};

const _sampleClubListWithWarningJson = {
  'success': true,
  'message': 'Data klub berhasil dimuat.',
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
      'code': 'CLUB_VERIFICATION_PENDING',
      'message': 'Data klub cabang olahraga ini sedang diverifikasi.',
    },
  },
  'data': [
    {
      'id': 29,
      'code': 'KGCL-0029',
      'name': 'BAJA FIGHT ACADEMY',
      'logo': 'https://sicabor.test/logo/baja.png',
      'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
      'head_name': 'Djaka umaran',
      'phone': '089630325024',
      'email': 'bajafight@gmail.com',
      'since': '2022',
      'no_sk': 'SK-029/2022',
      'status': 1,
      'status_label': 'Aktif',
      'secretariat': {
        'address': 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
        'subdistrict_id': 1728,
        'subdistrict_name': 'Garut Kota',
        'district_id': 126,
        'district_name': 'Kabupaten Garut',
      },
      'total_athlete_in_club': 15,
    },
  ],
};

const _sampleClubDetailJson = {
  'success': true,
  'message': 'Detail data klub berhasil dimuat.',
  'scope': {
    'subdistrict_id': 1728,
    'subdistrict_name': 'Garut Kota',
    'district_id': 126,
    'district_name': 'Kabupaten Garut',
  },
  'data': {
    'id': 29,
    'code': 'KGCL-0029',
    'name': 'BAJA FIGHT ACADEMY',
    'logo': 'https://sicabor.test/logo/baja.png',
    'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
    'head_name': 'Djaka umaran',
    'phone': '089630325024',
    'email': 'bajafight@gmail.com',
    'since': '2022',
    'no_sk': 'SK-029/2022',
    'status': 1,
    'status_label': 'Aktif',
    'secretariat': {
      'address': 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
      'subdistrict_id': 1728,
      'subdistrict_name': 'Garut Kota',
      'district_id': 126,
      'district_name': 'Kabupaten Garut',
    },
    'total_athlete_in_club': 15,
    'training': {
      'address': 'GOR Ciateul',
      'subdistrict_id': 1729,
      'subdistrict_name': 'Tarogong Kidul',
      'district_id': 126,
      'district_name': 'Kabupaten Garut',
    },
    'file_sk': 'https://sicabor.test/files/sk-029.pdf',
    'officials': {
      'data_available': false,
      'reason': 'NOT_RECORDED_IN_SYSTEM',
      'data': [],
    },
    'coaches': {
      'data_available': false,
      'reason': 'NOT_RECORDED_IN_SYSTEM',
      'data': [],
    },
    'management': {
      'data_available': true,
      'partial': true,
      'source': 'club.head_name',
      'data': [
        {
          'id': null,
          'name': 'Djaka umaran',
          'role': 'Ketua',
          'phone': '089630325024',
          'email': 'bajafight@gmail.com',
          'photo': null,
          'source': 'club.head_name',
        },
      ],
    },
  },
};

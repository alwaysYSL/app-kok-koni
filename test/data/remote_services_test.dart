import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';
import 'package:kok_app/data/services/profile_service.dart';
import 'package:kok_app/data/services/remote/remote_cabor_service.dart';
import 'package:kok_app/data/services/remote/remote_profile_service.dart';

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

  group('RemoteProfileService', () {
    test('fetchProfileSummary calls GET /profile and returns mapped ProfileSummary', () async {
      RequestOptions? capturedOptions;

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode(_sampleProfileJson),
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

      final service = RemoteProfileService(client: apiClient);
      expect(service, isA<ProfileService>());
      final result = await service.fetchProfileSummary();

      expect(capturedOptions?.path, '/profile');
      expect(capturedOptions?.method, 'GET');
      expect(capturedOptions?.headers['Authorization'], 'Bearer mock-token-abc');

      expect(result, isA<ProfileSummary>());
      expect(result.scope.subdistrictId, 1);
      expect(result.scope.subdistrictName, 'Tarogong Kidul');
      expect(result.member.username, 'admin_tarogong');
      expect(result.member.name, 'Admin Tarogong Kidul');
      expect(result.kontingen?.name, 'Kecamatan Tarogong Kidul');
      expect(result.totalCabor, 12);
      expect(result.totalCaborFromClub, 10);
      expect(result.totalCaborFromAthlete, 2);
      expect(result.totalClub, 24);
      expect(result.totalAthlete, 150);
      expect(result.totalAthleteWithoutClub, 15);
      expect(result.dataNotes, ['Catatan sinkronisasi data']);
    });

    test('fetchProfileSummary forwards cancellation token and handles cancellation', () async {
      final cancellationController = RequestCancellationController()..cancel('cancelled by user');

      final dio = Dio();
      final apiClient = ApiClient(
        profile: deploymentProfile,
        tokens: tokens,
        dio: dio,
      );

      final service = RemoteProfileService(client: apiClient);

      expect(
        () => service.fetchProfileSummary(cancellation: cancellationController.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });

    test('fetchProfileSummary propagates ApiClient exceptions', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          return ResponseBody.fromString(
            '{"message": "Unauthorized", "error_code": "UNAUTHORIZED"}',
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

      final service = RemoteProfileService(client: apiClient);

      expect(
        () => service.fetchProfileSummary(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('RemoteCaborService', () {
    test('fetchCaborList calls GET /cabor with default parameters and returns PaginatedResult<Cabor>', () async {
      RequestOptions? capturedOptions;

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode(_sampleCaborJson),
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

      final service = RemoteCaborService(client: apiClient);
      expect(service, isA<CaborService>());
      final result = await service.fetchCaborList();

      expect(capturedOptions?.path, '/cabor');
      expect(capturedOptions?.method, 'GET');
      expect(capturedOptions?.queryParameters, {
        'limit': 25,
        'offset': 0,
        'source': 'all',
        'sort': 'name',
      });

      expect(result, isA<PaginatedResult<Cabor>>());
      expect(result.limit, 25);
      expect(result.offset, 0);
      expect(result.total, 2);
      expect(result.items.length, 2);

      final item1 = result.items[0];
      expect(item1.id, 1);
      expect(item1.code, 'PSSI');
      expect(item1.name, 'Sepak Bola');
      expect(item1.groupName, 'Permainan');
      expect(item1.logoUrl, 'https://example.com/logo.png');
      expect(item1.status, 1);
      expect(item1.statusLabel, 'Aktif');
      expect(item1.totalClub, 5);
      expect(item1.totalAthlete, 40);

      final item2 = result.items[1];
      expect(item2.id, 2);
      expect(item2.code, 'PBSI');
      expect(item2.name, 'Bulutangkis');
      expect(item2.groupName, 'Raket');
      expect(item2.logoUrl, isNull);
      expect(item2.status, 1);
      expect(item2.statusLabel, 'Aktif');
      expect(item2.totalClub, 3);
      expect(item2.totalAthlete, 20);
    });

    test('fetchCaborList uses custom query parameters', () async {
      RequestOptions? capturedOptions;

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode(_sampleCaborJson),
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

      final service = RemoteCaborService(client: apiClient);
      await service.fetchCaborList(
        limit: 10,
        offset: 20,
        source: 'club',
        sort: '-name',
      );

      expect(capturedOptions?.queryParameters, {
        'limit': 10,
        'offset': 20,
        'source': 'club',
        'sort': '-name',
      });
    });

    test('fetchCaborList forwards cancellation token and handles cancellation', () async {
      final cancellationController = RequestCancellationController()..cancel('cabor cancel');

      final dio = Dio();
      final apiClient = ApiClient(
        profile: deploymentProfile,
        tokens: tokens,
        dio: dio,
      );

      final service = RemoteCaborService(client: apiClient);

      expect(
        () => service.fetchCaborList(cancellation: cancellationController.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });

    test('fetchCaborList propagates ApiClient exceptions', () async {
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

      final service = RemoteCaborService(client: apiClient);

      expect(
        () => service.fetchCaborList(),
        throwsA(isA<ServerErrorException>()),
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
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

const _sampleProfileJson = {
  'success': true,
  'message': 'Data profil berhasil dimuat.',
  'scope': {
    'subdistrict_id': 1,
    'subdistrict_name': 'Tarogong Kidul',
    'district_id': 3205,
    'district_name': 'Kabupaten Garut',
  },
  'data': {
    'member': {
      'id': 10,
      'username': 'admin_tarogong',
      'name': 'Admin Tarogong Kidul',
      'email': 'tarogong@kok.garutkab.go.id',
      'type': 'admin_kok',
      'status': 1,
      'status_label': 'Aktif',
    },
    'kontingen': {
      'id': 5,
      'code': 'TRG',
      'name': 'Kecamatan Tarogong Kidul',
    },
    'summary': {
      'total_cabor': 12,
      'total_cabor_from_club': 10,
      'total_cabor_from_athlete': 2,
      'total_club': 24,
      'total_athlete': 150,
      'total_athlete_without_club': 15,
    },
    'data_notes': ['Catatan sinkronisasi data'],
  },
};

const _sampleCaborJson = {
  'success': true,
  'message': 'Data cabang olahraga berhasil dimuat.',
  'scope': {
    'subdistrict_id': 1,
    'subdistrict_name': 'Tarogong Kidul',
    'district_id': 3205,
    'district_name': 'Kabupaten Garut',
  },
  'meta': {
    'limit': 25,
    'offset': 0,
    'total': 2,
  },
  'data': [
    {
      'id': 1,
      'code': 'PSSI',
      'name': 'Sepak Bola',
      'group_name': 'Permainan',
      'logo': 'https://example.com/logo.png',
      'status': 1,
      'status_label': 'Aktif',
      'total_club': 5,
      'total_athlete': 40,
    },
    {
      'id': 2,
      'code': 'PBSI',
      'name': 'Bulutangkis',
      'group_name': 'Raket',
      'logo': null,
      'status': 1,
      'status_label': 'Aktif',
      'total_club': 3,
      'total_athlete': 20,
    },
  ],
};

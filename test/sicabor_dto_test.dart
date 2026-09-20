import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_error_response.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_login_response.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';

void main() {
  group('SicaborLoginResponse', () {
    test('parses login envelope with status and token', () {
      final json = {
        'status': true,
        'message': 'LOGIN SUCCESSFULLY',
        'data': {
          'id': '578',
          'username': 'kt.garutkota',
          'name': 'ADMIN KONTINGEN GARUT KOTA',
          'email': null,
          'type': 'admin_kok',
        },
        'token': 'mock_jwt_token_123',
      };
      final res = SicaborLoginResponse.fromJson(json);
      expect(res.status, isTrue);
      expect(res.message, equals('LOGIN SUCCESSFULLY'));
      expect(res.token, equals('mock_jwt_token_123'));
      expect(res.data, isNotNull);
      expect(res.data?.id, equals('578'));
      expect(res.data?.username, equals('kt.garutkota'));
      expect(res.data?.name, equals('ADMIN KONTINGEN GARUT KOTA'));
      expect(res.data?.email, isNull);
      expect(res.data?.type, equals('admin_kok'));
    });

    test('parses login envelope with null data and token', () {
      final json = {
        'status': false,
        'message': 'Invalid credentials',
        'data': null,
        'token': null,
      };
      final res = SicaborLoginResponse.fromJson(json);
      expect(res.status, isFalse);
      expect(res.message, equals('Invalid credentials'));
      expect(res.data, isNull);
      expect(res.token, isNull);
    });

    test('toJson and fromJson round-trip', () {
      const response = SicaborLoginResponse(
        status: true,
        message: 'OK',
        data: SicaborLoginData(
          id: '123',
          username: 'user1',
          name: 'User One',
          email: 'user@example.com',
          type: 'admin_kok',
        ),
        token: 'token_abc',
      );

      final json = response.toJson();
      final fromJson = SicaborLoginResponse.fromJson(json);

      expect(fromJson.status, equals(response.status));
      expect(fromJson.message, equals(response.message));
      expect(fromJson.token, equals(response.token));
      expect(fromJson.data?.id, equals(response.data?.id));
      expect(fromJson.data?.username, equals(response.data?.username));
      expect(fromJson.data?.name, equals(response.data?.name));
      expect(fromJson.data?.email, equals(response.data?.email));
      expect(fromJson.data?.type, equals(response.data?.type));
    });
  });

  group('SicaborProfileResponse', () {
    test(
      'parses profile envelope with scope, member, kontingen, summary, and data_notes',
      () {
        final json = {
          'success': true,
          'message': 'Berhasil mengambil data.',
          'scope': {
            'subdistrict_id': 1714,
            'subdistrict_name': 'Blubur Limbangan',
            'district_id': 126,
            'district_name': 'Garut',
          },
          'data': {
            'member': {
              'id': 560,
              'username': 'kt.bllimbangan',
              'name': 'ADMIN KONTINGEN BL.LIMBANGAN',
              'email': null,
              'type': 'admin_kok',
              'status': 1,
              'status_label': 'Aktif',
            },
            'kontingen': {
              'id': 3,
              'code': 'KGPK-0044',
              'name': 'Balubur Limbangan',
            },
            'summary': {
              'total_cabor': 17,
              'total_cabor_from_club': 0,
              'total_cabor_from_athlete': 17,
              'total_club': 0,
              'total_athlete': 159,
              'total_athlete_without_club': 159,
            },
            'data_notes': ['Catatan batasan data 1'],
          },
        };

        final res = SicaborProfileResponse.fromJson(json);
        expect(res.success, isTrue);
        expect(res.message, equals('Berhasil mengambil data.'));
        expect(res.scope.subdistrictId, equals(1714));
        expect(res.scope.subdistrictName, equals('Blubur Limbangan'));
        expect(res.scope.districtId, equals(126));
        expect(res.scope.districtName, equals('Garut'));
        expect(res.data.member.id, equals(560));
        expect(res.data.member.username, equals('kt.bllimbangan'));
        expect(res.data.member.name, equals('ADMIN KONTINGEN BL.LIMBANGAN'));
        expect(res.data.member.email, isNull);
        expect(res.data.member.type, equals('admin_kok'));
        expect(res.data.member.status, equals(1));
        expect(res.data.member.statusLabel, equals('Aktif'));
        expect(res.data.kontingen, isNotNull);
        expect(res.data.kontingen?.id, equals(3));
        expect(res.data.kontingen?.code, equals('KGPK-0044'));
        expect(res.data.kontingen?.name, equals('Balubur Limbangan'));
        expect(res.data.summary.totalCabor, equals(17));
        expect(res.data.summary.totalCaborFromClub, equals(0));
        expect(res.data.summary.totalCaborFromAthlete, equals(17));
        expect(res.data.summary.totalClub, equals(0));
        expect(res.data.summary.totalAthlete, equals(159));
        expect(res.data.summary.totalAthleteWithoutClub, equals(159));
        expect(res.data.dataNotes, contains('Catatan batasan data 1'));
      },
    );

    test(
      'parses profile envelope with null kontingen and missing data_notes',
      () {
        final json = {
          'success': true,
          'message': 'OK',
          'scope': {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Garut',
          },
          'data': {
            'member': {
              'id': 578,
              'username': 'kt.garutkota',
              'name': 'ADMIN KONTINGEN GARUT KOTA',
              'email': 'garutkota@koni.id',
              'type': 'admin_kok',
              'status': 1,
              'status_label': 'Aktif',
            },
            'kontingen': null,
            'summary': {
              'total_cabor': 10,
              'total_cabor_from_club': 2,
              'total_cabor_from_athlete': 8,
              'total_club': 5,
              'total_athlete': 40,
              'total_athlete_without_club': 10,
            },
          },
        };

        final res = SicaborProfileResponse.fromJson(json);
        expect(res.data.kontingen, isNull);
        expect(res.data.dataNotes, isEmpty);
        expect(res.data.member.email, equals('garutkota@koni.id'));
      },
    );

    test('toJson and fromJson round-trip for SicaborProfileResponse', () {
      const response = SicaborProfileResponse(
        success: true,
        message: 'Success',
        scope: SicaborScope(
          subdistrictId: 100,
          subdistrictName: 'Subdistrict A',
          districtId: 200,
          districtName: 'District B',
        ),
        data: SicaborProfileData(
          member: SicaborMember(
            id: 1,
            username: 'admin1',
            name: 'Admin One',
            email: 'admin@test.com',
            type: 'admin_kok',
            status: 1,
            statusLabel: 'Aktif',
          ),
          kontingen: SicaborKontingen(
            id: 10,
            code: 'K-01',
            name: 'Kontingen A',
          ),
          summary: SicaborSummary(
            totalCabor: 5,
            totalCaborFromClub: 2,
            totalCaborFromAthlete: 3,
            totalClub: 4,
            totalAthlete: 20,
            totalAthleteWithoutClub: 5,
          ),
          dataNotes: ['Note A', 'Note B'],
        ),
      );

      final json = response.toJson();
      final fromJson = SicaborProfileResponse.fromJson(json);

      expect(fromJson.success, equals(response.success));
      expect(fromJson.message, equals(response.message));
      expect(
        fromJson.scope.subdistrictId,
        equals(response.scope.subdistrictId),
      );
      expect(
        fromJson.scope.subdistrictName,
        equals(response.scope.subdistrictName),
      );
      expect(fromJson.scope.districtId, equals(response.scope.districtId));
      expect(fromJson.scope.districtName, equals(response.scope.districtName));
      expect(fromJson.data.member.id, equals(response.data.member.id));
      expect(
        fromJson.data.member.username,
        equals(response.data.member.username),
      );
      expect(fromJson.data.member.name, equals(response.data.member.name));
      expect(fromJson.data.member.email, equals(response.data.member.email));
      expect(fromJson.data.member.type, equals(response.data.member.type));
      expect(fromJson.data.member.status, equals(response.data.member.status));
      expect(
        fromJson.data.member.statusLabel,
        equals(response.data.member.statusLabel),
      );
      expect(fromJson.data.kontingen?.id, equals(response.data.kontingen?.id));
      expect(
        fromJson.data.kontingen?.code,
        equals(response.data.kontingen?.code),
      );
      expect(
        fromJson.data.kontingen?.name,
        equals(response.data.kontingen?.name),
      );
      expect(
        fromJson.data.summary.totalCabor,
        equals(response.data.summary.totalCabor),
      );
      expect(fromJson.data.dataNotes, equals(response.data.dataNotes));
    });
  });

  group('SicaborErrorResponse', () {
    test('parses error envelope with error_code', () {
      final json = {
        'success': false,
        'message': 'Endpoint ini hanya dapat diakses oleh akun KOK.',
        'error_code': 'NOT_KOK',
      };
      final res = SicaborErrorResponse.fromJson(json);
      expect(res.success, isFalse);
      expect(
        res.message,
        equals('Endpoint ini hanya dapat diakses oleh akun KOK.'),
      );
      expect(res.errorCode, equals('NOT_KOK'));
    });

    test('parses error envelope without error_code', () {
      final json = {'success': false, 'message': 'Internal error occurred.'};
      final res = SicaborErrorResponse.fromJson(json);
      expect(res.success, isFalse);
      expect(res.message, equals('Internal error occurred.'));
      expect(res.errorCode, isNull);
    });

    test('toJson and fromJson round-trip for SicaborErrorResponse', () {
      const response = SicaborErrorResponse(
        success: false,
        message: 'Unauthorized',
        errorCode: 'MEMBER_NOT_FOUND',
      );
      final json = response.toJson();
      final fromJson = SicaborErrorResponse.fromJson(json);

      expect(fromJson.success, equals(response.success));
      expect(fromJson.message, equals(response.message));
      expect(fromJson.errorCode, equals(response.errorCode));
    });
  });
}
